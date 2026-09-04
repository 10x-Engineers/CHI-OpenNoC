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
*    Ziqing Li <liziqing@bosc.ac.cn>
*    Wenhao Li <liwenhao@bosc.ac.cn>
*/

`include "rni_param.svh"
`include "rni_defines.svh"
`include "axi4_defines.svh"

module rni_misc `RNI_PARAM
    (
    // global inputs
    input wire clk_i,
    input wire rst_i,

    // rni_link_ctl Interface
    input wire rxrspflitv_d1_i,
    input chie_pkg::rsp_flit_s rxrspflit_d1_q_i,

    // rni_aw_ctl Interface
    output wire pcrdgnt_pkt_v_d2_o,
    output opennoc_rni_pkg::pcrdgrant_pkt_s pcrdgnt_pkt_d2_o,
    input wire ar_pcrdgnt_l_present_d3_i,
    input wire ar_pcrdgnt_h_present_d3_i,
    input wire aw_pcrdgnt_l_present_d3_i,
    input wire aw_pcrdgnt_h_present_d3_i,
    output wire ar_pcrdgnt_l_win_d3_o,
    output wire ar_pcrdgnt_h_win_d3_o,
    output wire aw_pcrdgnt_l_win_d3_o,
    output wire aw_pcrdgnt_h_win_d3_o
    );

    //wire
    wire                                     pcrdgnt_fifo_push_d1_w;
    wire                                     pcrdgnt_fifo_pop_d3_w;
    wire [3:0] pcrdgnt_pcrdtype_d1_w;
    wire [chie_pkg::NID_WIDTH-1:0]    pcrdgnt_srcid_d1_w;
    wire [chie_pkg::NID_WIDTH-1:0]    pcrdgnt_tgtid_d1_w;
    opennoc_rni_pkg::pcrdgrant_pkt_s          pcrdgnt_fifo_in_d1_w;
    opennoc_rni_pkg::pcrdgrant_pkt_s          pcrdgnt_fifo_out_d2_w;
    wire                                     pcrdgnt_fifo_empty_d2_w;
    wire                                     nxt_h_pcrdgnt_ptr_w;
    wire                                     nxt_l_pcrdgnt_ptr_w;
    wire                                     l_arb_lost_w;
    wire                                     l_disable_h_cnt_inc_w;
    wire                                     l_disable_h_cnt_rst_w;
    wire                                     l_disable_h_cnt_upd_w;
    wire [`L_DISABLE_CNT_WIDTH-1:0]          nxt_l_disable_h_cnt_w;
    wire                                     l_disable_h_w;

    //reg
    logic                                      h_pcrdgnt_ptr_q;
    logic                                      l_pcrdgnt_ptr_q;
    logic  [`L_DISABLE_CNT_WIDTH-1:0]          l_disable_h_cnt_q;

    //local param
    localparam FIFO_ENTRIES_DEPTH = 32;
    localparam FIFO_ENTRIES_WIDTH = $bits(opennoc_rni_pkg::pcrdgrant_pkt_s);
    localparam L_DISABLE_H_EN     = 1'b0;

    //main function
    assign pcrdgnt_fifo_push_d1_w = rxrspflitv_d1_i & (rxrspflit_d1_q_i.opcode == chie_pkg::RSP_PCRDGRANT);
    assign pcrdgnt_fifo_pop_d3_w  = (ar_pcrdgnt_l_present_d3_i | ar_pcrdgnt_h_present_d3_i | aw_pcrdgnt_l_present_d3_i | aw_pcrdgnt_h_present_d3_i);
    assign pcrdgnt_pcrdtype_d1_w  = rxrspflit_d1_q_i.pcrdtype;
    assign pcrdgnt_srcid_d1_w     = rxrspflit_d1_q_i.srcid;
    assign pcrdgnt_tgtid_d1_w     = rxrspflit_d1_q_i.tgtid;
    assign pcrdgnt_fifo_in_d1_w   = {pcrdgnt_pcrdtype_d1_w,pcrdgnt_srcid_d1_w,pcrdgnt_tgtid_d1_w};

    sync_fifo #(
                  .FIFO_ENTRIES_WIDTH ( FIFO_ENTRIES_WIDTH )
                  ,.FIFO_ENTRIES_DEPTH ( FIFO_ENTRIES_DEPTH )
                  ,.FIFO_BYP_ENABLE    ( 1'b0               )
              )pcrdgnt_fifo(
                  .clk      ( clk_i                   )
                  ,.rst      ( rst_i                   )
                  ,.push     ( pcrdgnt_fifo_push_d1_w  )
                  ,.pop      ( pcrdgnt_fifo_pop_d3_w   )
                  ,.data_in  ( pcrdgnt_fifo_in_d1_w    )
                  ,.data_out ( pcrdgnt_fifo_out_d2_w   )
                  ,.empty    ( pcrdgnt_fifo_empty_d2_w )
                  ,.full     (                         )
                  ,.count    (                         )
              );

    assign pcrdgnt_pkt_d2_o   = pcrdgnt_fifo_out_d2_w;
    assign pcrdgnt_pkt_v_d2_o = ~pcrdgnt_fifo_empty_d2_w & ~pcrdgnt_fifo_pop_d3_w;

    // ar and aw H arbitration
    assign nxt_h_pcrdgnt_ptr_w = (ar_pcrdgnt_h_present_d3_i & aw_pcrdgnt_h_present_d3_i & (h_pcrdgnt_ptr_q == 1'b0))? 1 : (ar_pcrdgnt_h_present_d3_i & aw_pcrdgnt_h_present_d3_i & (h_pcrdgnt_ptr_q == 1'b1))? 0 : h_pcrdgnt_ptr_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            h_pcrdgnt_ptr_q <= 1'b0;
        else
            h_pcrdgnt_ptr_q <= nxt_h_pcrdgnt_ptr_w;
    end

    assign ar_pcrdgnt_h_win_d3_o = ~l_disable_h_w & ar_pcrdgnt_h_present_d3_i & (~aw_pcrdgnt_h_present_d3_i | (h_pcrdgnt_ptr_q == 1'b0));
    assign aw_pcrdgnt_h_win_d3_o = ~l_disable_h_w & aw_pcrdgnt_h_present_d3_i & (~ar_pcrdgnt_h_present_d3_i | (h_pcrdgnt_ptr_q == 1'b1));

    // ar and aw L arbitration
    assign nxt_l_pcrdgnt_ptr_w = (ar_pcrdgnt_l_present_d3_i & aw_pcrdgnt_l_present_d3_i & (l_pcrdgnt_ptr_q == 1'b0))? 1 : (ar_pcrdgnt_l_present_d3_i & aw_pcrdgnt_l_present_d3_i & (l_pcrdgnt_ptr_q == 1'b1))? 0 : l_pcrdgnt_ptr_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            l_pcrdgnt_ptr_q <= 1'b0;
        else
            l_pcrdgnt_ptr_q <= nxt_l_pcrdgnt_ptr_w;
    end

    assign ar_pcrdgnt_l_win_d3_o = ar_pcrdgnt_l_present_d3_i & ~ar_pcrdgnt_h_win_d3_o & ~aw_pcrdgnt_h_win_d3_o & (~aw_pcrdgnt_l_present_d3_i | (l_pcrdgnt_ptr_q == 1'b0));
    assign aw_pcrdgnt_l_win_d3_o = aw_pcrdgnt_l_present_d3_i & ~ar_pcrdgnt_h_win_d3_o & ~aw_pcrdgnt_h_win_d3_o & (~ar_pcrdgnt_l_present_d3_i | (l_pcrdgnt_ptr_q == 1'b1));

    assign l_arb_lost_w = (ar_pcrdgnt_l_present_d3_i | aw_pcrdgnt_l_present_d3_i) & ~(ar_pcrdgnt_l_win_d3_o | aw_pcrdgnt_l_win_d3_o);

    assign l_disable_h_cnt_inc_w = l_arb_lost_w;
    assign l_disable_h_cnt_rst_w = (ar_pcrdgnt_l_win_d3_o | aw_pcrdgnt_l_win_d3_o);
    assign l_disable_h_cnt_upd_w = (l_disable_h_cnt_inc_w | l_disable_h_cnt_rst_w);
    assign nxt_l_disable_h_cnt_w = l_disable_h_cnt_inc_w? (l_disable_h_cnt_q + 1'b1) : {`L_DISABLE_CNT_WIDTH{1'b0}};

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            l_disable_h_cnt_q <= {`L_DISABLE_CNT_WIDTH{1'b0}};
        else if(l_disable_h_cnt_upd_w == 1'b1)
            l_disable_h_cnt_q <= nxt_l_disable_h_cnt_w;
    end

    assign l_disable_h_w = (l_disable_h_cnt_q == `L_DISABLE_H_MAX_VAL) & (ar_pcrdgnt_l_present_d3_i | aw_pcrdgnt_l_present_d3_i) & L_DISABLE_H_EN;

endmodule
