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
// =============================================================================
// tb_mn_dvm -- the MN between four DVM-capable Requesters, played by the bench on
// the MN's one link (tb_home_peer.svh), each answering its SnpDVMOp pairs.
//
//   M1 Sec 2.3.7 (p.2-76): DBIDResp, NCBWrData, then Comp -- RespErr OK on both
//      (Table 9-12 p.9-344), Resp zero (Tables 8-4/8-6).
//   M2 Sec 8.1.1 (p.8-305): the pair reaches every listed Requester but the one
//      that asked, and nothing else; Comp only after every SnpResp.
//   M3 Table 8-8 (p.8-317) / Table 8-9 (p.8-320) / Table 8-3 (p.8-311): each part's
//      Addr, FwdNID and VMIDExt, one TxnID for both, NS/DoNotGoToSD/RetToSrc zero.
//   M4 Sec 8.1.2 (p.8-307): a Sync snoops only once every Non-sync the MN held when
//      it arrived has completed, and its Comp follows theirs.
//   M5 Sec 8.1.3 (p.8-307/8-308, MUST): at most one Sync and MN_RN_SNPDVM_NUM_PARAM
//      SnpDVMOps outstanding per Requester, and an entry held for a Non-sync while
//      Syncs fill the rest -- the Sync that cannot enter is RetryAck'd and later
//      P-Credited.
//   M6 Table 15-1 (p.15-468, MUST): no SnpDVMOp to a Requester outside the
//      coherency domain, and SYSCO_SNP_PEND high while one to it is unanswered.
// =============================================================================
`include "mn_defines.svh"
`include "mn_param.svh"

module tb_mn_dvm;

    localparam string BENCH    = "tb_mn_dvm";
    localparam        HOME_NID = 4;
    localparam        RN_NID   = 8;
    localparam int    R        = 4;
    localparam int    ENTRIES  = 4;
    localparam int    CAP      = 2;
    localparam logic [6:0] RN [R] = '{7'd8, 7'd40, 7'd16, 7'd48};

