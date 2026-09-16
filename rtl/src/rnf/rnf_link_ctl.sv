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
*/

`include "rnf_param.svh"

// Chapter 14 link layer for the RN-F: the LINKACTIVE handshake, per-channel
// L-Credit accounting and the flit registers, on the six channels a coherent
// Requester has -- TX REQ/RSP/DAT and RX RSP/DAT/SNP (Figure 13-5 p.13-399).
//
// The LINKACTIVE state encoding of Table 14-1 (p.14-449) is not repeated here:
// chi_link_handshake owns it and exports the three qualified enables this block
// actually needs, so the state vectors are left unconnected.
module rnf_link_ctl `RNF_PARAM
    (
    // global inputs
    input  wire                 clk_i,
    input  wire                 rst_i,

    // link handshake
    output wire                 TXLINKACTIVEREQ,
    input  wire                 TXLINKACTIVEACK,
    input  wire                 RXLINKACTIVEREQ,
    output wire                 RXLINKACTIVEACK,

    // CHI transmit channels
    output wire                 TXREQFLITPEND,
    output wire                 TXREQFLITV,
    output chie_pkg::req_flit_s TXREQFLIT,
    input  wire                 TXREQLCRDV,
    output wire                 TXRSPFLITPEND,
    output wire                 TXRSPFLITV,
    output chie_pkg::rsp_flit_s TXRSPFLIT,
    input  wire                 TXRSPLCRDV,
    output wire                 TXDATFLITPEND,
    output wire                 TXDATFLITV,
    output chie_pkg::dat_flit_s TXDATFLIT,
    input  wire                 TXDATLCRDV,

    // CHI receive channels
    input  wire                 RXRSPFLITPEND,
    input  wire                 RXRSPFLITV,
    input  chie_pkg::rsp_flit_s RXRSPFLIT,
    output logic                RXRSPLCRDV,
    input  wire                 RXDATFLITPEND,
    input  wire                 RXDATFLITV,
    input  chie_pkg::dat_flit_s RXDATFLIT,
    output logic                RXDATLCRDV,
    input  wire                 RXSNPFLITPEND,
    input  wire                 RXSNPFLITV,
    input  chie_pkg::snp_flit_s RXSNPFLIT,
    output logic                RXSNPLCRDV,

    // protocol layer, transmit side
    input  chie_pkg::req_flit_s prot_txreqflit_i,
    input  wire                 prot_txreqflitv_i,
    output wire                 prot_txreqflit_sent_o,
    input  chie_pkg::rsp_flit_s prot_txrspflit_i,
    input  wire                 prot_txrspflitv_i,
    output wire                 prot_txrspflit_sent_o,
    input  chie_pkg::dat_flit_s prot_txdatflit_i,
    input  wire                 prot_txdatflitv_i,
    output wire                 prot_txdatflit_sent_o,

    // protocol layer, receive side
    output logic                prot_rxrspflitv_o,
    output chie_pkg::rsp_flit_s prot_rxrspflit_o,
    output logic                prot_rxdatflitv_o,
    output chie_pkg::dat_flit_s prot_rxdatflit_o,
    output logic                prot_rxsnpflitv_o,
    output chie_pkg::snp_flit_s prot_rxsnpflit_o,

    // both directions in RUN, so the protocol layer may present a flit
    output wire                 prot_link_run_o
    );

    // internal wire
    wire                 txreq_lcrd_avail;
    wire                 txrsp_lcrd_avail;
    wire                 txdat_lcrd_avail;
    wire                 rxrsp_lcrd_avail;
    wire                 rxdat_lcrd_avail;
    wire                 rxsnp_lcrd_avail;
    wire                 rxrsp_lcrd_full;
    wire                 rxdat_lcrd_full;
    wire                 rxsnp_lcrd_full;
    wire                 rxrsplcrdv_w;
    wire                 rxdatlcrdv_w;
    wire                 rxsnplcrdv_w;
    wire                 txflit_avail;
    wire                 txlink_run;
    wire                 rxcrd_en;
    wire                 lcrd_return_en;
    wire                 rxcrd_cnt_full;
    wire                 txreqflit_lcrd_v;
    wire                 txrspflit_lcrd_v;
    wire                 txdatflit_lcrd_v;
    wire                 txreq_send;
    wire                 txrsp_send;
    wire                 txdat_send;
    chie_pkg::req_flit_s txreqflit_w;
    chie_pkg::rsp_flit_s txrspflit_w;
    chie_pkg::dat_flit_s txdatflit_w;

    // internal reg
    chie_pkg::req_flit_s txreqflit_lcrd;
    chie_pkg::rsp_flit_s txrspflit_lcrd;
    chie_pkg::dat_flit_s txdatflit_lcrd;
    logic                txreqflitv_q;
    logic                txrspflitv_q;
    logic                txdatflitv_q;
    chie_pkg::req_flit_s txreqflit_q;
    chie_pkg::rsp_flit_s txrspflit_q;
    chie_pkg::dat_flit_s txdatflit_q;
    logic                rxrspflitpend_q;
    logic                rxdatflitpend_q;
    logic                rxsnpflitpend_q;
    logic                rxrspflitv_q;
    logic                rxdatflitv_q;
    logic                rxsnpflitv_q;

    //*************************************************
    //                Link HandShake
    //*************************************************
    assign txflit_avail = prot_txreqflitv_i | prot_txrspflitv_i | prot_txdatflitv_i;

    // Table 14-2 (p.14-450): the returns are expected in DEACTIVATE, so the ack
    // may only drop once every credit this Receiver granted has come back.
    assign rxcrd_cnt_full = rxrsp_lcrd_full & rxdat_lcrd_full & rxsnp_lcrd_full
                            & ~prot_link_run_o;

    chi_link_handshake inst_chi_link_handshake(
                            .clk               ( clk_i           )
                           ,.rst               ( rst_i           )
                           ,.TXLINKACTIVEREQ   ( TXLINKACTIVEREQ )
                           ,.TXLINKACTIVEACK   ( TXLINKACTIVEACK )
                           ,.RXLINKACTIVEREQ   ( RXLINKACTIVEREQ )
                           ,.RXLINKACTIVEACK   ( RXLINKACTIVEACK )
                           ,.txlink_state      (                 )
                           ,.rxlink_state      (                 )
                           ,.txflit_avail      ( txflit_avail    )
                           ,.rxcrd_cnt_full    ( rxcrd_cnt_full  )
                           ,.lcrd_return_en    ( lcrd_return_en  )
                           ,.rxcrd_en          ( rxcrd_en        )
                           ,.txlink_run        ( txlink_run      )
                       );

    assign prot_link_run_o = txlink_run & rxcrd_en;

    // SS14.4 (p.14-447) lets a Transmitter "keep the signal permanently
    // asserted"; LINKFLITPEND_EN selects the cadence-accurate alternative.
