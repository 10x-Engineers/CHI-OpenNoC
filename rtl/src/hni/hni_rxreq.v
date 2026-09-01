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

`include "chie_defines.v"
`include "axi4_defines.v"
`include "hni_defines.v"
`include "hni_param.v"

module hni_rxreq `HNI_PARAM
    (
        clk,
        rst,

        rxreqflitv,
        rxreqflit,
        rxreqflitpend,

        rxreq_retry_enable_s0,

        txrsp_retryack_won_s1,

        rxreq_lcrdv,
        rxcrd_en,
        rxreq_crd_cnt_full,

        rxreq_valid_s0,
        rxreqflit_s0
    );

    //global inputs
    input wire                         clk;
    input wire                         rst;

    //inputs from link
    input wire                         rxreqflitv;
    input wire [`CHIE_REQ_FLIT_RANGE]  rxreqflit;
    input wire                         rxreqflitpend;

    //inputs from hni_qos
    input wire                         rxreq_retry_enable_s0;

    //inputs from hni_txrsp
    input wire                         txrsp_retryack_won_s1;

    //outputs to link
    output wire                        rxreq_lcrdv;
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input  wire                        rxcrd_en;
    // Table 14-2's DEACTIVATE row (p.14-450, MUST): "The Receiver must wait for all
    // credits to be returned before deasserting LINKACTIVEACK".
    output wire                        rxreq_crd_cnt_full;

    //outputs to hni_qos
    output wire                        rxreq_valid_s0;
    output wire [`CHIE_REQ_FLIT_RANGE] rxreqflit_s0;

    //internal reg signals
    reg                                             rxreqflitv_en_q;
    reg [`HNI_LL_REQ_CRD_CNT_RANGE]                 rxreq_crd_cnt_s1_q;
    reg                                             rxreqcrdv_s1_q;

    //internal wire signals
    wire                                            rxreq_crd_grant_sx;
    wire [1:0]                                      rxreq_crd_rtn_sx;
    wire                                            rxreq_crd_cnt_zero_sx;
    wire                                            req_crd_rtn_s0;
    wire                                            retack_tx_s1;
    wire                                            rxreq_crd_cnt_upd_s1;
    wire                                            rxreqcrdv_ns_s0;
    wire [`HNI_LL_REQ_CRD_CNT_RANGE]                rxreq_crd_cnt_nxt_s1;

    //main function

    //link_rxreq_parse awake
    always @(posedge clk or posedge rst)begin : rxreqflitv_en_q_logic_t
        if(rst == 1'b1)
            rxreqflitv_en_q <= 1'b0;
        else if (rxreqflitpend == 1'b1)
            rxreqflitv_en_q <= 1'b1;
        else
            rxreqflitv_en_q <= 1'b0;
    end

    //rxreqflit decode
    assign rxreq_valid_s0    = (rxreqflitv == 1'b1);
    assign rxreqflit_s0      = (rxreqflitv == 1'b1) ? rxreqflit : {`CHIE_REQ_FLIT_WIDTH{1'b0}};

    //rxreq L-credit
    assign req_crd_rtn_s0 = !rxreq_retry_enable_s0 && rxreqflitv == 1'b1;

    //retry transaction sent
    assign retack_tx_s1 = txrsp_retryack_won_s1;

    assign rxreq_crd_cnt_zero_sx = (rxreq_crd_cnt_s1_q == {`HNI_LL_REQ_CRD_CNT_WIDTH{1'b0}});
    assign rxreq_crd_rtn_sx      = {1'b0, req_crd_rtn_s0} + {1'b0, retack_tx_s1};
    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxreq_crd_grant_sx    = rxcrd_en & ((~rxreq_crd_cnt_zero_sx) | (|rxreq_crd_rtn_sx));
    assign rxreqcrdv_ns_s0       = rxreq_crd_grant_sx;
    assign rxreq_crd_cnt_upd_s1  = rxreq_crd_grant_sx | (|rxreq_crd_rtn_sx);
    assign rxreq_crd_cnt_nxt_s1  = rxreq_crd_cnt_s1_q - {{(`HNI_LL_REQ_CRD_CNT_WIDTH-1){1'b0}}, rxreq_crd_grant_sx}
                                                     + {{(`HNI_LL_REQ_CRD_CNT_WIDTH-2){1'b0}}, rxreq_crd_rtn_sx};
    assign rxreq_crd_cnt_full    = (rxreq_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNI_LL_REQ_CRD_CNT_WIDTH-1:0]);

    always @(posedge clk or posedge rst) begin: rxreq_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxreq_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else if (rxreq_crd_cnt_upd_s1 == 1'b1)
            rxreq_crd_cnt_s1_q <= rxreq_crd_cnt_nxt_s1;
    end

    always @(posedge clk or posedge rst) begin: rxreqcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxreqcrdv_s1_q <= 1'b0;
        else
            rxreqcrdv_s1_q <= rxreqcrdv_ns_s0;
    end

    assign rxreq_lcrdv = rxreqcrdv_s1_q;

endmodule
