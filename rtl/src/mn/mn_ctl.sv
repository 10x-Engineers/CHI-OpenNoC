/*
* Copyright (c) 2026 10xEngineers
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*/

`include "mn_defines.svh"
`include "mn_param.svh"

// The MN's protocol layer: a tracker of DVMOp transactions, each taken through
// SS2.3.7's (p.2-76) separate-response flow -- DBIDResp, NCBWrData, then Comp once
// every snoopee has answered its SnpDVMOp pair (SS8.1.1 p.8-305; no early Comp).
//
// A Sync broadcasts only after every Non-sync the tracker held when the Sync
// arrived has completed, so its SnpResp -- sent "after all DVM related operations
// are complete" (SS8.1.2 p.8-307) -- covers them, and its Comp follows theirs.
//
// Entry index is the DBID and the SnpDVMOp TxnID.
module mn_ctl `MN_PARAM
    (
    input  wire                         clk_i,
    input  wire                         rst_i,

    input  wire                         rxreqflitv_i,
    input  chie_pkg::req_flit_s         rxreqflit_i,
    input  wire                         rxrspflitv_i,
    input  chie_pkg::rsp_flit_s         rxrspflit_i,
    input  wire                         rxdatflitv_i,
    input  chie_pkg::dat_flit_s         rxdatflit_i,
    output wire [1:0]                   req_free_o,

    output wire                         txrspflitv_o,
    output chie_pkg::rsp_flit_s         txrspflit_o,
    input  wire                         txrspflit_sent_i,
    output wire                         txsnpflitv_o,
    output opennoc_mn_pkg::snp_routed_s txsnpflit_o,
    input  wire                         txsnpflit_sent_i,

    input  wire [MN_RN_NUM_PARAM-1:0]   sysco_snp_en_i,
    output logic [MN_RN_NUM_PARAM-1:0]  sysco_snp_pend_o,

    // a transaction is in progress (SS14.7.2 p.14-460)
    output wire                         busy_o
    );

    localparam int N   = MN_ENTRIES_NUM_PARAM;
    localparam int IW  = MN_ENTRIES_WIDTH_PARAM;
    localparam int R   = MN_RN_NUM_PARAM;
    localparam int RW  = (R > 1) ? $clog2(R) : 1;
    localparam int NW  = CHIE_NID_WIDTH_PARAM;
    localparam int CNW = $clog2(N + 1);
    localparam int OW  = $clog2(MN_RN_SNPDVM_NUM_PARAM + 1);
    localparam int RCW = `MN_RETRY_CNT_WIDTH;

    typedef enum logic [2:0] {
        E_FREE,
        E_DBID,    // DBIDResp owed
        E_DATA,    // awaiting NCBWrData
        E_ORDER,   // Sync: awaiting the older Non-syncs
        E_SNP,     // SnpDVMOp pairs to send, SnpResps to collect
        E_COMP     // Comp owed
    } ent_st_e;

    ent_st_e                             st_q     [N];
    logic                                sync_q   [N];
    logic [NW-1:0]                       srcid_q  [N];
    logic [11:0]                         txnid_q  [N];
    logic [3:0]                          qos_q    [N];
    logic                                trace_q  [N];
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0] addr_q   [N];
    logic [63:0]                         data_q   [N];
    chie_pkg::resp_err_e                 err_q    [N];
    logic [N-1:0]                        older_q  [N];
    logic [R-1:0]                        todo_q   [N];
    logic [R-1:0]                        pend_q   [N];

    logic [NW-1:0] rn_nid [R];
    always_comb
        for (int r = 0; r < R; r++)
            rn_nid[r] = MN_RN_NID_LIST_PARAM[r*NW +: NW];

    // The MN_RN_NID_LIST_PARAM place of a NodeID, as {found, index}.
    function automatic logic [RW:0] rn_idx(logic [NW-1:0] nid);
        rn_idx = '0;
        for (int r = 0; r < R; r++)
            if (!rn_idx[RW] && (MN_RN_NID_LIST_PARAM[r*NW +: NW] == nid))
                rn_idx = {1'b1, RW'(r)};
    endfunction

    // The first set bit at or after `start`, wrapping.
    function automatic int rr_pick(logic [N-1:0] vec, int start);
        rr_pick = -1;
        for (int k = 0; k < N; k++)
            if (rr_pick < 0 && vec[(start + k) % N]) rr_pick = (start + k) % N;
    endfunction

    //*************************************************
    //                 Occupancy
    //*************************************************
    logic [CNW-1:0] busy_cnt, sync_cnt;
    logic [N-1:0]   ent_free, ent_ns;
    always_comb begin
        busy_cnt = '0;
        sync_cnt = '0;
        for (int e = 0; e < N; e++) begin
            ent_free[e] = (st_q[e] == E_FREE);
            ent_ns[e]   = (st_q[e] != E_FREE) & ~sync_q[e];
            busy_cnt    = busy_cnt + CNW'(st_q[e] != E_FREE);
            sync_cnt    = sync_cnt + CNW'((st_q[e] != E_FREE) & sync_q[e]);
        end
    end

    // P-Credits granted and not yet used, per class; RetryAck'd requests awaiting one.
    logic [CNW-1:0] resv_q  [2];
    logic [RCW-1:0] retry_q [R][2];
    logic [1:0]     retry_waiting;
    always_comb begin
        retry_waiting = '0;
        for (int r = 0; r < R; r++)
            for (int c = 0; c < 2; c++)
                if (retry_q[r][c] != '0) retry_waiting[c] = 1'b1;
    end

    //*************************************************
    //                 Request intake
    //*************************************************
    wire                 req_dvm    = rxreqflitv_i & (rxreqflit_i.opcode == chie_pkg::REQ_DVMOP);
    wire                 req_sync   = opennoc_mn_pkg::dvm_is_sync(rxreqflit_i.addr);
    wire                 req_retry1 = rxreqflit_i.allowretry;

    // SS8.1.3 (p.8-307, MUST): at least one entry reserved for DVMOp(Non-Sync), so
    // Syncs, held or credited, never fill the tracker.
    wire [CNW-1:0] free_n    = CNW'(N) - busy_cnt - resv_q[0] - resv_q[1];
    wire           sync_room = (sync_cnt + resv_q[1]) < CNW'(N - 1);
    wire           room      = (free_n != '0) & (~req_sync | sync_room);

    // A request that may be retried does not overtake a RetryAck'd one of its class,
    // nor take the last free entry from the other class's P-Credit. One resent with
    // AllowRetry deasserted spends the P-Credit granted for it (SS2.11 p.2-145).
    wire other_owed = req_sync ? retry_waiting[0] : (retry_waiting[1] & sync_room);
    wire req_alloc  = req_dvm & (~req_retry1 |
                                 (room & ~retry_waiting[req_sync] & (free_n > CNW'(other_owed))));
    wire req_rtack = req_dvm & req_retry1 & ~req_alloc;

    int alloc_e;
    always_comb alloc_e = rr_pick(ent_free, 0);

    //*************************************************
    //                 RetryAck queue
    //*************************************************
    // Every queued RetryAck holds its REQ L-Credit, so the queue can never overfill.
    chie_pkg::retry_ackq_s rtq_in, rtq_out;
    wire                   rtq_empty, rtq_full;
    wire                   rtq_pop;

    always_comb begin
        rtq_in          = '0;
        rtq_in.pcrdtype = req_sync ? `MN_PCRD_SYNC : `MN_PCRD_NONSYNC;
        rtq_in.trace    = rxreqflit_i.tracetag;
        rtq_in.qos      = rxreqflit_i.qos;
        rtq_in.txnid    = rxreqflit_i.txnid;
        rtq_in.srcid    = rxreqflit_i.srcid;
    end

    sync_fifo #(
        .FIFO_ENTRIES_WIDTH ($bits(chie_pkg::retry_ackq_s)),
        .FIFO_ENTRIES_DEPTH (16)
    ) u_retry_ackq (
        .clk      (clk_i     ),
        .rst      (rst_i     ),
        .push     (req_rtack ),
        .pop      (rtq_pop   ),
        .data_in  (rtq_in    ),
        .data_out (rtq_out   ),
        .empty    (rtq_empty ),
        .full     (rtq_full  ),
        .count    (          )
    );

    //*************************************************
    //                 PCrdGrant
    //*************************************************
    // Measured after this cycle's intake, so a grant and an arrival never both take
    // the last entry. The classes alternate when both can be granted; a Sync never
    // takes the Non-sync entry (SS8.1.3 p.8-307, MUST), so a Non-sync always gets one.
    logic           pg_v_q;
    logic [RW-1:0]  pg_rn_q;
    logic           pg_sync_q;
    logic [RW-1:0]  pg_ptr_q;
    logic           pg_prio_q;
    wire            pg_sent;

    wire            alloc_takes_free = req_alloc & req_retry1;
    wire [CNW-1:0]  free_after       = free_n - CNW'(alloc_takes_free);
    wire            sync_room_after  = (sync_cnt + resv_q[1] + CNW'(alloc_takes_free & req_sync)) < CNW'(N - 1);
    wire            pg_ns_ok         = ~pg_v_q & retry_waiting[0] & (free_after != '0);
    wire            pg_s_ok          = ~pg_v_q & retry_waiting[1] & (free_after != '0) & sync_room_after;
    wire            pg_s             = pg_s_ok & (~pg_ns_ok | pg_prio_q);
    wire            pg_new           = pg_ns_ok | pg_s_ok;

    logic [RW-1:0]  pg_pick;
    always_comb begin
        logic done;
        pg_pick = '0;
        done    = 1'b0;
        for (int k = 0; k < R; k++) begin
            int r;
            r = (int'(pg_ptr_q) + k) % R;
            if (!done && (retry_q[r][pg_s] != '0)) begin
                pg_pick = RW'(r);
                done    = 1'b1;
            end
        end
    end

    //*************************************************
    //                 Snoop issue
    //*************************************************
    // SS8.1.3 (p.8-307/8-308, MUST): a SnpDVMOp goes only to a snoopee with room for
    // both parts; only one Sync is outstanding to it, and it can always take one
    // Non-sync beside that Sync -- so at most MN_RN_SNPDVM_NUM_PARAM-1 Non-syncs.
    // SPEC-AMBIGUITY: SS8.1.3 does not say whether a snoopee's declared count may be
    // spent on Non-syncs alone; holding one place for a Sync is safe under either reading.
    logic [OW-1:0] ns_out_q   [R];
    logic          sync_out_q [R];

    logic          iss_v_q, iss_p2_q;
    logic [IW-1:0] iss_e_q;
    logic [RW-1:0] iss_t_q;
    logic [IW-1:0] iss_ptr_q;

    logic [R-1:0] cand   [N];
    logic [N-1:0] ent_can;
    always_comb
        for (int e = 0; e < N; e++) begin
            for (int t = 0; t < R; t++)
                cand[e][t] = (st_q[e] == E_SNP) & todo_q[e][t] & sysco_snp_en_i[t] &
                             (sync_q[e] ? ~sync_out_q[t]
                                        : (ns_out_q[t] < OW'(MN_RN_SNPDVM_NUM_PARAM - 1)));
            ent_can[e] = |cand[e];
        end

    int            iss_pick_e;
    logic [RW-1:0] iss_pick_t;
    always_comb begin
        logic done;
        iss_pick_e = rr_pick(ent_can, int'(iss_ptr_q));
        iss_pick_t = '0;
        done       = 1'b0;
        if (iss_pick_e >= 0)
            for (int t = 0; t < R; t++)
                if (!done && cand[iss_pick_e][t]) begin
                    iss_pick_t = RW'(t);
                    done       = 1'b1;
                end
    end

    wire           iss_start   = ~iss_v_q & (iss_pick_e >= 0);
    wire [IW-1:0]  iss_pick_ei = IW'(iss_start ? iss_pick_e : 0);
    wire iss_done  = iss_v_q & iss_p2_q & txsnpflit_sent_i;

    opennoc_mn_pkg::dvm_snp_part_s snp_part;
    always_comb begin
        snp_part                   = opennoc_mn_pkg::dvm_snp_part(iss_p2_q, addr_q[iss_e_q], data_q[iss_e_q]);
        txsnpflit_o                = '0;
        txsnpflit_o.tgtid          = rn_nid[iss_t_q];
        txsnpflit_o.flit.qos       = qos_q[iss_e_q];
        txsnpflit_o.flit.srcid     = NW'(MN_NID_PARAM);
        txsnpflit_o.flit.txnid     = 12'(iss_e_q);
        txsnpflit_o.flit.fwdnid    = snp_part.fwdnid;
        txsnpflit_o.flit.fwdtxnid  = 12'(snp_part.vmidext);
        txsnpflit_o.flit.opcode    = chie_pkg::SNP_SNPDVMOP;
        txsnpflit_o.flit.addr      = snp_part.addr;
        txsnpflit_o.flit.tracetag  = trace_q[iss_e_q];
        // Table 8-3 (p.8-311): NS, DoNotGoToSD and RetToSrc zero, MPAM all zeros.
    end
    assign txsnpflitv_o = iss_v_q;

    //*************************************************
    //                 Responses in
    //*************************************************
    wire           rsp_snp = rxrspflitv_i & (rxrspflit_i.opcode == chie_pkg::RSP_SNPRESP);
    wire [IW-1:0]  rsp_e   = rxrspflit_i.txnid[IW-1:0];
    wire           rsp_t_found;
    wire  [RW-1:0] rsp_t;
    assign {rsp_t_found, rsp_t} = rn_idx(rxrspflit_i.srcid);
    wire           rsp_ok  = rsp_snp & rsp_t_found & (rxrspflit_i.txnid < 12'(N)) &&
                             (st_q[rsp_e] == E_SNP) && pend_q[rsp_e][rsp_t];

    // Table 8-2 (p.8-310): the NCBWrData's TxnID is the DBID, which is the entry.
    wire           dat_wr  = rxdatflitv_i & (rxdatflit_i.opcode == chie_pkg::DAT_NONCOPYBACKWRDATA);
    wire [IW-1:0]  dat_e   = rxdatflit_i.txnid[IW-1:0];
    wire           dat_ok  = dat_wr & (rxdatflit_i.txnid < 12'(N)) && (st_q[dat_e] == E_DATA);

    //*************************************************
    //                 Responses out
    //*************************************************
    logic [N-1:0] ent_rsp;
    always_comb
        for (int e = 0; e < N; e++)
            ent_rsp[e] = (st_q[e] == E_DBID) | (st_q[e] == E_COMP);

    logic [IW-1:0] rsp_ptr_q;
    int            rsp_pick;
    always_comb rsp_pick = rr_pick(ent_rsp, int'(rsp_ptr_q));

    wire use_ent = (rsp_pick >= 0);
    wire use_rtq = ~use_ent & ~rtq_empty;
    wire use_pg  = ~use_ent & rtq_empty & pg_v_q;
    wire [IW-1:0] rsp_pick_e = IW'(use_ent ? rsp_pick : 0);

    always_comb begin
        txrspflit_o = '0;
        if (use_ent) begin
            // Tables 8-4 and 8-6 (p.8-312/8-314): Resp and PCrdType zero; the DBIDResp's
            // RespErr is OK (SS9.4.5 p.9-344), the Comp's carries what was consolidated.
            txrspflit_o.qos      = qos_q[rsp_pick_e];
            txrspflit_o.srcid    = NW'(MN_NID_PARAM);
            txrspflit_o.tgtid    = srcid_q[rsp_pick_e];
            txrspflit_o.txnid    = txnid_q[rsp_pick_e];
            txrspflit_o.dbid     = 12'(rsp_pick_e);
            txrspflit_o.tracetag = trace_q[rsp_pick_e];
            if (st_q[rsp_pick_e] == E_DBID)
                txrspflit_o.opcode = chie_pkg::RSP_DBIDRESP;
            else begin
                txrspflit_o.opcode  = chie_pkg::RSP_COMP;
                txrspflit_o.resperr = err_q[rsp_pick_e];
            end
        end
        else if (use_rtq) begin
            txrspflit_o.qos      = rtq_out.qos;
            txrspflit_o.srcid    = NW'(MN_NID_PARAM);
            txrspflit_o.tgtid    = rtq_out.srcid;
            txrspflit_o.txnid    = rtq_out.txnid;
            txrspflit_o.opcode   = chie_pkg::RSP_RETRYACK;
            txrspflit_o.pcrdtype = rtq_out.pcrdtype;
            txrspflit_o.tracetag = rtq_out.trace;
        end
        else begin
            // SS2.6.5 (p.2-111): a PCrdGrant's TxnID is zero.
            txrspflit_o.srcid    = NW'(MN_NID_PARAM);
            txrspflit_o.tgtid    = rn_nid[pg_rn_q];
            txrspflit_o.opcode   = chie_pkg::RSP_PCRDGRANT;
            txrspflit_o.pcrdtype = pg_sync_q ? `MN_PCRD_SYNC : `MN_PCRD_NONSYNC;
        end
    end

    assign txrspflitv_o = use_ent | use_rtq | use_pg;
    wire   ent_rsp_sent = txrspflit_sent_i & use_ent;
    assign rtq_pop      = txrspflit_sent_i & use_rtq;
    assign pg_sent      = txrspflit_sent_i & use_pg;

    wire           rtq_rn_found;
    wire  [RW-1:0] rtq_rn;
    assign {rtq_rn_found, rtq_rn} = rn_idx(rtq_out.srcid);
    wire           rtq_cls = (rtq_out.pcrdtype == `MN_PCRD_SYNC);

    wire   req_taken  = rxreqflitv_i & ~req_rtack;
    assign req_free_o = {1'b0, req_taken} + {1'b0, rtq_pop};

    //*************************************************
    //                 State
    //*************************************************
    wire [N-1:0] retire = {N{ent_rsp_sent & (st_q[rsp_pick_e] == E_COMP)}} & (N'(1) << rsp_pick_e);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            for (int e = 0; e < N; e++) begin
                st_q[e]    <= E_FREE;
                sync_q[e]  <= 1'b0;
                srcid_q[e] <= '0;
                txnid_q[e] <= '0;
                qos_q[e]   <= '0;
                trace_q[e] <= 1'b0;
                addr_q[e]  <= '0;
                data_q[e]  <= '0;
                err_q[e]   <= chie_pkg::RESP_ERR_NORM_OK;
                older_q[e] <= '0;
                todo_q[e]  <= '0;
                pend_q[e]  <= '0;
            end
        end
        else begin
            for (int e = 0; e < N; e++) begin
                older_q[e] <= older_q[e] & ~retire;

                case (st_q[e])
                    E_FREE:
                        if (req_alloc && (alloc_e == e)) begin
                            st_q[e]    <= E_DBID;
                            sync_q[e]  <= req_sync;
                            srcid_q[e] <= rxreqflit_i.srcid;
                            txnid_q[e] <= rxreqflit_i.txnid;
                            qos_q[e]   <= rxreqflit_i.qos;
                            trace_q[e] <= rxreqflit_i.tracetag;
                            addr_q[e]  <= rxreqflit_i.addr;
                            err_q[e]   <= chie_pkg::RESP_ERR_NORM_OK;
                            older_q[e] <= req_sync ? (ent_ns & ~retire) : '0;
                        end
                    E_DBID:
                        if (ent_rsp_sent && (rsp_pick_e == IW'(e)))
                            st_q[e] <= E_DATA;
                    E_DATA:
                        if (dat_ok && (dat_e == IW'(e))) begin
                            logic [R-1:0] tgt;
                            // SS8.1.1 (p.8-305) and Figures 8-1/8-2: every DVM-capable
                            // Requester other than the one that asked.
                            // SPEC-AMBIGUITY: step 4 says "all the RN-F and RN-D nodes";
                            // both figures leave the Requester out, and this follows them.
                            for (int t = 0; t < R; t++)
                                tgt[t] = (rn_nid[t] != srcid_q[e]) & sysco_snp_en_i[t];
                            st_q[e]   <= sync_q[e] ? E_ORDER : E_SNP;
                            data_q[e] <= rxdatflit_i.data[63:0];
                            todo_q[e] <= tgt;
                            pend_q[e] <= '0;
                            // SS9.4.5 (p.9-344): the Comp carries the error consolidated
                            // from the write data and every snoop response.
                            if (rxdatflit_i.resperr == chie_pkg::RESP_ERR_DATA)
                                err_q[e] <= chie_pkg::RESP_ERR_DATA;
                        end
                    E_ORDER:
                        if ((older_q[e] & ~retire) == '0)
                            st_q[e] <= E_SNP;
                    E_SNP: begin
                        logic [R-1:0] todo_n, pend_n;
                        // Table 15-1 (p.15-468, MUST): no new snoop to a Requester
                        // that has left the coherency domain.
                        todo_n = todo_q[e] & sysco_snp_en_i;
                        pend_n = pend_q[e];
                        if (iss_done && (iss_e_q == IW'(e))) begin
                            todo_n[iss_t_q] = 1'b0;
                            pend_n[iss_t_q] = 1'b1;
                        end
                        if (rsp_ok && (rsp_e == IW'(e))) begin
                            pend_n[rsp_t] = 1'b0;
                            if ((rxrspflit_i.resperr != chie_pkg::RESP_ERR_NORM_OK) &&
                                (err_q[e] == chie_pkg::RESP_ERR_NORM_OK))
                                err_q[e] <= chie_pkg::RESP_ERR_NON_DATA;
                        end
                        todo_q[e] <= todo_n;
                        pend_q[e] <= pend_n;
                        if ((todo_n == '0) && (pend_n == '0))
                            st_q[e] <= E_COMP;
                    end
                    E_COMP:
                        if (retire[e])
                            st_q[e] <= E_FREE;
                    default:
                        st_q[e] <= E_FREE;
                endcase
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            iss_v_q   <= 1'b0;
            iss_p2_q  <= 1'b0;
            iss_e_q   <= '0;
            iss_t_q   <= '0;
            iss_ptr_q <= '0;
        end
        else if (iss_start) begin
            iss_v_q   <= 1'b1;
            iss_p2_q  <= 1'b0;
            iss_e_q   <= iss_pick_ei;
            iss_t_q   <= iss_pick_t;
            iss_ptr_q <= IW'((iss_pick_e + 1) % N);
        end
        else if (iss_v_q && txsnpflit_sent_i) begin
            iss_p2_q <= 1'b1;
            if (iss_p2_q)
                iss_v_q <= 1'b0;
        end
    end

    // A snoopee's places are taken when its pair is chosen and given back by its SnpResp.
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            for (int t = 0; t < R; t++) begin
                ns_out_q[t]   <= '0;
                sync_out_q[t] <= 1'b0;
            end
        end
        else begin
            for (int t = 0; t < R; t++) begin
                logic take, give, ns_take, ns_give;
                take    = iss_start & (iss_pick_t == RW'(t));
                give    = rsp_ok & (rsp_t == RW'(t));
                ns_take = take & ~sync_q[iss_pick_ei];
                ns_give = give & ~sync_q[rsp_e];
                if (take && sync_q[iss_pick_ei])
                    sync_out_q[t] <= 1'b1;
                else if (give && sync_q[rsp_e])
                    sync_out_q[t] <= 1'b0;
                ns_out_q[t] <= ns_out_q[t] + OW'(ns_take) - OW'(ns_give);
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            rsp_ptr_q <= '0;
        else if (ent_rsp_sent)
            rsp_ptr_q <= IW'((rsp_pick + 1) % N);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            resv_q[0] <= '0;
            resv_q[1] <= '0;
            pg_v_q    <= 1'b0;
            pg_rn_q   <= '0;
            pg_sync_q <= 1'b0;
            pg_ptr_q  <= '0;
            pg_prio_q <= 1'b0;
            for (int r = 0; r < R; r++) begin
                retry_q[r][0] <= '0;
                retry_q[r][1] <= '0;
            end
        end
        else begin
            for (int c = 0; c < 2; c++) begin
                logic grant, spend;
                grant = pg_new & (pg_s == 1'(c));
                spend = req_alloc & ~req_retry1 & (rxreqflit_i.pcrdtype == 4'(c));
                resv_q[c] <= resv_q[c] + CNW'(grant) - CNW'(spend);
            end
            for (int r = 0; r < R; r++)
                for (int c = 0; c < 2; c++) begin
                    logic acked, granted;
                    acked   = rtq_pop & rtq_rn_found & (rtq_rn == RW'(r)) & (rtq_cls == 1'(c));
                    granted = pg_new & (pg_pick == RW'(r)) & (pg_s == 1'(c));
                    retry_q[r][c] <= retry_q[r][c] + RCW'(acked) - RCW'(granted);
                end
            if (pg_new) begin
                pg_v_q    <= 1'b1;
                pg_rn_q   <= pg_pick;
                pg_sync_q <= pg_s;
                pg_ptr_q  <= RW'((int'(pg_pick) + 1) % R);
                pg_prio_q <= ~pg_s;
            end
            else if (pg_sent)
                pg_v_q <= 1'b0;
        end
    end

    // SS15.2.2 (p.15-468, MUST): the owner of SYSCOACK completes every snoop to a
    // Requester before dropping it, a pair in flight included.
    always_comb
        for (int t = 0; t < R; t++)
            sysco_snp_pend_o[t] = (ns_out_q[t] != '0) | sync_out_q[t];

    logic any_resv_or_retry;
    always_comb begin
        any_resv_or_retry = (resv_q[0] != '0) | (resv_q[1] != '0) | (|retry_waiting);
    end

    assign busy_o = ~(&ent_free) | ~rtq_empty | pg_v_q | any_resv_or_retry;

`ifdef ASSERT_CHECKER_ON
    // Table B-1 (p.B-493): DVMOp is the only request an MN is the target of.
    assert_checker #(2, "MN: a request other than DVMOp (Table B-1)")
        u_req_not_dvm (.clk(clk_i), .rst(rst_i), .cond(rxreqflitv_i & ~req_dvm));
    assert_checker #(2, "MN: a DVMOp from a Requester not in MN_RN_NID_LIST_PARAM cannot be P-Credited")
        u_rtq_unlisted (.clk(clk_i), .rst(rst_i), .cond(rtq_pop & ~rtq_rn_found));
    // SS2.11 (p.2-145): a request sent with AllowRetry deasserted spends a P-Credit
    // granted for its class.
    assert_checker #(2, "MN: a DVMOp resent without a P-Credit of its class")
        u_pcrd_class (.clk(clk_i), .rst(rst_i),
                      .cond(req_alloc & ~req_retry1 &
                            ((rxreqflit_i.pcrdtype != (req_sync ? `MN_PCRD_SYNC : `MN_PCRD_NONSYNC)) |
                             (resv_q[req_sync] == '0))));
    assert_checker #(2, "MN: RetryAck queue overflow")
        u_rtq_full (.clk(clk_i), .rst(rst_i), .cond(req_rtack & rtq_full));
    assert_checker #(2, "MN: a SnpResp that answers no outstanding SnpDVMOp")
        u_rsp_stray (.clk(clk_i), .rst(rst_i), .cond(rxrspflitv_i & ~rsp_ok));
    assert_checker #(2, "MN: write data that matches no DVMOp awaiting it")
        u_dat_stray (.clk(clk_i), .rst(rst_i), .cond(rxdatflitv_i & ~dat_ok));
`endif

endmodule
