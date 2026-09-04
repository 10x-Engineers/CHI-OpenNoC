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
*    Wenhao Li <liwenhao@bosc.ac.cn>
*    Li Zhao <lizhao@bosc.ac.cn>
*    Bingcheng Jin <jinbingcheng@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_txrsp_wrap `HNF_PARAM
    (
    //global inputs
    input  wire                           clk,
    input  wire                           rst,

    //inputs from hnf_link
    input  wire                           txrsp_lcrdv,
    input  wire                           lcrd_return_en,
    input  wire                           txlink_run,
    output wire                           txrsp_flit_avail,

    //inputs from hnf_mshr_bypass
    input  wire                           mshr_txrsp_bypass_valid_s1,
    input  wire [3:0]                     mshr_txrsp_bypass_qos_s1,
    input  wire [chie_pkg::NID_WIDTH-1:0] mshr_txrsp_bypass_tgtid_s1,
    input  wire [11:0]                    mshr_txrsp_bypass_txnid_s1,
    input  chie_pkg::rsp_opcode_e         mshr_txrsp_bypass_opcode_s1,
    input  chie_pkg::resp_err_e           mshr_txrsp_bypass_resperr_s1,
    input  wire [11:0]                    mshr_txrsp_bypass_dbid_s1,
    input  wire                           mshr_txrsp_bypass_tracetag_s1,

    //inputs from hnf_mshr_qos
    input  wire                           qos_txrsp_retryack_valid_s1,
    input  wire [3:0]                     qos_txrsp_retryack_qos_s1,
    input  wire [chie_pkg::NID_WIDTH-1:0] qos_txrsp_retryack_tgtid_s1,
    input  wire [11:0]                    qos_txrsp_retryack_txnid_s1,
    input  wire [3:0]                     qos_txrsp_retryack_pcrdtype_s1,
    input  wire                           qos_txrsp_retryack_tracetag_s1,
    input  wire                           qos_txrsp_pcrdgnt_valid_s2,
    input  wire [3:0]                     qos_txrsp_pcrdgnt_qos_s2,
    input  wire [chie_pkg::NID_WIDTH-1:0] qos_txrsp_pcrdgnt_tgtid_s2,
    input  wire [3:0]                     qos_txrsp_pcrdgnt_pcrdtype_s2,

    //inputs from hnf_mshr_ctl
    input  wire                           mshr_txrsp_valid_sx1_q,
    input  wire [3:0]                     mshr_txrsp_qos_sx1,
    input  wire [chie_pkg::NID_WIDTH-1:0] mshr_txrsp_tgtid_sx1,
    input  wire [11:0]                    mshr_txrsp_txnid_sx1_q,
    input  chie_pkg::rsp_opcode_e         mshr_txrsp_opcode_sx1,
    input  chie_pkg::resp_err_e           mshr_txrsp_resperr_sx1,
    input  chie_pkg::resp_state_e         mshr_txrsp_resp_sx1,
    input  wire [11:0]                    mshr_txrsp_dbid_sx1,
    input  wire                           mshr_txrsp_tracetag_sx1,

    //outputs to hnf_link
    output logic                          txrspflitv,
    output chie_pkg::rsp_flit_s           txrspflit,
    output wire                           txrspflitpend,

    //outputs to hnf_mshr_qos
    output wire                           txrsp_mshr_retryack_won_s1,
    output wire                           txrsp_mshr_pcrdgnt_won_s2,

    //outputs to hnf_mshr_ctl
    output wire                           txrsp_mshr_won_sx1,
    output wire                           txrsp_mshr_bypass_won_s1
    );

    //internal reg signals
    logic [`HNF_LCRD_RSP_CNT_WIDTH-1:0] txrsp_crd_cnt_q;
    chie_pkg::rsp_flit_s                txrspflit_bypass_s1;
    chie_pkg::rsp_flit_s                txrspflit_retyack_s1;
    chie_pkg::rsp_flit_s                txrspflit_pcrdgnt_s2;
    chie_pkg::rsp_flit_s                txrspflit_mshr_sx1;
    logic [`HNF_LCRD_RSP_CNT_WIDTH-1:0] rsp_crd_cnt_ns_s0;

    //internal wire signals
    wire                                txrsp_crd_avail_s1;
    wire                                txrsp_busy_sx;
    wire                                txrspcrdv_s0;
    wire                                txrsp_req_s0;
    wire                                txrspflitv_s0;
    chie_pkg::rsp_flit_s                txrspflit_s0;
    wire [`HNF_LCRD_RSP_CNT_WIDTH-1:0]  rsp_crd_cnt_s1;
    wire [`HNF_LCRD_RSP_CNT_WIDTH-1:0]  rsp_crd_cnt_inc_s0;
    wire [`HNF_LCRD_RSP_CNT_WIDTH-1:0]  rsp_crd_cnt_dec_s0;
    wire                                update_rsp_crd_cnt_s0;
    wire                                txrsp_crd_cnt_inc_sx;
    wire                                txrsp_crd_cnt_dec_sx;
    wire                                rsp_crd_cnt_not_zero_sx;

    wire                                txrsp_lcrd_rtn_sx;

    //main function

    //arb and lcrd_avail

    assign rsp_crd_cnt_not_zero_sx     = (txrsp_crd_cnt_q != 0);

    // just received it or not zero

    assign txrsp_crd_avail_s1          = (txrsp_lcrdv | rsp_crd_cnt_not_zero_sx);
    assign txrsp_busy_sx               = ~txrsp_crd_avail_s1 | (~txlink_run);

    //outputs to mshr

    assign txrsp_mshr_bypass_won_s1       = mshr_txrsp_bypass_valid_s1 &
           ~txrsp_busy_sx;

    assign txrsp_mshr_retryack_won_s1 = (qos_txrsp_retryack_valid_s1) &
           (~mshr_txrsp_bypass_valid_s1) &
           ~txrsp_busy_sx;

    assign txrsp_mshr_pcrdgnt_won_s2  = (qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           (~mshr_txrsp_bypass_valid_s1) &
           ~txrsp_busy_sx;

    assign txrsp_mshr_won_sx1         = (mshr_txrsp_valid_sx1_q) &
           (~qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           (~mshr_txrsp_bypass_valid_s1) &
           ~txrsp_busy_sx;

    assign txrspcrdv_s0               = txrsp_lcrdv;
    assign txrsp_crd_cnt_inc_sx       = txrspcrdv_s0;
    assign txrsp_req_s0               = (mshr_txrsp_bypass_valid_s1      |
                                         qos_txrsp_retryack_valid_s1 |
                                         qos_txrsp_pcrdgnt_valid_s2  |
                                         mshr_txrsp_valid_sx1_q);

    //arbitration

    always_comb begin
        //bypass wrap
        txrspflit_bypass_s1.qos           = mshr_txrsp_bypass_qos_s1;
        txrspflit_bypass_s1.tgtid         = mshr_txrsp_bypass_tgtid_s1;
        txrspflit_bypass_s1.srcid         = HNF_NID_PARAM;
        txrspflit_bypass_s1.txnid         = mshr_txrsp_bypass_txnid_s1;
        txrspflit_bypass_s1.opcode        = mshr_txrsp_bypass_opcode_s1;
        txrspflit_bypass_s1.resperr       = mshr_txrsp_bypass_resperr_s1;
        txrspflit_bypass_s1.resp          = chie_pkg::RESP_I;
        txrspflit_bypass_s1.fwdstate      = '0;
        txrspflit_bypass_s1.cbusy         = '0;
        txrspflit_bypass_s1.dbid          = mshr_txrsp_bypass_dbid_s1;
        txrspflit_bypass_s1.pcrdtype      = '0;
        txrspflit_bypass_s1.tagop         = '0;
        txrspflit_bypass_s1.tracetag      = mshr_txrsp_bypass_tracetag_s1;
    end
    always_comb begin
        //RetryAck wrap
        txrspflit_retyack_s1.qos      = qos_txrsp_retryack_qos_s1;
        txrspflit_retyack_s1.tgtid    = qos_txrsp_retryack_tgtid_s1;
        txrspflit_retyack_s1.srcid    = HNF_NID_PARAM;
        txrspflit_retyack_s1.txnid    = qos_txrsp_retryack_txnid_s1;
        txrspflit_retyack_s1.opcode   = chie_pkg::RSP_RETRYACK;
        txrspflit_retyack_s1.resperr  = chie_pkg::RESP_ERR_NORM_OK;
        txrspflit_retyack_s1.resp     = chie_pkg::RESP_I;
        txrspflit_retyack_s1.fwdstate = '0;
        txrspflit_retyack_s1.cbusy    = '0;
        txrspflit_retyack_s1.dbid     = '0;
        txrspflit_retyack_s1.pcrdtype = qos_txrsp_retryack_pcrdtype_s1;
        txrspflit_retyack_s1.tagop    = '0;
        txrspflit_retyack_s1.tracetag = qos_txrsp_retryack_tracetag_s1;
    end

    always_comb begin
        //PCrdGrant wrap
        txrspflit_pcrdgnt_s2.qos      = qos_txrsp_pcrdgnt_qos_s2;
        txrspflit_pcrdgnt_s2.tgtid    = qos_txrsp_pcrdgnt_tgtid_s2;
        txrspflit_pcrdgnt_s2.srcid    = HNF_NID_PARAM;
        txrspflit_pcrdgnt_s2.txnid    = '0;
        txrspflit_pcrdgnt_s2.opcode   = chie_pkg::RSP_PCRDGRANT;
        txrspflit_pcrdgnt_s2.resperr  = chie_pkg::RESP_ERR_NORM_OK;
        txrspflit_pcrdgnt_s2.resp     = chie_pkg::RESP_I;
        txrspflit_pcrdgnt_s2.fwdstate = '0;
        txrspflit_pcrdgnt_s2.cbusy    = '0;
        txrspflit_pcrdgnt_s2.dbid     = '0;
        txrspflit_pcrdgnt_s2.pcrdtype = qos_txrsp_pcrdgnt_pcrdtype_s2;
        txrspflit_pcrdgnt_s2.tagop    = '0;
        txrspflit_pcrdgnt_s2.tracetag = '0;
    end

    always_comb begin
        //MSHR txrspflit wrap
        txrspflit_mshr_sx1.qos        = mshr_txrsp_qos_sx1;
        txrspflit_mshr_sx1.tgtid      = mshr_txrsp_tgtid_sx1;
        txrspflit_mshr_sx1.srcid      = HNF_NID_PARAM;
        txrspflit_mshr_sx1.txnid      = mshr_txrsp_txnid_sx1_q;
        txrspflit_mshr_sx1.opcode     = mshr_txrsp_opcode_sx1;
        txrspflit_mshr_sx1.resperr    = mshr_txrsp_resperr_sx1;
        txrspflit_mshr_sx1.resp       = mshr_txrsp_resp_sx1;
        txrspflit_mshr_sx1.fwdstate   = '0;
        txrspflit_mshr_sx1.cbusy      = '0;
        txrspflit_mshr_sx1.dbid       = mshr_txrsp_dbid_sx1;
        txrspflit_mshr_sx1.pcrdtype   = '0;
        txrspflit_mshr_sx1.tagop      = '0;
        txrspflit_mshr_sx1.tracetag   = mshr_txrsp_tracetag_sx1;
    end

    assign txrspflit_s0 = ({chie_pkg::RSP_FLIT_WIDTH{txrsp_mshr_bypass_won_s1      }} & txrspflit_bypass_s1     ) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_mshr_retryack_won_s1}} & txrspflit_retyack_s1) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_mshr_pcrdgnt_won_s2 }} & txrspflit_pcrdgnt_s2) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_mshr_won_sx1        }} & txrspflit_mshr_sx1  ) ;

    assign rsp_crd_cnt_s1          = txrsp_crd_cnt_q;
    assign txrspflitv_s0           = txrsp_req_s0 & ~txrsp_busy_sx;
    assign txrsp_crd_cnt_dec_sx    = txrspflitv_s0 & txrsp_crd_avail_s1 | txrsp_lcrd_rtn_sx;
    assign txrsp_lcrd_rtn_sx  = lcrd_return_en & rsp_crd_cnt_not_zero_sx;
    assign txrsp_flit_avail   = txrsp_req_s0;

    assign txrspflitpend = 1'b1;

    //txrspflit sending logic
    always_ff @(posedge clk or posedge rst) begin: txrspflit_logic_t
        if(rst == 1'b1)begin
            txrspflit <= '0;
            txrspflitv <= 1'b0;
        end
        else if(txrsp_lcrd_rtn_sx == 1'b1)begin
            txrspflit  <= '0;
            txrspflitv <= 1'b1;
        end
        else if((txrspflitv_s0 == 1'b1) & (txrsp_crd_avail_s1 == 1'b1))begin
            txrspflit <= txrspflit_s0;
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
        unique case({txrsp_crd_cnt_inc_sx, txrsp_crd_cnt_dec_sx})
            2'b00:
                rsp_crd_cnt_ns_s0   = txrsp_crd_cnt_q;     // hold
            2'b01:
                rsp_crd_cnt_ns_s0   = rsp_crd_cnt_dec_s0;  // dec
            2'b10:
                rsp_crd_cnt_ns_s0   = rsp_crd_cnt_inc_s0;  // inc
            2'b11:
                rsp_crd_cnt_ns_s0   = txrsp_crd_cnt_q;     // hold
            default:
                rsp_crd_cnt_ns_s0 = {`HNF_LCRD_RSP_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin: txrsp_crd_cnt_q_logic_t
        if (rst == 1'b1)
            txrsp_crd_cnt_q <= {`HNF_LCRD_RSP_CNT_WIDTH{1'b0}};
        else if (update_rsp_crd_cnt_s0 == 1'b1)
            txrsp_crd_cnt_q <= rsp_crd_cnt_ns_s0;
    end

    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(txrspflitv)begin
            `display_info($sformatf("HNF TXRSP send a flit\n tgtid: %h\n opcode: %h\n txnid: %h\n resperr: %h\n dbid: %h\n Time: %0d\n",txrspflit.tgtid,txrspflit.opcode,txrspflit.txnid,txrspflit.resperr,txrspflit.dbid,$time()));
        end
    end
`endif
endmodule