`ifdef LINKFLITPEND_EN
    assign TXREQFLITPEND = prot_txreqflitv_i | txreqflit_lcrd_v;
    assign TXRSPFLITPEND = prot_txrspflitv_i | txrspflit_lcrd_v;
    assign TXDATFLITPEND = prot_txdatflitv_i | txdatflit_lcrd_v;
`else
    assign TXREQFLITPEND = 1'b1;
    assign TXRSPFLITPEND = 1'b1;
    assign TXDATFLITPEND = 1'b1;
`endif

    //***************** TXREQ Channel *****************
    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( 0                   )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )txreq_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( TXREQLCRDV          )
                      ,.lcrd_dec          ( txreq_send          )
                      ,.lcrd_full         (                     )
                      ,.lcrd_avail        ( txreq_lcrd_avail    )
                  );

    assign txreqflit_lcrd_v      = lcrd_return_en & txreq_lcrd_avail;
    // Table 14-3 (p.14-451, MUST): no flit is sent outside RUN.
    assign prot_txreqflit_sent_o = prot_txreqflitv_i & txreq_lcrd_avail
                                   & ~lcrd_return_en & txlink_run;
    assign txreq_send            = prot_txreqflit_sent_o | txreqflit_lcrd_v;
    assign txreqflit_w           = txreqflit_lcrd_v ? txreqflit_lcrd : prot_txreqflit_i;

    always_comb begin
        txreqflit_lcrd        = '0;
        txreqflit_lcrd.opcode = chie_pkg::REQ_REQLCRDRETURN;
        txreqflit_lcrd.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txreqflitv_q <= 1'b0;
        else
            txreqflitv_q <= txreq_send;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txreqflit_q <= '0;
        else if (txreq_send == 1'b1)
            txreqflit_q <= txreqflit_w;
    end

    assign TXREQFLITV = txreqflitv_q;
    assign TXREQFLIT  = txreqflit_q;

    //***************** TXRSP Channel *****************
    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( 0                   )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )txrsp_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( TXRSPLCRDV          )
                      ,.lcrd_dec          ( txrsp_send          )
                      ,.lcrd_full         (                     )
                      ,.lcrd_avail        ( txrsp_lcrd_avail    )
                  );

    assign txrspflit_lcrd_v      = lcrd_return_en & txrsp_lcrd_avail;
    assign prot_txrspflit_sent_o = prot_txrspflitv_i & txrsp_lcrd_avail
                                   & ~lcrd_return_en & txlink_run;
    assign txrsp_send            = prot_txrspflit_sent_o | txrspflit_lcrd_v;
    assign txrspflit_w           = txrspflit_lcrd_v ? txrspflit_lcrd : prot_txrspflit_i;

    always_comb begin
        txrspflit_lcrd        = '0;
        txrspflit_lcrd.opcode = chie_pkg::RSP_RSPLCRDRETURN;
        txrspflit_lcrd.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txrspflitv_q <= 1'b0;
        else
            txrspflitv_q <= txrsp_send;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txrspflit_q <= '0;
        else if (txrsp_send == 1'b1)
            txrspflit_q <= txrspflit_w;
    end

    assign TXRSPFLITV = txrspflitv_q;
    assign TXRSPFLIT  = txrspflit_q;

    //***************** TXDAT Channel *****************
    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( 0                   )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )txdat_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( TXDATLCRDV          )
                      ,.lcrd_dec          ( txdat_send          )
                      ,.lcrd_full         (                     )
                      ,.lcrd_avail        ( txdat_lcrd_avail    )
                  );

    assign txdatflit_lcrd_v      = lcrd_return_en & txdat_lcrd_avail;
    assign prot_txdatflit_sent_o = prot_txdatflitv_i & txdat_lcrd_avail
                                   & ~lcrd_return_en & txlink_run;
    assign txdat_send            = prot_txdatflit_sent_o | txdatflit_lcrd_v;
    assign txdatflit_w           = txdatflit_lcrd_v ? txdatflit_lcrd : prot_txdatflit_i;

    always_comb begin
        txdatflit_lcrd        = '0;
        txdatflit_lcrd.opcode = chie_pkg::DAT_DATLCRDRETURN;
        txdatflit_lcrd.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txdatflitv_q <= 1'b0;
        else
            txdatflitv_q <= txdat_send;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            txdatflit_q <= '0;
        else if (txdat_send == 1'b1)
            txdatflit_q <= txdatflit_w;
    end

    assign TXDATFLITV = txdatflitv_q;
    assign TXDATFLIT  = txdatflit_q;

    //***************** RXRSP Channel *****************
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            rxrspflitpend_q <= 1'b0;
            rxrspflitv_q    <= 1'b0;
        end
        else begin
            rxrspflitpend_q <= RXRSPFLITPEND;
            rxrspflitv_q    <= RXRSPFLITV;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            prot_rxrspflit_o <= '0;
`ifdef LINKFLITPEND_EN
        else if (rxrspflitpend_q == 1'b1 && RXRSPFLITV == 1'b1)
