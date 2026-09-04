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

`include "axi4_defines.svh"
`include "hni_defines.svh"
`include "hni_param.svh"

module hni_txrsp `HNI_PARAM
    (
    //global inputs
    input  wire                               clk,
    input  wire                               rst,

    //inputs from hni_link
    input  wire                               txrsp_lcrdv,
    // CHI E.b Table 14-2's DEACTIVATE row (p.14-450, MUST): "The Transmitter must
    // return credits using Protocol flits or L-Credit return flits" -- an all-zero
    // flit, whose Opcode field is that channel's LCrdReturn (SS13.11 p.13-442).
    input  wire                               lcrd_return_en,
    // Table 14-3 (p.14-451, MUST): no flit is sent outside the RUN state.
    input  wire                               txlink_run,
    // Table 14-2's STOP row (p.14-450, MUST): the Transmitter "must assert
    // LINKACTIVEREQ to move to the ACTIVATE state if it has flits to send".
    output wire                               txrsp_flit_avail,

    //inputs from hni_qos
    input  wire                               rxreq_alloc_en_s0,
    input  chie_pkg::req_flit_s               rxreq_alloc_flit_s0,
    input  wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s0,

    input  wire                               qos_txrsp_retryack_valid_s1,
    input  chie_pkg::retry_ackq_s             qos_txrsp_retryack_fifo_s1,

    input  wire                               qos_txrsp_pcrdgnt_valid_s2,
    input  chie_pkg::pcrdgrantq_s             qos_txrsp_pcrdgnt_fifo_s2,

    //inputs from hni_mshr
    input  wire                               mshr_entry_sleep_s1,  //endpoint hazard
    input  wire                               txrsp_valid_sx_q,
    input  wire [3:0]                         txrsp_qos_sx,
    input  wire [chie_pkg::NID_WIDTH-1:0]     txrsp_tgtid_sx,
    input  wire [11:0]                        txrsp_txnid_sx,
    input  chie_pkg::rsp_opcode_e             txrsp_opcode_sx,
    input  chie_pkg::resp_err_e               txrsp_resperr_sx,
    input  chie_pkg::resp_state_e             txrsp_resp_sx,
    input  wire [11:0]                        txrsp_dbid_sx,
    input  wire                               txrsp_tracetag_sx,

    //inputs from hni_global_monitor
    input  wire                               excl_pass_s1,

    //outputs to hni_link
    output logic                              txrspflitv,
    output chie_pkg::rsp_flit_s               txrspflit,
    output wire                               txrspflitpend,

    //outputs to hni_qos
    output wire                               txrsp_retryack_won_s1,
    output wire                               txrsp_pcrdgnt_won_s2,

    //outputs to hni_mshr
    output wire                               txrsp_won_sx,
    output wire                               txrsp_fp_won_s1
    );

    //internal reg signals
    logic [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0] txrsp_crd_cnt_q;

    logic [3:0]                           rxreq_qos_s1_q;
    logic [chie_pkg::NID_WIDTH-1:0]       rxreq_srcid_s1_q;
    logic [11:0]                          rxreq_txnid_s1_q;
    logic                                 rxreq_excl_s1_q;
    logic                                 rxreq_tracetag_s1_q;
    logic                                 rd_receipt_s1_q;
    logic                                 wr_grant_s1_q;
    logic                                 wr_ewa_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]   mshr_entry_idx_alloc_s1_q;
    chie_pkg::rsp_flit_s                  txrspflit_fp_s1;
    chie_pkg::rsp_flit_s                  txrspflit_retyack_s1;
    chie_pkg::rsp_flit_s                  txrspflit_pcrdgnt_s2;
    chie_pkg::rsp_flit_s                  txrspflit_mshr_sx1;
    logic [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0] rsp_crd_cnt_ns_s0;

    //internal wire signals
    wire [3:0]                            rxreq_qos_s0;
    wire [chie_pkg::NID_WIDTH-1:0]        rxreq_srcid_s0;
    wire [11:0]                           rxreq_txnid_s0;
    chie_pkg::req_opcode_e                rxreq_opcode_s0;
    chie_pkg::order_e                     rxreq_order_s0;
    wire                                  rxreq_excl_s0;
    wire                                  rxreq_tracetag_s0;
    wire                                  req_wrnosnp_s0;
    wire                                  rd_receipt_s0;
    wire                                  wr_grant_s0;
    wire                                  rxreq_ewa_s0;

    wire                                  txrsp_fp_valid_s1;
    wire [3:0]                            txrsp_fp_qos_s1;
    wire [chie_pkg::NID_WIDTH-1:0]        txrsp_fp_tgtid_s1;
    wire [11:0]                           txrsp_fp_txnid_s1;
    chie_pkg::rsp_opcode_e                txrsp_fp_opcode_s1;
    chie_pkg::resp_err_e                  txrsp_fp_resperr_s1;
    wire [11:0]                           txrsp_fp_dbid_s1;
    wire                                  txrsp_fp_tracetag_s1;

    wire                                  txrsp_crd_avail_s1;
    wire                                  txrsp_busy_sx;
    wire                                  txrspcrdv_s0;
    wire                                  txrsp_req_s0;
    wire                                  txrspflitv_s0;
    chie_pkg::rsp_flit_s                  txrspflit_s0;
    wire [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0]  rsp_crd_cnt_s1;
    wire [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0]  rsp_crd_cnt_inc_s0;
    wire [`HNI_LL_RSP_CRD_CNT_WIDTH-1:0]  rsp_crd_cnt_dec_s0;
    wire                                  update_rsp_crd_cnt_s0;
    wire                                  txrsp_crd_cnt_inc_sx;
    wire                                  txrsp_crd_cnt_dec_sx;
    wire                                  txrsp_lcrd_rtn_sx;
    wire                                  rsp_crd_cnt_not_zero_sx;

    //main function

    //arb and lcrd_avail

    assign rsp_crd_cnt_not_zero_sx     = (txrsp_crd_cnt_q != 0);

    // just received it or not zero

    assign txrsp_crd_avail_s1          = (txrsp_lcrdv | rsp_crd_cnt_not_zero_sx);
    assign txrsp_busy_sx               = ~txrsp_crd_avail_s1 | (~txlink_run);

    //req decode
    assign rxreq_qos_s0        = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.qos        : '0;     
    assign rxreq_srcid_s0      = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.srcid      : '0;   
    assign rxreq_txnid_s0      = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.txnid      : '0;   
    assign rxreq_opcode_s0     = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.opcode     : chie_pkg::REQ_REQLCRDRETURN;    
    assign rxreq_order_s0      = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.order      : chie_pkg::ORDER_NONE;   
    assign rxreq_excl_s0       = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.excl       : '0;    
    assign rxreq_tracetag_s0   = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.tracetag   : '0; 
    assign rxreq_ewa_s0        = (rxreq_alloc_en_s0 == 1'b1) ? rxreq_alloc_flit_s0.memattr.early_wr_ack : '0;

    assign req_wrnosnp_s0        = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULL) || (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTL);

    //fp readreceipt
    assign rd_receipt_s0        = (rxreq_opcode_s0 == chie_pkg::REQ_READNOSNP)&&(rxreq_order_s0 != 2'b0)&&rxreq_alloc_en_s0;

    //fp write grant
    // Sec 2.9.3 (p.2-126): a write completion may come "from an intermediate point
    // in the interconnect, such as a Home Node" only with EWA asserted, so the
    // combined CompDBIDResp grant is elected on EWA alone -- the same election
    // hni_mshr makes for the entry that does not take this path.
    assign wr_grant_s0          = req_wrnosnp_s0 && rxreq_alloc_en_s0;

    //fp s1 stage
    always_ff @(posedge clk or posedge rst)begin :pass_qos
        if(rst)
            rxreq_qos_s1_q <= '0;
        else
            rxreq_qos_s1_q <= rxreq_qos_s0;
    end
    always_ff @(posedge clk or posedge rst)begin :pass_srcid
        if(rst)
            rxreq_srcid_s1_q <= '0;
        else
            rxreq_srcid_s1_q <= rxreq_srcid_s0;
    end

    always_ff @(posedge clk or posedge rst)begin :pass_txnid
        if(rst)
            rxreq_txnid_s1_q <= '0;
        else
            rxreq_txnid_s1_q <= rxreq_txnid_s0;
    end

    always_ff @(posedge clk or posedge rst)begin :pass_excl
        if(rst)
            rxreq_excl_s1_q <= '0;
        else
            rxreq_excl_s1_q <= rxreq_excl_s0;
    end

    always_ff @(posedge clk or posedge rst)begin :pass_tracetag
        if (rst)
            rxreq_tracetag_s1_q <= '0;
        else
            rxreq_tracetag_s1_q <= rxreq_tracetag_s0;
    end

    always_ff @(posedge clk or posedge rst)begin :pass_rd_receipt
        if (rst)
            rd_receipt_s1_q <= 1'b0;
        else
            rd_receipt_s1_q <= rd_receipt_s0;
    end

    always_ff @(posedge clk or posedge rst) begin:pass_wr_grant
        if (rst)
            wr_grant_s1_q <= 1'b0;
        else
            wr_grant_s1_q <= wr_grant_s0;
    end

    always_ff @(posedge clk or posedge rst) begin:pass_wr_ewa
        if (rst)
            wr_ewa_s1_q <= 1'b0;
        else
            wr_ewa_s1_q <= rxreq_ewa_s0;
    end

    always_ff @(posedge clk or posedge rst) begin:pass_alloc_entry_idx
        if (rst)
            mshr_entry_idx_alloc_s1_q <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        else
            mshr_entry_idx_alloc_s1_q <= mshr_entry_idx_alloc_s0;
    end

    //fp output
    assign txrsp_fp_valid_s1    = (rd_receipt_s1_q||wr_grant_s1_q) && (~mshr_entry_sleep_s1);
    assign txrsp_fp_qos_s1      = rxreq_qos_s1_q;
    assign txrsp_fp_tgtid_s1    = rxreq_srcid_s1_q;
    assign txrsp_fp_txnid_s1    = rxreq_txnid_s1_q;
    assign txrsp_fp_opcode_s1   = rd_receipt_s1_q?chie_pkg::RSP_READRECEIPT:
                                  wr_grant_s1_q?(wr_ewa_s1_q?chie_pkg::RSP_COMPDBIDRESP
                                                            :chie_pkg::RSP_DBIDRESP)
                                               :chie_pkg::RSP_RSPLCRDRETURN;
    assign txrsp_fp_resperr_s1  = (wr_grant_s1_q&&wr_ewa_s1_q&&rxreq_excl_s1_q&&excl_pass_s1)? chie_pkg::RESP_ERR_EX_OK : chie_pkg::RESP_ERR_NORM_OK;
    assign txrsp_fp_dbid_s1     = {{(12-`HNI_MSHR_ENTRIES_WIDTH){1'b0}}, mshr_entry_idx_alloc_s1_q};
    assign txrsp_fp_tracetag_s1 = rxreq_tracetag_s1_q;

    //output to mshr
    assign txrsp_fp_won_s1       = txrsp_fp_valid_s1 &
           ~txrsp_busy_sx;

    //output to qos
    assign txrsp_retryack_won_s1 = (qos_txrsp_retryack_valid_s1) &
           (~txrsp_fp_valid_s1) &
           ~txrsp_busy_sx;

    assign txrsp_pcrdgnt_won_s2  = (qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           (~txrsp_fp_valid_s1) &
           ~txrsp_busy_sx;

    //output to mshr
    assign txrsp_won_sx         = (txrsp_valid_sx_q) &
           (~qos_txrsp_pcrdgnt_valid_s2) &
           (~qos_txrsp_retryack_valid_s1) &
           (~txrsp_fp_valid_s1) &
           ~txrsp_busy_sx;

    assign txrspcrdv_s0               = txrsp_lcrdv;
    assign txrsp_crd_cnt_inc_sx       = txrspcrdv_s0;
    assign txrsp_req_s0               = (txrsp_fp_valid_s1           |
                                         qos_txrsp_retryack_valid_s1 |
                                         qos_txrsp_pcrdgnt_valid_s2  |
                                         txrsp_valid_sx_q);

    //arbitration

    always_comb begin
        //FastPath wrap
        txrspflit_fp_s1.qos           = txrsp_fp_qos_s1;
        txrspflit_fp_s1.tgtid         = txrsp_fp_tgtid_s1;
        txrspflit_fp_s1.srcid         = `HNI0_ID;
        txrspflit_fp_s1.txnid         = txrsp_fp_txnid_s1;
        txrspflit_fp_s1.opcode        = txrsp_fp_opcode_s1;
        txrspflit_fp_s1.resperr       = txrsp_fp_resperr_s1;
        txrspflit_fp_s1.resp          = chie_pkg::RESP_I;
        txrspflit_fp_s1.fwdstate      = '0;
        txrspflit_fp_s1.cbusy         = '0;
        txrspflit_fp_s1.dbid          = txrsp_fp_dbid_s1;
        txrspflit_fp_s1.pcrdtype      = '0;
        txrspflit_fp_s1.tagop         = '0;
        txrspflit_fp_s1.tracetag      = txrsp_fp_tracetag_s1;
    end
    always_comb begin
        //RetryAck wrap
        txrspflit_retyack_s1.qos      = qos_txrsp_retryack_fifo_s1.qos;
        txrspflit_retyack_s1.tgtid    = qos_txrsp_retryack_fifo_s1.srcid;
        txrspflit_retyack_s1.srcid    = `HNI0_ID;
        txrspflit_retyack_s1.txnid    = qos_txrsp_retryack_fifo_s1.txnid;
        txrspflit_retyack_s1.opcode   = chie_pkg::RSP_RETRYACK;
        txrspflit_retyack_s1.resperr  = chie_pkg::RESP_ERR_NORM_OK;
        txrspflit_retyack_s1.resp     = chie_pkg::RESP_I;
        txrspflit_retyack_s1.fwdstate = '0;
        txrspflit_retyack_s1.cbusy    = '0;
        txrspflit_retyack_s1.dbid     = '0;
        txrspflit_retyack_s1.pcrdtype = qos_txrsp_retryack_fifo_s1.pcrdtype;
        txrspflit_retyack_s1.tagop    = '0;
        txrspflit_retyack_s1.tracetag = qos_txrsp_retryack_fifo_s1.trace;
    end

    always_comb begin
        //PCrdGrant wrap
        txrspflit_pcrdgnt_s2.qos      = qos_txrsp_pcrdgnt_fifo_s2.qos;
        txrspflit_pcrdgnt_s2.tgtid    = qos_txrsp_pcrdgnt_fifo_s2.srcid;
        txrspflit_pcrdgnt_s2.srcid    = `HNI0_ID;
        txrspflit_pcrdgnt_s2.txnid    = '0;
        txrspflit_pcrdgnt_s2.opcode   = chie_pkg::RSP_PCRDGRANT;
        txrspflit_pcrdgnt_s2.resperr  = chie_pkg::RESP_ERR_NORM_OK;
        txrspflit_pcrdgnt_s2.resp     = chie_pkg::RESP_I;
        txrspflit_pcrdgnt_s2.fwdstate = '0;
        txrspflit_pcrdgnt_s2.cbusy    = '0;
        txrspflit_pcrdgnt_s2.dbid     = '0;
        txrspflit_pcrdgnt_s2.pcrdtype = qos_txrsp_pcrdgnt_fifo_s2.pcrdtype;
        txrspflit_pcrdgnt_s2.tagop    = '0;
        txrspflit_pcrdgnt_s2.tracetag = '0;
    end

    always_comb begin
        //MSHR txrspflit wrap
        txrspflit_mshr_sx1.qos        = txrsp_qos_sx;
        txrspflit_mshr_sx1.tgtid      = txrsp_tgtid_sx;
        txrspflit_mshr_sx1.srcid      = `HNI0_ID;
        txrspflit_mshr_sx1.txnid      = txrsp_txnid_sx;
        txrspflit_mshr_sx1.opcode     = txrsp_opcode_sx;
        txrspflit_mshr_sx1.resperr    = txrsp_resperr_sx;
        txrspflit_mshr_sx1.resp       = txrsp_resp_sx;
        txrspflit_mshr_sx1.fwdstate   = '0;
        txrspflit_mshr_sx1.cbusy      = '0;
        txrspflit_mshr_sx1.dbid       = txrsp_dbid_sx;
        txrspflit_mshr_sx1.pcrdtype   = '0;
        txrspflit_mshr_sx1.tagop      = '0;
        txrspflit_mshr_sx1.tracetag   = txrsp_tracetag_sx;
    end

    assign txrspflit_s0 = ({chie_pkg::RSP_FLIT_WIDTH{txrsp_fp_won_s1      }} & txrspflit_fp_s1     ) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_retryack_won_s1}} & txrspflit_retyack_s1) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_pcrdgnt_won_s2 }} & txrspflit_pcrdgnt_s2) |
           ({chie_pkg::RSP_FLIT_WIDTH{txrsp_won_sx        }} & txrspflit_mshr_sx1  ) ;

    assign rsp_crd_cnt_s1          = txrsp_crd_cnt_q;
    assign txrspflitv_s0           = txrsp_req_s0 & (~txrsp_busy_sx);
    assign txrsp_lcrd_rtn_sx       = lcrd_return_en & rsp_crd_cnt_not_zero_sx;
    assign txrsp_crd_cnt_dec_sx    = (txrspflitv_s0 & txrsp_crd_avail_s1) | txrsp_lcrd_rtn_sx; //lcrd - 1
    assign txrsp_flit_avail        = txrsp_req_s0;

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
                rsp_crd_cnt_ns_s0 = {`HNI_LL_RSP_CRD_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin: txrsp_crd_cnt_q_logic_t
        if (rst == 1'b1)
            txrsp_crd_cnt_q <= {`HNI_LL_RSP_CRD_CNT_WIDTH{1'b0}};
        else if (update_rsp_crd_cnt_s0 == 1'b1)
            txrsp_crd_cnt_q <= rsp_crd_cnt_ns_s0;
    end

endmodule
