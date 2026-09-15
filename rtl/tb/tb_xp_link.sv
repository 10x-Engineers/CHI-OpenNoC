// =============================================================================
// rtl/tb/tb_xp_link.sv -- Chapter 14 link activation at one crosspoint port.
//
//   The crosspoint had no testbench of any kind: it is in no filelist, and until
//   tools/lint.sh grew a generated-NoC pass nothing had ever elaborated it. This
//   drives P0's RXLINK through STOP -> RUN -> DEACTIVATE -> STOP and judges:
//
//     Table 14-2 STOP/ACTIVATE (p.14-450, MUST)  no credit outside RUN
//     Table 14-2 DEACTIVATE Receiver (MUST)      LINKACTIVEACK held until every
//                                                granted credit is returned
//     SS14.6.1 (p.14-454)                        the TXLINK follows the RXLINK
//                                                into DEACTIVATE
//     Table 14-2 DEACTIVATE Transmitter (MUST)   held L-Credits returned with
//                                                L-Credit return flits
//
//   Runs under Verilator, so tools/lint.sh gates it -- unlike tb_hnf_link.sv,
//   which needs a licensed simulator.
// =============================================================================
// Chapter 14 link activation at one crosspoint port. The crosspoint has never been
// simulated; this drives P0's RXLINK through STOP -> RUN -> DEACTIVATE -> STOP and
// checks Table 14-2's Receiver and Transmitter rules on the wire.
module tb_xp_link;
  localparam int RW = $bits(chie_pkg::req_flit_s);
  localparam int SW = $bits(chie_pkg::snp_flit_s) + chie_pkg::NID_WIDTH;

  logic clk = 0, rst = 1;
  always #5 clk = ~clk;

  logic rxreq_req_p0 = 0;              // peer drives our RXLINKACTIVEREQ
  logic txack_p0     = 0;              // peer acks our TXLINKACTIVEREQ
  logic rxreqflitv_p0 = 0;
  logic [RW-1:0] rxreqflit_p0 = '0;

  wire rxack_p0, txreq_p0, rxreqlcrdv_p0, txreqflitv_p0;
  wire [RW-1:0] txreqflit_p0;
  int fails = 0, grants = 0, returns = 0, n_ret = 0;
  // Every other port of chi_xp_node, tied off so the bench drives P0 alone.
  logic  RXREQFLITV_E = '0;
  logic  RXREQFLITV_W = '0;
  logic  RXREQFLITV_N = '0;
  logic  RXREQFLITV_S = '0;
  logic  RXREQFLITV_P1 = '0;
  logic [RW-1:0] RXREQFLIT_E = '0;
  logic [RW-1:0] RXREQFLIT_W = '0;
  logic [RW-1:0] RXREQFLIT_N = '0;
  logic [RW-1:0] RXREQFLIT_S = '0;
  logic [RW-1:0] RXREQFLIT_P1 = '0;
  wire  RXREQLCRDV_E;
  wire  RXREQLCRDV_W;
  wire  RXREQLCRDV_N;
  wire  RXREQLCRDV_S;
  wire  RXREQLCRDV_P1;
  wire  TXREQFLITV_E;
  wire  TXREQFLITV_W;
  wire  TXREQFLITV_N;
  wire  TXREQFLITV_S;
  wire  TXREQFLITPEND_P0;
  wire  TXREQFLITPEND_P1;
  wire  TXREQFLITV_P1;
  wire [RW-1:0] TXREQFLIT_E;
  wire [RW-1:0] TXREQFLIT_W;
  wire [RW-1:0] TXREQFLIT_N;
  wire [RW-1:0] TXREQFLIT_S;
  wire [RW-1:0] TXREQFLIT_P1;
  logic  TXREQLCRDV_E = '0;
  logic  TXREQLCRDV_W = '0;
  logic  TXREQLCRDV_N = '0;
  logic  TXREQLCRDV_S = '0;
  logic  TXREQLCRDV_P0 = '0;
  logic  TXREQLCRDV_P1 = '0;
  logic  RXRSPFLITV_E = '0;
  logic  RXRSPFLITV_W = '0;
  logic  RXRSPFLITV_N = '0;
  logic  RXRSPFLITV_S = '0;
  logic  RXRSPFLITV_P0 = '0;
  logic  RXRSPFLITV_P1 = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_E = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_W = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_N = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_S = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_P0 = '0;
  logic [$bits(chie_pkg::rsp_flit_s)-1:0] RXRSPFLIT_P1 = '0;
  wire  RXRSPLCRDV_E;
  wire  RXRSPLCRDV_W;
  wire  RXRSPLCRDV_N;
  wire  RXRSPLCRDV_S;
  wire  RXRSPLCRDV_P0;
  wire  RXRSPLCRDV_P1;
  wire  TXRSPFLITV_E;
  wire  TXRSPFLITV_W;
  wire  TXRSPFLITV_N;
  wire  TXRSPFLITV_S;
  wire  TXRSPFLITPEND_P0;
  wire  TXRSPFLITPEND_P1;
  wire  TXRSPFLITV_P0;
  wire  TXRSPFLITV_P1;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_E;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_W;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_N;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_S;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_P0;
  wire [$bits(chie_pkg::rsp_flit_s)-1:0] TXRSPFLIT_P1;
  logic  TXRSPLCRDV_E = '0;
  logic  TXRSPLCRDV_W = '0;
  logic  TXRSPLCRDV_N = '0;
  logic  TXRSPLCRDV_S = '0;
  logic  TXRSPLCRDV_P0 = '0;
  logic  TXRSPLCRDV_P1 = '0;
  logic  RXDATFLITV_E = '0;
  logic  RXDATFLITV_W = '0;
  logic  RXDATFLITV_N = '0;
  logic  RXDATFLITV_S = '0;
  logic  RXDATFLITV_P0 = '0;
  logic  RXDATFLITV_P1 = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_E = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_W = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_N = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_S = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_P0 = '0;
  logic [$bits(chie_pkg::dat_flit_s)-1:0] RXDATFLIT_P1 = '0;
  wire  RXDATLCRDV_E;
  wire  RXDATLCRDV_W;
  wire  RXDATLCRDV_N;
  wire  RXDATLCRDV_S;
  wire  RXDATLCRDV_P0;
  wire  RXDATLCRDV_P1;
  wire  TXDATFLITV_E;
  wire  TXDATFLITV_W;
  wire  TXDATFLITV_N;
  wire  TXDATFLITV_S;
  wire  TXDATFLITPEND_P0;
  wire  TXDATFLITPEND_P1;
  wire  TXDATFLITV_P0;
  wire  TXDATFLITV_P1;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_E;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_W;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_N;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_S;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_P0;
  wire [$bits(chie_pkg::dat_flit_s)-1:0] TXDATFLIT_P1;
  logic  TXDATLCRDV_E = '0;
  logic  TXDATLCRDV_W = '0;
  logic  TXDATLCRDV_N = '0;
  logic  TXDATLCRDV_S = '0;
  logic  TXDATLCRDV_P0 = '0;
  logic  TXDATLCRDV_P1 = '0;
  logic  RXSNPFLITV_E = '0;
  logic  RXSNPFLITV_W = '0;
  logic  RXSNPFLITV_N = '0;
  logic  RXSNPFLITV_S = '0;
  logic  RXSNPFLITV_P0 = '0;
  logic  RXSNPFLITV_P1 = '0;
  logic [SW-1:0] RXSNPFLIT_E = '0;
  logic [SW-1:0] RXSNPFLIT_W = '0;
  logic [SW-1:0] RXSNPFLIT_N = '0;
  logic [SW-1:0] RXSNPFLIT_S = '0;
  logic [SW-1:0] RXSNPFLIT_P0 = '0;
  logic [SW-1:0] RXSNPFLIT_P1 = '0;
  wire  RXSNPLCRDV_E;
  wire  RXSNPLCRDV_W;
  wire  RXSNPLCRDV_N;
  wire  RXSNPLCRDV_S;
  wire  RXSNPLCRDV_P0;
  wire  RXSNPLCRDV_P1;
  wire  TXSNPFLITV_E;
  wire  TXSNPFLITV_W;
  wire  TXSNPFLITV_N;
  wire  TXSNPFLITV_S;
  wire  TXSNPFLITPEND_P0;
  wire  TXSNPFLITPEND_P1;
  wire  TXSNPFLITV_P0;
  wire  TXSNPFLITV_P1;
  wire [SW-1:0] TXSNPFLIT_E;
  wire [SW-1:0] TXSNPFLIT_W;
  wire [SW-1:0] TXSNPFLIT_N;
  wire [SW-1:0] TXSNPFLIT_S;
  wire [SW-1:0] TXSNPFLIT_P0;
  wire [SW-1:0] TXSNPFLIT_P1;
  logic  TXSNPLCRDV_E = '0;
  logic  TXSNPLCRDV_W = '0;
  logic  TXSNPLCRDV_N = '0;
  logic  TXSNPLCRDV_S = '0;
  logic  TXSNPLCRDV_P0 = '0;
  logic  TXSNPLCRDV_P1 = '0;

  chi_xp_node #(.REQ_FLIT_WIDTH(RW), .RSP_FLIT_WIDTH($bits(chie_pkg::rsp_flit_s)),
                .DAT_FLIT_WIDTH($bits(chie_pkg::dat_flit_s)),
                .SNP_FLIT_WIDTH(SW), .SNP_TGTID_OFFSET($bits(chie_pkg::snp_flit_s)),
                .CHIE_NID_WIDTH_PARAM(chie_pkg::NID_WIDTH))
  dut (.clk(clk), .rst(rst), .my_xid(3'd0), .my_yid(3'd0),
       .RXLINKACTIVEREQ_P0(rxreq_req_p0), .RXLINKACTIVEACK_P0(rxack_p0),
       .TXLINKACTIVEREQ_P0(txreq_p0),     .TXLINKACTIVEACK_P0(txack_p0),
       .RXSACTIVE_P0(1'b0), .TXSACTIVE_P0(),
       .RXLINKACTIVEREQ_P1(1'b0), .RXLINKACTIVEACK_P1(),
       .TXLINKACTIVEREQ_P1(), .TXLINKACTIVEACK_P1(1'b0),
       .RXSACTIVE_P1(1'b0), .TXSACTIVE_P1(),
       .RXREQFLITV_P0(rxreqflitv_p0), .RXREQFLIT_P0(rxreqflit_p0),
       .RXREQLCRDV_P0(rxreqlcrdv_p0), .TXREQFLITV_P0(txreqflitv_p0),
       .TXREQFLIT_P0(txreqflit_p0),
       .* );

  // Table 14-2 (p.14-450, MUST): the Receiver must not send credits outside RUN.
  always @(posedge clk) if (!rst && rxreqlcrdv_p0) begin
    grants++;
    if (!(rxreq_req_p0 && rxack_p0)) begin
      $display("FAIL t=%0t RXREQLCRDV asserted with RX link not in RUN (req=%0b ack=%0b)",
               $time, rxreq_req_p0, rxack_p0);
      fails++;
    end
  end
  // SS13.11 (p.13-442): an all-zero flit is the L-Credit return.
  always @(posedge clk) if (!rst && txreqflitv_p0 && (txreqflit_p0 == '0)) returns++;

  initial begin
    repeat (4) @(posedge clk); rst = 0;
    // 1. #216's scenario exactly: the peer acknowledges OUR TXLINK, but has no
    //    flits to send yet, so ITS TXLINK -- our RXLINK -- is still in STOP. A
    //    Receiver that gates its grants on the TX pair starts granting here;
    //    Table 14-2 (p.14-450, MUST) says it must not.
    txack_p0 = 1;
    repeat (20) @(posedge clk);
    if (grants != 0) begin $display("FAIL: %0d credit(s) granted before RUN", grants); fails++; end
    else $display("PASS: no credits granted in STOP/ACTIVATE (%0d)", grants);

    // 2. RUN: the peer activates, we ack, credits flow.
    rxreq_req_p0 = 1;
    repeat (8) @(posedge clk);
    // The peer grants US three TXREQ credits. Table 14-2 DEACTIVATE Transmitter
    // (p.14-450, MUST) then owes them back when our TXLINK deactivates.
    for (int i = 0; i < 3; i++) begin
      @(negedge clk); TXREQLCRDV_P0 = 1;
      @(negedge clk); TXREQLCRDV_P0 = 0;
    end
    repeat (22) @(posedge clk);
    if (!rxack_p0) begin $display("FAIL: RXLINKACTIVEACK never asserted"); fails++; end
    if (grants == 0) begin $display("FAIL: no credits granted in RUN"); fails++; end
    else $display("PASS: %0d credit(s) granted once in RUN", grants);
    if (!txreq_p0) begin $display("FAIL: TXLINKACTIVEREQ not asserted in RUN"); fails++; end

    // 3. DEACTIVATE: peer drops REQ. Ack must hold until credits come back.
    rxreq_req_p0 = 0;
    repeat (3) @(posedge clk);
    if (!rxack_p0) begin
      $display("FAIL: RXLINKACTIVEACK dropped with credits still outstanding"); fails++; end
    else $display("PASS: RXLINKACTIVEACK held while credits outstanding");
    // SS14.6.1 (p.14-454): the TXLINK follows the RXLINK into DEACTIVATE.
    if (txreq_p0) begin $display("FAIL: TXLINKACTIVEREQ did not follow the RXLINK down"); fails++; end
    else $display("PASS: TXLINKACTIVEREQ followed the RXLINK into DEACTIVATE");

    // The peer spends every credit it was given, on EVERY channel, returning them
    // as link flits. Table 14-2 waits for all credits, and the handshake is per
    // port while the credits are per channel -- so repaying only REQ is not enough.
    n_ret = grants + 2;   // snapshot: grants is still being counted by the monitor
    for (int i = 0; i < n_ret; i++) begin
      @(negedge clk);
      rxreqflitv_p0 = 1; rxreqflit_p0 = '0;
      RXRSPFLITV_P0 = 1; RXRSPFLIT_P0 = '0;
      RXDATFLITV_P0 = 1; RXDATFLIT_P0 = '0;
      RXSNPFLITV_P0 = 1; RXSNPFLIT_P0 = '0;
      @(negedge clk);
      rxreqflitv_p0 = 0; RXRSPFLITV_P0 = 0; RXDATFLITV_P0 = 0; RXSNPFLITV_P0 = 0;
    end
    repeat (40) @(posedge clk);
    if (rxack_p0) begin
      $display("FAIL: RXLINKACTIVEACK still high after every credit returned"); fails++; end
    else $display("PASS: RXLINKACTIVEACK deasserted once all credits were returned");

    if (returns >= 3) $display("PASS: %0d L-Credit return flit(s) sent in TX DEACTIVATE", returns);
    else begin $display("FAIL: %0d L-Credit return flit(s), expected the 3 granted", returns); fails++; end
    if (fails == 0) $display("=== TB PASS ===");
    else            $display("=== TB FAIL (%0d) ===", fails);
    $finish;
  end
endmodule : tb_xp_link
