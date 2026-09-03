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
*    Li Zhao <lizhao@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

`include "chie_defines.svh"
`include "axi4_defines.svh"
`include "hni_defines.svh"
`include "hni_param.svh"

module hni_rxrsp `HNI_PARAM
    (
        clk,
        rst,

        rxrspflitv,
        rxrspflit,
        rxrspflitpend,

        rxrsp_lcrdv,
        rxcrd_en,
        rxrsp_crd_cnt_full,

        rxrsp_valid_s0,
        rxrspflit_s0
    );

    //global inputs
    input wire                                      clk;
    input wire                                      rst;

    //inputs from hni_link
    input wire                                      rxrspflitv;
    input wire [`CHIE_RSP_FLIT_RANGE]               rxrspflit;
    input wire                                      rxrspflitpend;

    //outputs to hni_link
    output wire                                     rxrsp_lcrdv;
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input  wire                                     rxcrd_en;
    // Table 14-2's DEACTIVATE row (p.14-450, MUST): "The Receiver must wait for all
    // credits to be returned before deasserting LINKACTIVEACK".
    output wire                                     rxrsp_crd_cnt_full;

    //outputs to hni_mshr
    output wire                                     rxrsp_valid_s0;
    output wire [`CHIE_RSP_FLIT_RANGE]              rxrspflit_s0;

    //internal reg signals
    logic                                             rxrspflitv_en_q;
    logic  [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0]            rxrsp_crd_cnt_s1_q;
    logic                                             rxrspcrdv_s1_q;

    //internal wire signals
    wire                                            rxrsp_crd_grant_sx;
    wire                                            rxrsp_crd_cnt_zero;
    wire                                            rxrsp_crd_cnt_upd_s0;
    wire [`HNI_LL_RSP_CRD_CNT_RANGE]                rxrsp_crd_cnt_nxt_s0;
    wire                                            rxrspcrdv_ns_s0;

    //main function
    //receive rxrspflitpend
    always_ff @(posedge clk or posedge rst)begin : rxrspflitv_en_q_logic_t
        if(rst == 1'b1)
            rxrspflitv_en_q <= 1'b0;
        else if (rxrspflitpend == 1'b1)
            rxrspflitv_en_q <= 1'b1;
        else
            rxrspflitv_en_q <= 1'b0;
    end

    //to mshr
    assign rxrsp_valid_s0  = (rxrspflitv == 1'b1);
    assign rxrspflit_s0    = (rxrspflitv == 1'b1) ? rxrspflit : {`CHIE_RSP_FLIT_WIDTH{1'b0}};

    assign rxrsp_crd_cnt_zero  = (rxrsp_crd_cnt_s1_q == {`HNI_LL_RSP_CRD_CNT_WIDTH{1'b0}});
    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxrsp_crd_grant_sx  = rxcrd_en & ((~rxrsp_crd_cnt_zero) | rxrsp_valid_s0);
    assign rxrspcrdv_ns_s0     = rxrsp_crd_grant_sx;
    assign rxrsp_crd_cnt_upd_s0 = rxrsp_crd_grant_sx | rxrsp_valid_s0;
    assign rxrsp_crd_cnt_nxt_s0 = rxrsp_crd_cnt_s1_q - {{(`HNI_LL_RSP_CRD_CNT_WIDTH-1){1'b0}}, rxrsp_crd_grant_sx}
                                                  + {{(`HNI_LL_RSP_CRD_CNT_WIDTH-1){1'b0}}, rxrsp_valid_s0};
    assign rxrsp_crd_cnt_full  = (rxrsp_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNI_LL_RSP_CRD_CNT_WIDTH-1:0]);

    always_ff @(posedge clk or posedge rst) begin: rxrsp_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxrsp_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else if (rxrsp_crd_cnt_upd_s0 == 1'b1)
            rxrsp_crd_cnt_s1_q <= rxrsp_crd_cnt_nxt_s0;
    end

    always_ff @(posedge clk or posedge rst) begin: rxrspcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxrspcrdv_s1_q <= 1'b0;
        else
            rxrspcrdv_s1_q <= rxrspcrdv_ns_s0;
    end

    assign rxrsp_lcrdv = rxrspcrdv_s1_q;

endmodule
