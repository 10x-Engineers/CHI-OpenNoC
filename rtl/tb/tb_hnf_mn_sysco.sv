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
// tb_hnf_mn_sysco -- the HN-F owns each RN-F's SYSCOACK, the MN snoops the same
// RN-F with SnpDVMOp pairs. The bench plays two DVM Requesters on the MN's link
// (tb_home_peer.svh); the HN-F's own link stays down, as it sends no snoop here.
//
//   S1 Sec 15.2.2 (p.15-468, MUST): the interconnect must "complete all snoop
//      accesses to the interface before it sets SYSCOACK LOW" -- a Requester that
//      drops SYSCOREQ with a SnpDVMOp pair to it unanswered keeps SYSCOACK HIGH
//      until it has answered, and then sees it fall.
// =============================================================================
`include "mn_defines.svh"
`include "mn_param.svh"

module tb_hnf_mn_sysco;

    localparam string BENCH    = "tb_hnf_mn_sysco";
    localparam        HOME_NID = 4;
    localparam        RN_NID   = 8;
    localparam int    R        = 2;
    localparam logic [6:0] RN [R] = '{7'd8, 7'd40};
    localparam int    RESP_DELAY = 200;

`include "tb_home_peer.svh"

    wire                         TXSNPFLITV, TXSNPFLITPEND;
    opennoc_mn_pkg::snp_routed_s TXSNPFLIT;
    reg   [R-1:0]                SYSCOREQ = '1;
    wire  [R-1:0]                SYSCOACK;
    wire  [R-1:0]                snp_pend;

    mn #(
        .MN_NID_PARAM           (HOME_NID        ),
        .MN_ENTRIES_NUM_PARAM   (4               ),
        .MN_RN_NUM_PARAM        (R               ),
        .MN_RN_NID_LIST_PARAM   ({RN[1], RN[0]}  ),
        .MN_RN_SNPDVM_NUM_PARAM (2               )
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
        .SYSCO_SNP_EN(SYSCOREQ), .SYSCO_SNP_PEND(snp_pend)
    );

    // The Home the RN-Fs' SYSCO pairs run to, its CHI link idle.
    chie_pkg::req_flit_s          hnf_txreqflit;
    chie_pkg::rsp_flit_s          hnf_txrspflit;
    chie_pkg::dat_flit_s          hnf_txdatflit;
    opennoc_hnf_pkg::snp_routed_s hnf_txsnpflit;
    wire [2:0]                    notify_reg;

    hnf #(
        .HNF_MSHR_RNF_NUM_PARAM (R             ),
        .HNF_MSHR_RNI_NUM_PARAM (0             ),
        .RNF_NID_LIST_PARAM     ({RN[1], RN[0]}),
        .HNF_NID_PARAM          (0             ),
        .SNF_NID_PARAM          (32            ),
        .HNF_SF_ENTRIES_NUM_PARAM(1024         ),
        .HNF_L3_CACHE_SIZE_PARAM(64            )
    ) u_hnf (
        .CLK(CLK), .RST(RST),
        .TXLINKACTIVEREQ(), .TXLINKACTIVEACK(1'b0),
        .RXLINKACTIVEREQ(1'b0), .RXLINKACTIVEACK(),
        .TXSACTIVE(), .RXSACTIVE(1'b0),
        .RXREQFLITV(1'b0), .RXREQFLIT('0), .RXREQFLITPEND(1'b0),
        .RXRSPFLITV(1'b0), .RXRSPFLIT('0), .RXRSPFLITPEND(1'b0),
        .RXDATFLITV(1'b0), .RXDATFLIT('0), .RXDATFLITPEND(1'b0),
        .TXREQLCRDV(1'b0), .TXRSPLCRDV(1'b0), .TXSNPLCRDV(1'b0), .TXDATLCRDV(1'b0),
        .RXREQLCRDV(), .RXRSPLCRDV(), .RXDATLCRDV(),
        .TXREQFLITV(), .TXREQFLIT(hnf_txreqflit), .TXREQFLITPEND(),
        .TXRSPFLITV(), .TXRSPFLIT(hnf_txrspflit), .TXRSPFLITPEND(),
        .TXSNPFLITV(), .TXSNPFLIT(hnf_txsnpflit), .TXSNPFLITPEND(),
        .TXDATFLITV(), .TXDATFLIT(hnf_txdatflit), .TXDATFLITPEND(),
        .SYSCOREQ(SYSCOREQ), .SYSCOACK(SYSCOACK), .SYSCO_SNP_PEND(snp_pend),
        .notify_reg(notify_reg),
        .SNPQ_REQ_VALID(1'b0), .SNPQ_REQ_READY(), .SNPQ_REQ_ADDR('0), .SNPQ_REQ_NS(1'b0),
        .SNPQ_REQ_RN('0), .SNPQ_RSP_VALID(), .SNPQ_RSP_SENT(), .SNPQ_RSP_RESP(), .SNPQ_RSP_RESPERR()
    );

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

    // RN0's SnpDVMOp pair: both parts in, then its SnpResp after RESP_DELAY cycles.
    bit          pair_in    = 1'b0;
    bit          answered   = 1'b0;
    bit [1:0]    parts      = '0;
    logic [11:0] pair_txnid;
    always @(posedge CLK) if (!RST && TXSNPFLITV && (TXSNPFLIT.flit.opcode == chie_pkg::SNP_SNPDVMOP) &&
                              (TXSNPFLIT.tgtid == RN[0])) begin
        parts[TXSNPFLIT.flit.addr[0]] = 1'b1;
        pair_txnid                    = TXSNPFLIT.flit.txnid;
        if (&parts) pair_in = 1'b1;
    end

    task automatic answer_rn0;
        chie_pkg::rsp_flit_s f;
        repeat (RESP_DELAY) @(posedge CLK);
        f        = '0;
        f.opcode = chie_pkg::RSP_SNPRESP;
        f.srcid  = RN[0];
        f.tgtid  = HOME_NID;
        f.txnid  = pair_txnid;
        f.resp   = chie_pkg::RESP_I;
        send_rsp(f);
        answered = 1'b1;
    endtask

    // A Non-sync DVMOp from RN1, which the MN snoops RN0 for (Sec 8.1.1 p.8-305).
    task automatic rn1_dvmop;
        chie_pkg::req_flit_s req;
        chie_pkg::dat_flit_s dat;
        chie_pkg::rsp_flit_s r;
        integer              at;
        bit                  ok;
        req            = '0;
        req.opcode     = chie_pkg::REQ_DVMOP;
        req.size       = chie_pkg::SIZE_8B;
        req.srcid      = RN[1];
        req.tgtid      = HOME_NID;
        req.txnid      = 12'h21;
        req.allowretry = 1'b1;
        send_req(req);
        take_rsp(req.txnid, r, at, ok);
        if (!ok || r.opcode != chie_pkg::RSP_DBIDRESP) begin fail("S1: the DVMOp was not granted"); return; end
        dat           = '0;
        dat.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
        dat.srcid     = RN[1];
        dat.tgtid     = r.srcid;
        dat.txnid     = r.dbid;
        dat.be        = 'hFF;
        dat.datacheck = chie_pkg::datacheck_of(dat.data);
        send_dat(dat);
        take_rsp(req.txnid, r, at, ok);
        if (!ok || r.opcode != chie_pkg::RSP_COMP) fail("S1: the DVMOp was not completed");
    endtask

    // S1: from RN0's SYSCOREQ fall to its SnpResp, SYSCOACK stays HIGH.
    always @(posedge CLK) if (!RST && pair_in && !answered && !SYSCOREQ[0] && !SYSCOACK[0])
        fail("S1: SYSCOACK fell with a SnpDVMOp pair to that Requester unanswered (Sec 15.2.2 p.15-468)");

    initial begin
        bring_up;
        refill_en = 1'b1;
        fork begin
            fork
                wait (&SYSCOACK);
                begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("S1: the HN-F never granted SYSCOACK"); end
            join_any
            disable fork;
        end join
        if (errors == 0) begin
            fork
                rn1_dvmop;
                begin
                    fork
                        wait (pair_in);
                        begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("S1: no SnpDVMOp pair reached RN0"); end
                    join_any
                    disable fork;
                    // Sec 15.2 (p.15-467): SYSCOREQ changes only while SYSCOACK matches it.
                    @(posedge CLK) SYSCOREQ[0] <= 1'b0;
                    answer_rn0;
                    fork
                        wait (!SYSCOACK[0]);
                        begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("S1: SYSCOACK never fell once the pair was answered"); end
                    join_any
                    disable fork;
                    if (!SYSCOACK[1]) fail("S1: the other Requester's SYSCOACK fell");
                end
            join
        end
        repeat (50) @(posedge CLK);
        finish_bench;
    end

endmodule