`else
        else if (RXRSPFLITV == 1'b1)
`endif
            prot_rxrspflit_o <= RXRSPFLIT;
    end

    // A returned credit is one this Receiver may grant again, so it counts here
    // but is not a Protocol layer flit (SS13.11 p.13-442).
    assign prot_rxrspflitv_o = rxrspflitv_q
                               & (prot_rxrspflit_o.opcode != chie_pkg::RSP_RSPLCRDRETURN);
    assign rxrsplcrdv_w      = rxrsp_lcrd_avail & rxcrd_en;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            RXRSPLCRDV <= 1'b0;
        else
            RXRSPLCRDV <= rxrsplcrdv_w;
    end

    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( RNF_LCRD_NUM_PARAM  )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )rxrsp_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( rxrspflitv_q        )
                      ,.lcrd_dec          ( rxrsplcrdv_w        )
                      ,.lcrd_full         ( rxrsp_lcrd_full     )
                      ,.lcrd_avail        ( rxrsp_lcrd_avail    )
                  );

    //***************** RXDAT Channel *****************
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            rxdatflitpend_q <= 1'b0;
            rxdatflitv_q    <= 1'b0;
        end
        else begin
            rxdatflitpend_q <= RXDATFLITPEND;
            rxdatflitv_q    <= RXDATFLITV;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            prot_rxdatflit_o <= '0;
