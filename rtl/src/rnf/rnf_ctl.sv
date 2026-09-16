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

`include "rnf_param.svh"
`include "rnf_defines.svh"
`include "axi4_defines.svh"

// The RN-F's core-side engine: an AXI4 read or write, served from the cache or
// by the coherent transaction that makes it servable.
//
// Which transaction that is comes from Table 4-4 (SS4.2.1 p.4-167) and Table
// 4-38 (SS4.7.2 p.4-218):
//
//   read miss                -> ReadShared,  filling SC or whatever Table 4-33
//                               (SS4.7.1 p.4-211) grants
//   write hit, Unique        -> nothing on the link; SS4.6's Table 4-32
//                               (p.4-209) makes UC -> UD a silent transition
//   write hit, Shared        -> CleanUnique, which Table 4-38 ends UC from SC
//                               and UD from SD
//   write miss, whole line   -> MakeUnique, which needs no data fetched
//   write miss, part of one  -> ReadUnique, whose data the store merges into
//
// A line is I, SC, UC, UD or SD, and UCE for the length of one race. A snoop can
// take a Shared line away while its CleanUnique is in flight, and Table 4-38
// then ends that CleanUnique -- from Invalid -- in UCE: owned, with no valid
// bytes. p.4-215 names the cost, "the Requester needing to issue another
// transaction", so a store that does not cover the whole line follows it with a
// ReadUnique, which Table 4-33 (p.4-212) permits from UCE. UDP is never entered:
// that store is merged into the ReadUnique's data, not into the empty line.
//
// Displacing a Dirty victim owes a WriteBackFull (Table 4-16 SS4.2.2 p.4-175);
// a Clean one is dropped silently, which Table 4-32 permits.
//
// Every request goes out with AllowRetry set, which SS2.11 (p.2-145, MUST)
// requires of a first attempt, so any of them may draw a RetryAck. The node then
// holds it until a PCrdGrant of the RetryAck's PCrdType, and resends it with
// AllowRetry clear. A P-Credit can land before the RetryAck it answers, so credits
// are banked per type rather than matched to a request; one the node holds when it
// has nothing left that could draw a RetryAck is surplus, and SS2.11.1 (p.2-147,
// MUST) has it returned.
//
// One transaction at a time: SS2.5.2 (p.2-87) bounds TxnID reuse by what is
// outstanding, so a single context needs no MSHR to stay legal.
module rnf_ctl `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    // AXI4 subordinate, read channels
    input  wire [`AXI4_ARID_WIDTH-1:0]          ARID,
    input  wire [`AXI4_ARADDR_WIDTH-1:0]        ARADDR,
    input  wire [`AXI4_ARLEN_WIDTH-1:0]         ARLEN,
    input  wire [`AXI4_ARSIZE_WIDTH-1:0]        ARSIZE,
    input  wire                                 ARVALID,
    output wire                                 ARREADY,
    output wire [`AXI4_RID_WIDTH-1:0]           RID,
    output wire [`AXI4_RDATA_WIDTH-1:0]         RDATA,
    output wire [`AXI4_RRESP_WIDTH-1:0]         RRESP,
    output wire                                 RLAST,
    output wire                                 RVALID,
    input  wire                                 RREADY,

    // AXI4 subordinate, write channels
    input  wire [`AXI4_AWID_WIDTH-1:0]          AWID,
    input  wire [`AXI4_AWADDR_WIDTH-1:0]        AWADDR,
    input  wire [`AXI4_AWLEN_WIDTH-1:0]         AWLEN,
    input  wire [`AXI4_AWSIZE_WIDTH-1:0]        AWSIZE,
    input  wire                                 AWVALID,
    output wire                                 AWREADY,
    input  wire [`AXI4_WDATA_WIDTH-1:0]         WDATA,
    input  wire [`AXI4_WSTRB_WIDTH-1:0]         WSTRB,
    input  wire                                 WLAST,
    input  wire                                 WVALID,
    output wire                                 WREADY,
    output wire [`AXI4_BID_WIDTH-1:0]           BID,
    output wire [`AXI4_BRESP_WIDTH-1:0]         BRESP,
    output wire                                 BVALID,
    input  wire                                 BREADY,

    // Cache
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_lu_addr_o,
    input  wire                                 cache_lu_hit_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_lu_state_i,
    input  wire [`RNF_WAY_W-1:0]                cache_lu_way_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_lu_data_i,
    input  wire [`RNF_WAY_W-1:0]                cache_vic_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_vic_state_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_vic_addr_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_vic_data_i,
    output wire                                 cache_fill_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_fill_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_fill_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_fill_state_o,
    output wire [`RNF_LINE_BITS-1:0]            cache_fill_data_o,
    output wire                                 cache_upd_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_upd_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_upd_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_upd_state_o,

    // The snoop port's own cache writes, watched rather than arbitrated with:
    // Table 4-39 fn a (SS4.7.3 p.4-220) has a snoop change the line under a
    // pending CopyBack, and the WriteData that follows must carry the state it
    // left behind.
    input  wire                                 snp_upd_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_upd_addr_i,
    input  wire [`RNF_WAY_W-1:0]                snp_upd_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]             snp_upd_state_i,

    // Protocol layer, to the link
    output chie_pkg::req_flit_s                 prot_txreqflit_o,
    output wire                                 prot_txreqflitv_o,
    input  wire                                 prot_txreqflit_sent_i,
    output chie_pkg::rsp_flit_s                 prot_txrspflit_o,
    output wire                                 prot_txrspflitv_o,
    input  wire                                 prot_txrspflit_sent_i,
    output chie_pkg::dat_flit_s                 prot_txdatflit_o,
    output wire                                 prot_txdatflitv_o,
    input  wire                                 prot_txdatflit_sent_i,
    input  wire                                 prot_rxdatflitv_i,
    input  chie_pkg::dat_flit_s                 prot_rxdatflit_i,
    input  wire                                 prot_rxrspflitv_i,
    input  chie_pkg::rsp_flit_s                 prot_rxrspflit_i,

    // Table 15-1 (p.15-468): only Coherency Enabled permits a transaction that
    // caches a coherent location.
    input  wire                                 coh_enabled_i,
    input  wire                                 link_run_i,

    // SS4.11.1 (p.4-242, MUST): a snoop to a line whose Data response is part-way
    // in waits for the rest. Held until the fill has landed, since before then the
    // cache still shows the line as it was.
    output wire                                 defer_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] defer_addr_o,

    output wire                                 txn_active_o
    );

    localparam logic [3:0] S_IDLE    = 4'd0;
    localparam logic [3:0] S_WDATA   = 4'd1;
    localparam logic [3:0] S_CB_REQ  = 4'd2;
    localparam logic [3:0] S_CB_DBID = 4'd3;
    localparam logic [3:0] S_CB_DAT  = 4'd4;
    localparam logic [3:0] S_REQ     = 4'd5;
    localparam logic [3:0] S_DATA    = 4'd6;
    localparam logic [3:0] S_ACK     = 4'd7;
    localparam logic [3:0] S_RESP    = 4'd8;
    localparam logic [3:0] S_BRESP   = 4'd9;
    localparam logic [3:0] S_PCRD    = 4'd10;
    localparam logic [3:0] S_PCRD_RET= 4'd11;

    logic [3:0]                                 st_q;
    logic [`AXI4_ARID_WIDTH-1:0]                id_q;
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       addr_q;
    logic [11:0]                                txnid_q;
    logic [`RNF_LINE_BITS-1:0]                  line_q;
    logic [`RNF_CS_WIDTH-1:0]                   fill_state_q;
    logic                                       got_lo_q, got_hi_q, got_rsp_q;
    logic [CHIE_NID_WIDTH_PARAM-1:0]            ack_tgt_q;
    logic [11:0]                                ack_txnid_q;
    logic                                       fill_v_q;
    logic                                       hit_q;
    logic                                       err_q;

    logic                                       is_wr_q;
    logic [`RNF_LINE_BITS-1:0]                  wbuf_q;
    logic [`RNF_LINE_BYTES-1:0]                 wbe_q;
    logic [1:0]                                 wchunk_q;
    logic [`RNF_WAY_W-1:0]                      way_q;
    chie_pkg::req_opcode_e                      acq_op_q;
    logic                                       acq_data_q;   // the acquire returns data

    // The victim, latched when the transaction commits to displacing it. Its
    // data cannot change under us -- the snoop port writes state only -- but its
    // state can, which is what vic_state_q tracks.
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       vic_addr_q;
    logic [`RNF_WAY_W-1:0]                      vic_way_q;
    logic [`RNF_CS_WIDTH-1:0]                   vic_state_q;
    logic [`RNF_LINE_BITS-1:0]                  vic_data_q;
    // SS2.11 (p.2-145): the request that drew a RetryAck, and what it waits for.
    logic                                       retry_q;
    logic [3:0]                                 retry_type_q;
    logic                                       retry_cb_q;
    // P-Credits held, per PCrdType, and the Completer each came from -- SS2.6.6
    // (p.2-112) addresses a PCrdReturn to "the SrcID of the credit that was
    // obtained".
    logic [1:0]                                 pcrd_cnt_q [16];
    logic [CHIE_NID_WIDTH_PARAM-1:0]            pcrd_src_q [16];
    logic [3:0]                                 ret_type_q;
    logic [3:0]                                 surplus_type;
    logic                                       surplus_v;

    // The acquire's own line, tracked the same way while the request is out.
    logic [`RNF_CS_WIDTH-1:0]                   acq_cs_q;
    logic                                       fill_uce_q;
    logic                                       chain_ru_q;
    logic [CHIE_NID_WIDTH_PARAM-1:0]            cb_tgt_q;
    logic [11:0]                                cb_txnid_q;
    logic                                       cb_hi_q;
    logic                                       cb_done_q;

    function automatic bit is_dirty(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UD) || (cs == `RNF_CS_SD) || (cs == `RNF_CS_UDP);
    endfunction

    function automatic bit is_unique(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UC) || (cs == `RNF_CS_UD) ||
               (cs == `RNF_CS_UCE) || (cs == `RNF_CS_UDP);
    endfunction

    // Table 4-33 (SS4.7.1 p.4-211) read grants, and Table 4-38's (p.4-218)
    // dataless ones, share the Comp-response reading of Table 13-35
    // (SS13.10.44 p.13-437).
    function automatic logic [`RNF_CS_WIDTH-1:0] cs_of_resp(chie_pkg::resp_state_e r);
        case (r)
            chie_pkg::RESP_SC:     return `RNF_CS_SC;
            chie_pkg::RESP_UC_UD:  return `RNF_CS_UC;
            chie_pkg::RESP_UC_PD:  return `RNF_CS_UD;
            chie_pkg::RESP_SD_PD:  return `RNF_CS_SD;
            default:               return `RNF_CS_I;
        endcase
    endfunction

    // Table 4-39 (SS4.7.3 p.4-220): a CopyBackWrData names the state the line is
    // in when the data is sent, which a snoop may have moved since the request.
    function automatic chie_pkg::resp_state_e cb_resp_of(logic [`RNF_CS_WIDTH-1:0] cs);
        case (cs)
            `RNF_CS_UD:  return chie_pkg::RESP_UC_PD;
            `RNF_CS_SD:  return chie_pkg::RESP_SD_PD;
            `RNF_CS_UC:  return chie_pkg::RESP_UC_UD;
            `RNF_CS_SC:  return chie_pkg::RESP_SC;
            default:     return chie_pkg::RESP_I;
        endcase
    endfunction

    function automatic logic [`RNF_LINE_BITS-1:0]
        merge_line(logic [`RNF_LINE_BITS-1:0]  base,
                   logic [`RNF_LINE_BITS-1:0]  wdat,
                   logic [`RNF_LINE_BYTES-1:0] be);
        for (int b = 0; b < `RNF_LINE_BYTES; b++)
            merge_line[b*8 +: 8] = be[b] ? wdat[b*8 +: 8] : base[b*8 +: 8];
    endfunction

    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] ar_line =
        {ARADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] aw_line =
        {AWADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};

    // A read is taken ahead of a write when both are offered, so the lookup this
    // cycle is the one the accepted channel needs.
    assign cache_lu_addr_o = (st_q != S_IDLE) ? addr_q :
                             ARVALID          ? ar_line : aw_line;

    // SS15.2.1 (p.15-467, MUST) forbids issuing a caching transaction before
    // SYSCOACK, so neither channel is accepted before Coherency Enabled.
    // A surplus P-Credit goes back before new work is taken: offering READY in
    // the same cycle the FSM leaves to return it would complete an AXI handshake
    // for a request nothing then serves.
    wire accept_ok = (st_q == S_IDLE) && !surplus_v && link_run_i && coh_enabled_i;
    assign ARREADY = accept_ok;
    assign AWREADY = accept_ok && !ARVALID;
    assign WREADY  = (st_q == S_WDATA);

    wire [`RNF_CS_WIDTH-1:0] lu_state = cache_lu_hit_i ? cache_lu_state_i : `RNF_CS_I;

    // The byte mask including the beat being accepted this cycle: wbe_q does not
    // carry it until the next edge, and the whole-line question is asked on
    // WLAST, which is that same cycle.
    logic [`RNF_LINE_BYTES-1:0] wbe_now;
    always_comb begin
        wbe_now = wbe_q;
        case (wchunk_q)
            2'd0:    wbe_now[15:0]  = WSTRB;
            2'd1:    wbe_now[31:16] = WSTRB;
            2'd2:    wbe_now[47:32] = WSTRB;
            default: wbe_now[63:48] = WSTRB;
        endcase
    end
    wire wr_full = &wbe_now;

    // Whether the displaced way owes a write-back. Evaluated at the point the
    // transaction commits to filling, so cache_vic_* still describe the way the
    // fill will take.
    wire need_cb = is_dirty(cache_vic_state_i);

    // Table 2-8 (SS2.8.3 p.2-117) makes CompAck required for every request this
    // engine issues except the CopyBack, which it forbids outright.
    always_comb begin
        prot_txreqflit_o              = '0;
        prot_txreqflit_o.srcid        = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txreqflit_o.tgtid        = CHIE_NID_WIDTH_PARAM'(HNF_NID_PARAM);
        prot_txreqflit_o.size         = chie_pkg::SIZE_64B;
        prot_txreqflit_o.allowretry   = !retry_q;
        prot_txreqflit_o.pcrdtype     = retry_q ? retry_type_q : 4'd0;
        prot_txreqflit_o.order        = chie_pkg::ORDER_NONE;
        prot_txreqflit_o.memattr.allocate     = 1'b1;
        prot_txreqflit_o.memattr.cacheable    = 1'b1;
        prot_txreqflit_o.memattr.device       = 1'b0;
        prot_txreqflit_o.memattr.early_wr_ack = 1'b1;
        prot_txreqflit_o.snpattr.snpattr      = 1'b1;
        if (st_q == S_PCRD_RET) begin
            // SS2.6.6 (p.2-112): addressed to the credit's source, TxnID zero, and
            // the PCrdType it was granted under. Table A-2 (p.A-484) leaves every
            // other field inapplicable, so zero.
            prot_txreqflit_o          = '0;
            prot_txreqflit_o.srcid    = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
            prot_txreqflit_o.tgtid    = pcrd_src_q[ret_type_q];
            prot_txreqflit_o.opcode   = chie_pkg::REQ_PCRDRETURN;
            prot_txreqflit_o.pcrdtype = ret_type_q;
        end
        else if (st_q == S_CB_REQ) begin
            prot_txreqflit_o.txnid      = txnid_q;
            prot_txreqflit_o.opcode     = chie_pkg::REQ_WRITEBACKFULL;
            prot_txreqflit_o.addr       = vic_addr_q;
            prot_txreqflit_o.expcompack = 1'b0;
        end
        else begin
            prot_txreqflit_o.txnid      = txnid_q;
            prot_txreqflit_o.opcode     = acq_op_q;
            prot_txreqflit_o.addr       = addr_q;
            prot_txreqflit_o.expcompack = 1'b1;
        end
    end

    assign prot_txreqflitv_o = (st_q == S_REQ) || (st_q == S_CB_REQ) || (st_q == S_PCRD_RET);

    // SS2.6.1 (p.2-100, MUST): a CompAck takes its TgtID from the completion's
    // HomeNID and its TxnID from its DBID, not from this node's own request.
    always_comb begin
        prot_txrspflit_o        = '0;
        prot_txrspflit_o.tgtid  = ack_tgt_q;
        prot_txrspflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txrspflit_o.txnid  = ack_txnid_q;
        prot_txrspflit_o.opcode = chie_pkg::RSP_COMPACK;
    end

    assign prot_txrspflitv_o = (st_q == S_ACK);

    // SS2.10.3 (p.2-135, MUST): "A Requester must deassert all BE values in
    // CopyBackWrData_I", and a deasserted byte enable "must set the associated
    // data byte value to zero". Every other CopyBackWrData of a WriteBackFull
    // asserts all 64 (SS4.2.2 p.4-175).
    wire cb_invalid = (cb_resp_of(vic_state_q) == chie_pkg::RESP_I);

    always_comb begin
        prot_txdatflit_o        = '0;
        prot_txdatflit_o.tgtid  = cb_tgt_q;
        prot_txdatflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txdatflit_o.txnid  = cb_txnid_q;
        prot_txdatflit_o.opcode = chie_pkg::DAT_COPYBACKWRDATA;
        prot_txdatflit_o.resp   = cb_resp_of(vic_state_q);
        // SS2.10.4 (p.2-136): a 64-byte line is two packets at Data_Width 256.
        prot_txdatflit_o.dataid = cb_hi_q ? 2'd2 : 2'd0;
        prot_txdatflit_o.be     = cb_invalid ? '0 : '1;
        prot_txdatflit_o.data   = cb_invalid ? '0 :
                                  (cb_hi_q ? vic_data_q[511:256] : vic_data_q[255:0]);
    end

    assign prot_txdatflitv_o = (st_q == S_CB_DAT);

    // The response half: RespSepData in the separate form, CompData in the
    // combined one, Comp for a Dataless acquire. SS2.5.5 (p.2-89) makes the
    // first's HomeNID and DBID the values "that can always be used".
    wire rx_rsp_mine = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                       ((prot_rxrspflit_i.opcode == chie_pkg::RSP_RESPSEPDATA) ||
                        (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMP));
    wire rx_comp_dataless = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                            (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMP);
    wire rx_dat_mine = prot_rxdatflitv_i && (prot_rxdatflit_i.txnid == txnid_q) &&
                       ((prot_rxdatflit_i.opcode == chie_pkg::DAT_COMPDATA) ||
                        (prot_rxdatflit_i.opcode == chie_pkg::DAT_DATASEPRESP));
    wire rx_dat_comb = rx_dat_mine &&
                       (prot_rxdatflit_i.opcode == chie_pkg::DAT_COMPDATA);
    // SS2.3.2 (p.2-51) / Table 4-39 (p.4-219): a CopyBack completes with the
    // combined CompDBIDResp, never a separate DBIDResp and Comp.
    wire rx_cb_dbid = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                      (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMPDBIDRESP);

    wire rx_retryack  = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                        (prot_rxrspflit_i.opcode == chie_pkg::RSP_RETRYACK);
    // A PCrdGrant names no transaction, so it is taken whatever this node is doing.
    wire rx_pcrdgrant = prot_rxrspflitv_i &&
                        (prot_rxrspflit_i.opcode == chie_pkg::RSP_PCRDGRANT);

    // SS2.11 (p.2-145): "The transaction must only be retried by the Requester when
    // a PCrdGrant is received with the correct PCrdType" -- one already banked, or
    // one landing this cycle.
    wire pcrd_ready = (pcrd_cnt_q[retry_type_q] != 2'd0) ||
                      (rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == retry_type_q));
    wire pcrd_use   = (st_q == S_PCRD) && pcrd_ready;

    // Idle, nothing outstanding can still draw a RetryAck, so a held credit is one
    // no request needs.
    always_comb begin
        surplus_v    = 1'b0;
        surplus_type = 4'd0;
        for (int t = 0; t < 16; t++) begin
            if (!surplus_v && (pcrd_cnt_q[t] != 2'd0)) begin
                surplus_v    = 1'b1;
                surplus_type = 4'(t);
            end
        end
    end
    wire pcrd_ret_sent = (st_q == S_PCRD_RET) && prot_txreqflit_sent_i;

    // SS9.3 (p.9-336): NormalOkay and ExclusiveOkay are both success; the other
    // two are the endpoint reporting an error.
    function automatic bit is_err(chie_pkg::resp_err_e e);
        return (e == chie_pkg::RESP_ERR_DATA) || (e == chie_pkg::RESP_ERR_NON_DATA);
    endfunction

    wire rx_err = (prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                   is_err(prot_rxrspflit_i.resperr)) ||
                  (rx_dat_mine && is_err(prot_rxdatflit_i.resperr));

    // The line the transaction installs: the store merged over whatever the
    // acquire brought back, or over the copy already resident.
    wire [`RNF_LINE_BITS-1:0] fill_line = is_wr_q ? merge_line(line_q, wbuf_q, wbe_q)
                                                  : line_q;

    // The acquire's line as it stands this cycle, including a snoop writing it on
    // the very edge its completion arrives -- acq_cs_q alone would miss that one.
    wire acq_snp_now = snp_upd_v_i &&
        (snp_upd_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W] ==
         addr_q[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W]);
    wire [`RNF_CS_WIDTH-1:0] acq_cs_now = acq_snp_now ? snp_upd_state_i : acq_cs_q;
    wire                     acq_lost   = (acq_cs_now == `RNF_CS_I);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            st_q         <= S_IDLE;
            id_q         <= '0;
            addr_q       <= '0;
            txnid_q      <= '0;
            line_q       <= '0;
            fill_state_q <= `RNF_CS_I;
            got_lo_q     <= 1'b0;
            got_hi_q     <= 1'b0;
            got_rsp_q    <= 1'b0;
            ack_tgt_q    <= '0;
            ack_txnid_q  <= '0;
            fill_v_q     <= 1'b0;
            hit_q        <= 1'b0;
            err_q        <= 1'b0;
            is_wr_q      <= 1'b0;
            wbuf_q       <= '0;
            wbe_q        <= '0;
            wchunk_q     <= 2'd0;
            way_q        <= '0;
            acq_op_q     <= chie_pkg::REQ_READSHARED;
            acq_data_q   <= 1'b0;
            vic_addr_q   <= '0;
            vic_way_q    <= '0;
            vic_state_q  <= `RNF_CS_I;
            vic_data_q   <= '0;
            acq_cs_q     <= `RNF_CS_I;
            retry_q      <= 1'b0;
            retry_type_q <= 4'd0;
            retry_cb_q   <= 1'b0;
            ret_type_q   <= 4'd0;
            for (int t = 0; t < 16; t++) begin
                pcrd_cnt_q[t] <= 2'd0;
                pcrd_src_q[t] <= '0;
            end
            fill_uce_q   <= 1'b0;
            chain_ru_q   <= 1'b0;
            cb_tgt_q     <= '0;
            cb_txnid_q   <= '0;
            cb_hi_q      <= 1'b0;
            cb_done_q    <= 1'b0;
        end
        else begin
            fill_v_q  <= 1'b0;
            cb_done_q <= 1'b0;

            // Table 4-39 fn a (p.4-220): the snoop port may move the victim while
            // its CopyBack is in flight, and the WriteData must say so.
            for (int t = 0; t < 16; t++) begin
                automatic logic inc = rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == 4'(t));
                automatic logic dec = (pcrd_use      && (retry_type_q == 4'(t))) ||
                                      (pcrd_ret_sent && (ret_type_q   == 4'(t)));
                pcrd_cnt_q[t] <= pcrd_cnt_q[t] + {1'b0, inc} - {1'b0, dec};
                if (inc) pcrd_src_q[t] <= prot_rxrspflit_i.srcid;
            end

            if (acq_snp_now && (st_q != S_IDLE))
                acq_cs_q <= snp_upd_state_i;

            if (snp_upd_v_i && (snp_upd_way_i == vic_way_q) &&
                (snp_upd_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W] ==
                 vic_addr_q[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W]))
                vic_state_q <= snp_upd_state_i;

            case (st_q)
                S_IDLE: begin
                    got_lo_q  <= 1'b0;
                    got_hi_q  <= 1'b0;
                    got_rsp_q <= 1'b0;
                    err_q     <= 1'b0;
                    if (surplus_v) begin
                        ret_type_q <= surplus_type;
                        st_q       <= S_PCRD_RET;
                    end
                    else if (ARVALID && ARREADY) begin
                        id_q       <= ARID;
                        addr_q     <= ar_line;
                        is_wr_q    <= 1'b0;
                        way_q      <= cache_lu_hit_i ? cache_lu_way_i : cache_vic_way_i;
                        if (cache_lu_hit_i) begin
                            line_q <= cache_lu_data_i;
                            hit_q  <= 1'b1;
                            st_q   <= S_RESP;
                        end
                        else begin
                            hit_q      <= 1'b0;
                            acq_op_q   <= chie_pkg::REQ_READSHARED;
                            acq_data_q <= 1'b1;
                            vic_addr_q <= cache_vic_addr_i;
                            vic_way_q  <= cache_vic_way_i;
                            vic_state_q<= cache_vic_state_i;
                            vic_data_q <= cache_vic_data_i;
                            st_q       <= need_cb ? S_CB_REQ : S_REQ;
                        end
                    end
                    else if (AWVALID && AWREADY) begin
                        id_q     <= AWID;
                        addr_q   <= aw_line;
                        is_wr_q  <= 1'b1;
                        wbe_q    <= '0;
                        wbuf_q   <= '0;
                        wchunk_q <= AWADDR[5:4];
                        st_q     <= S_WDATA;
                    end
                end

                S_WDATA: begin
                    if (WVALID) begin
                        case (wchunk_q)
                            2'd0: begin wbuf_q[127:0]   <= WDATA; wbe_q[15:0]  <= WSTRB; end
                            2'd1: begin wbuf_q[255:128] <= WDATA; wbe_q[31:16] <= WSTRB; end
                            2'd2: begin wbuf_q[383:256] <= WDATA; wbe_q[47:32] <= WSTRB; end
                            default: begin wbuf_q[511:384] <= WDATA; wbe_q[63:48] <= WSTRB; end
                        endcase
                        wchunk_q <= wchunk_q + 2'd1;
                        if (WLAST) begin
                            way_q <= cache_lu_hit_i ? cache_lu_way_i : cache_vic_way_i;
                            // A Unique line is already this node's to modify;
                            // Table 4-32 (SS4.6 p.4-209) makes UC -> UD silent.
                            if (cache_lu_hit_i && is_unique(lu_state)) begin
                                line_q       <= cache_lu_data_i;
                                fill_state_q <= `RNF_CS_UD;
                                hit_q        <= 1'b1;
                                fill_v_q     <= 1'b1;
                                st_q         <= S_BRESP;
                            end
                            else begin
                                hit_q <= 1'b0;
                                if (cache_lu_hit_i) begin
                                    // SC or SD: Table 4-38 (p.4-218) ends both
                                    // Unique, and no data need move.
                                    line_q     <= cache_lu_data_i;
                                    acq_cs_q   <= lu_state;
                                    acq_op_q   <= chie_pkg::REQ_CLEANUNIQUE;
                                    acq_data_q <= 1'b0;
                                    st_q       <= S_REQ;
                                end
                                else begin
                                    line_q     <= '0;
                                    // Table 4-38 (p.4-218): MakeUnique needs no
                                    // data fetched, so it is the whole-line
                                    // store's request; a partial one has to read
                                    // the bytes it does not write.
                                    acq_op_q   <= wr_full ? chie_pkg::REQ_MAKEUNIQUE
                                                          : chie_pkg::REQ_READUNIQUE;
                                    acq_data_q <= !wr_full;
                                    vic_addr_q <= cache_vic_addr_i;
                                    vic_way_q  <= cache_vic_way_i;
                                    vic_state_q<= cache_vic_state_i;
                                    vic_data_q <= cache_vic_data_i;
                                    st_q       <= need_cb ? S_CB_REQ : S_REQ;
                                end
                            end
                        end
                    end
                end

                S_CB_REQ: begin
                    if (prot_txreqflit_sent_i) st_q <= S_CB_DBID;
                end

                S_CB_DBID: begin
                    if (rx_retryack) begin
                        retry_q      <= 1'b1;
                        retry_type_q <= prot_rxrspflit_i.pcrdtype;
                        retry_cb_q   <= 1'b1;
                        st_q         <= S_PCRD;
                    end
                    else if (rx_cb_dbid) begin
                        retry_q    <= 1'b0;
                        cb_tgt_q   <= prot_rxrspflit_i.srcid;
                        cb_txnid_q <= prot_rxrspflit_i.dbid;
                        cb_hi_q    <= 1'b0;
                        st_q       <= S_CB_DAT;
                    end
                end

                S_CB_DAT: begin
                    if (prot_txdatflit_sent_i) begin
                        if (cb_hi_q) begin
                            // The way is free only now: until the data has gone,
                            // a snoop on this line is still answered from it.
                            cb_done_q <= 1'b1;
                            txnid_q   <= txnid_q + 12'd1;
                            st_q      <= S_REQ;
                        end
                        else cb_hi_q <= 1'b1;
                    end
                end

                S_REQ: begin
                    if (prot_txreqflit_sent_i) st_q <= S_DATA;
                end

                S_DATA: begin
                    if (rx_retryack) begin
                        retry_q      <= 1'b1;
                        retry_type_q <= prot_rxrspflit_i.pcrdtype;
                        retry_cb_q   <= 1'b0;
                        st_q         <= S_PCRD;
                    end
                    else begin
                    if (rx_err) err_q <= 1'b1;

                    if (rx_rsp_mine) begin
                        got_rsp_q   <= 1'b1;
                        ack_tgt_q   <= prot_rxrspflit_i.srcid;
                        ack_txnid_q <= prot_rxrspflit_i.dbid;
                    end
                    if (rx_dat_comb) begin
                        ack_tgt_q   <= prot_rxdatflit_i.homenid;
                        ack_txnid_q <= prot_rxdatflit_i.dbid;
                    end
                    // Table 4-33 (SS4.7.1 p.4-211) puts a read's granted state on
                    // the DATA half of both shapes; Table 4-38 (p.4-218) puts a
                    // Dataless one on the Comp.
                    if (rx_dat_mine)       fill_state_q <= cs_of_resp(prot_rxdatflit_i.resp);
                    if (rx_comp_dataless)  fill_state_q <= cs_of_resp(prot_rxrspflit_i.resp);

                    // SS2.10.4 (p.2-136): a 64-byte transfer at Data_Width 256 is
                    // two packets, DataID 0 then 2.
                    if (rx_dat_mine) begin
                        if (prot_rxdatflit_i.dataid == 2'd0) begin
                            line_q[255:0] <= prot_rxdatflit_i.data;
                            got_lo_q      <= 1'b1;
                        end
                        else begin
                            line_q[511:256] <= prot_rxdatflit_i.data;
                            got_hi_q        <= 1'b1;
                        end
                    end

                    // The line takes its granted state on the completion, not on
                    // this node's CompAck, so the fill lands now: a snoop released
                    // by the deferral below must find the state already there.
                    if (acq_data_q) begin
                        if ((got_lo_q || (rx_dat_mine && (prot_rxdatflit_i.dataid == 2'd0))) &&
                            (got_hi_q || (rx_dat_mine && (prot_rxdatflit_i.dataid != 2'd0))) &&
                            (got_rsp_q || rx_rsp_mine || rx_dat_comb)) begin
                            fill_v_q <= 1'b1;
                            st_q     <= S_ACK;
                        end
                    end
                    else if (got_rsp_q || rx_comp_dataless) begin
                        fill_v_q <= 1'b1;
                        st_q     <= S_ACK;
                        // Table 4-38 (p.4-218): the line went Invalid under the
                        // CleanUnique, which therefore ends UCE. The bytes held in
                        // line_q are what the snoop took away, so none survive.
                        if ((acq_op_q == chie_pkg::REQ_CLEANUNIQUE) && acq_lost) begin
                            line_q <= '0;
                            if (!(&wbe_q)) begin
                                fill_uce_q <= 1'b1;
                                chain_ru_q <= 1'b1;
                            end
                        end
                    end
                    end
                end

                // SS2.11 (p.2-145): held until a P-Credit of the RetryAck's type,
                // then resent. The resend keeps its TxnID, which the same section
                // frees for reuse as soon as the RetryAck arrives.
                S_PCRD: begin
                    if (pcrd_ready) st_q <= retry_cb_q ? S_CB_REQ : S_REQ;
                end

                S_PCRD_RET: begin
                    if (prot_txreqflit_sent_i) st_q <= S_IDLE;
                end

                S_ACK: begin
                    retry_q <= 1'b0;
                    if (prot_txrspflit_sent_i) begin
                        if (chain_ru_q) begin
                            // p.4-215: the other transaction the lost line costs.
                            chain_ru_q <= 1'b0;
                            fill_uce_q <= 1'b0;
                            got_lo_q   <= 1'b0;
                            got_hi_q   <= 1'b0;
                            got_rsp_q  <= 1'b0;
                            acq_op_q   <= chie_pkg::REQ_READUNIQUE;
                            acq_data_q <= 1'b1;
                            txnid_q    <= txnid_q + 12'd1;
                            st_q       <= S_REQ;
                        end
                        else st_q <= is_wr_q ? S_BRESP : S_RESP;
                    end
                end

                S_RESP: begin
                    if (RREADY) begin
                        st_q    <= S_IDLE;
                        txnid_q <= txnid_q + 12'd1;
                    end
                end

                S_BRESP: begin
                    if (BREADY) begin
                        st_q    <= S_IDLE;
                        txnid_q <= txnid_q + 12'd1;
                    end
                end

                default: st_q <= S_IDLE;
            endcase
        end
    end

    // The store's final state. Table 4-38 (p.4-218) ends CleanUnique and
    // MakeUnique Unique, and the merge that follows makes the line Dirty.
    wire [`RNF_CS_WIDTH-1:0] wr_fill_state =
        (fill_state_q == `RNF_CS_I) ? `RNF_CS_I : `RNF_CS_UD;

    assign cache_fill_v_o     = fill_v_q;
    assign cache_fill_addr_o  = addr_q;
    assign cache_fill_way_o   = way_q;
    assign cache_fill_state_o = fill_uce_q ? `RNF_CS_UCE :
                                is_wr_q    ? (hit_q ? `RNF_CS_UD : wr_fill_state)
                                           : fill_state_q;
    assign cache_fill_data_o  = fill_line;

    // Retiring the written-back way, which the fill behind it would otherwise
    // leave Dirty for the window between the two.
    assign cache_upd_v_o     = cb_done_q;
    assign cache_upd_addr_o  = vic_addr_q;
    assign cache_upd_way_o   = vic_way_q;
    assign cache_upd_state_o = `RNF_CS_I;

    // The 128-bit chunk the access falls in. A fixed set of slices rather than a
    // variable base, so the select cannot read past the line.
    logic [`AXI4_RDATA_WIDTH-1:0] rdata_c;
    always_comb begin
        case (addr_q[5:4])
            2'd0:    rdata_c = line_q[127:0];
            2'd1:    rdata_c = line_q[255:128];
            2'd2:    rdata_c = line_q[383:256];
            default: rdata_c = line_q[511:384];
        endcase
    end

    // SS9.3 (p.9-336): a non-OK RespErr is the endpoint's, and the core is owed
    // it rather than a silent OKAY.
    wire [1:0] axi_resp = err_q ? 2'b10 : 2'b00;

    assign RVALID = (st_q == S_RESP);
    assign RDATA  = rdata_c;
    assign RID    = id_q;
    assign RRESP  = axi_resp;
    assign RLAST  = 1'b1;

    assign BVALID = (st_q == S_BRESP);
    assign BID    = `AXI4_BID_WIDTH'(id_q);
    assign BRESP  = axi_resp;

    // From the first Data packet until the fill it completes has been written.
    assign defer_v_o    = ((st_q == S_DATA) && (got_lo_q || got_hi_q || rx_dat_mine)) || fill_v_q;
    assign defer_addr_o = addr_q;

    // SS14.7.1 (p.14-460): a held surplus P-Credit is a PCrdReturn this node still
    // owes, so it counts as work in progress even from idle.
    assign txn_active_o = (st_q != S_IDLE) || surplus_v;

    // A single-outstanding Requester draws at most one RetryAck at a time, so a
    // conformant Completer never grants it more than a few credits of one type
    // before they are used or returned. Two bits wrapping would silently lose one.
`ifdef ASSERT_CHECKER_ON
    for (genvar gt = 0; gt < 16; gt++) begin : g_pcrd_sat
        assert_checker #(
                           3,
                           "RN-F P-Credit bank saturated: a PCrdGrant arrived with three of its type already held")
                       PCRD_SAT_check (
                           .clk   ( clk_i ),
                           .rst   ( rst_i ),
                           .cond  ( rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == 4'(gt)) &&
                                    (pcrd_cnt_q[gt] == 2'd3) )
                       );
    end
`endif

endmodule
