/*
* Copyright (c) 2024 Beijing Institute of Open Source Chip
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*
* Author:
*    Jianxing Wang <wangjianxing@bosc.ac.cn>
*/
`ifndef CHI_XP_NODE_H
`define CHI_XP_NODE_H
module chi_xp_node #(
    parameter CHIE_NID_WIDTH_PARAM = 7,
    parameter XP_XID_WIDTH = 3,
    parameter XP_YID_WIDTH = 3,
    parameter REQ_FLIT_WIDTH = 0,
    parameter RSP_FLIT_WIDTH = 0,
    parameter DAT_FLIT_WIDTH = 0,
    parameter SNP_FLIT_WIDTH = 0,
    parameter SNP_TGTID_OFFSET = 0,
    parameter REQ_CH_EN = {6{1'b1}},
    parameter RSP_CH_EN = {6{1'b1}},
    parameter DAT_CH_EN = {6{1'b1}},
    parameter SNP_CH_EN = {6{1'b1}}
) (
    input clk,
    input rst,
    input [XP_XID_WIDTH-1:0] my_xid,
    input [XP_YID_WIDTH-1:0] my_yid,

    //REQ
    input RXREQFLITV_E,
    input RXREQFLITV_W,
    input RXREQFLITV_N,
    input RXREQFLITV_S,
    input RXREQFLITV_P0,
    input RXREQFLITV_P1,

    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_E,
    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_W,
    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_N,
    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_S,
    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_P0,
    input [REQ_FLIT_WIDTH-1:0] RXREQFLIT_P1,

    output RXREQLCRDV_E,
    output RXREQLCRDV_W,
    output RXREQLCRDV_N,
    output RXREQLCRDV_S,
    output RXREQLCRDV_P0,
    output RXREQLCRDV_P1,

    output TXREQFLITV_E,
    output TXREQFLITV_W,
    output TXREQFLITV_N,
    output TXREQFLITV_S,
    output TXREQFLITPEND_P0,
    output TXREQFLITPEND_P1,
    output TXREQFLITV_P0,
    output TXREQFLITV_P1,

    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_E,
    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_W,
    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_N,
    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_S,
    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_P0,
    output [REQ_FLIT_WIDTH-1:0] TXREQFLIT_P1,

    input TXREQLCRDV_E,
    input TXREQLCRDV_W,
    input TXREQLCRDV_N,
    input TXREQLCRDV_S,
    input TXREQLCRDV_P0,
    input TXREQLCRDV_P1,

    //RSP
    input RXRSPFLITV_E,
    input RXRSPFLITV_W,
    input RXRSPFLITV_N,
    input RXRSPFLITV_S,
    input RXRSPFLITV_P0,
    input RXRSPFLITV_P1,

    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_E,
    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_W,
    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_N,
    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_S,
    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_P0,
    input [RSP_FLIT_WIDTH-1:0] RXRSPFLIT_P1,

    output RXRSPLCRDV_E,
    output RXRSPLCRDV_W,
    output RXRSPLCRDV_N,
    output RXRSPLCRDV_S,
    output RXRSPLCRDV_P0,
    output RXRSPLCRDV_P1,

    output TXRSPFLITV_E,
    output TXRSPFLITV_W,
    output TXRSPFLITV_N,
    output TXRSPFLITV_S,
    output TXRSPFLITPEND_P0,
    output TXRSPFLITPEND_P1,
    output TXRSPFLITV_P0,
    output TXRSPFLITV_P1,

    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_E,
    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_W,
    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_N,
    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_S,
    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_P0,
    output [RSP_FLIT_WIDTH-1:0] TXRSPFLIT_P1,

    input TXRSPLCRDV_E,
    input TXRSPLCRDV_W,
    input TXRSPLCRDV_N,
    input TXRSPLCRDV_S,
    input TXRSPLCRDV_P0,
    input TXRSPLCRDV_P1,

    //DAT
    input RXDATFLITV_E,
    input RXDATFLITV_W,
    input RXDATFLITV_N,
    input RXDATFLITV_S,
    input RXDATFLITV_P0,
    input RXDATFLITV_P1,

    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_E,
    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_W,
    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_N,
    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_S,
    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_P0,
    input [DAT_FLIT_WIDTH-1:0] RXDATFLIT_P1,

    output RXDATLCRDV_E,
    output RXDATLCRDV_W,
    output RXDATLCRDV_N,
    output RXDATLCRDV_S,
    output RXDATLCRDV_P0,
    output RXDATLCRDV_P1,

    output TXDATFLITV_E,
    output TXDATFLITV_W,
    output TXDATFLITV_N,
    output TXDATFLITV_S,
    output TXDATFLITPEND_P0,
    output TXDATFLITPEND_P1,
    output TXDATFLITV_P0,
    output TXDATFLITV_P1,

    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_E,
    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_W,
    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_N,
    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_S,
    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_P0,
    output [DAT_FLIT_WIDTH-1:0] TXDATFLIT_P1,

    input TXDATLCRDV_E,
    input TXDATLCRDV_W,
    input TXDATLCRDV_N,
    input TXDATLCRDV_S,
    input TXDATLCRDV_P0,
    input TXDATLCRDV_P1,
    //SNP
    input RXSNPFLITV_E,
    input RXSNPFLITV_W,
    input RXSNPFLITV_N,
    input RXSNPFLITV_S,
    input RXSNPFLITV_P0,
    input RXSNPFLITV_P1,

    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_E,
    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_W,
    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_N,
    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_S,
    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_P0,
    input [SNP_FLIT_WIDTH-1:0] RXSNPFLIT_P1,

    output RXSNPLCRDV_E,
    output RXSNPLCRDV_W,
    output RXSNPLCRDV_N,
    output RXSNPLCRDV_S,
    output RXSNPLCRDV_P0,
    output RXSNPLCRDV_P1,

    output TXSNPFLITV_E,
    output TXSNPFLITV_W,
    output TXSNPFLITV_N,
    output TXSNPFLITV_S,
    output TXSNPFLITPEND_P0,
    output TXSNPFLITPEND_P1,
    output TXSNPFLITV_P0,
    output TXSNPFLITV_P1,

    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_E,
    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_W,
    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_N,
    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_S,
    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_P0,
    output [SNP_FLIT_WIDTH-1:0] TXSNPFLIT_P1,

    input TXSNPLCRDV_E,
    input TXSNPLCRDV_W,
    input TXSNPLCRDV_N,
    input TXSNPLCRDV_S,
    input TXSNPLCRDV_P0,
    input TXSNPLCRDV_P1,

    output TXLINKACTIVEREQ_P0,
    input  TXLINKACTIVEACK_P0,
    input  RXLINKACTIVEREQ_P0,
    output RXLINKACTIVEACK_P0,

    output TXLINKACTIVEREQ_P1,
    input  TXLINKACTIVEACK_P1,
    input  RXLINKACTIVEREQ_P1,
    output RXLINKACTIVEACK_P1,

    output TXSACTIVE_P0,
    input  RXSACTIVE_P0, 
    output TXSACTIVE_P1,
    input  RXSACTIVE_P1 
);

  wire TXLINKACTIVEREQ_SYNC_P0;
  wire TXLINKACTIVEACK_SYNC_P0;
  reg  TXLINKACTIVE_P0_q;
  reg  RXLINKACTIVE_P0_q;

  wire TXLINKACTIVEREQ_SYNC_P1;
  wire TXLINKACTIVEACK_SYNC_P1;
  reg  TXLINKACTIVE_P1_q;
  reg  RXLINKACTIVE_P1_q;
  reg  reset_done;


  // CHI E.b SS13.11 (p.13-442) identifies a link flit by a zero Opcode, so the
  // crosspoint has to read that field. Its position is the sum of the widths
  // BELOW it in each chie_pkg flit struct (packed structs are declared MSB-first):
  //   REQ  qos4 + tgtid + srcid + txnid12 + returnnid + stashnidvalid1 + returntxnid12
  //   RSP  qos4 + tgtid + srcid + txnid12
  //   DAT  qos4 + tgtid + srcid + txnid12 + homenid
  //   SNP  qos4 +         srcid + txnid12 + fwdnid + fwdtxnid12
  localparam int NIDW = CHIE_NID_WIDTH_PARAM;
  localparam int REQ_OPC_OFF = 29 + 3*NIDW, REQ_OPC_W = 7;
  localparam int RSP_OPC_OFF = 16 + 2*NIDW, RSP_OPC_W = 5;
  localparam int DAT_OPC_OFF = 16 + 3*NIDW, DAT_OPC_W = 4;
  localparam int SNP_OPC_OFF = 28 + 2*NIDW, SNP_OPC_W = 5;

`ifdef DISPLAY_FATAL
  // The offsets above are the one thing here that a chie_pkg layout change can
  // silently invalidate -- a wrong offset decodes some other field as the opcode
  // and either drops protocol flits or routes link flits. Checked rather than
  // trusted: set only the opcode and confirm those are exactly the bits that move.
  // Every width defaults to 0 and is refused here: none is a safe guess, and
  // omitting the default is legal IEEE 1800 that Xcelium 23.03 does not elaborate.
  initial if ((REQ_FLIT_WIDTH == 0) || (RSP_FLIT_WIDTH == 0) || (DAT_FLIT_WIDTH == 0) || (SNP_FLIT_WIDTH == 0) || (SNP_TGTID_OFFSET == 0))
    $fatal(1, "chi_xp_node: the flit widths, SNP_TGTID_OFFSET must be overridden");

  initial begin : opcode_offset_check
    chie_pkg::req_flit_s rq; chie_pkg::rsp_flit_s rs;
    chie_pkg::dat_flit_s dt; chie_pkg::snp_flit_s sn;
    logic [$bits(chie_pkg::req_flit_s)-1:0] rqv;
    logic [$bits(chie_pkg::rsp_flit_s)-1:0] rsv;
    logic [$bits(chie_pkg::dat_flit_s)-1:0] dtv;
    logic [$bits(chie_pkg::snp_flit_s)-1:0] snv;
    rq = '0; rq.opcode = chie_pkg::req_opcode_e'('1); rqv = rq;
    rs = '0; rs.opcode = chie_pkg::rsp_opcode_e'('1); rsv = rs;
    dt = '0; dt.opcode = chie_pkg::dat_opcode_e'('1); dtv = dt;
    sn = '0; sn.opcode = chie_pkg::snp_opcode_e'('1); snv = sn;
    if (rqv != ($bits(chie_pkg::req_flit_s)'({REQ_OPC_W{1'b1}}) << REQ_OPC_OFF))
      $fatal(1, "REQ opcode offset %0d/%0d does not match chie_pkg", REQ_OPC_OFF, REQ_OPC_W);
    if (rsv != ($bits(chie_pkg::rsp_flit_s)'({RSP_OPC_W{1'b1}}) << RSP_OPC_OFF))
      $fatal(1, "RSP opcode offset %0d/%0d does not match chie_pkg", RSP_OPC_OFF, RSP_OPC_W);
    if (dtv != ($bits(chie_pkg::dat_flit_s)'({DAT_OPC_W{1'b1}}) << DAT_OPC_OFF))
      $fatal(1, "DAT opcode offset %0d/%0d does not match chie_pkg", DAT_OPC_OFF, DAT_OPC_W);
    if (snv != ($bits(chie_pkg::snp_flit_s)'({SNP_OPC_W{1'b1}}) << SNP_OPC_OFF))
      $fatal(1, "SNP opcode offset %0d/%0d does not match chie_pkg", SNP_OPC_OFF, SNP_OPC_W);
  end
`endif


  wire rx_run_P0, rx_run_P1, tx_deact_P0, tx_deact_P1;
  wire req_rx_lcrd_out_P0, req_rx_lcrd_out_P1, rsp_rx_lcrd_out_P0, rsp_rx_lcrd_out_P1;
  wire dat_rx_lcrd_out_P0, dat_rx_lcrd_out_P1, snp_rx_lcrd_out_P0, snp_rx_lcrd_out_P1;
  wire req_tx_lcrd_held_P0, req_tx_lcrd_held_P1, rsp_tx_lcrd_held_P0, rsp_tx_lcrd_held_P1;
  wire dat_tx_lcrd_held_P0, dat_tx_lcrd_held_P1, snp_tx_lcrd_held_P0, snp_tx_lcrd_held_P1;
  wire req_tx_pend_P0, req_tx_pend_P1, rsp_tx_pend_P0, rsp_tx_pend_P1;
  wire dat_tx_pend_P0, dat_tx_pend_P1, snp_tx_pend_P0, snp_tx_pend_P1;
  wire tx_pend_P0 = req_tx_pend_P0 | rsp_tx_pend_P0 | dat_tx_pend_P0 | snp_tx_pend_P0;
  wire tx_pend_P1 = req_tx_pend_P1 | rsp_tx_pend_P1 | dat_tx_pend_P1 | snp_tx_pend_P1;

  chi_xp_channel #(
      .CHIE_NID_WIDTH_PARAM(CHIE_NID_WIDTH_PARAM),
      .XP_XID_WIDTH(XP_XID_WIDTH),
      .XP_YID_WIDTH(XP_YID_WIDTH),
      .FLIT_WIDTH(REQ_FLIT_WIDTH),
      .FLIT_OPCODE_OFFSET(REQ_OPC_OFF),
      .FLIT_OPCODE_WIDTH(REQ_OPC_W),
      .XP_PORT_EN(REQ_CH_EN)
  ) m_req (
      .clk(clk),
      .rst(rst),
      .my_xid(my_xid),
      .my_yid(my_yid),

      .TXLINKACTIVEREQ_P0(TXLINKACTIVEREQ_SYNC_P0),
      .TXLINKACTIVEACK_P0(TXLINKACTIVEACK_SYNC_P0),
      .TXLINKACTIVEREQ_P1(TXLINKACTIVEREQ_SYNC_P1),
      .TXLINKACTIVEACK_P1(TXLINKACTIVEACK_SYNC_P1),

      .RXFLITV_E(RXREQFLITV_E),
      .RXFLITV_W(RXREQFLITV_W),
      .RXFLITV_N(RXREQFLITV_N),
      .RXFLITV_S(RXREQFLITV_S),
      .RXFLITV_P0(RXREQFLITV_P0),
      .RXFLITV_P1(RXREQFLITV_P1),

      .RXFLIT_E (RXREQFLIT_E),
      .RXFLIT_W (RXREQFLIT_W),
      .RXFLIT_N (RXREQFLIT_N),
      .RXFLIT_S (RXREQFLIT_S),
      .RXFLIT_P0(RXREQFLIT_P0),
      .RXFLIT_P1(RXREQFLIT_P1),

      .RXLCRDV_E (RXREQLCRDV_E),
      .RXLCRDV_W (RXREQLCRDV_W),
      .RXLCRDV_N (RXREQLCRDV_N),
      .RXLCRDV_S (RXREQLCRDV_S),
      .RXLCRDV_P0(RXREQLCRDV_P0),
      .RXLCRDV_P1(RXREQLCRDV_P1),

      .TXFLITV_E (TXREQFLITV_E),
      .TXFLITV_W (TXREQFLITV_W),
      .TXFLITV_N (TXREQFLITV_N),
      .TXFLITV_S (TXREQFLITV_S),
      .rx_run_P0(rx_run_P0),
      .rx_run_P1(rx_run_P1),
      .rx_lcrd_out_P0(req_rx_lcrd_out_P0),
      .rx_lcrd_out_P1(req_rx_lcrd_out_P1),
      .tx_deact_P0(tx_deact_P0),
      .tx_deact_P1(tx_deact_P1),
      .tx_lcrd_held_P0(req_tx_lcrd_held_P0),
      .tx_lcrd_held_P1(req_tx_lcrd_held_P1),
      .tx_pend_P0(req_tx_pend_P0),
      .tx_pend_P1(req_tx_pend_P1),
      .TXFLITPEND_P0(TXREQFLITPEND_P0),
      .TXFLITPEND_P1(TXREQFLITPEND_P1),
      .TXFLITV_P0(TXREQFLITV_P0),
      .TXFLITV_P1(TXREQFLITV_P1),

      .TXFLIT_E (TXREQFLIT_E),
      .TXFLIT_W (TXREQFLIT_W),
      .TXFLIT_N (TXREQFLIT_N),
      .TXFLIT_S (TXREQFLIT_S),
      .TXFLIT_P0(TXREQFLIT_P0),
      .TXFLIT_P1(TXREQFLIT_P1),

      .TXLCRDV_E (TXREQLCRDV_E),
      .TXLCRDV_W (TXREQLCRDV_W),
      .TXLCRDV_N (TXREQLCRDV_N),
      .TXLCRDV_S (TXREQLCRDV_S),
      .TXLCRDV_P0(TXREQLCRDV_P0),
      .TXLCRDV_P1(TXREQLCRDV_P1)
  );
  chi_xp_channel #(
      .CHIE_NID_WIDTH_PARAM(CHIE_NID_WIDTH_PARAM),
      .XP_XID_WIDTH(XP_XID_WIDTH),
      .XP_YID_WIDTH(XP_YID_WIDTH),
      .FLIT_WIDTH(RSP_FLIT_WIDTH),
      .FLIT_OPCODE_OFFSET(RSP_OPC_OFF),
      .FLIT_OPCODE_WIDTH(RSP_OPC_W),
      .XP_PORT_EN(RSP_CH_EN)
  ) m_rsp (
      .clk(clk),
      .rst(rst),
      .my_xid(my_xid),
      .my_yid(my_yid),

      .TXLINKACTIVEREQ_P0(TXLINKACTIVEREQ_SYNC_P0),
      .TXLINKACTIVEACK_P0(TXLINKACTIVEACK_SYNC_P0),
      .TXLINKACTIVEREQ_P1(TXLINKACTIVEREQ_SYNC_P1),
      .TXLINKACTIVEACK_P1(TXLINKACTIVEACK_SYNC_P1),

      .RXFLITV_E(RXRSPFLITV_E),
      .RXFLITV_W(RXRSPFLITV_W),
      .RXFLITV_N(RXRSPFLITV_N),
      .RXFLITV_S(RXRSPFLITV_S),
      .RXFLITV_P0(RXRSPFLITV_P0),
      .RXFLITV_P1(RXRSPFLITV_P1),

      .RXFLIT_E (RXRSPFLIT_E),
      .RXFLIT_W (RXRSPFLIT_W),
      .RXFLIT_N (RXRSPFLIT_N),
      .RXFLIT_S (RXRSPFLIT_S),
      .RXFLIT_P0(RXRSPFLIT_P0),
      .RXFLIT_P1(RXRSPFLIT_P1),

      .RXLCRDV_E (RXRSPLCRDV_E),
      .RXLCRDV_W (RXRSPLCRDV_W),
      .RXLCRDV_N (RXRSPLCRDV_N),
      .RXLCRDV_S (RXRSPLCRDV_S),
      .RXLCRDV_P0(RXRSPLCRDV_P0),
      .RXLCRDV_P1(RXRSPLCRDV_P1),

      .TXFLITV_E (TXRSPFLITV_E),
      .TXFLITV_W (TXRSPFLITV_W),
      .TXFLITV_N (TXRSPFLITV_N),
      .TXFLITV_S (TXRSPFLITV_S),
      .rx_run_P0(rx_run_P0),
      .rx_run_P1(rx_run_P1),
      .rx_lcrd_out_P0(rsp_rx_lcrd_out_P0),
      .rx_lcrd_out_P1(rsp_rx_lcrd_out_P1),
      .tx_deact_P0(tx_deact_P0),
      .tx_deact_P1(tx_deact_P1),
      .tx_lcrd_held_P0(rsp_tx_lcrd_held_P0),
      .tx_lcrd_held_P1(rsp_tx_lcrd_held_P1),
      .tx_pend_P0(rsp_tx_pend_P0),
      .tx_pend_P1(rsp_tx_pend_P1),
      .TXFLITPEND_P0(TXRSPFLITPEND_P0),
      .TXFLITPEND_P1(TXRSPFLITPEND_P1),
      .TXFLITV_P0(TXRSPFLITV_P0),
      .TXFLITV_P1(TXRSPFLITV_P1),

      .TXFLIT_E (TXRSPFLIT_E),
      .TXFLIT_W (TXRSPFLIT_W),
      .TXFLIT_N (TXRSPFLIT_N),
      .TXFLIT_S (TXRSPFLIT_S),
      .TXFLIT_P0(TXRSPFLIT_P0),
      .TXFLIT_P1(TXRSPFLIT_P1),

      .TXLCRDV_E (TXRSPLCRDV_E),
      .TXLCRDV_W (TXRSPLCRDV_W),
      .TXLCRDV_N (TXRSPLCRDV_N),
      .TXLCRDV_S (TXRSPLCRDV_S),
      .TXLCRDV_P0(TXRSPLCRDV_P0),
      .TXLCRDV_P1(TXRSPLCRDV_P1)
  );
  chi_xp_channel #(
      .CHIE_NID_WIDTH_PARAM(CHIE_NID_WIDTH_PARAM),
      .XP_XID_WIDTH(XP_XID_WIDTH),
      .XP_YID_WIDTH(XP_YID_WIDTH),
      .FLIT_WIDTH(DAT_FLIT_WIDTH),
      .FLIT_OPCODE_OFFSET(DAT_OPC_OFF),
      .FLIT_OPCODE_WIDTH(DAT_OPC_W),
      .XP_PORT_EN(DAT_CH_EN)
  ) m_dat (
      .clk(clk),
      .rst(rst),
      .my_xid(my_xid),
      .my_yid(my_yid),

      .TXLINKACTIVEREQ_P0(TXLINKACTIVEREQ_SYNC_P0),
      .TXLINKACTIVEACK_P0(TXLINKACTIVEACK_SYNC_P0),
      .TXLINKACTIVEREQ_P1(TXLINKACTIVEREQ_SYNC_P1),
      .TXLINKACTIVEACK_P1(TXLINKACTIVEACK_SYNC_P1),

      .RXFLITV_E(RXDATFLITV_E),
      .RXFLITV_W(RXDATFLITV_W),
      .RXFLITV_N(RXDATFLITV_N),
      .RXFLITV_S(RXDATFLITV_S),
      .RXFLITV_P0(RXDATFLITV_P0),
      .RXFLITV_P1(RXDATFLITV_P1),

      .RXFLIT_E (RXDATFLIT_E),
      .RXFLIT_W (RXDATFLIT_W),
      .RXFLIT_N (RXDATFLIT_N),
      .RXFLIT_S (RXDATFLIT_S),
      .RXFLIT_P0(RXDATFLIT_P0),
      .RXFLIT_P1(RXDATFLIT_P1),

      .RXLCRDV_E (RXDATLCRDV_E),
      .RXLCRDV_W (RXDATLCRDV_W),
      .RXLCRDV_N (RXDATLCRDV_N),
      .RXLCRDV_S (RXDATLCRDV_S),
      .RXLCRDV_P0(RXDATLCRDV_P0),
      .RXLCRDV_P1(RXDATLCRDV_P1),

      .TXFLITV_E (TXDATFLITV_E),
      .TXFLITV_W (TXDATFLITV_W),
      .TXFLITV_N (TXDATFLITV_N),
      .TXFLITV_S (TXDATFLITV_S),
      .rx_run_P0(rx_run_P0),
      .rx_run_P1(rx_run_P1),
      .rx_lcrd_out_P0(dat_rx_lcrd_out_P0),
      .rx_lcrd_out_P1(dat_rx_lcrd_out_P1),
      .tx_deact_P0(tx_deact_P0),
      .tx_deact_P1(tx_deact_P1),
      .tx_lcrd_held_P0(dat_tx_lcrd_held_P0),
      .tx_lcrd_held_P1(dat_tx_lcrd_held_P1),
      .tx_pend_P0(dat_tx_pend_P0),
      .tx_pend_P1(dat_tx_pend_P1),
      .TXFLITPEND_P0(TXDATFLITPEND_P0),
      .TXFLITPEND_P1(TXDATFLITPEND_P1),
      .TXFLITV_P0(TXDATFLITV_P0),
      .TXFLITV_P1(TXDATFLITV_P1),

      .TXFLIT_E (TXDATFLIT_E),
      .TXFLIT_W (TXDATFLIT_W),
      .TXFLIT_N (TXDATFLIT_N),
      .TXFLIT_S (TXDATFLIT_S),
      .TXFLIT_P0(TXDATFLIT_P0),
      .TXFLIT_P1(TXDATFLIT_P1),

      .TXLCRDV_E (TXDATLCRDV_E),
      .TXLCRDV_W (TXDATLCRDV_W),
      .TXLCRDV_N (TXDATLCRDV_N),
      .TXLCRDV_S (TXDATLCRDV_S),
      .TXLCRDV_P0(TXDATLCRDV_P0),
      .TXLCRDV_P1(TXDATLCRDV_P1)
  );
  chi_xp_channel #(
      .CHIE_NID_WIDTH_PARAM(CHIE_NID_WIDTH_PARAM),
      .XP_XID_WIDTH(XP_XID_WIDTH),
      .XP_YID_WIDTH(XP_YID_WIDTH),
      .FLIT_WIDTH(SNP_FLIT_WIDTH),
      .FLIT_OPCODE_OFFSET(SNP_OPC_OFF),
      .FLIT_OPCODE_WIDTH(SNP_OPC_W),
      .FLIT_TGT_OFFSET(SNP_TGTID_OFFSET),
      .XP_PORT_EN(SNP_CH_EN)
  ) m_snp (
      .clk(clk),
      .rst(rst),
      .my_xid(my_xid),
      .my_yid(my_yid),

      .TXLINKACTIVEREQ_P0(TXLINKACTIVEREQ_SYNC_P0),
      .TXLINKACTIVEACK_P0(TXLINKACTIVEACK_SYNC_P0),
      .TXLINKACTIVEREQ_P1(TXLINKACTIVEREQ_SYNC_P1),
      .TXLINKACTIVEACK_P1(TXLINKACTIVEACK_SYNC_P1),

      .RXFLITV_E(RXSNPFLITV_E),
      .RXFLITV_W(RXSNPFLITV_W),
      .RXFLITV_N(RXSNPFLITV_N),
      .RXFLITV_S(RXSNPFLITV_S),
      .RXFLITV_P0(RXSNPFLITV_P0),
      .RXFLITV_P1(RXSNPFLITV_P1),

      .RXFLIT_E (RXSNPFLIT_E),
      .RXFLIT_W (RXSNPFLIT_W),
      .RXFLIT_N (RXSNPFLIT_N),
      .RXFLIT_S (RXSNPFLIT_S),
      .RXFLIT_P0(RXSNPFLIT_P0),
      .RXFLIT_P1(RXSNPFLIT_P1),

      .RXLCRDV_E (RXSNPLCRDV_E),
      .RXLCRDV_W (RXSNPLCRDV_W),
      .RXLCRDV_N (RXSNPLCRDV_N),
      .RXLCRDV_S (RXSNPLCRDV_S),
      .RXLCRDV_P0(RXSNPLCRDV_P0),
      .RXLCRDV_P1(RXSNPLCRDV_P1),

      .TXFLITV_E (TXSNPFLITV_E),
      .TXFLITV_W (TXSNPFLITV_W),
      .TXFLITV_N (TXSNPFLITV_N),
      .TXFLITV_S (TXSNPFLITV_S),
      .rx_run_P0(rx_run_P0),
      .rx_run_P1(rx_run_P1),
      .rx_lcrd_out_P0(snp_rx_lcrd_out_P0),
      .rx_lcrd_out_P1(snp_rx_lcrd_out_P1),
      .tx_deact_P0(tx_deact_P0),
      .tx_deact_P1(tx_deact_P1),
      .tx_lcrd_held_P0(snp_tx_lcrd_held_P0),
      .tx_lcrd_held_P1(snp_tx_lcrd_held_P1),
      .tx_pend_P0(snp_tx_pend_P0),
      .tx_pend_P1(snp_tx_pend_P1),
      .TXFLITPEND_P0(TXSNPFLITPEND_P0),
      .TXFLITPEND_P1(TXSNPFLITPEND_P1),
      .TXFLITV_P0(TXSNPFLITV_P0),
      .TXFLITV_P1(TXSNPFLITV_P1),

      .TXFLIT_E (TXSNPFLIT_E),
      .TXFLIT_W (TXSNPFLIT_W),
      .TXFLIT_N (TXSNPFLIT_N),
      .TXFLIT_S (TXSNPFLIT_S),
      .TXFLIT_P0(TXSNPFLIT_P0),
      .TXFLIT_P1(TXSNPFLIT_P1),

      .TXLCRDV_E (TXSNPLCRDV_E),
      .TXLCRDV_W (TXSNPLCRDV_W),
      .TXLCRDV_N (TXSNPLCRDV_N),
      .TXLCRDV_S (TXSNPLCRDV_S),
      .TXLCRDV_P0(TXSNPLCRDV_P0),
      .TXLCRDV_P1(TXSNPLCRDV_P1)
  );

  always @(posedge clk or posedge rst) begin
      if (rst) begin
          TXLINKACTIVE_P0_q <= 1'b0;
      end else if (TXLINKACTIVEACK_P0 & TXLINKACTIVEREQ_P0) begin
          TXLINKACTIVE_P0_q <= 1'b1;
      end
  end
  always @(posedge clk or posedge rst) begin
      if (rst) begin
          RXLINKACTIVE_P0_q <= 1'b0;
      end else if (RXLINKACTIVEREQ_P0) begin
          RXLINKACTIVE_P0_q <= 1'b1;
      end
  end

  always @(posedge clk or posedge rst) begin
      if (rst) begin
          TXLINKACTIVE_P1_q <= 1'b0;
      end else if (TXLINKACTIVEACK_P1 & TXLINKACTIVEREQ_P1) begin
          TXLINKACTIVE_P1_q <= 1'b1;
      end
  end
  always @(posedge clk or posedge rst) begin
      if (rst) begin
          RXLINKACTIVE_P1_q <= 1'b0;
      end else if (RXLINKACTIVEREQ_P1) begin
          RXLINKACTIVE_P1_q <= 1'b1;
      end
  end

  always @(posedge clk or posedge rst) begin
      if (rst) begin
          reset_done <= 1'b0;
      end else begin
          reset_done <= 1'b1;
      end
  end


  // ---------------------------------------------------------------------------
  // Chapter 14 link activation, per external port.
  //
  //   SS14.6.1 (p.14-454) makes the TXLINK and RXLINK separate state machines and
  //   then requires them to be coordinated: "If the RXLINK moves to the DEACTIVATE
  //   state ... it is required that the TXLINK also moves to the DEACTIVATE state,
  //   in a timely manner."
  //
  //   The handshake is per PORT while the credits are per CHANNEL, so it lives
  //   here and reads all four channels: Table 14-2 DEACTIVATE (p.14-450, MUST) --
  //   "The Receiver must wait for all credits to be returned before deasserting
  //   LINKACTIVEACK" -- is only satisfied once every channel has been repaid.
  // ---------------------------------------------------------------------------
  wire rx_drained_P0 = ~(req_rx_lcrd_out_P0 | rsp_rx_lcrd_out_P0 |
                         dat_rx_lcrd_out_P0 | snp_rx_lcrd_out_P0);
  wire rx_drained_P1 = ~(req_rx_lcrd_out_P1 | rsp_rx_lcrd_out_P1 |
                         dat_rx_lcrd_out_P1 | snp_rx_lcrd_out_P1);

  reg rxack_P0_q, rxack_P1_q, txreq_P0_q, txreq_P1_q;

  always @(posedge clk or posedge rst) begin
      if (rst)                          rxack_P0_q <= 1'b0;
      else if (RXLINKACTIVEREQ_P0)      rxack_P0_q <= 1'b1;
      else if (rx_drained_P0)           rxack_P0_q <= 1'b0;
  end
  always @(posedge clk or posedge rst) begin
      if (rst)                          rxack_P1_q <= 1'b0;
      else if (RXLINKACTIVEREQ_P1)      rxack_P1_q <= 1'b1;
      else if (rx_drained_P1)           rxack_P1_q <= 1'b0;
  end

  // The TXLINK follows the RXLINK up and down, and also comes up on its own for a
  // flit waiting to leave: SS14.5 (p.14-452) has a Transmitter with flits to send move
  // STOP -> RUN, and a fabric that only followed would never reach a node that is
  // itself waiting to be addressed. It rises from STOP only -- not while the RXLINK
  // is still going down, and not before the TXLINK's own ACK has fallen -- and once
  // raised holds until ACK, since Table 14-1 (p.14-449) leaves ACTIVATE only for RUN.
  always @(posedge clk or posedge rst) begin
      if (rst)                          txreq_P0_q <= 1'b0;
      else if (!reset_done)             txreq_P0_q <= 1'b0;
      else                              txreq_P0_q <= RXLINKACTIVEREQ_P0 |
                                                    (tx_pend_P0 & ~rxack_P0_q & ~TXLINKACTIVEACK_P0) |
                                                    (txreq_P0_q & ~TXLINKACTIVEACK_P0);
  end
  always @(posedge clk or posedge rst) begin
      if (rst)                          txreq_P1_q <= 1'b0;
      else if (!reset_done)             txreq_P1_q <= 1'b0;
      else                              txreq_P1_q <= RXLINKACTIVEREQ_P1 |
                                                    (tx_pend_P1 & ~rxack_P1_q & ~TXLINKACTIVEACK_P1) |
                                                    (txreq_P1_q & ~TXLINKACTIVEACK_P1);
  end

  assign TXLINKACTIVEREQ_P0 = txreq_P0_q;
  assign TXLINKACTIVEREQ_P1 = txreq_P1_q;
  assign RXLINKACTIVEACK_P0 = rxack_P0_q;
  assign RXLINKACTIVEACK_P1 = rxack_P1_q;

  // What the channels gate on: RUN is REQ and ACK both high (Table 14-1).
  assign rx_run_P0   = RXLINKACTIVEREQ_P0 & rxack_P0_q;
  assign rx_run_P1   = RXLINKACTIVEREQ_P1 & rxack_P1_q;
  // DEACTIVATE on the Transmit side: our REQ down, the peer's ACK still up.
  assign tx_deact_P0 = ~TXLINKACTIVEREQ_P0 & TXLINKACTIVEACK_P0;
  assign tx_deact_P1 = ~TXLINKACTIVEREQ_P1 & TXLINKACTIVEACK_P1;

  assign TXSACTIVE_P0 = TXLINKACTIVE_P0_q;
  assign TXSACTIVE_P1 = TXLINKACTIVE_P1_q;

  assign TXLINKACTIVEREQ_SYNC_P0 = TXLINKACTIVEREQ_P0;
  assign TXLINKACTIVEACK_SYNC_P0 = TXLINKACTIVE_P0_q;
  assign TXLINKACTIVEREQ_SYNC_P1 = TXLINKACTIVEREQ_P1;
  assign TXLINKACTIVEACK_SYNC_P1 = TXLINKACTIVE_P1_q;
endmodule
`endif /* CHI_XP_NODE_H */