`ifdef LINKFLITPEND_EN
        else if (rxdatflitpend_q == 1'b1 && RXDATFLITV == 1'b1)
`else
        else if (RXDATFLITV == 1'b1)
`endif
            prot_rxdatflit_o <= RXDATFLIT;
    end

    assign prot_rxdatflitv_o = rxdatflitv_q
                               & (prot_rxdatflit_o.opcode != chie_pkg::DAT_DATLCRDRETURN);
    assign rxdatlcrdv_w      = rxdat_lcrd_avail & rxcrd_en;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            RXDATLCRDV <= 1'b0;
        else
            RXDATLCRDV <= rxdatlcrdv_w;
    end

    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( RNF_LCRD_NUM_PARAM  )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )rxdat_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( rxdatflitv_q        )
                      ,.lcrd_dec          ( rxdatlcrdv_w        )
                      ,.lcrd_full         ( rxdat_lcrd_full     )
                      ,.lcrd_avail        ( rxdat_lcrd_avail    )
                  );

    //***************** RXSNP Channel *****************
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            rxsnpflitpend_q <= 1'b0;
            rxsnpflitv_q    <= 1'b0;
        end
        else begin
            rxsnpflitpend_q <= RXSNPFLITPEND;
            rxsnpflitv_q    <= RXSNPFLITV;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            prot_rxsnpflit_o <= '0;
`ifdef LINKFLITPEND_EN
        else if (rxsnpflitpend_q == 1'b1 && RXSNPFLITV == 1'b1)
`else
        else if (RXSNPFLITV == 1'b1)
`endif
            prot_rxsnpflit_o <= RXSNPFLIT;
    end

    assign prot_rxsnpflitv_o = rxsnpflitv_q
                               & (prot_rxsnpflit_o.opcode != chie_pkg::SNP_SNPLCRDRETURN);
    assign rxsnplcrdv_w      = rxsnp_lcrd_avail & rxcrd_en;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            RXSNPLCRDV <= 1'b0;
        else
            RXSNPLCRDV <= rxsnplcrdv_w;
    end

    chi_lcrd_hdlr #(
                       .LCRD_INIT_CNT_VAL ( RNF_LCRD_NUM_PARAM  )
                      ,.LCRD_MAX_CNT_VAL  ( RNF_LCRD_NUM_PARAM  )
                  )rxsnp_lcrd_hdlr(
                       .clk               ( clk_i               )
                      ,.rst               ( rst_i               )
                      ,.lcrd_inc          ( rxsnpflitv_q        )
                      ,.lcrd_dec          ( rxsnplcrdv_w        )
                      ,.lcrd_full         ( rxsnp_lcrd_full     )
                      ,.lcrd_avail        ( rxsnp_lcrd_avail    )
                  );

endmodule
