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
// tb_hnf_stash -- a Stash request naming a target the HN-F declares unable to
// receive Stash snoops. RNF_STASH_LIST_PARAM is left at its default, which
// declares no RN-F stash-capable, so Sec 9.4.6 (p.9-344, MUST) has the Home
// "disregard the Stash hint and complete the transaction without Stashing" and
// "not signal an error": no Stash snoop leaves, and the Comp carries RespErr OK.
// =============================================================================
`include "hnf_defines.svh"
`include "hnf_param.svh"

module tb_hnf_stash;

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

    localparam string BENCH = "tb_hnf_stash";
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
        .SYSCOREQ(SYSCOREQ), .SYSCOACK(SYSCOACK),
        .notify_reg(notify_reg),
        .SNPQ_REQ_VALID(1'b0), .SNPQ_REQ_READY(), .SNPQ_REQ_ADDR('0), .SNPQ_REQ_NS(1'b0),
        .SNPQ_REQ_RN('0), .SNPQ_RSP_VALID(), .SNPQ_RSP_SENT(), .SNPQ_RSP_RESP(), .SNPQ_RSP_RESPERR()
    );

    // RNF_NID_LIST_PARAM's other RN-F, named as the target.
    localparam STASH_NID = 40;

    always @(posedge CLK)
        if (!RST && TXSNPFLITV && (TXSNPFLIT.flit.opcode inside {chie_pkg::SNP_SNPSTASHUNIQUE,
                                                                 chie_pkg::SNP_SNPSTASHSHARED,
                                                                 chie_pkg::SNP_SNPUNIQUESTASH,
                                                                 chie_pkg::SNP_SNPMAKEINVALIDSTASH}))
            fail($sformatf("%s sent to 0x%0h, a target declared unable to receive Stash snoops (Sec 9.4.6 p.9-344)",
                           TXSNPFLIT.flit.opcode.name(), TXSNPFLIT.tgtid));

    task automatic stash_once(input chie_pkg::req_opcode_e op, input logic [11:0] txnid,
                              input logic [chie_pkg::REQ_ADDR_WIDTH-1:0] addr);
        chie_pkg::req_flit_s req;
        chie_pkg::rsp_flit_s r;
        integer              r_at;
        bit                  ok;
        begin
            req                             = '0;
            req.opcode                      = op;
            req.size                        = chie_pkg::SIZE_64B;
            req.addr                        = addr;
            req.srcid                       = RN_NID;
            req.tgtid                       = HOME_NID;
            req.txnid                       = txnid;
            req.allowretry                  = 1'b1;
            req.snpattr.snpattr             = 1'b1;
            req.memattr.cacheable           = 1'b1;
            req.memattr.allocate            = 1'b1;
            req.stashnidvalid.stashnidvalid = 1'b1;
            req.returnnid                   = STASH_NID;
            send_req(req);
            take_rsp(txnid, r, r_at, ok);
            if (!ok)
                fail($sformatf("%s got no completion", op.name()));
            else if (r.opcode != chie_pkg::RSP_COMP)
                fail($sformatf("%s completed by %s, not Comp (Table 4-38 p.4-218)", op.name(), r.opcode.name()));
            else if (r.resperr != chie_pkg::RESP_ERR_NORM_OK)
                fail($sformatf("%s Comp carries RespErr %s -- Sec 9.4.6 (p.9-344, MUST) signals no error", op.name(), r.resperr.name()));
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
        if (errors == 0) begin
            stash_once(chie_pkg::REQ_STASHONCEUNIQUE, 12'h21, 'h4000);
            stash_once(chie_pkg::REQ_STASHONCESHARED, 12'h22, 'h4040);
            // Sec 14.7.2 (p.14-460): TXSACTIVE stays up while the Home has protocol
            // work outstanding, a snoop included, so its fall is when none can follow.
            fork begin
                fork
                    wait (!TXSACTIVE);
                    begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("TXSACTIVE never fell"); end
                join_any
                disable fork;
            end join
        end
        finish_bench;
    end

endmodule
