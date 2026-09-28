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

// Chapter 14 link layer for the MN: the LINKACTIVE handshake, per-channel L-Credit
// accounting and the flit registers, on RX REQ/RSP/DAT and TX RSP/SNP -- a DVMOp
// is answered with responses and snoops only, never data.
module mn_link_ctl `MN_PARAM
    (
    input  wire                         clk_i,
    input  wire                         rst_i,

    output wire                         TXLINKACTIVEREQ,
    input  wire                         TXLINKACTIVEACK,
    input  wire                         RXLINKACTIVEREQ,
    output wire                         RXLINKACTIVEACK,

    output wire                         TXRSPFLITPEND,
    output wire                         TXRSPFLITV,
    output chie_pkg::rsp_flit_s         TXRSPFLIT,
    input  wire                         TXRSPLCRDV,
    output wire                         TXSNPFLITPEND,
    output wire                         TXSNPFLITV,
    output opennoc_mn_pkg::snp_routed_s TXSNPFLIT,
    input  wire                         TXSNPLCRDV,

    input  wire                         RXREQFLITPEND,
    input  wire                         RXREQFLITV,
    input  chie_pkg::req_flit_s         RXREQFLIT,
    output logic                        RXREQLCRDV,
    input  wire                         RXRSPFLITPEND,
    input  wire                         RXRSPFLITV,
    input  chie_pkg::rsp_flit_s         RXRSPFLIT,
    output logic                        RXRSPLCRDV,
    input  wire                         RXDATFLITPEND,
    input  wire                         RXDATFLITV,
    input  chie_pkg::dat_flit_s         RXDATFLIT,
    output logic                        RXDATLCRDV,

    input  chie_pkg::rsp_flit_s         prot_txrspflit_i,
    input  wire                         prot_txrspflitv_i,
    output wire                         prot_txrspflit_sent_o,
    input  opennoc_mn_pkg::snp_routed_s prot_txsnpflit_i,
    input  wire                         prot_txsnpflitv_i,
    output wire                         prot_txsnpflit_sent_o,

    output wire                         prot_rxreqflitv_o,
    output chie_pkg::req_flit_s         prot_rxreqflit_o,
    output wire                         prot_rxrspflitv_o,
    output chie_pkg::rsp_flit_s         prot_rxrspflit_o,
    output wire                         prot_rxdatflitv_o,
    output chie_pkg::dat_flit_s         prot_rxdatflit_o,
    // REQ slots the protocol layer freed this cycle: a request taken into the
    // tracker, and a RetryAck sent for one it could not take.
    input  wire [1:0]                   prot_req_free_i,

    // a Protocol flit on a TX channel this cycle
    output wire                         prot_txflitv_o
    );

    wire txrsp_lcrd_avail, txsnp_lcrd_avail;
    wire rxreq_lcrd_avail, rxrsp_lcrd_avail, rxdat_lcrd_avail;
    wire rxrsp_lcrd_full, rxdat_lcrd_full;
    wire txlink_run, rxcrd_en, lcrd_return_en;
    wire txrspflit_lcrd_v, txsnpflit_lcrd_v;
    wire txrsp_send, txsnp_send;
    wire rxreqlcrdv_w, rxrsplcrdv_w, rxdatlcrdv_w;

    logic                        txrspflitv_q, txsnpflitv_q, prot_txflitv_q;
    chie_pkg::rsp_flit_s         txrspflit_q;
    opennoc_mn_pkg::snp_routed_s txsnpflit_q;
    chie_pkg::rsp_flit_s         txrspflit_lcrd;
    logic                        rxreqflitv_q, rxrspflitv_q, rxdatflitv_q;
    chie_pkg::req_flit_s         rxreqflit_q;
    chie_pkg::rsp_flit_s         rxrspflit_q;
    chie_pkg::dat_flit_s         rxdatflit_q;

    //*************************************************
    //                Link HandShake
    //*************************************************
    // Table 14-2 (p.14-450, MUST): DEACTIVATE is left only once every credit granted
    // has come back, which a flit does on arrival. A REQ slot the protocol layer still
    // holds for a RetryAck is not a credit the peer holds, so REQ counts arrivals.
    logic [`MN_LL_CRD_CNT_WIDTH:0] rxreq_home_cnt_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            rxreq_home_cnt_q <= '0;
        else
            rxreq_home_cnt_q <= rxreq_home_cnt_q + rxreqlcrdv_w - rxreqflitv_q;
    end

    wire rxcrd_cnt_full = (rxreq_home_cnt_q == '0) & ~rxreqlcrdv_w
                          & rxrsp_lcrd_full & rxdat_lcrd_full;

    chi_link_handshake u_chi_link_handshake (
        .clk             (clk_i                                  ),
        .rst             (rst_i                                  ),
        .TXLINKACTIVEREQ (TXLINKACTIVEREQ                        ),
        .TXLINKACTIVEACK (TXLINKACTIVEACK                        ),
        .RXLINKACTIVEREQ (RXLINKACTIVEREQ                        ),
        .RXLINKACTIVEACK (RXLINKACTIVEACK                        ),
        .txlink_state    (                                       ),
        .rxlink_state    (                                       ),
        .txflit_avail    (prot_txrspflitv_i | prot_txsnpflitv_i  ),
        .rxcrd_cnt_full  (rxcrd_cnt_full                         ),
        .lcrd_return_en  (lcrd_return_en                         ),
        .rxcrd_en        (rxcrd_en                               ),
        .txlink_run      (txlink_run                             )
    );

    // SS14.4 (p.14-447) lets a Transmitter keep FLITPEND permanently asserted.
    assign TXRSPFLITPEND = 1'b1;
    assign TXSNPFLITPEND = 1'b1;

    //***************** TXRSP Channel *****************
    chi_lcrd_hdlr #(
        .LCRD_INIT_CNT_VAL (0                 ),
        .LCRD_MAX_CNT_VAL  (XP_LCRD_NUM_PARAM )
    ) u_txrsp_lcrd_hdlr (
        .clk        (clk_i            ),
        .rst        (rst_i            ),
        .lcrd_inc   (TXRSPLCRDV       ),
        .lcrd_dec   (txrsp_send       ),
        .lcrd_full  (                 ),
        .lcrd_avail (txrsp_lcrd_avail )
    );

    // Table 14-2 DEACTIVATE (p.14-450, MUST): the Transmitter returns its credits with
    // L-Credit return flits; Table 14-3 (p.14-451, MUST): no Protocol flit outside RUN.
    assign txrspflit_lcrd_v      = lcrd_return_en & txrsp_lcrd_avail;
    assign prot_txrspflit_sent_o = prot_txrspflitv_i & txrsp_lcrd_avail & ~lcrd_return_en & txlink_run;
    assign txrsp_send            = prot_txrspflit_sent_o | txrspflit_lcrd_v;

    always_comb begin
        txrspflit_lcrd        = '0;
        txrspflit_lcrd.opcode = chie_pkg::RSP_RSPLCRDRETURN;
        txrspflit_lcrd.srcid  = CHIE_NID_WIDTH_PARAM'(MN_NID_PARAM);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            txrspflitv_q <= 1'b0;
            txrspflit_q  <= '0;
        end
        else begin
            txrspflitv_q <= txrsp_send;
            if (txrsp_send == 1'b1)
                txrspflit_q <= txrspflit_lcrd_v ? txrspflit_lcrd : prot_txrspflit_i;
        end
    end

    assign TXRSPFLITV = txrspflitv_q;
    assign TXRSPFLIT  = txrspflit_q;

    //***************** TXSNP Channel *****************
    chi_lcrd_hdlr #(
        .LCRD_INIT_CNT_VAL (0                 ),
        .LCRD_MAX_CNT_VAL  (XP_LCRD_NUM_PARAM )
    ) u_txsnp_lcrd_hdlr (
        .clk        (clk_i            ),
        .rst        (rst_i            ),
        .lcrd_inc   (TXSNPLCRDV       ),
        .lcrd_dec   (txsnp_send       ),
        .lcrd_full  (                 ),
        .lcrd_avail (txsnp_lcrd_avail )
    );

    // A SnpLCrdReturn (SS13.11 p.13-442) is the all-zero flit, envelope included.
    assign txsnpflit_lcrd_v      = lcrd_return_en & txsnp_lcrd_avail;
    assign prot_txsnpflit_sent_o = prot_txsnpflitv_i & txsnp_lcrd_avail & ~lcrd_return_en & txlink_run;
    assign txsnp_send            = prot_txsnpflit_sent_o | txsnpflit_lcrd_v;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            txsnpflitv_q <= 1'b0;
            txsnpflit_q  <= '0;
        end
        else begin
            txsnpflitv_q <= txsnp_send;
            if (txsnp_send == 1'b1)
                txsnpflit_q <= txsnpflit_lcrd_v ? '0 : prot_txsnpflit_i;
        end
    end

    assign TXSNPFLITV = txsnpflitv_q;
    assign TXSNPFLIT  = txsnpflit_q;

    // SS14.7.2 (p.14-460, MUST): TXSACTIVE is held until the last Protocol flit is on
    // the wire, a cycle after the protocol layer is told it went.
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            prot_txflitv_q <= 1'b0;
        else
            prot_txflitv_q <= prot_txrspflit_sent_o | prot_txsnpflit_sent_o;
    end

    assign prot_txflitv_o = prot_txflitv_q;

    //***************** RX flit registers *****************
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            rxreqflitv_q <= 1'b0;
            rxrspflitv_q <= 1'b0;
            rxdatflitv_q <= 1'b0;
            rxreqflit_q  <= '0;
            rxrspflit_q  <= '0;
            rxdatflit_q  <= '0;
        end
        else begin
            rxreqflitv_q <= RXREQFLITV;
            rxrspflitv_q <= RXRSPFLITV;
            rxdatflitv_q <= RXDATFLITV;
            if (RXREQFLITV == 1'b1) rxreqflit_q <= RXREQFLIT;
            if (RXRSPFLITV == 1'b1) rxrspflit_q <= RXRSPFLIT;
            if (RXDATFLITV == 1'b1) rxdatflit_q <= RXDATFLIT;
        end
    end

    // SS13.11 (p.13-442): a link flit, zero Opcode, only returns its L-Credit.
    wire rxreq_is_lcrdret = rxreqflitv_q & (rxreqflit_q.opcode == chie_pkg::REQ_REQLCRDRETURN);
    assign prot_rxreqflitv_o = rxreqflitv_q & ~rxreq_is_lcrdret;
    assign prot_rxreqflit_o  = rxreqflit_q;
    assign prot_rxrspflitv_o = rxrspflitv_q & (rxrspflit_q.opcode != chie_pkg::RSP_RSPLCRDRETURN);
    assign prot_rxrspflit_o  = rxrspflit_q;
    assign prot_rxdatflitv_o = rxdatflitv_q & (rxdatflit_q.opcode != chie_pkg::DAT_DATLCRDRETURN);
    assign prot_rxdatflit_o  = rxdatflit_q;

    //***************** RXREQ Channel *****************
    // SS14.2.1 (p.14-445): an L-Credit is granted only for a flit the Receiver can take.
    // A request's slot comes free when the tracker takes it or its RetryAck goes out,
    // which can be two in a cycle; the handler takes one increment a cycle, so the
    // rest wait here rather than being lost.
    logic [`MN_LL_CRD_CNT_WIDTH:0] rxreq_free_owed_q;
    wire  [`MN_LL_CRD_CNT_WIDTH:0] rxreq_free_total = rxreq_free_owed_q
                                                      + (`MN_LL_CRD_CNT_WIDTH+1)'(prot_req_free_i)
                                                      + (`MN_LL_CRD_CNT_WIDTH+1)'(rxreq_is_lcrdret);
    wire                           rxreq_free_apply = (rxreq_free_total != '0);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            rxreq_free_owed_q <= '0;
        else
            rxreq_free_owed_q <= rxreq_free_total - (`MN_LL_CRD_CNT_WIDTH+1)'(rxreq_free_apply);
    end

    chi_lcrd_hdlr #(
        .LCRD_INIT_CNT_VAL (XP_LCRD_NUM_PARAM ),
        .LCRD_MAX_CNT_VAL  (XP_LCRD_NUM_PARAM )
    ) u_rxreq_lcrd_hdlr (
        .clk        (clk_i            ),
        .rst        (rst_i            ),
        .lcrd_inc   (rxreq_free_apply ),
        .lcrd_dec   (rxreqlcrdv_w     ),
        .lcrd_full  (                 ),
        .lcrd_avail (rxreq_lcrd_avail )
    );

    assign rxreqlcrdv_w = rxreq_lcrd_avail & rxcrd_en;

    //***************** RXRSP / RXDAT Channels *****************
    // Every Response and Data flit is consumed the cycle it lands, so its slot is free
    // at once.
    chi_lcrd_hdlr #(
        .LCRD_INIT_CNT_VAL (XP_LCRD_NUM_PARAM ),
        .LCRD_MAX_CNT_VAL  (XP_LCRD_NUM_PARAM )
    ) u_rxrsp_lcrd_hdlr (
        .clk        (clk_i            ),
        .rst        (rst_i            ),
        .lcrd_inc   (rxrspflitv_q     ),
        .lcrd_dec   (rxrsplcrdv_w     ),
        .lcrd_full  (rxrsp_lcrd_full  ),
        .lcrd_avail (rxrsp_lcrd_avail )
    );

    chi_lcrd_hdlr #(
        .LCRD_INIT_CNT_VAL (XP_LCRD_NUM_PARAM ),
        .LCRD_MAX_CNT_VAL  (XP_LCRD_NUM_PARAM )
    ) u_rxdat_lcrd_hdlr (
        .clk        (clk_i            ),
        .rst        (rst_i            ),
        .lcrd_inc   (rxdatflitv_q     ),
        .lcrd_dec   (rxdatlcrdv_w     ),
        .lcrd_full  (rxdat_lcrd_full  ),
        .lcrd_avail (rxdat_lcrd_avail )
    );

    assign rxrsplcrdv_w = rxrsp_lcrd_avail & rxcrd_en;
    assign rxdatlcrdv_w = rxdat_lcrd_avail & rxcrd_en;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            RXREQLCRDV <= 1'b0;
            RXRSPLCRDV <= 1'b0;
            RXDATLCRDV <= 1'b0;
        end
        else begin
            RXREQLCRDV <= rxreqlcrdv_w;
            RXRSPLCRDV <= rxrsplcrdv_w;
            RXDATLCRDV <= rxdatlcrdv_w;
        end
    end

endmodule
