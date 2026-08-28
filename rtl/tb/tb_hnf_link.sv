// =============================================================================
// tb_hnf_link -- Chapter 14 link-activation conformance check for hnf.v.
//
// Licence-free (Verilator --binary), so it runs in CI alongside tools/lint.sh.
// It drives the peer half of the CHI link and judges the three rules the HN-F
// had no wires to answer for before CHI-OpenNoC#3:
//
//   R1 Table 14-2 STOP/ACTIVATE (p.14-450, MUST): "The Receiver must not send
//      any credits" -- so no RX*LCRDV before RXLINKACTIVEACK, reset included.
//   R2 Table 14-2 RUN (p.14-450): the Receiver sends credits once in RUN, and
//      Sec 14.2.1 (p.14-445) bounds the outstanding count at 15.
//   R3 Table 14-2 DEACTIVATE (p.14-450, MUST): "The Receiver must wait for all
//      credits to be returned before deasserting LINKACTIVEACK", and the pool
//      must refill on re-activation.
// =============================================================================
`include "chie_defines.v"
`include "hnf_defines.v"
`include "hnf_param.v"

module tb_hnf_link;

  parameter CHIE_REQ_ADDR_WIDTH_PARAM   = 44;
  parameter CHIE_SNP_ADDR_WIDTH_PARAM   = 41;
  parameter CHIE_NID_WIDTH_PARAM        = 7;
  parameter CHIE_DATA_WIDTH_PARAM       = 256;
  parameter CHIE_BE_WIDTH_PARAM         = 32;
  parameter CHIE_DATACHECK_WIDTH_PARAM  = 0;
  parameter CHIE_POISON_WIDTH_PARAM     = 0;
  parameter CHIE_REQ_RSVDC_WIDTH_PARAM  = 0;
  parameter CHIE_DAT_RSVDC_WIDTH_PARAM  = 0;
  parameter HNF_MSHR_RNF_NUM_PARAM      = 4;
  parameter HNF_MSHR_RNI_NUM_PARAM      = 0;
  parameter RNF_NID_LIST_PARAM          = {7'd40, 7'd8};
  parameter RNI_NID_LIST_PARAM          = {7'd1};
  parameter HNF_NID_PARAM               = 0;
  parameter SNF_NID_PARAM               = 32;
  parameter XP_LCRD_NUM_PARAM           = 15;
  // Smallest legal geometry: this bench judges link activation, not the cache,
  // and the full 4MB L3 + 128K Snoop Filter costs minutes of Verilator model
  // initialisation for nothing.
  parameter HNF_SF_ENTRIES_NUM_PARAM    = 1024;
  parameter HNF_SF_WAY_NUM_PARAM        = 16;
  parameter HNF_MSHR_EXCL_RN_NUM_PARAM  = 32;
  parameter HNF_MSHR_EXCL_RN_WIDTH_PARAM= 5;
  parameter HNF_MSHR_ENTRIES_NUM_PARAM  = 32;
  parameter HNF_MSHR_ENTRIES_WIDTH_PARAM= 5;
  parameter HNF_L3_CACHE_SIZE_PARAM     = 64;
  parameter HNF_L3_WAY_NUM_PARAM        = 16;

    localparam CYCLE         = 10;
    localparam RESET_CYCLES  = 10;
    // Long enough for ACTIVATE -> RUN and the whole credit burst that follows.
    localparam SETTLE_CYCLES = 60;

    reg  CLK = 1'b0;
    reg  RST = 1'b1;
    always #(CYCLE/2) CLK = ~CLK;

    reg  RXLINKACTIVEREQ = 1'b0;
    reg  TXLINKACTIVEACK = 1'b0;
    reg  RXSACTIVE       = 1'b0;
    wire TXLINKACTIVEREQ, RXLINKACTIVEACK, TXSACTIVE;

    // The peer Receiver: Table 14-1 (p.14-449) lets LINKACTIVEACK follow
    // LINKACTIVEREQ, which is all this bench needs -- what it judges is the HN-F's
    // own half, not the peer's.
    always @(posedge CLK) begin
        if (RST) TXLINKACTIVEACK <= 1'b0;
        else     TXLINKACTIVEACK <= TXLINKACTIVEREQ;
    end

    reg  RXREQFLITV = 1'b0, RXRSPFLITV = 1'b0, RXDATFLITV = 1'b0;
    reg  RXREQFLITPEND = 1'b0, RXRSPFLITPEND = 1'b0, RXDATFLITPEND = 1'b0;
    reg [`CHIE_REQ_FLIT_RANGE] RXREQFLIT = '0;
    reg [`CHIE_RSP_FLIT_RANGE] RXRSPFLIT = '0;
    reg [`CHIE_DAT_FLIT_RANGE] RXDATFLIT = '0;
    wire RXREQLCRDV, RXRSPLCRDV, RXDATLCRDV;
    wire TXREQFLITV, TXRSPFLITV, TXSNPFLITV, TXDATFLITV;
    wire TXREQFLITPEND, TXRSPFLITPEND, TXSNPFLITPEND, TXDATFLITPEND;
    wire [`CHIE_REQ_FLIT_RANGE] TXREQFLIT;
    wire [`CHIE_RSP_FLIT_RANGE] TXRSPFLIT;
    wire [`HNF_SNP_FLIT_RANGE]  TXSNPFLIT;
    wire [`CHIE_DAT_FLIT_RANGE] TXDATFLIT;
    wire [2:0] notify_reg;

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
        .TXREQLCRDV(1'b0), .TXRSPLCRDV(1'b0), .TXSNPLCRDV(1'b0), .TXDATLCRDV(1'b0),
        .RXREQLCRDV(RXREQLCRDV), .RXRSPLCRDV(RXRSPLCRDV), .RXDATLCRDV(RXDATLCRDV),
        .TXREQFLITV(TXREQFLITV), .TXREQFLIT(TXREQFLIT), .TXREQFLITPEND(TXREQFLITPEND),
        .TXRSPFLITV(TXRSPFLITV), .TXRSPFLIT(TXRSPFLIT), .TXRSPFLITPEND(TXRSPFLITPEND),
        .TXSNPFLITV(TXSNPFLITV), .TXSNPFLIT(TXSNPFLIT), .TXSNPFLITPEND(TXSNPFLITPEND),
        .TXDATFLITV(TXDATFLITV), .TXDATFLIT(TXDATFLIT), .TXDATFLITPEND(TXDATFLITPEND),
        .notify_reg(notify_reg)
    );

    integer errors = 0;
    localparam CH_REQ = 0, CH_RSP = 1, CH_DAT = 2;
    integer crd [0:2];

    task fail(input string what);
        begin
            $display("FAIL @%0t: %s", $time, what);
            errors = errors + 1;
        end
    endtask

    // R1/R2: count the credits granted, and flag any granted before RUN.
    always @(posedge CLK) begin
        if (RXREQLCRDV | RXRSPLCRDV | RXDATLCRDV) begin
            if (RST)               fail("RX L-Credit granted during reset");
            else if (!RXLINKACTIVEACK)
                fail("RX L-Credit granted before RXLINKACTIVEACK (Table 14-2 p.14-450)");
        end
        if (RXREQLCRDV) crd[CH_REQ] = crd[CH_REQ] + 1;
        if (RXRSPLCRDV) crd[CH_RSP] = crd[CH_RSP] + 1;
        if (RXDATLCRDV) crd[CH_DAT] = crd[CH_DAT] + 1;
        if (crd[CH_REQ] > XP_LCRD_NUM_PARAM || crd[CH_RSP] > XP_LCRD_NUM_PARAM
                                            || crd[CH_DAT] > XP_LCRD_NUM_PARAM)
            fail($sformatf("more than %0d L-Credits outstanding (Sec 14.2.1 p.14-445)",
                           XP_LCRD_NUM_PARAM));
    end

    // Return one credit on the named channel as an all-zero L-Credit return flit.
    task return_credit(input integer ch);
        begin
            @(negedge CLK);
            RXREQFLITV = (ch == CH_REQ); RXREQFLIT = '0;
            RXRSPFLITV = (ch == CH_RSP); RXRSPFLIT = '0;
            RXDATFLITV = (ch == CH_DAT); RXDATFLIT = '0;
            @(negedge CLK);
            RXREQFLITV = 1'b0; RXRSPFLITV = 1'b0; RXDATFLITV = 1'b0;
            crd[ch] = crd[ch] - 1;
        end
    endtask

    integer i, ch;
    initial begin
        for (ch = CH_REQ; ch <= CH_DAT; ch = ch + 1) crd[ch] = 0;
        repeat (RESET_CYCLES) @(posedge CLK);
        RST = 1'b0;

        // Still STOP: nothing may be granted.
        repeat (SETTLE_CYCLES) @(posedge CLK);
        if (crd[CH_REQ] != 0 || crd[CH_RSP] != 0 || crd[CH_DAT] != 0)
            fail("credits granted in the STOP state");

        // ACTIVATE -> RUN.
        RXLINKACTIVEREQ = 1'b1;
        repeat (SETTLE_CYCLES) @(posedge CLK);
        if (!RXLINKACTIVEACK) fail("RXLINKACTIVEACK never asserted in ACTIVATE");
        if (crd[CH_REQ] == 0 || crd[CH_RSP] == 0 || crd[CH_DAT] == 0)
            fail("no L-Credit granted after reaching RUN");

        // DEACTIVATE: ACK must hold until every credit is back.
        RXLINKACTIVEREQ = 1'b0;
        repeat (SETTLE_CYCLES) @(posedge CLK);
        if (!RXLINKACTIVEACK) fail("RXLINKACTIVEACK dropped with credits outstanding (Table 14-2 p.14-450)");
        for (ch = CH_REQ; ch <= CH_DAT; ch = ch + 1)
            for (i = 0; i < XP_LCRD_NUM_PARAM; i = i + 1) return_credit(ch);
        repeat (SETTLE_CYCLES) @(posedge CLK);
        if (RXLINKACTIVEACK) fail("RXLINKACTIVEACK never dropped after every credit was returned");

        // Re-activate: the pool must have refilled.
        for (ch = CH_REQ; ch <= CH_DAT; ch = ch + 1) crd[ch] = 0;
        RXLINKACTIVEREQ = 1'b1;
        repeat (SETTLE_CYCLES) @(posedge CLK);
        if (crd[CH_REQ] == 0 || crd[CH_RSP] == 0 || crd[CH_DAT] == 0)
            fail("the RX L-Credit pool did not refill for a re-activation");

        if (errors == 0) $display("tb_hnf_link: PASSED");
        else             $display("tb_hnf_link: FAILED (%0d error(s))", errors);
        $finish;
    end

endmodule
