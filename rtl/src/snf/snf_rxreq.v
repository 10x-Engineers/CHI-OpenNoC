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
*    Nana Cai <cainana@bosc.ac.cn>
*    Li Zhao <lizhao@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*    Guo Bing <guobing@bosc.ac.cn>
*/

`include "chie_defines.v"
`include "axi4_defines.v"
`include "snf_defines.v"
`include "snf_param.v"

module snf_rxreq `SNF_PARAM
    (
        clk,
        rst,
        run_state,
        rxreqflitv,
        rxreqflit,
        rxreqflitpend,

        rxreq_retry_enable_s0,

        txrsp_retryack_won_s1,

        rxreq_lcrdv,

        rxreq_valid_s0,
        rxreqflit_s0
    );

    //global inputs
    input wire                                      clk;
    input wire                                      rst;
    input wire                                      run_state;

    //inputs from link
    input wire                                      rxreqflitv;
    input wire [`CHIE_REQ_FLIT_RANGE]               rxreqflit;
    input wire                                      rxreqflitpend;

    //inputs from snf_qos
    input wire                                      rxreq_retry_enable_s0;

    //inputs from snf_txrsp
    input wire                                      txrsp_retryack_won_s1;

    //outputs to link
    output wire                                     rxreq_lcrdv;

    //outputs to snf_qos
    output wire                                     rxreq_valid_s0;
    output wire [`CHIE_REQ_FLIT_RANGE]              rxreqflit_s0;

    //internal reg signals
    reg                                             rxreqflitv_en_q;
    reg [`SNF_LL_REQ_CRD_CNT_RANGE]                 rxreq_crd_cnt_s1_q;
    reg                                             rxreqcrdv_s1_q;

    //internal wire signals
    wire                                            snf_rxcrd_enable_sx;
    wire                                            rxreq_crd_cnt_zero_sx;
    wire [1:0]                                      rxreq_crd_rtn_cnt_s1;
    wire                                            req_crd_rtn_s0;
    wire                                            rxreq_link_flit_s0;
    wire                                            retack_tx_s1;
    wire                                            rxreqcrdv_ns_s0;
    wire [`SNF_LL_REQ_CRD_CNT_RANGE]                rxreq_crd_cnt_nxt_s1;

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
    // CHI E.b Sec 13.11: "A link flit is identified by a zero value in the Opcode
    // field." It carries no request -- only the L-Credit it returns -- so it is
    // dropped here rather than allocated a tracker entry, and only the credit
    // accounting below sees it.
    assign rxreq_link_flit_s0 = (rxreqflitv == 1'b1) &&
           (rxreqflit[`CHIE_REQ_FLIT_OPCODE_RANGE] == {`CHIE_REQ_FLIT_OPCODE_WIDTH{1'b0}});
    assign rxreq_valid_s0    = (rxreqflitv == 1'b1) && !rxreq_link_flit_s0;
    assign rxreqflit_s0      = (rxreq_valid_s0 == 1'b1) ? rxreqflit : {`CHIE_REQ_FLIT_WIDTH{1'b0}};

    //rxreq L-credit
    assign req_crd_rtn_s0 = !rxreq_retry_enable_s0 && rxreqflitv == 1'b1;

    //retry transaction sent
    assign retack_tx_s1 = txrsp_retryack_won_s1;

    // The Receiver's pool of L-Credits not yet granted to the peer.
    //   into the pool  : an arriving flit hands back the credit it was sent under,
    //     and a RetryAck'd request's credit is replaced by a P-Credit
    //     (Sec 2.11 p.2-145) rather than re-granted, so it returns too;
    //   out of the pool: only in RUN -- CHI E.b Table 14-2 (p.14-450, MUST) has the
    //     Receiver send no credits in STOP/ACTIVATE and stop sending them in
    //     DEACTIVATE, which is precisely when the peer returns its own.
    // The returns are counted in every state: Table 14-2 has the Transmitter return
    // every held L-Credit while the link sits in DEACTIVATE, so a pool that ignored
    // them would come back from STOP empty and never grant again.
    assign snf_rxcrd_enable_sx   = run_state;
    assign rxreq_crd_cnt_zero_sx = (rxreq_crd_cnt_s1_q == {`SNF_LL_REQ_CRD_CNT_WIDTH{1'b0}});

    assign rxreq_crd_rtn_cnt_s1  = {1'b0, req_crd_rtn_s0} + {1'b0, retack_tx_s1};
    assign rxreqcrdv_ns_s0       = snf_rxcrd_enable_sx &
           (~rxreq_crd_cnt_zero_sx | req_crd_rtn_s0 | retack_tx_s1);

    assign rxreq_crd_cnt_nxt_s1  = rxreq_crd_cnt_s1_q
                                 + {{(`SNF_LL_REQ_CRD_CNT_WIDTH-2){1'b0}}, rxreq_crd_rtn_cnt_s1}
                                 - {{(`SNF_LL_REQ_CRD_CNT_WIDTH-1){1'b0}}, rxreqcrdv_ns_s0};


    always @(posedge clk or posedge rst) begin: rxreq_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxreq_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else
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
