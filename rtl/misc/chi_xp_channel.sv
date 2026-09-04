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
*    Guo Bing <guobing@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

module chi_xp_channel #(
        parameter FLIT_WIDTH = 131,
        parameter FLIT_TGT_OFFSET = 4,
        parameter LCRD_NUM_WIDTH = 4,
        parameter XP_PORT_EN    = {6{1'b1}},
        parameter CHIE_NID_WIDTH_PARAM = 7,
        parameter XP_XID_WIDTH  = 3,
        parameter XP_YID_WIDTH  = 3
    )
    (
    input wire clk,
    input wire rst,
    input wire [XP_XID_WIDTH-1:0] my_xid,
    input wire [XP_YID_WIDTH-1:0] my_yid,

    input wire TXLINKACTIVEREQ_P0,
    input wire TXLINKACTIVEACK_P0,
    input wire TXLINKACTIVEREQ_P1,
    input wire TXLINKACTIVEACK_P1,

    input wire RXFLITV_E,
    input wire RXFLITV_W,
    input wire RXFLITV_N,
    input wire RXFLITV_S,
    input wire RXFLITV_P0,
    input wire RXFLITV_P1,

    input wire [FLIT_WIDTH-1:0] RXFLIT_E,
    input wire [FLIT_WIDTH-1:0] RXFLIT_W,
    input wire [FLIT_WIDTH-1:0] RXFLIT_N,
    input wire [FLIT_WIDTH-1:0] RXFLIT_S,
    input wire [FLIT_WIDTH-1:0] RXFLIT_P0,
    input wire [FLIT_WIDTH-1:0] RXFLIT_P1,

    output wire RXLCRDV_E,
    output wire RXLCRDV_W,
    output wire RXLCRDV_N,
    output wire RXLCRDV_S,
    output wire RXLCRDV_P0,
    output wire RXLCRDV_P1,

    output wire TXFLITV_E,
    output wire TXFLITV_W,
    output wire TXFLITV_N,
    output wire TXFLITV_S,
    output wire TXFLITV_P0,
    output wire TXFLITV_P1,

    output wire [FLIT_WIDTH-1:0] TXFLIT_E,
    output wire [FLIT_WIDTH-1:0] TXFLIT_W,
    output wire [FLIT_WIDTH-1:0] TXFLIT_N,
    output wire [FLIT_WIDTH-1:0] TXFLIT_S,
    output wire [FLIT_WIDTH-1:0] TXFLIT_P0,
    output wire [FLIT_WIDTH-1:0] TXFLIT_P1,

    input wire TXLCRDV_E,
    input wire TXLCRDV_W,
    input wire TXLCRDV_N,
    input wire TXLCRDV_S,
    input wire TXLCRDV_P0,
    input wire TXLCRDV_P1
    );
    localparam LCRD_MAX_NUM = ($pow(2, LCRD_NUM_WIDTH) - 1);
    localparam CHIE_NID_WIDTH = CHIE_NID_WIDTH_PARAM;
    localparam RX_MAX_ENTRY = 2'h2;
    localparam XP_INTF_E = 0;
    localparam XP_INTF_W = 1;
    localparam XP_INTF_N = 2;
    localparam XP_INTF_S = 3;
    localparam XP_INTF_P0 = 4;
    localparam XP_INTF_P1 = 5;
    localparam XP_INTF_MAX = 6;
    // fit inside it.
    // CHI E.b Sec 16.1: NodeID_Width is 7-11, and the three routing fields have to
    initial begin
        if ((CHIE_NID_WIDTH_PARAM < 7) || (CHIE_NID_WIDTH_PARAM > 11))
            $fatal(1, "chi_xp_channel: CHIE_NID_WIDTH_PARAM=%0d is outside CHI E.b's 7..11",
                   CHIE_NID_WIDTH_PARAM);
        if ((1 + XP_XID_WIDTH + XP_YID_WIDTH) > CHIE_NID_WIDTH_PARAM)
            $fatal(1, "chi_xp_channel: port(1)+Y(%0d)+X(%0d) exceeds CHIE_NID_WIDTH_PARAM=%0d",
                   XP_YID_WIDTH, XP_XID_WIDTH, CHIE_NID_WIDTH_PARAM);
    end

    wire [XP_INTF_MAX-1:0] rxactive_run;
    logic [XP_INTF_MAX-1:0] rxactive_run_q;

    wire [XP_INTF_MAX-1:0] rxflitv_r1;
    wire [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] rxflit_r1;

    logic [XP_INTF_MAX-1:0][LCRD_NUM_WIDTH-1:0] rxlcrd_cnt_q;
    wire [XP_INTF_MAX-1:0][LCRD_NUM_WIDTH-1:0] rxlcrd_cnt_ns;
    wire [XP_INTF_MAX-1:0] rxlcrd_empty;
    wire [XP_INTF_MAX-1:0] rxlcrd_inc;
    wire [XP_INTF_MAX-1:0] rxlcrd_dec;
    logic [XP_INTF_MAX-1:0] rxlcrdv_q;

    logic [XP_INTF_MAX-1:0][LCRD_NUM_WIDTH-1:0] txlcrd_cnt_q;
    wire [XP_INTF_MAX-1:0][LCRD_NUM_WIDTH-1:0] txlcrd_cnt_ns;
    wire [XP_INTF_MAX-1:0] txlcrdv;
    wire [XP_INTF_MAX-1:0] txlcrd_empty;
    wire [XP_INTF_MAX-1:0] txlcrd_inc;
    wire [XP_INTF_MAX-1:0] txlcrd_dec;
    wire [XP_INTF_MAX-1:0] txflit_next_avail;

    logic [XP_INTF_MAX-1:0] txflitv_q;
    wire [XP_INTF_MAX-1:0] txflitv_d1;
    logic [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_q;

    //buffer rxflit
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_valid_q;
    wire [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_valid_ns;
    wire [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_valid_upd;
    wire [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_valid_set;
    wire [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_valid_clr;

    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_qos_hh_q;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_qos_h_q;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_qos_m_q;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_qos_l_q;
    wire [XP_INTF_MAX-1:0] rxflit_qos_hh_r1;
    wire [XP_INTF_MAX-1:0] rxflit_qos_h_r1;
    wire [XP_INTF_MAX-1:0] rxflit_qos_m_r1;
    wire [XP_INTF_MAX-1:0] rxflit_qos_l_r1;

    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0][XP_INTF_MAX-1:0] rxflit_buffer_entry_tgt_q;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_rdy_q;
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0] rxflit_buffer_entry_tgt_r1;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_rdy_clr_r1;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_rdy_set_d1;

    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0][FLIT_WIDTH-1:0] rxflit_buffer_entry_q;

    //Route rxflit
    wire [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0][XP_INTF_MAX-1:0] rxflit_buffer_entries_rdy_d1;
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] txflit_buffer_entries_rdy_d1;

    //pending arb qos, [dst][src][entry];
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] txflit_qos_hh_d1;
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] txflit_qos_h_d1;
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] txflit_qos_m_d1;
    wire [XP_INTF_MAX-1:0][XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] txflit_qos_l_d1;

    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_hh_invec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_h_invec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_m_invec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_l_invec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_hh_outvec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_h_outvec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_m_outvec_d1;
    wire [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_qos_l_outvec_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_hh_found_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_h_found_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_m_found_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_l_found_d1;

    logic [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_arb_hh_nxt_q;
    logic [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_arb_h_nxt_q;
    logic [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_arb_m_nxt_q;
    logic [XP_INTF_MAX-1:0][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] txflit_arb_l_nxt_q;
    wire [XP_INTF_MAX-1:0] txflit_arb_hh_nxt_upd_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_h_nxt_upd_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_m_nxt_upd_d1;
    wire [XP_INTF_MAX-1:0] txflit_arb_l_nxt_upd_d1;

    logic [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_hh_d1;
    logic [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_h_d1;
    logic [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_m_d1;
    logic [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_l_d1;
    wire [XP_INTF_MAX-1:0][FLIT_WIDTH-1:0] txflit_d1;

    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_enq_r1;
    logic [XP_INTF_MAX-1:0][RX_MAX_ENTRY-1:0] rxflit_buffer_entry_deq_d1;

    wire [XP_INTF_MAX-1:0][CHIE_NID_WIDTH-1:0] rxflit_tgtid_r1;

    integer i_src, i_entry, i_dst;
    genvar g_src, g_entry, g_dst;

    logic linkactive_p0, linkactive_p1;
    always_ff @(posedge clk or posedge rst) begin
        if (rst == 1) begin
            linkactive_p0 <= 1'b0;
            linkactive_p1 <= 1'b0;
        end
        else begin
            linkactive_p0 <= TXLINKACTIVEREQ_P0 & TXLINKACTIVEACK_P0;
            linkactive_p1 <= TXLINKACTIVEREQ_P1 & TXLINKACTIVEACK_P1;
        end
    end
    //assign TXLINKACTIVEACK_P0 = linkactive_p0;
    //assign TXLINKACTIVEACK_P1 = linkactive_p1;

    assign rxactive_run[XP_INTF_E]  = XP_PORT_EN[XP_INTF_E];
    assign rxactive_run[XP_INTF_W]  = XP_PORT_EN[XP_INTF_W];
    assign rxactive_run[XP_INTF_N]  = XP_PORT_EN[XP_INTF_N];
    assign rxactive_run[XP_INTF_S]  = XP_PORT_EN[XP_INTF_S];
    assign rxactive_run[XP_INTF_P0] = XP_PORT_EN[XP_INTF_P0] & linkactive_p0;
    assign rxactive_run[XP_INTF_P1] = XP_PORT_EN[XP_INTF_P1] & linkactive_p1;
    always_ff @(posedge clk or posedge rst) begin
        if (rst == 1)
            rxactive_run_q[XP_INTF_MAX-1:0] <= XP_INTF_MAX'(1'b0);
        else
            rxactive_run_q[XP_INTF_MAX-1:0] <= rxactive_run[XP_INTF_MAX-1:0];
    end

    generate
        for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin : rx_lcredit_mgr

            always_ff @(posedge clk) begin
                if (rst == 1'b1) begin
                    rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] <= XP_PORT_EN[g_src] ? ({LCRD_NUM_WIDTH{1'b0}} | RX_MAX_ENTRY) : {LCRD_NUM_WIDTH{1'b0}};
                end
                else begin
                    rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] <= XP_PORT_EN[g_src] ? rxlcrd_cnt_ns[g_src][LCRD_NUM_WIDTH-1:0] : {LCRD_NUM_WIDTH{1'b0}};
                end
            end

            assign rxlcrd_empty[g_src] = ~(|rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0]);
            assign rxlcrd_inc[g_src] = &rxflit_buffer_entry_deq_d1[g_src][RX_MAX_ENTRY-1:0];
            assign rxlcrd_dec[g_src] = !((|rxflit_buffer_entry_deq_d1[g_src][RX_MAX_ENTRY-1:0]) | rxlcrd_empty[g_src]) & rxactive_run_q[g_src];
            assign rxlcrd_cnt_ns[g_src][LCRD_NUM_WIDTH-1:0] = rxlcrd_inc[g_src] ? (rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] + 1'b1):
                   (rxlcrd_dec[g_src] ? (rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] - 1'b1): rxlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0]);

            always_ff @(posedge clk) begin
                if (rst) begin
                    rxlcrdv_q[g_src] <= 1'b0;
                end
                else begin
                    rxlcrdv_q[g_src] <= ((!rxlcrd_empty[g_src]) | (|rxflit_buffer_entry_deq_d1[g_src][RX_MAX_ENTRY-1:0])) & rxactive_run_q[g_src];
                end
            end

        end
    endgenerate

    generate
        for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin : tx_lcredi_mgr

            always_ff @(posedge clk) begin
                if (rst) begin
                    txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] <= {LCRD_NUM_WIDTH{1'b0}};
                end
                else begin
                    txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] <= XP_PORT_EN[g_src] ? txlcrd_cnt_ns[g_src][LCRD_NUM_WIDTH-1:0] : {LCRD_NUM_WIDTH{1'b0}};
                end
            end
            assign txlcrd_empty[g_src] = ~(|txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0]);
            assign txlcrd_inc[g_src] = txlcrdv[g_src] & (!txflitv_d1[g_src]) & XP_PORT_EN[g_src];
            assign txlcrd_dec[g_src] = txflitv_d1[g_src] & (!txlcrdv[g_src]) & XP_PORT_EN[g_src];
            assign txlcrd_cnt_ns[g_src][LCRD_NUM_WIDTH-1:0] = txlcrd_inc[g_src] ? (txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] + 1'b1):
                   (txlcrd_dec[g_src] ? (txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0] - 1'b1): txlcrd_cnt_q[g_src][LCRD_NUM_WIDTH-1:0]);

            assign txflit_next_avail[g_src] = ~txlcrd_empty[g_src] | txlcrdv[g_src];

        end
    endgenerate



    //=====================================================================================================
    // Enqueue
    //=====================================================================================================
    always_comb begin : rx_flit_find_free_entry
        for (i_src = 0; i_src < XP_INTF_MAX; i_src = i_src + 1) begin : iter_find_free_entry
            if (XP_PORT_EN[i_src]) begin
                rxflit_buffer_entry_enq_r1[i_src][0] = rxflitv_r1[i_src] & ~rxflit_buffer_entry_valid_ns[i_src][0];
                for (i_entry = 1; i_entry < RX_MAX_ENTRY; i_entry = i_entry + 1) begin : find_free_entry
                    rxflit_buffer_entry_enq_r1[i_src][i_entry] = rxflitv_r1[i_src] & ~rxflit_buffer_entry_enq_r1[i_src][i_entry-1] & ~rxflit_buffer_entry_valid_ns[i_src][i_entry];
                end
            end
            else begin
                rxflit_buffer_entry_enq_r1[i_src][RX_MAX_ENTRY-1:0] = {RX_MAX_ENTRY{1'b0}};
            end
        end
    end

    generate
        for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin : rx_flit_iter_port
            if (XP_PORT_EN[g_src]) begin
                for (
                    g_entry = 0; g_entry < RX_MAX_ENTRY; g_entry = g_entry + 1
                ) begin : rx_flit_iter_port_entry

                    always_ff @(posedge clk) begin
                        if (rxflit_buffer_entry_enq_r1[g_src][g_entry]) begin
                            rxflit_buffer_entry_q[g_src][g_entry][FLIT_WIDTH-1:0]      <= rxflit_r1[g_src][FLIT_WIDTH-1:0];
                            rxflit_buffer_entry_tgt_q[g_src][g_entry][XP_INTF_MAX-1:0] <= rxflit_buffer_entry_tgt_r1[g_src][XP_INTF_MAX-1:0];
                            rxflit_qos_hh_q[g_src][g_entry] <= rxflit_qos_hh_r1[g_src];
                            rxflit_qos_h_q[g_src][g_entry] <= rxflit_qos_h_r1[g_src];
                            rxflit_qos_m_q[g_src][g_entry] <= rxflit_qos_m_r1[g_src];
                            rxflit_qos_l_q[g_src][g_entry] <= rxflit_qos_l_r1[g_src];
                        end
                        else begin
                            rxflit_buffer_entry_q[g_src][g_entry][FLIT_WIDTH-1:0]      <= rxflit_buffer_entry_q[g_src][g_entry][FLIT_WIDTH-1:0];
                            rxflit_buffer_entry_tgt_q[g_src][g_entry][XP_INTF_MAX-1:0] <= rxflit_buffer_entry_tgt_q[g_src][g_entry][XP_INTF_MAX-1:0];
                            rxflit_qos_hh_q[g_src][g_entry] <= rxflit_qos_hh_q[g_src][g_entry];
                            rxflit_qos_h_q[g_src][g_entry] <= rxflit_qos_h_q[g_src][g_entry];
                            rxflit_qos_m_q[g_src][g_entry] <= rxflit_qos_m_q[g_src][g_entry];
                            rxflit_qos_l_q[g_src][g_entry] <= rxflit_qos_l_q[g_src][g_entry];
                        end
                    end

                    assign rxflit_buffer_entry_rdy_clr_r1[g_src][g_entry] = rxflitv_r1[g_src] & rxflit_buffer_entry_enq_r1[g_src][g_entry] &
                           (rxflit_buffer_entry_tgt_r1[g_src][XP_INTF_MAX-1:0] == rxflit_buffer_entry_tgt_q[g_src][RX_MAX_ENTRY-1-g_entry][XP_INTF_MAX-1:0])
                           & rxflit_buffer_valid_q[g_src][RX_MAX_ENTRY-1-g_entry] & ~rxflit_buffer_entry_deq_d1[g_src][RX_MAX_ENTRY-1-g_entry];
                    assign rxflit_buffer_entry_rdy_set_d1[g_src][g_entry] = rxflit_buffer_entry_deq_d1[g_src][RX_MAX_ENTRY-1-g_entry] & ~rxflit_buffer_entry_rdy_q[g_src][g_entry];
                    always_ff @(posedge clk) begin
                        if (rxflit_buffer_entry_enq_r1[g_src][g_entry]) begin
                            rxflit_buffer_entry_rdy_q[g_src][g_entry] <= ~rxflit_buffer_entry_rdy_clr_r1[g_src][g_entry];
                        end
                        else if (rxflit_buffer_entry_rdy_set_d1[g_src][g_entry]) begin
                            rxflit_buffer_entry_rdy_q[g_src][g_entry] <= 1'b1;
                        end
                        else begin
                            rxflit_buffer_entry_rdy_q[g_src][g_entry] <= rxflit_buffer_entry_rdy_q[g_src][g_entry];
                        end
                    end

                    assign rxflit_buffer_valid_set[g_src][g_entry] = rxflit_buffer_entry_enq_r1[g_src][g_entry];
                    assign rxflit_buffer_valid_clr[g_src][g_entry] = rxflit_buffer_entry_deq_d1[g_src][g_entry];
                    assign rxflit_buffer_valid_upd[g_src][g_entry] = rxflit_buffer_valid_set[g_src][g_entry] | rxflit_buffer_valid_clr[g_src][g_entry];
                    always_ff @(posedge clk) begin
                        if (rst) begin
                            rxflit_buffer_valid_q[g_src][g_entry] <= 1'b0;
                        end
                        else if (rxflit_buffer_valid_upd[g_src][g_entry]) begin
                            rxflit_buffer_valid_q[g_src][g_entry] <= rxflit_buffer_valid_set[g_src][g_entry] | (~rxflit_buffer_valid_clr[g_src][g_entry]);
                        end
                        else begin
                            rxflit_buffer_valid_q[g_src][g_entry] <= rxflit_buffer_valid_q[g_src][g_entry];
                        end
                    end
                    assign rxflit_buffer_entry_valid_ns[g_src][g_entry] = rxflit_buffer_valid_q[g_src][g_entry] & ~rxflit_buffer_entry_deq_d1[g_src][g_entry];

                end

                assign rxflit_qos_hh_r1[g_src] = rxflit_r1[g_src][3];
                assign rxflit_qos_h_r1[g_src] = !rxflit_r1[g_src][3] & rxflit_r1[g_src][2];
                assign rxflit_qos_m_r1[g_src] = !rxflit_r1[g_src][3] & !rxflit_r1[g_src][2] & rxflit_r1[g_src][1];
                assign rxflit_qos_l_r1[g_src] = !rxflit_r1[g_src][3] & !rxflit_r1[g_src][2] & !rxflit_r1[g_src][1];

                assign rxflit_tgtid_r1[g_src][CHIE_NID_WIDTH-1:0] = rxflit_r1[g_src][FLIT_TGT_OFFSET+CHIE_NID_WIDTH-1:FLIT_TGT_OFFSET];
                assign rxflit_buffer_entry_tgt_r1[g_src][XP_INTF_MAX-1:0] = route_xy(rxflit_tgtid_r1[g_src]);
            end
        end
    endgenerate


    //=====================================================================================================
    // Dequeue Prepare Stage
    //=====================================================================================================
    generate
        for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin : gen_all_rxflit
            for (g_entry = 0; g_entry < RX_MAX_ENTRY; g_entry = g_entry + 1) begin
                if (XP_PORT_EN[g_src]) begin
                    assign rxflit_buffer_entries_rdy_d1[g_src][g_entry][XP_INTF_MAX-1:0] = rxflit_buffer_entry_rdy_q[g_src][g_entry] ? rxflit_buffer_entry_tgt_q[g_src][g_entry][XP_INTF_MAX-1:0]: {XP_INTF_MAX{1'b0}};
                end
                else begin
                    assign rxflit_buffer_entries_rdy_d1[g_src][g_entry][XP_INTF_MAX-1:0] = {XP_INTF_MAX{1'b0}};
                end
            end
        end
    endgenerate

    generate
        for (g_dst = 0; g_dst < XP_INTF_MAX; g_dst = g_dst + 1) begin : iter_dst_direction
            if (XP_PORT_EN[g_dst]) begin
                for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin : iter_src_direction
                    for (g_entry = 0; g_entry < RX_MAX_ENTRY; g_entry = g_entry + 1) begin
                        assign txflit_buffer_entries_rdy_d1[g_dst][g_src][g_entry] = rxflit_buffer_entries_rdy_d1[g_src][g_entry][g_dst];

                        assign txflit_qos_hh_d1[g_dst][g_src][g_entry] =  rxflit_buffer_entry_tgt_q[g_src][g_entry][g_dst] & rxflit_buffer_entry_rdy_q[g_src][g_entry] & rxflit_qos_hh_q[g_src][g_entry] & rxflit_buffer_valid_q[g_src][g_entry];
                        assign txflit_qos_h_d1[g_dst][g_src][g_entry] =  rxflit_buffer_entry_tgt_q[g_src][g_entry][g_dst] & rxflit_buffer_entry_rdy_q[g_src][g_entry] & rxflit_qos_h_q[g_src][g_entry] & rxflit_buffer_valid_q[g_src][g_entry];
                        assign txflit_qos_m_d1[g_dst][g_src][g_entry] =  rxflit_buffer_entry_tgt_q[g_src][g_entry][g_dst] & rxflit_buffer_entry_rdy_q[g_src][g_entry] & rxflit_qos_m_q[g_src][g_entry] & rxflit_buffer_valid_q[g_src][g_entry];
                        assign txflit_qos_l_d1[g_dst][g_src][g_entry] =  rxflit_buffer_entry_tgt_q[g_src][g_entry][g_dst] & rxflit_buffer_entry_rdy_q[g_src][g_entry] & rxflit_qos_l_q[g_src][g_entry] & rxflit_buffer_valid_q[g_src][g_entry];
                    end
                end
            end
        end
    endgenerate


    //=====================================================================================================
    // Dequeue Arb Stage
    //=====================================================================================================
    generate
        for (g_dst = 0; g_dst < XP_INTF_MAX; g_dst = g_dst + 1) begin
            if (XP_PORT_EN[g_dst]) begin
                for (g_src = 0; g_src < XP_INTF_MAX; g_src = g_src + 1) begin
                    for (g_entry = 0; g_entry < RX_MAX_ENTRY; g_entry = g_entry + 1) begin
                        assign txflit_qos_hh_invec_d1[g_dst][g_src*RX_MAX_ENTRY+g_entry] = txflit_qos_hh_d1[g_dst][g_src][g_entry];
                        assign txflit_qos_h_invec_d1[g_dst][g_src*RX_MAX_ENTRY+g_entry]  = txflit_qos_h_d1[g_dst][g_src][g_entry];
                        assign txflit_qos_m_invec_d1[g_dst][g_src*RX_MAX_ENTRY+g_entry]  = txflit_qos_m_d1[g_dst][g_src][g_entry];
                        assign txflit_qos_l_invec_d1[g_dst][g_src*RX_MAX_ENTRY+g_entry]  = txflit_qos_l_d1[g_dst][g_src][g_entry];
                    end
                end
            end
            else begin
                assign txflit_qos_hh_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] = {(XP_INTF_MAX*RX_MAX_ENTRY){1'b0}};
                assign txflit_qos_h_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]  = {(XP_INTF_MAX*RX_MAX_ENTRY){1'b0}};
                assign txflit_qos_m_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]  = {(XP_INTF_MAX*RX_MAX_ENTRY){1'b0}};
                assign txflit_qos_l_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]  = {(XP_INTF_MAX*RX_MAX_ENTRY){1'b0}};
            end
        end
    endgenerate

    generate
        for (g_dst = 0; g_dst < XP_INTF_MAX; g_dst = g_dst + 1) begin
            if (XP_PORT_EN[g_dst]) begin
                xp_sel_bit_from_vec #(
                                        .VEC_WIDTH(XP_INTF_MAX * RX_MAX_ENTRY)
                                    ) m_find_hh (
                                        .in_vec (txflit_qos_hh_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .startx (txflit_arb_hh_nxt_q[g_dst]),
                                        .ptr_dec(txflit_qos_hh_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .found  (txflit_arb_hh_found_d1[g_dst])
                                    );

                xp_sel_bit_from_vec #(
                                        .VEC_WIDTH(XP_INTF_MAX * RX_MAX_ENTRY)
                                    ) m_find_h (
                                        .in_vec (txflit_qos_h_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .startx (txflit_arb_h_nxt_q[g_dst]),
                                        .ptr_dec(txflit_qos_h_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .found  (txflit_arb_h_found_d1[g_dst])
                                    );

                xp_sel_bit_from_vec #(
                                        .VEC_WIDTH(XP_INTF_MAX * RX_MAX_ENTRY)
                                    ) m_find_m (
                                        .in_vec (txflit_qos_m_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .startx (txflit_arb_m_nxt_q[g_dst]),
                                        .ptr_dec(txflit_qos_m_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .found  (txflit_arb_m_found_d1[g_dst])
                                    );

                xp_sel_bit_from_vec #(
                                        .VEC_WIDTH(XP_INTF_MAX * RX_MAX_ENTRY)
                                    ) m_find_l (
                                        .in_vec (txflit_qos_l_invec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .startx (txflit_arb_l_nxt_q[g_dst]),
                                        .ptr_dec(txflit_qos_l_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0]),
                                        .found  (txflit_arb_l_found_d1[g_dst])
                                    );

                assign txflit_arb_hh_nxt_upd_d1[g_dst] = txflit_arb_hh_found_d1[g_dst] & txflit_next_avail[g_dst];
                assign txflit_arb_h_nxt_upd_d1[g_dst] = !txflit_arb_hh_found_d1[g_dst] & txflit_arb_h_found_d1[g_dst] & txflit_next_avail[g_dst];
                assign txflit_arb_m_nxt_upd_d1[g_dst] = !txflit_arb_hh_found_d1[g_dst] & !txflit_arb_h_found_d1[g_dst] & txflit_arb_m_found_d1[g_dst] & txflit_next_avail[g_dst];
                assign txflit_arb_l_nxt_upd_d1[g_dst] = !txflit_arb_hh_found_d1[g_dst] & !txflit_arb_h_found_d1[g_dst] & !txflit_arb_m_found_d1[g_dst] & txflit_arb_l_found_d1[g_dst] & txflit_next_avail[g_dst];

                always_ff @(posedge clk) begin
                    if (rst) begin
                        txflit_arb_hh_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= {{XP_INTF_MAX * RX_MAX_ENTRY} {1'b0}};
                    end
                    else if (txflit_arb_hh_nxt_upd_d1[g_dst]) begin
                        txflit_arb_hh_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_qos_hh_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                    else begin
                        txflit_arb_hh_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_arb_hh_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                end

                always_ff @(posedge clk) begin
                    if (rst) begin
                        txflit_arb_h_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= {{
                                              XP_INTF_MAX * RX_MAX_ENTRY
                                          } {1'b0}};
                    end
                    else if (txflit_arb_h_nxt_upd_d1[g_dst]) begin
                        txflit_arb_h_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_qos_h_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                    else begin
                        txflit_arb_h_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_arb_h_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                end

                always_ff @(posedge clk) begin
                    if (rst) begin
                        txflit_arb_m_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= {{
                                              XP_INTF_MAX * RX_MAX_ENTRY
                                          } {1'b0}};
                    end
                    else if (txflit_arb_m_nxt_upd_d1[g_dst]) begin
                        txflit_arb_m_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_qos_m_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                    else begin
                        txflit_arb_m_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_arb_m_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                end

                always_ff @(posedge clk) begin
                    if (rst) begin
                        txflit_arb_l_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= {{
                                              XP_INTF_MAX * RX_MAX_ENTRY
                                          } {1'b0}};
                    end
                    else if (txflit_arb_l_nxt_upd_d1[g_dst]) begin
                        txflit_arb_l_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_qos_l_outvec_d1[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                    else begin
                        txflit_arb_l_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0] <= txflit_arb_l_nxt_q[g_dst][(XP_INTF_MAX*RX_MAX_ENTRY)-1:0];
                    end
                end
            end
            else begin
                assign txflit_arb_hh_nxt_upd_d1[g_dst] = 1'b0;
                assign txflit_arb_h_nxt_upd_d1[g_dst] = 1'b0;
                assign txflit_arb_m_nxt_upd_d1[g_dst] = 1'b0;
                assign txflit_arb_l_nxt_upd_d1[g_dst] = 1'b0;
            end
        end
    endgenerate

    always_comb begin
        for (i_src = 0; i_src < XP_INTF_MAX; i_src = i_src + 1) begin
            for (i_entry = 0; i_entry < RX_MAX_ENTRY; i_entry = i_entry + 1) begin
                rxflit_buffer_entry_deq_d1[i_src][i_entry] = 1'b0;
                if (XP_PORT_EN[i_src]) begin
                    for (i_dst = 0; i_dst < XP_INTF_MAX; i_dst = i_dst + 1) begin
                        rxflit_buffer_entry_deq_d1[i_src][i_entry] = rxflit_buffer_entry_deq_d1[i_src][i_entry] | (txflit_arb_hh_nxt_upd_d1[i_dst] ? txflit_qos_hh_outvec_d1[i_dst][i_src * RX_MAX_ENTRY + i_entry]:
                                                  (txflit_arb_h_nxt_upd_d1[i_dst] ? txflit_qos_h_outvec_d1[i_dst][i_src * RX_MAX_ENTRY + i_entry]:
                                                   (txflit_arb_m_nxt_upd_d1[i_dst] ? txflit_qos_m_outvec_d1[i_dst][i_src * RX_MAX_ENTRY + i_entry]:
                                                    (txflit_arb_l_nxt_upd_d1[i_dst] ? txflit_qos_l_outvec_d1[i_dst][i_src * RX_MAX_ENTRY + i_entry]: 1'b0))));
                    end
                end
            end
        end
    end

    always_comb begin : gen_txflit_block

        for (i_dst = 0; i_dst < XP_INTF_MAX; i_dst = i_dst + 1) begin

            txflit_hh_d1[i_dst][FLIT_WIDTH-1:0] = {FLIT_WIDTH{1'b0}};
            txflit_h_d1[i_dst][FLIT_WIDTH-1:0]  = {FLIT_WIDTH{1'b0}};
            txflit_m_d1[i_dst][FLIT_WIDTH-1:0]  = {FLIT_WIDTH{1'b0}};
            txflit_l_d1[i_dst][FLIT_WIDTH-1:0]  = {FLIT_WIDTH{1'b0}};

            for (i_src = 0; i_src < XP_INTF_MAX; i_src = i_src + 1) begin
                if (XP_PORT_EN[i_src]) begin
                    for (i_entry = 0; i_entry < RX_MAX_ENTRY; i_entry = i_entry + 1) begin
                        txflit_hh_d1[i_dst][FLIT_WIDTH-1:0] = txflit_hh_d1[i_dst][FLIT_WIDTH-1:0]|({FLIT_WIDTH{txflit_qos_hh_outvec_d1[i_dst][i_src*RX_MAX_ENTRY+i_entry]}} & rxflit_buffer_entry_q[i_src][i_entry][FLIT_WIDTH-1:0]);
                        txflit_h_d1[i_dst][FLIT_WIDTH-1:0] = txflit_h_d1[i_dst][FLIT_WIDTH-1:0]|({FLIT_WIDTH{txflit_qos_h_outvec_d1[i_dst][i_src*RX_MAX_ENTRY+i_entry]}} & rxflit_buffer_entry_q[i_src][i_entry][FLIT_WIDTH-1:0]);
                        txflit_m_d1[i_dst][FLIT_WIDTH-1:0] = txflit_m_d1[i_dst][FLIT_WIDTH-1:0]|({FLIT_WIDTH{txflit_qos_m_outvec_d1[i_dst][i_src*RX_MAX_ENTRY+i_entry]}} & rxflit_buffer_entry_q[i_src][i_entry][FLIT_WIDTH-1:0]);
                        txflit_l_d1[i_dst][FLIT_WIDTH-1:0] = txflit_l_d1[i_dst][FLIT_WIDTH-1:0]|({FLIT_WIDTH{txflit_qos_l_outvec_d1[i_dst][i_src*RX_MAX_ENTRY+i_entry]}} & rxflit_buffer_entry_q[i_src][i_entry][FLIT_WIDTH-1:0]);
                    end
                end
            end

        end
    end

    generate
        for (g_dst = 0;
                g_dst < XP_INTF_MAX;
                g_dst = g_dst + 1) begin
            if (XP_PORT_EN[g_dst]) begin
                assign txflitv_d1[g_dst]
                       = txflit_arb_hh_nxt_upd_d1[g_dst]|txflit_arb_h_nxt_upd_d1[g_dst]|txflit_arb_m_nxt_upd_d1[g_dst]|txflit_arb_l_nxt_upd_d1[g_dst];
                assign txflit_d1[g_dst][FLIT_WIDTH-1:0] = txflit_arb_hh_nxt_upd_d1[g_dst] ? txflit_hh_d1[g_dst][FLIT_WIDTH-1:0]:
                       (txflit_arb_h_nxt_upd_d1[g_dst] ? txflit_h_d1[g_dst][FLIT_WIDTH-1:0] :
                        (txflit_arb_m_nxt_upd_d1[g_dst] ? txflit_m_d1[g_dst][FLIT_WIDTH-1:0] :
                         (txflit_arb_l_nxt_upd_d1[g_dst] ? txflit_l_d1[g_dst][FLIT_WIDTH-1:0] :
                          {FLIT_WIDTH{1'b0}})));
            end
            else begin
                assign txflitv_d1[g_dst] = 1'b0;
            end
        end
    endgenerate

    generate
        for (g_dst = 0;
                g_dst < XP_INTF_MAX;
                g_dst = g_dst + 1) begin : gen_txflitv_block
            always_ff @(posedge clk) begin
                if (rst) begin
                    txflitv_q[g_dst] <= 1'b0;
                end
                else begin
                    txflitv_q[g_dst] <= txflitv_d1[g_dst];
                end
            end

            always_ff @(posedge clk) begin
                if (rst) begin
                    txflit_q[g_dst][FLIT_WIDTH-1:0] <= {FLIT_WIDTH{1'b0}};
                end
                else begin
                    txflit_q[g_dst][FLIT_WIDTH-1:0] <= txflit_d1[g_dst][FLIT_WIDTH-1:0];
                end
            end
        end
    endgenerate

    // NodeID routing fields are LSB-anchored: bit 0 is the local port, then Y,
    // then X. Taking them as indexed part-selects keeps the decode identical at
    // the 7-bit default and correct at every width CHI E.b Sec 16.1 allows (7-11).
    function [XP_INTF_MAX-1:0] route_xy(input [CHIE_NID_WIDTH-1:0] tgtid);
        logic [XP_XID_WIDTH-1:0] tgt_xid;
        logic [XP_YID_WIDTH-1:0] tgt_yid;
        logic                    tgt_portid;
        begin
            tgt_portid = tgtid[0];
            tgt_yid    = tgtid[1 +: XP_YID_WIDTH];
            tgt_xid    = tgtid[1+XP_YID_WIDTH +: XP_XID_WIDTH];

            route_xy[XP_INTF_E]  = (tgt_xid > my_xid);
            route_xy[XP_INTF_W]  = (tgt_xid < my_xid);

            route_xy[XP_INTF_N]  = (tgt_xid == my_xid) & (tgt_yid > my_yid);
            route_xy[XP_INTF_S]  = (tgt_xid == my_xid) & (tgt_yid < my_yid);

            route_xy[XP_INTF_P0] = (tgt_xid == my_xid) & (tgt_yid == my_yid) & (tgt_portid == 1'b0);
            route_xy[XP_INTF_P1] = (tgt_xid == my_xid) & (tgt_yid == my_yid) & (tgt_portid == 1'b1);
        end
    endfunction

    assign rxflitv_r1[XP_INTF_E]                 = RXFLITV_E;
    assign rxflitv_r1[XP_INTF_W]                 = RXFLITV_W;
    assign rxflitv_r1[XP_INTF_N]                 = RXFLITV_N;
    assign rxflitv_r1[XP_INTF_S]                 = RXFLITV_S;
    assign rxflitv_r1[XP_INTF_P0]                = RXFLITV_P0;
    assign rxflitv_r1[XP_INTF_P1]                = RXFLITV_P1;

    assign rxflit_r1[XP_INTF_E][FLIT_WIDTH-1:
                                0]  = RXFLIT_E[FLIT_WIDTH-1:
                                               0];
    assign rxflit_r1[XP_INTF_W][FLIT_WIDTH-1:
                                0]  = RXFLIT_W[FLIT_WIDTH-1:
                                               0];
    assign rxflit_r1[XP_INTF_N][FLIT_WIDTH-1:
                                0]  = RXFLIT_N[FLIT_WIDTH-1:
                                               0];
    assign rxflit_r1[XP_INTF_S][FLIT_WIDTH-1:
                                0]  = RXFLIT_S[FLIT_WIDTH-1:
                                               0];
    assign rxflit_r1[XP_INTF_P0][FLIT_WIDTH-1:
                                 0] = RXFLIT_P0[FLIT_WIDTH-1:
                                                0];
    assign rxflit_r1[XP_INTF_P1][FLIT_WIDTH-1:
                                 0] = RXFLIT_P1[FLIT_WIDTH-1:
                                                0];

    assign RXLCRDV_E                             = rxlcrdv_q[XP_INTF_E];
    assign RXLCRDV_W                             = rxlcrdv_q[XP_INTF_W];
    assign RXLCRDV_N                             = rxlcrdv_q[XP_INTF_N];
    assign RXLCRDV_S                             = rxlcrdv_q[XP_INTF_S];
    assign RXLCRDV_P0                            = rxlcrdv_q[XP_INTF_P0];
    assign RXLCRDV_P1                            = rxlcrdv_q[XP_INTF_P1];

    assign txlcrdv[XP_INTF_E]                    = TXLCRDV_E;
    assign txlcrdv[XP_INTF_W]                    = TXLCRDV_W;
    assign txlcrdv[XP_INTF_N]                    = TXLCRDV_N;
    assign txlcrdv[XP_INTF_S]                    = TXLCRDV_S;
    assign txlcrdv[XP_INTF_P0]                   = TXLCRDV_P0;
    assign txlcrdv[XP_INTF_P1]                   = TXLCRDV_P1;

    assign TXFLITV_E                             = txflitv_q[XP_INTF_E];
    assign TXFLITV_W                             = txflitv_q[XP_INTF_W];
    assign TXFLITV_N                             = txflitv_q[XP_INTF_N];
    assign TXFLITV_S                             = txflitv_q[XP_INTF_S];
    assign TXFLITV_P0                            = txflitv_q[XP_INTF_P0];
    assign TXFLITV_P1                            = txflitv_q[XP_INTF_P1];

    assign TXFLIT_E[FLIT_WIDTH-1:
                    0]              = txflit_q[XP_INTF_E][FLIT_WIDTH-1:
                                                          0];
    assign TXFLIT_W[FLIT_WIDTH-1:
                    0]              = txflit_q[XP_INTF_W][FLIT_WIDTH-1:
                                                          0];
    assign TXFLIT_N[FLIT_WIDTH-1:
                    0]              = txflit_q[XP_INTF_N][FLIT_WIDTH-1:
                                                          0];
    assign TXFLIT_S[FLIT_WIDTH-1:
                    0]              = txflit_q[XP_INTF_S][FLIT_WIDTH-1:
                                                          0];
    assign TXFLIT_P0[FLIT_WIDTH-1:
                     0]             = txflit_q[XP_INTF_P0][FLIT_WIDTH-1:
                                                           0];
    assign TXFLIT_P1[FLIT_WIDTH-1:
                     0]             = txflit_q[XP_INTF_P1][FLIT_WIDTH-1:
                                                           0];

endmodule
