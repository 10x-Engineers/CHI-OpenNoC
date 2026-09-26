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
// tb_hnf_mte -- a WriteNoSnp with TagOp Match to memory that is not Normal
// WriteBack. Sec 12.1 (p.12-372) permits tagging in no request to such memory,
// so the HN-F forwards none downstream, and Sec 12.11.3 (p.12-387, MUST) still
// owes the Requester a TagMatch -- a Fail -- which the Home sends itself. A small
// Subordinate emulator answers the Home's downstream write in either shape:
// DWT (only the Comp reaches the Home) or staged through the Home.
// =============================================================================
`include "hnf_defines.svh"
`include "hnf_param.svh"

module tb_hnf_mte;

  parameter CHIE_REQ_ADDR_WIDTH_PARAM   = chie_pkg::REQ_ADDR_WIDTH;
  parameter CHIE_SNP_ADDR_WIDTH_PARAM   = chie_pkg::SNP_ADDR_WIDTH;
  parameter CHIE_NID_WIDTH_PARAM        = chie_pkg::NID_WIDTH;
  parameter CHIE_DATA_WIDTH_PARAM       = chie_pkg::DATA_WIDTH;
  parameter CHIE_BE_WIDTH_PARAM         = chie_pkg::BE_WIDTH;
  parameter CHIE_DATACHECK_WIDTH_PARAM  = chie_pkg::DATACHECK_WIDTH;
  parameter CHIE_POISON_WIDTH_PARAM     = chie_pkg::POISON_WIDTH;
  parameter CHIE_REQ_RSVDC_WIDTH_PARAM  = chie_pkg::REQ_RSVDC_WIDTH;
  parameter CHIE_DAT_RSVDC_WIDTH_PARAM  = chie_pkg::DAT_RSVDC_WIDTH;
  parameter HNF_MSHR_RNF_NUM_PARAM      = 4;
  parameter HNF_MSHR_RNI_NUM_PARAM      = 0;
  parameter RNF_NID_LIST_PARAM          = {7'd40, 7'd8};
  parameter RNI_NID_LIST_PARAM          = {7'd1};
  parameter HNF_NID_PARAM               = 0;
  parameter SNF_NID_PARAM               = 32;
  parameter XP_LCRD_NUM_PARAM           = 15;
  parameter HNF_SF_ENTRIES_NUM_PARAM    = 1024;
  parameter HNF_SF_WAY_NUM_PARAM        = 16;
  parameter HNF_MSHR_EXCL_RN_NUM_PARAM  = 32;
  parameter HNF_MSHR_EXCL_RN_WIDTH_PARAM= 5;
  parameter HNF_MSHR_ENTRIES_NUM_PARAM  = 32;
  parameter HNF_MSHR_ENTRIES_WIDTH_PARAM= 5;
  parameter HNF_L3_CACHE_SIZE_PARAM     = 64;
  parameter HNF_L3_WAY_NUM_PARAM        = 16;

    localparam string BENCH = "tb_hnf_mte";
    localparam RN_NID       = 8;
    localparam HOME_NID     = HNF_NID_PARAM;

`include "tb_home_peer.svh"

    wire TXREQFLITV, TXSNPFLITV, TXREQFLITPEND, TXSNPFLITPEND;
    chie_pkg::req_flit_s          TXREQFLIT;
    opennoc_hnf_pkg::snp_routed_s TXSNPFLIT;
    wire [2:0] notify_reg;
    // Table 15-1 (p.15-468): a Home snoops only a Requester inside the coherency
    // domain, so both RN-Fs join it before any request is sent.
    reg  [HNF_MSHR_RNF_NUM_PARAM-1:0] SYSCOREQ = '1;
    wire [HNF_MSHR_RNF_NUM_PARAM-1:0] SYSCOACK;

    hnf #(
        .CHIE_REQ_ADDR_WIDTH_PARAM   (CHIE_REQ_ADDR_WIDTH_PARAM),
        .CHIE_SNP_ADDR_WIDTH_PARAM   (CHIE_SNP_ADDR_WIDTH_PARAM),
        .CHIE_NID_WIDTH_PARAM        (CHIE_NID_WIDTH_PARAM),
        .CHIE_DATA_WIDTH_PARAM       (CHIE_DATA_WIDTH_PARAM),
        .CHIE_BE_WIDTH_PARAM         (CHIE_BE_WIDTH_PARAM),
        .CHIE_DATACHECK_WIDTH_PARAM  (CHIE_DATACHECK_WIDTH_PARAM),
        .CHIE_POISON_WIDTH_PARAM     (CHIE_POISON_WIDTH_PARAM),
        .CHIE_REQ_RSVDC_WIDTH_PARAM  (CHIE_REQ_RSVDC_WIDTH_PARAM),
        .CHIE_DAT_RSVDC_WIDTH_PARAM  (CHIE_DAT_RSVDC_WIDTH_PARAM),
        .HNF_MSHR_RNF_NUM_PARAM      (HNF_MSHR_RNF_NUM_PARAM),
        .HNF_MSHR_RNI_NUM_PARAM      (HNF_MSHR_RNI_NUM_PARAM),
        .RNF_NID_LIST_PARAM          (RNF_NID_LIST_PARAM),
        .RNI_NID_LIST_PARAM          (RNI_NID_LIST_PARAM),
        .HNF_NID_PARAM               (HNF_NID_PARAM),
        .SNF_NID_PARAM               (SNF_NID_PARAM),
        .XP_LCRD_NUM_PARAM           (XP_LCRD_NUM_PARAM),
        .HNF_SF_ENTRIES_NUM_PARAM    (HNF_SF_ENTRIES_NUM_PARAM),
        .HNF_SF_WAY_NUM_PARAM        (HNF_SF_WAY_NUM_PARAM),
        .HNF_MSHR_EXCL_RN_NUM_PARAM  (HNF_MSHR_EXCL_RN_NUM_PARAM),
        .HNF_MSHR_EXCL_RN_WIDTH_PARAM(HNF_MSHR_EXCL_RN_WIDTH_PARAM),
        .HNF_MSHR_ENTRIES_NUM_PARAM  (HNF_MSHR_ENTRIES_NUM_PARAM),
        .HNF_MSHR_ENTRIES_WIDTH_PARAM(HNF_MSHR_ENTRIES_WIDTH_PARAM),
        .HNF_L3_CACHE_SIZE_PARAM     (HNF_L3_CACHE_SIZE_PARAM),
        .HNF_L3_WAY_NUM_PARAM        (HNF_L3_WAY_NUM_PARAM)
    ) u_hnf (
        .CLK(CLK), .RST(RST),
        .TXLINKACTIVEREQ(TXLINKACTIVEREQ), .TXLINKACTIVEACK(TXLINKACTIVEACK),
        .RXLINKACTIVEREQ(RXLINKACTIVEREQ), .RXLINKACTIVEACK(RXLINKACTIVEACK),
        .TXSACTIVE(TXSACTIVE), .RXSACTIVE(RXSACTIVE),
        .RXREQFLITV(RXREQFLITV), .RXREQFLIT(RXREQFLIT), .RXREQFLITPEND(RXREQFLITPEND),
        .RXRSPFLITV(RXRSPFLITV), .RXRSPFLIT(RXRSPFLIT), .RXRSPFLITPEND(RXRSPFLITPEND),
        .RXDATFLITV(RXDATFLITV), .RXDATFLIT(RXDATFLIT), .RXDATFLITPEND(RXDATFLITPEND),
        .TXREQLCRDV(TXREQLCRDV), .TXRSPLCRDV(TXRSPLCRDV),
        .TXSNPLCRDV(TXSNPLCRDV), .TXDATLCRDV(TXDATLCRDV),
        .RXREQLCRDV(RXREQLCRDV), .RXRSPLCRDV(RXRSPLCRDV), .RXDATLCRDV(RXDATLCRDV),
        .TXREQFLITV(TXREQFLITV), .TXREQFLIT(TXREQFLIT), .TXREQFLITPEND(TXREQFLITPEND),
        .TXRSPFLITV(TXRSPFLITV), .TXRSPFLIT(TXRSPFLIT), .TXRSPFLITPEND(TXRSPFLITPEND),
        .TXSNPFLITV(TXSNPFLITV), .TXSNPFLIT(TXSNPFLIT), .TXSNPFLITPEND(TXSNPFLITPEND),
        .TXDATFLITV(TXDATFLITV), .TXDATFLIT(TXDATFLIT), .TXDATFLITPEND(TXDATFLITPEND),
        .SYSCOREQ(SYSCOREQ), .SYSCOACK(SYSCOACK), .SYSCO_SNP_PEND({HNF_MSHR_RNF_NUM_PARAM{1'b0}}),
        .notify_reg(notify_reg),
        .SNPQ_REQ_VALID(1'b0), .SNPQ_REQ_READY(), .SNPQ_REQ_ADDR('0), .SNPQ_REQ_NS(1'b0),
        .SNPQ_REQ_RN('0), .SNPQ_RSP_VALID(), .SNPQ_RSP_SENT(), .SNPQ_RSP_RESP(), .SNPQ_RSP_RESPERR()
    );

    chie_pkg::req_flit_s dn_q[$];
    chie_pkg::dat_flit_s dn_dat_q[$];
    always @(posedge CLK) begin
        if (!RST && TXREQFLITV && (TXREQFLIT.opcode != chie_pkg::REQ_REQLCRDRETURN)) dn_q.push_back(TXREQFLIT);
        if (!RST && TXDATFLITV && (TXDATFLIT.tgtid == SNF_NID_PARAM))                dn_dat_q.push_back(TXDATFLIT);
    end

    // The Subordinate's half of the Home's downstream write (Sec 2.3.9 p.2-78).
    task automatic serve_downstream(input chie_pkg::req_flit_s dn);
        chie_pkg::rsp_flit_s rsp;
        integer n;
        begin
            if (dn.tagop != chie_pkg::TAGOP_INVALID)
                fail($sformatf("%s to the Subordinate carries TagOp %0d for memory that is not Normal WriteBack (Sec 12.1 p.12-372)",
                               dn.opcode.name(), dn.tagop));
            rsp       = '0;
            rsp.srcid = SNF_NID_PARAM;
            rsp.tgtid = HOME_NID;
            rsp.txnid = dn.txnid;
            // Under DWT the grant and the data run between Requester and Subordinate,
            // off this link; the Home hears only the Comp.
            if (!dn.snpattr.dodwt) begin
                rsp.opcode = chie_pkg::RSP_DBIDRESP;
                rsp.dbid   = 12'h7;
                send_rsp(rsp);
                for (n = 0; n < TIMEOUT_CYCLES && dn_dat_q.size() == 0; n = n + 1) @(posedge CLK);
                if (dn_dat_q.size() == 0) begin
                    fail("the Home never sent its write data to the Subordinate");
                    return;
                end
                if (dn_dat_q[0].tagop != chie_pkg::TAGOP_INVALID)
                    fail("write data to the Subordinate carries a TagOp its request does not (Sec 12.13 p.12-390)");
                dn_dat_q.delete(0);
            end
            rsp.opcode = chie_pkg::RSP_COMP;
            send_rsp(rsp);
        end
    endtask

    task automatic match_write(input logic [11:0] txnid, input logic [chie_pkg::REQ_ADDR_WIDTH-1:0] addr);
        chie_pkg::req_flit_s req;
        chie_pkg::dat_flit_s dat;
        chie_pkg::rsp_flit_s r;
        integer              n, i;
        bit                  ok, sent, dn_done;
        begin
            req            = '0;
            req.opcode     = chie_pkg::REQ_WRITENOSNPPTL;
            req.size       = chie_pkg::SIZE_8B;
            req.addr       = addr;
            req.srcid      = RN_NID;
            req.tgtid      = HOME_NID;
            req.txnid      = txnid;
            req.allowretry = 1'b1;
            req.tagop      = chie_pkg::TAGOP_MATCH;
            req.lpid       = 8'h5;   // TagGroupID (Sec 13.10.40 p.13-435)
            send_req(req);

            // Serve whichever shape the Home takes until the Requester's Comp arrives.
            sent = 1'b0; dn_done = 1'b0; ok = 1'b0;
            for (n = 0; n < TIMEOUT_CYCLES && !ok; n = n + 1) begin
                if (dn_q.size() > 0) begin
                    if (dn_q[0].snpattr.dodwt) sent = 1'b1;   // the data goes to the Subordinate
                    serve_downstream(dn_q[0]);
                    dn_q.delete(0);
                    dn_done = 1'b1;
                end
                for (i = 0; i < rsp_q.size(); i = i + 1)
                    if (rsp_q[i].txnid == txnid && rsp_q[i].opcode == chie_pkg::RSP_DBIDRESP && !sent) begin
                        dat           = '0;
                        dat.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
                        dat.srcid     = RN_NID;
                        dat.tgtid     = rsp_q[i].srcid;
                        dat.txnid     = rsp_q[i].dbid;
                        dat.be        = 'hFF;
                        dat.tagop     = chie_pkg::TAGOP_MATCH;
                        dat.datacheck = chie_pkg::datacheck_of(dat.data);
                        rsp_q.delete(i); rsp_cyc.delete(i);
                        send_dat(dat);
                        sent = 1'b1;
                        break;
                    end
                for (i = 0; i < rsp_q.size(); i = i + 1)
                    if (rsp_q[i].txnid == txnid &&
                        rsp_q[i].opcode inside {chie_pkg::RSP_COMP, chie_pkg::RSP_COMPDBIDRESP}) ok = 1'b1;
                if (!ok) @(posedge CLK);
            end
            if (!ok) fail("the Match write never completed");
            if (!dn_done) fail("the Home never wrote to the Subordinate");

            take_rsp_op(chie_pkg::RSP_TAGMATCH, r, ok);
            if (!ok)
                fail("no TagMatch for a TagOp Match write -- Sec 12.11.3 (p.12-387, MUST) owes one even where MTE is not supported");
            else if (r.resp[0] != 1'b0)
                fail("TagMatch reports Pass for memory without MTE -- Sec 12.11.3 (p.12-387, MUST) requires Fail");
        end
    endtask

    initial begin
        bring_up;
        // notify_reg reports the SRAM initialisation done, as tb_hnf waits for it.
        fork begin
            fork
                wait ((notify_reg == 3'd7) && (&SYSCOACK));
                begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("HN-F never finished initialising or never granted SYSCOACK"); end
            join_any
            disable fork;
        end join
        if (errors == 0) match_write(12'h31, 'h5000);
        finish_bench;
    end

endmodule
