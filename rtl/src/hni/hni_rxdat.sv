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

module hni_rxdat `HNI_PARAM
    (
        clk,
        rst,

        rxdatflitv,
        rxdatflit,
        rxdatflitpend,

        rxdat_lcrdv,
        rxcrd_en,
        rxdat_crd_cnt_full,

        rxdat_valid_s0,
        rxdatflit_s0
    );

    //global inputs
    input wire                        clk;
    input wire                        rst;

    //inputs from hni_link
    input wire                        rxdatflitv;
    input wire [`CHIE_DAT_FLIT_RANGE] rxdatflit;
    input wire                        rxdatflitpend;

    //outputs to hni_link
    output wire                       rxdat_lcrdv;
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input  wire                       rxcrd_en;
    // Table 14-2's DEACTIVATE row (p.14-450, MUST): "The Receiver must wait for all
    // credits to be returned before deasserting LINKACTIVEACK".
    output wire                       rxdat_crd_cnt_full;

    //outputs to hni_data_buffer
    output wire                        rxdat_valid_s0;
    output wire [`CHIE_DAT_FLIT_RANGE] rxdatflit_s0;

    //internal reg signals
    logic                                             rxdatflitv_en_q;
    logic  [`HNI_LL_DAT_CRD_CNT_WIDTH-1:0]            rxdat_crd_cnt_s1_q;
    logic                                             rxdatcrdv_s1_q;

    //internal wire signals
    wire                                            rxdat_crd_grant_sx;
    wire                                            rxdat_crd_cnt_zero;
    wire                                            rxdat_crd_cnt_upd_s0;
    wire [`HNI_LL_DAT_CRD_CNT_RANGE]                rxdat_crd_cnt_nxt_s0;
    wire                                            rxdatcrdv_ns_s0;

    //main function
    always_ff @(posedge clk or posedge rst) begin:rxdatflitv_en_q_logic_t
        if(rst == 1'b1)
            rxdatflitv_en_q <= 1'b0;
        else if(rxdatflitpend == 1'b1)
            rxdatflitv_en_q <= 1'b1;
        else
            rxdatflitv_en_q <= 1'b0;
    end

    // to dbf
    assign rxdat_valid_s0  = (rxdatflitv == 1'b1);
    assign rxdatflit_s0    = (rxdatflitv == 1'b1)? rxdatflit : {`CHIE_DAT_FLIT_WIDTH{1'b0}};
    
    assign rxdat_crd_cnt_zero  = (rxdat_crd_cnt_s1_q == {`HNI_LL_DAT_CRD_CNT_WIDTH{1'b0}});
    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxdat_crd_grant_sx  = rxcrd_en & ((~rxdat_crd_cnt_zero) | rxdat_valid_s0);
    assign rxdatcrdv_ns_s0     = rxdat_crd_grant_sx;
    assign rxdat_crd_cnt_upd_s0 = rxdat_crd_grant_sx | rxdat_valid_s0;
    assign rxdat_crd_cnt_nxt_s0 = rxdat_crd_cnt_s1_q - {{(`HNI_LL_DAT_CRD_CNT_WIDTH-1){1'b0}}, rxdat_crd_grant_sx}
                                                  + {{(`HNI_LL_DAT_CRD_CNT_WIDTH-1){1'b0}}, rxdat_valid_s0};
    assign rxdat_crd_cnt_full  = (rxdat_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNI_LL_DAT_CRD_CNT_WIDTH-1:0]);

    always_ff @(posedge clk or posedge rst) begin: rxdat_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxdat_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else if (rxdat_crd_cnt_upd_s0 == 1'b1)
            rxdat_crd_cnt_s1_q <= rxdat_crd_cnt_nxt_s0;
    end

    always_ff @(posedge clk or posedge rst) begin: rxdatcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxdatcrdv_s1_q <= 1'b0;
        else
            rxdatcrdv_s1_q <= rxdatcrdv_ns_s0;
    end

    assign rxdat_lcrdv = rxdatcrdv_s1_q;

endmodule