`include "tb_home_peer.svh"

    wire                         TXSNPFLITV, TXSNPFLITPEND;
    opennoc_mn_pkg::snp_routed_s TXSNPFLIT;
    logic [R-1:0]                coh = '1;
    wire  [R-1:0]                snp_pend;

    mn #(
        .MN_NID_PARAM           (HOME_NID                                ),
        .MN_ENTRIES_NUM_PARAM   (ENTRIES                                 ),
        .MN_RN_NUM_PARAM        (R                                       ),
        .MN_RN_NID_LIST_PARAM   ({RN[3], RN[2], RN[1], RN[0]}            ),
        .MN_RN_SNPDVM_NUM_PARAM (CAP                                     )
    ) u_mn (
        .CLK(CLK), .RST(RST),
        .TXLINKACTIVEREQ(TXLINKACTIVEREQ), .TXLINKACTIVEACK(TXLINKACTIVEACK),
        .RXLINKACTIVEREQ(RXLINKACTIVEREQ), .RXLINKACTIVEACK(RXLINKACTIVEACK),
        .TXSACTIVE(TXSACTIVE), .RXSACTIVE(RXSACTIVE),
        .RXREQFLITV(RXREQFLITV), .RXREQFLIT(RXREQFLIT), .RXREQFLITPEND(RXREQFLITPEND), .RXREQLCRDV(RXREQLCRDV),
        .RXRSPFLITV(RXRSPFLITV), .RXRSPFLIT(RXRSPFLIT), .RXRSPFLITPEND(RXRSPFLITPEND), .RXRSPLCRDV(RXRSPLCRDV),
        .RXDATFLITV(RXDATFLITV), .RXDATFLIT(RXDATFLIT), .RXDATFLITPEND(RXDATFLITPEND), .RXDATLCRDV(RXDATLCRDV),
        .TXRSPFLITV(TXRSPFLITV), .TXRSPFLIT(TXRSPFLIT), .TXRSPFLITPEND(TXRSPFLITPEND), .TXRSPLCRDV(TXRSPLCRDV),
        .TXSNPFLITV(TXSNPFLITV), .TXSNPFLIT(TXSNPFLIT), .TXSNPFLITPEND(TXSNPFLITPEND), .TXSNPLCRDV(TXSNPLCRDV),
        .SYSCO_SNP_EN(coh), .SYSCO_SNP_PEND(snp_pend)
    );

    // The peers share one link, so each channel is sent on by one process at a time.
    semaphore sem_req = new(1), sem_rsp = new(1), sem_dat = new(1);

    // TX L-Credits for the MN are handed back as its flits land, once the link is up.
    bit     refill_en = 1'b0;
    integer rsp_owed = 0, snp_owed = 0;
    always @(posedge CLK) if (refill_en) begin
        if (TXRSPFLITV) rsp_owed = rsp_owed + 1;
        if (TXSNPFLITV) snp_owed = snp_owed + 1;
    end
    always @(negedge CLK) if (refill_en) begin
        TXRSPLCRDV = (rsp_owed > 0);
        TXSNPLCRDV = (snp_owed > 0);
        if (rsp_owed > 0) rsp_owed = rsp_owed - 1;
        if (snp_owed > 0) snp_owed = snp_owed - 1;
    end

    // -------------------------------------------------------------------------
    // Snoopee side: every listed Requester collects its pairs and answers once
    // both parts are in, after resp_delay[r] cycles.
    // -------------------------------------------------------------------------
    typedef struct {
        bit                                  have [2];
        logic [chie_pkg::SNP_ADDR_WIDTH-1:0] addr [2];
        logic [6:0]                          fwdnid [2];
        logic [7:0]                          vmidext [2];
        bit                                  sync;
    } pair_t;

    pair_t  pairs [R][logic [11:0]];     // in flight, by snoopee and TxnID
    pair_t  got   [$];                   // completed pairs, in order
    integer got_rn [$];
    integer got_cyc [$];
    logic [11:0] got_txn [$];
    integer resp_delay [R] = '{default: 2};
    integer ns_out [R] = '{default: 0};
    integer sync_out [R] = '{default: 0};
    integer snp_resp_cyc [logic [11:0]];  // last SnpResp per MN TxnID

    function automatic int rn_of(logic [6:0] nid);
        for (int r = 0; r < R; r++) if (RN[r] == nid) return r;
        return -1;
    endfunction

    task automatic answer(int r, logic [11:0] txnid, bit sync);
        chie_pkg::rsp_flit_s f;
        repeat (resp_delay[r]) @(posedge CLK);
        f        = '0;
        f.opcode = chie_pkg::RSP_SNPRESP;
        f.srcid  = RN[r];
        f.tgtid  = HOME_NID;
        f.txnid  = txnid;
        f.resp   = chie_pkg::RESP_I;
        sem_rsp.get();
        send_rsp(f);
        sem_rsp.put();
        if (sync) sync_out[r]--; else ns_out[r]--;
        snp_resp_cyc[txnid] = cycle;
    endtask

    // M6: SYSCO_SNP_PEND covers every pair from its first part to its SnpResp.
    always @(posedge CLK) if (!RST)
        for (int r = 0; r < R; r++)
            if ((ns_out[r] + sync_out[r] > 0) && !snp_pend[r])
                fail($sformatf("M6: SYSCO_SNP_PEND low with a SnpDVMOp to %0d unanswered", RN[r]));

    always @(posedge CLK) if (!RST && TXSNPFLITV && (TXSNPFLIT.flit.opcode != chie_pkg::SNP_SNPLCRDRETURN)) begin
        automatic chie_pkg::snp_flit_s s = TXSNPFLIT.flit;
        automatic int r = rn_of(TXSNPFLIT.tgtid);
        automatic int p = int'(s.addr[0]);
        if (r < 0)
            fail($sformatf("M2: SnpDVMOp routed to NodeID %0d, which is no listed Requester", TXSNPFLIT.tgtid));
        else if (!coh[r] && !pairs[r].exists(s.txnid))
            fail($sformatf("M6: a new SnpDVMOp to %0d, which is outside the coherency domain", RN[r]));
        else begin
            // M3 Table 8-3 (p.8-311)
            if (s.opcode != chie_pkg::SNP_SNPDVMOP) fail($sformatf("M3: snoop opcode %s", s.opcode.name()));
            if (s.srcid != HOME_NID)                fail("M3: SnpDVMOp SrcID is not the MN");
            if (s.ns || s.donotgotosd || s.rettosrc) fail("M3: SnpDVMOp with NS, DoNotGoToSD or RetToSrc set");
            if (!pairs[r].exists(s.txnid)) begin
                pair_t n;
                n.have = '{0, 0};
                pairs[r][s.txnid] = n;
                if (ns_out[r] + sync_out[r] >= CAP)
                    fail($sformatf("M5: a SnpDVMOp to Requester %0d beyond the %0d it accepts (Sec 8.1.3 p.8-308)", RN[r], CAP));
            end
            if (pairs[r][s.txnid].have[p])
                fail($sformatf("M3: part %0d of SnpDVMOp TxnID %0d sent twice to %0d", p + 1, s.txnid, RN[r]));
            pairs[r][s.txnid].have[p]    = 1'b1;
            pairs[r][s.txnid].addr[p]    = s.addr;
            pairs[r][s.txnid].fwdnid[p]  = s.fwdnid;
            pairs[r][s.txnid].vmidext[p] = s.fwdtxnid.vmidext[7:0];
            if (p == 0) begin
                pairs[r][s.txnid].sync = (s.addr[10:8] == 3'b100);
                if (pairs[r][s.txnid].sync) begin
                    if (sync_out[r] != 0)
                        fail($sformatf("M5: a second SnpDVMOp(Sync) outstanding to %0d (Sec 8.1.3 p.8-307)", RN[r]));
                    sync_out[r]++;
                end
                else begin
                    ns_out[r]++;
                end
            end
            if (pairs[r][s.txnid].have[0] && pairs[r][s.txnid].have[1]) begin
                got.push_back(pairs[r][s.txnid]);
                got_rn.push_back(r);
                got_cyc.push_back(cycle);
                got_txn.push_back(s.txnid);
                begin
                    automatic bit          sy = pairs[r][s.txnid].sync;
                    automatic int          rr = r;
                    automatic logic [11:0] tx = s.txnid;
                    fork
                        answer(rr, tx, sy);
                    join_none
                end
                pairs[r].delete(s.txnid);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Requester side
    // -------------------------------------------------------------------------
    // Table 8-8 (p.8-317): Req.Addr fields of a DVMOp.
    function automatic logic [43:0] dvm_addr(logic [2:0] typ, logic [63:0] rnd);
        logic [43:0] a;
        a        = '0;
        if (typ != 3'b100) begin
            a[10:4]  = rnd[6:0];
            a[42:14] = rnd[35:7];
        end
        a[13:11] = typ;
        return a;
    endfunction

    // Table 8-8 (p.8-317/8-318) and Table 8-9 (p.8-320), at Req_Addr_Width 44.
    function automatic void expect_pair(logic [43:0] ra, logic [63:0] d, output pair_t e);
        logic pa;
        pa = (ra[13:11] == 3'b010);
        e.addr[0] = '0;
        e.addr[1] = '0;
        e.addr[1][0] = 1'b1;
        for (int x = 1; x <= 37; x++) e.addr[0][x] = ra[x + 3];
        if (!pa) begin
            e.addr[0][38] = d[44];
            e.addr[0][39] = d[45];
            e.addr[0][40] = d[46];
        end
        for (int x = 1; x <= 40; x++) e.addr[1][x] = d[x + 3];
        e.fwdnid[0]  = {6'b0, ra[41]};
        e.fwdnid[1]  = {2'b0, ra[42], d[3:0]};
        e.vmidext[0] = d[63:56];
        e.vmidext[1] = '0;
    endfunction

    typedef struct {
        integer acc_cyc;
        integer comp_cyc;
        integer first_snp_cyc;
        integer n_pairs;
    } op_rec_t;

    // One DVMOp from Requester `src`, through M1..M3.
    task automatic mn_dvm(input int src, input logic [11:0] txnid, input logic [2:0] typ,
                       input logic [63:0] rnd, input logic [63:0] d, output op_rec_t rec);
        chie_pkg::req_flit_s req;
        chie_pkg::dat_flit_s dat;
        chie_pkg::rsp_flit_s r;
        integer              at, got0, mn_txn, n_exp;
        bit                  ok, retried;
        pair_t               e;
        string               what;
        what = $sformatf("DVMOp type %b TxnID 0x%0h from %0d", typ, txnid, RN[src]);
        rec  = '{default: -1};
        rec.n_pairs = 0;
        req            = '0;
        req.opcode     = chie_pkg::REQ_DVMOP;
        req.size       = chie_pkg::SIZE_8B;
        req.addr       = dvm_addr(typ, rnd);
        req.srcid      = RN[src];
        req.tgtid      = HOME_NID;
        req.txnid      = txnid;
        req.allowretry = 1'b1;
        retried        = 1'b0;

        forever begin
            sem_req.get();
            send_req(req);
            sem_req.put();
            take_rsp(txnid, r, at, ok);
            if (!ok) begin fail({"M1: ", what, " got no response"}); return; end
            if (r.opcode != chie_pkg::RSP_RETRYACK) break;
            // Sec 2.11 (p.2-145): resend with AllowRetry deasserted on the P-Credit.
            retried = 1'b1;
            wait_pcrd(RN[src], r.pcrdtype, ok);
            if (!ok) begin fail({"M5: ", what, " RetryAck'd and never P-Credited"}); return; end
            req.allowretry = 1'b0;
            req.pcrdtype   = r.pcrdtype;
        end
        if (r.opcode != chie_pkg::RSP_DBIDRESP) begin
            fail($sformatf("M1: %s answered %s first -- the MN sends DBIDResp", what, r.opcode.name()));
            return;
        end
        if (r.resperr != chie_pkg::RESP_ERR_NORM_OK || r.resp != chie_pkg::RESP_I || r.srcid != HOME_NID)
            fail({"M1: ", what, " DBIDResp with RespErr/Resp non-zero or SrcID not the MN (Table 8-4 p.8-312)"});
        rec.acc_cyc = at;
        mn_txn      = int'(r.dbid);
        n_exp       = 0;
        for (int t = 0; t < R; t++) n_exp += (t != src) && coh[t];
        // Pairs for this DVMOp follow its write data, and the entry's previous user
        // had all of its pairs answered before its Comp.
        got0        = got.size();

        dat           = '0;
        dat.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
        dat.srcid     = RN[src];
        dat.tgtid     = r.srcid;
        dat.txnid     = r.dbid;
        dat.be        = 'hFF;
        dat.data      = {{(chie_pkg::DATA_WIDTH-64){1'b0}}, d};
        dat.datacheck = chie_pkg::datacheck_of(dat.data);
        sem_dat.get();
        send_dat(dat);
        sem_dat.put();

        take_rsp(txnid, r, at, ok);
        if (!ok) begin fail({"M1: ", what, " got no Comp"}); return; end
        if (r.opcode != chie_pkg::RSP_COMP || r.resperr != chie_pkg::RESP_ERR_NORM_OK || r.resp != chie_pkg::RESP_I)
            fail($sformatf("M1: %s completed by %s RespErr %s (Table 8-6 p.8-314)", what, r.opcode.name(), r.resperr.name()));
        rec.comp_cyc = at;

        // M2/M3: the pairs carrying this DVMOp's MN TxnID since its DBIDResp.
        expect_pair(req.addr, d, e);
        for (int k = got0; k < got.size(); k++) begin
            if (got_txn[k] != 12'(mn_txn)) continue;
            rec.n_pairs++;
            if (rec.first_snp_cyc < 0) rec.first_snp_cyc = got_cyc[k];
            if (RN[got_rn[k]] == RN[src])
                fail({"M2: ", what, " snooped the Requester that sent it"});
            if (got[k].addr[0] != e.addr[0] || got[k].addr[1] != e.addr[1])
                fail($sformatf("M3: %s Addr %h/%h, expected %h/%h", what,
                               got[k].addr[0], got[k].addr[1], e.addr[0], e.addr[1]));
            if (got[k].fwdnid[0] != e.fwdnid[0] || got[k].fwdnid[1] != e.fwdnid[1] ||
                got[k].vmidext[0] != e.vmidext[0] || got[k].vmidext[1] != e.vmidext[1])
                fail($sformatf("M3: %s FwdNID %h/%h VMIDExt %h/%h, expected %h/%h %h/%h", what,
                               got[k].fwdnid[0], got[k].fwdnid[1], got[k].vmidext[0], got[k].vmidext[1],
                               e.fwdnid[0], e.fwdnid[1], e.vmidext[0], e.vmidext[1]));
        end
        if (rec.n_pairs != n_exp)
            fail($sformatf("M2: %s reached %0d Requesters, expected %0d", what, rec.n_pairs, n_exp));
        if (snp_resp_cyc.exists(12'(mn_txn)) && snp_resp_cyc[12'(mn_txn)] > rec.comp_cyc)
            fail({"M2: ", what, " completed before its last SnpResp"});
    endtask

    // PCrdGrants are addressed by TgtID and carry no TxnID (Sec 2.6.5 p.2-111).
    task automatic wait_pcrd(input logic [6:0] tgt, input logic [3:0] ptype, output bit ok);
        ok = 1'b0;
        for (int n = 0; n < 4 * TIMEOUT_CYCLES && !ok; n++) begin
            for (int i = 0; i < rsp_q.size() && !ok; i++)
                if (rsp_q[i].opcode == chie_pkg::RSP_PCRDGRANT && rsp_q[i].tgtid == tgt &&
                    rsp_q[i].pcrdtype == ptype) begin
                    rsp_q.delete(i); rsp_cyc.delete(i);
                    ok = 1'b1;
                end
            if (!ok) @(posedge CLK);
        end
    endtask

    // -------------------------------------------------------------------------
    integer retry_seen = 0, first_pcrd_cyc = -1;
    always @(posedge CLK) if (!RST && TXRSPFLITV && TXRSPFLIT.opcode == chie_pkg::RSP_PCRDGRANT && first_pcrd_cyc < 0)
        first_pcrd_cyc = cycle;
    always @(posedge CLK) if (!RST && TXRSPFLITV && TXRSPFLIT.opcode == chie_pkg::RSP_RETRYACK) begin
        retry_seen++;
        if (TXRSPFLIT.pcrdtype != `MN_PCRD_SYNC)
            fail("M5: a Non-sync DVMOp was RetryAck'd while an entry was reserved for it");
    end

    initial begin
        op_rec_t a, b, c, s [ENTRIES];
        bit      ok;
        bring_up;
        refill_en = 1'b1;
        if (errors == 0) begin
            // M1..M3, one of every operation type (Table 8-7 p.8-315).
            mn_dvm(0, 12'h010, 3'b000, 64'h1234_5678_9abc_def0, 64'hfedc_ba98_7654_3210, a);
            mn_dvm(1, 12'h011, 3'b001, 64'h0f0f_0f0f_0f0f_0f0f, 64'h5a5a_5a5a_5a5a_5a5a, a);
            mn_dvm(2, 12'h012, 3'b010, 64'h3333_cccc_3333_cccc, 64'h0123_4567_89ab_cdef, a);
            mn_dvm(3, 12'h013, 3'b011, 64'hffff_ffff_ffff_ffff, 64'hffff_ffff_ffff_ffff, a);
            mn_dvm(0, 12'h014, 3'b100, 64'h0,                   64'h0,                   a);

            // M4: a Non-sync with a slow snoopee, then a Sync from another Requester.
            resp_delay[3] = 150;
            fork
                mn_dvm(0, 12'h020, 3'b000, 64'h2468_ace0_1357_9bdf, 64'h1111_2222_3333_4444, a);
                begin
                    repeat (20) @(posedge CLK);
                    mn_dvm(1, 12'h021, 3'b100, 64'h0, 64'h0, b);
                end
            join
            resp_delay[3] = 2;
            if (b.first_snp_cyc < a.comp_cyc)
                fail($sformatf("M4: the Sync snooped at cycle %0d, before the older Non-sync completed at %0d",
                               b.first_snp_cyc, a.comp_cyc));
            if (b.comp_cyc < a.comp_cyc)
                fail("M4: the Sync completed before the older Non-sync");

            // M5: Syncs stall on a slow snoopee until they hold all but one entry; the
            // next Sync is RetryAck'd, a Non-sync still enters, and the retried Sync
            // completes on its P-Credit.
            resp_delay[2] = 300;
            fork
                mn_dvm(0, 12'h030, 3'b100, 64'h0, 64'h0, s[0]);
                begin repeat (5)  @(posedge CLK); mn_dvm(0, 12'h031, 3'b100, 64'h0, 64'h0, s[1]); end
                begin repeat (10) @(posedge CLK); mn_dvm(0, 12'h032, 3'b100, 64'h0, 64'h0, s[2]); end
                begin repeat (15) @(posedge CLK); mn_dvm(0, 12'h033, 3'b100, 64'h0, 64'h0, s[3]); end
                begin
                    repeat (60) @(posedge CLK);
                    mn_dvm(1, 12'h040, 3'b000, 64'h7777_8888_9999_aaaa, 64'hbbbb_cccc_dddd_eeee, c);
                    if (c.acc_cyc < 0 || (first_pcrd_cyc >= 0 && c.acc_cyc > first_pcrd_cyc))
                        fail("M5: the Non-sync did not enter while Syncs held the other entries (Sec 8.1.3 p.8-307)");
                end
            join
            resp_delay[2] = 2;

            // M6: Requester 48 leaves the coherency domain.
            coh[3] = 1'b0;
            mn_dvm(0, 12'h050, 3'b000, 64'h0bad_cafe_0bad_cafe, 64'h1357_2468_1357_2468, a);
            coh[3] = 1'b1;
            if (retry_seen == 0)
                fail("M5: no Sync was RetryAck'd though the Syncs outnumbered the entries they may hold");
        end
        repeat (50) @(posedge CLK);
        finish_bench;
    end

endmodule
