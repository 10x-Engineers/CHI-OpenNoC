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

`include "chie_defines.svh"
`include "axi4_defines.svh"
`include "snf_defines.svh"
`include "snf_param.svh"

module snf_txrsp `SNF_PARAM
    (
        //global inputs
        input  wire                            clk,
        input  wire                            rst,

        //inputs from snf_link
        input  wire                            txrsp_lcrdv,
        input  wire                            tx_deactivate,
        input  wire                            txlink_run,

        input  wire                            qos_txrsp_retryack_valid_s1,
        input snf_pkg::retry_ackq_s qos_txrsp_retryack_fifo_s1,

        input  wire                            qos_txrsp_pcrdgnt_valid_s2,
        input snf_pkg::pcrdgrantq_s qos_txrsp_pcrdgnt_fifo_s2,

        //inputs from snf_mshr
        input  wire                                 txrsp_valid_sx,
        input  wire [3:0]                           txrsp_qos_sx,
        input  wire [chie_pkg::NID_WIDTH-1:0]       txrsp_tgtid_sx,
        input  wire [11:0]                          txrsp_txnid_sx,
        input  wire [4:0]                           txrsp_opcode_sx,
        input  wire [1:0]                           txrsp_resperr_sx,
        input  wire [2:0]                           txrsp_resp_sx,
        input  wire [11:0]                          txrsp_dbid_sx,
        input  wire                                 txrsp_tracetag_sx,
        input  wire [chie_pkg::NID_WIDTH-1:0]       txrsp_srcid_sx,

        //outputs to snf_link
        output logic                           txrspflitv,
        output chie_pkg::rsp_flit_s            txrspflit,
        output wire                            txrspflitpend,

        //outputs to snf_qos
        output wire                            txrsp_retryack_won_s1,
        output wire                            txrsp_pcrdgnt_won_s2,

        //outputs to snf_mshr
        output wire                            txrsp_won_sx
    );

    //internal reg signals
    logic [`SNF_LL_RSP_CRD_CNT_WIDTH-1:0]            txrsp_crd_cnt_q;

    chie_pkg::rsp_flit_s                             txrspflit_retyack_s1;
    chie_pkg::rsp_flit_s                             txrspflit_pcrdgnt_s2;
    chie_pkg::rsp_flit_s                             txrspflit_mshr_sx1;
    logic [`SNF_LL_RSP_CRD_CNT_WIDTH-1:0]            rsp_crd_cnt_ns_s0;
    wire                                           txrsp_crd_avail_s1;
    wire                                           txrsp_busy_sx;
    wire                                           txrspcrdv_s0;
    wire                                           txrsp_req_s0;
    wire                                           txrspflitv_s0;
    chie_pkg::rsp_flit_s                           txrspflit_s0;
    wire [`SNF_LL_RSP_CRD_CNT_WIDTH-1:0]           rsp_crd_cnt_s1;
    wire [`SNF_LL_RSP_CRD_CNT_WIDTH-1:0]           rsp_crd_cnt_inc_s0;
    wire [`SNF_LL_RSP_CRD_CNT_WIDTH-1:0]           rsp_crd_cnt_dec_s0;
    wire                                           update_rsp_crd_cnt_s0;
    wire                                           txrsp_crd_cnt_inc_sx;
    wire                                           txrsp_crd_cnt_dec_sx;
    wire                                           rsp_crd_cnt_not_zero_sx;
    wire                                           txrsp_lcrd_rtn_s0;

    //arb and lcrd_avail
    assign rsp_crd_cnt_not_zero_sx     = (txrsp_crd_cnt_q != 0);

    // Sec 14.2.1 (p.14-445, MUST): "An L-Credit cannot be used in the cycle it is
    // received." txrsp_crd_cnt_q already folds this cycle's grant in for the next
    // one, so the counted credits are the whole of what is spendable.
    assign txrsp_crd_avail_s1          = rsp_crd_cnt_not_zero_sx;
    // Table 14-3 (p.14-451, MUST): the Transmitter "must not send flits" in STOP
    // or ACTIVATE. Holding a credit is not that gate -- Sec 14.6.3 (p.14-459) has
    // the peer's ack legally in flight while it is already granting, so the link
    // state this node has itself observed is what a Protocol flit waits on. Busy
    // rather than the flitv term alone, so the arbitration feedback to QoS and
    // the MSHR cannot retire a response the link is not entitled to carry. The
    // L-Credit return below is deliberately outside it: Table 14-2 DEACTIVATE
    // requires those flits in a state that is not RUN.
    assign txrsp_busy_sx               = ~txrsp_crd_avail_s1 | ~txlink_run;

    //output to qos
    assign txrsp_retryack_won_s1 = (qos_txrsp_retryack_valid_s1) &
           ~txrsp_busy_sx;

    assign txrsp_pcrdgnt_won_s2  = (qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           ~txrsp_busy_sx;

    //output to mshr
    assign txrsp_won_sx         = (txrsp_valid_sx) &
           (~qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           ~txrsp_busy_sx;

    assign txrspcrdv_s0               = txrsp_lcrdv;
    assign txrsp_crd_cnt_inc_sx       = txrspcrdv_s0;
    assign txrsp_req_s0               = (qos_txrsp_retryack_valid_s1 |
                                         qos_txrsp_pcrdgnt_valid_s2  |
                                         txrsp_valid_sx);
    always_comb begin
        //RetryAck wrap
        txrspflit_retyack_s1          = '0;
        txrspflit_retyack_s1.qos      = qos_txrsp_retryack_fifo_s1.qos;
        txrspflit_retyack_s1.tgtid    = qos_txrsp_retryack_fifo_s1.srcid;
        txrspflit_retyack_s1.srcid    = SNF_NID_PARAM;
        txrspflit_retyack_s1.txnid    = qos_txrsp_retryack_fifo_s1.txnid;
        txrspflit_retyack_s1.opcode   = chie_pkg::RSP_RETRYACK;
        txrspflit_retyack_s1.pcrdtype = qos_txrsp_retryack_fifo_s1.pcrdtype;
        txrspflit_retyack_s1.tracetag = qos_txrsp_retryack_fifo_s1.trace;
    end

    always_comb begin
        //PCrdGrant wrap
        txrspflit_pcrdgnt_s2          = '0;
        txrspflit_pcrdgnt_s2.qos      = qos_txrsp_pcrdgnt_fifo_s2.qos;
        txrspflit_pcrdgnt_s2.tgtid    = qos_txrsp_pcrdgnt_fifo_s2.srcid;
        txrspflit_pcrdgnt_s2.srcid    = SNF_NID_PARAM;
        txrspflit_pcrdgnt_s2.opcode   = chie_pkg::RSP_PCRDGRANT;
        txrspflit_pcrdgnt_s2.pcrdtype = qos_txrsp_pcrdgnt_fifo_s2.pcrdtype;
    end

    always_comb begin
        //MSHR txrspflit wrap
        txrspflit_mshr_sx1          = '0;
        txrspflit_mshr_sx1.qos      = txrsp_qos_sx;
        txrspflit_mshr_sx1.tgtid    = txrsp_tgtid_sx;
        txrspflit_mshr_sx1.srcid    = txrsp_srcid_sx;
        txrspflit_mshr_sx1.txnid    = txrsp_txnid_sx;
        txrspflit_mshr_sx1.opcode   = chie_pkg::rsp_opcode_e'(txrsp_opcode_sx);
        txrspflit_mshr_sx1.resperr  = chie_pkg::resp_err_e'(txrsp_resperr_sx);
        txrspflit_mshr_sx1.resp     = chie_pkg::resp_state_e'(txrsp_resp_sx);
        txrspflit_mshr_sx1.dbid     = txrsp_dbid_sx;
        txrspflit_mshr_sx1.tracetag = txrsp_tracetag_sx;
    end

    always_comb begin : txrspflit_s0_mux_t
        if      (txrsp_retryack_won_s1) txrspflit_s0 = txrspflit_retyack_s1;
        else if (txrsp_pcrdgnt_won_s2)  txrspflit_s0 = txrspflit_pcrdgnt_s2;
        else if (txrsp_won_sx)          txrspflit_s0 = txrspflit_mshr_sx1;
        else                            txrspflit_s0 = '0;
    end

    assign rsp_crd_cnt_s1          = txrsp_crd_cnt_q;
    assign txrspflitv_s0           = txrsp_req_s0 & (~txrsp_busy_sx);

    // CHI E.b Table 14-2 DEACTIVATE (p.14-450, MUST): "The Transmitter must return
    // credits using Protocol flits or L-Credit return flits", and Sec 14.6.3
    // (p.14-458): "A link must remain in the DEACTIVATE state until all L-Credits
    // are returned." A Protocol flit still wins the cycle.
    assign txrsp_lcrd_rtn_s0       = tx_deactivate & (~txrsp_req_s0) & txrsp_crd_avail_s1;

    assign txrsp_crd_cnt_dec_sx    = (txrspflitv_s0 & txrsp_crd_avail_s1) | txrsp_lcrd_rtn_s0; //lcrd - 1

    assign txrspflitpend = 1'b1;

    //txrspflit sending logic
    always_ff @(posedge clk or posedge rst) begin: txrspflit_logic_t
        if(rst == 1'b1)begin
            txrspflit <= '0;
            txrspflitv <= 1'b0;
        end
        else if((txrspflitv_s0 == 1'b1) & (txrsp_crd_avail_s1 == 1'b1))begin
            txrspflit <= txrspflit_s0;
            txrspflitv <= 1'b1;
        end
        else if(txrsp_lcrd_rtn_s0 == 1'b1)begin
            //RespLCrdReturn: opcode 0 with every other field zero (Table 13-13)
            txrspflit <= '0;
            txrspflitv <= 1'b1;
        end
        else begin
            txrspflitv <= 1'b0;
        end
    end

    //L-credit logic
    assign update_rsp_crd_cnt_s0   = txrsp_crd_cnt_inc_sx | txrsp_crd_cnt_dec_sx;
    assign rsp_crd_cnt_inc_s0      = (rsp_crd_cnt_s1 + 1'b1);
    assign rsp_crd_cnt_dec_s0      = (rsp_crd_cnt_s1 - 1'b1);

    always_comb begin: rsp_crd_cnt_ns_s0_logic_c
        casez({txrsp_crd_cnt_inc_sx, txrsp_crd_cnt_dec_sx})
            2'b00:
                rsp_crd_cnt_ns_s0   = txrsp_crd_cnt_q;     // hold
            2'b01:
                rsp_crd_cnt_ns_s0   = rsp_crd_cnt_dec_s0;  // dec
            2'b10:
                rsp_crd_cnt_ns_s0   = rsp_crd_cnt_inc_s0;  // inc
            2'b11:
                rsp_crd_cnt_ns_s0   = txrsp_crd_cnt_q;     // hold
            default:
                rsp_crd_cnt_ns_s0 = {`SNF_LL_RSP_CRD_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin: txrsp_crd_cnt_q_logic_t
        if (rst == 1'b1)
            txrsp_crd_cnt_q <= {`SNF_LL_RSP_CRD_CNT_WIDTH{1'b0}};
        else if (update_rsp_crd_cnt_s0 == 1'b1)
            txrsp_crd_cnt_q <= rsp_crd_cnt_ns_s0;
    end


endmodule

