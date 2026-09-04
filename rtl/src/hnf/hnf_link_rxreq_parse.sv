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
*    Qichao Xie <xieqichao@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_rxreq_parse `HNF_PARAM
    (
    //global inputs
    input wire clk,
    input wire rst,

    //inputs from link
    input wire rxreqflitv,
    input chie_pkg::req_flit_s rxreqflit,
    input wire rxreqflitpend,
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input wire rxcrd_en,
    output wire rxreq_crd_cnt_full,

    //inputs from hnf_cache_pipeline
    input wire biq_req_valid_s0_q,
    input wire [chie_pkg::REQ_ADDR_WIDTH-1:0] biq_req_addr_s0_q,

    //inputs from hnf_mshr_qos
    input wire qos_seq_pool_full_s0_q,
    input wire rxreq_retry_enable_s0,

    //inputs from hnf_link_txrsp_wrap
    input wire txrsp_mshr_retryack_won_s1,

    //outputs to link
    output wire rxreq_lcrdv,

    //outputs to hnf_mshr
    output wire li_mshr_rxreq_valid_s0,
    output wire [3:0] li_mshr_rxreq_qos_s0,
    output wire [chie_pkg::NID_WIDTH-1:0] li_mshr_rxreq_srcid_s0,
    output wire [11:0] li_mshr_rxreq_txnid_s0,
    output chie_pkg::req_opcode_e li_mshr_rxreq_opcode_s0,
    output chie_pkg::size_e li_mshr_rxreq_size_s0,
    output wire [chie_pkg::REQ_ADDR_WIDTH-1:0] li_mshr_rxreq_addr_s0,
    output wire li_mshr_rxreq_ns_s0,
    output wire li_mshr_rxreq_allowretry_s0,
    output chie_pkg::order_e li_mshr_rxreq_order_s0,
    output wire [3:0] li_mshr_rxreq_pcrdtype_s0,
    output chie_pkg::memattr_s li_mshr_rxreq_memattr_s0,
    output wire [7:0] li_mshr_rxreq_lpid_s0,
    output wire li_mshr_rxreq_excl_s0,
    output wire li_mshr_rxreq_expcompack_s0,
    output wire li_mshr_rxreq_tracetag_s0
    );

    //internal reg signals
    logic                                             rxreqflitv_en_q;
    logic [`HNF_LCRD_REQ_CNT_RANGE]                 rxreq_crd_cnt_s1_q;
    logic                                             rxreqcrdv_s1_q;

    //internal wire signals
    wire                                            rxreq_crd_grant_sx;
    wire [1:0]                                      rxreq_crd_rtn_sx;
    wire                                            rxreq_crd_cnt_zero_sx;
    wire                                            li_req_crd_rtn_s0;
    wire                                            li_retack_tx_s1;
    wire                                            rxreq_crd_cnt_upd_s1;
    wire                                            rxreqcrdv_ns_s0;
    wire [`HNF_LCRD_REQ_CNT_RANGE]                rxreq_crd_cnt_nxt_s1;

    //main function

    //link_rxreq_parse awake
    always_ff @(posedge clk or posedge rst)begin : rxreqflitv_en_q_logic_t
        if(rst == 1'b1)
            rxreqflitv_en_q <= 1'b0;
        else if (rxreqflitpend == 1'b1)
            rxreqflitv_en_q <= 1'b1;
        else
            rxreqflitv_en_q <= 1'b0;
    end

    //rxreqflit decode
    assign li_mshr_rxreq_valid_s0      = (rxreqflitv == 1'b1) || (biq_req_valid_s0_q == 1'b1 && qos_seq_pool_full_s0_q == 1'b0);

    assign li_mshr_rxreq_qos_s0        = (rxreqflitv == 1'b1)? rxreqflit.qos       :'0;
    assign li_mshr_rxreq_srcid_s0      = (rxreqflitv == 1'b1)? rxreqflit.srcid     :'0;
    assign li_mshr_rxreq_txnid_s0      = (rxreqflitv == 1'b1)? rxreqflit.txnid     :'0;
    assign li_mshr_rxreq_opcode_s0     = (rxreqflitv == 1'b1)? rxreqflit.opcode    :(biq_req_valid_s0_q == 1'b1 && qos_seq_pool_full_s0_q == 1'b0) ? chie_pkg::REQ_SNOOPFILTEREVICT : chie_pkg::REQ_REQLCRDRETURN;
    assign li_mshr_rxreq_size_s0       = (rxreqflitv == 1'b1)? rxreqflit.size      :chie_pkg::SIZE_1B;

    assign li_mshr_rxreq_addr_s0       = (rxreqflitv == 1'b1)? rxreqflit.addr      :
           (biq_req_valid_s0_q == 1'b1 && qos_seq_pool_full_s0_q == 1'b0)? biq_req_addr_s0_q:'0;

    assign li_mshr_rxreq_ns_s0         = (rxreqflitv == 1'b1)? rxreqflit.ns        :'0;
    assign li_mshr_rxreq_allowretry_s0 = (rxreqflitv == 1'b1)? rxreqflit.allowretry:(biq_req_valid_s0_q == 1'b1 && qos_seq_pool_full_s0_q == 1'b0) ? {1{1'b1}} : '0;
    assign li_mshr_rxreq_order_s0      = (rxreqflitv == 1'b1)? rxreqflit.order     :chie_pkg::ORDER_NONE;
    assign li_mshr_rxreq_pcrdtype_s0   = (rxreqflitv == 1'b1)? rxreqflit.pcrdtype  :'0;
    assign li_mshr_rxreq_memattr_s0    = (rxreqflitv == 1'b1)? rxreqflit.memattr   :'0;
    assign li_mshr_rxreq_lpid_s0       = (rxreqflitv == 1'b1)? rxreqflit.lpid      :'0;
    assign li_mshr_rxreq_excl_s0       = (rxreqflitv == 1'b1)? rxreqflit.excl      :'0;
    assign li_mshr_rxreq_expcompack_s0 = (rxreqflitv == 1'b1)? rxreqflit.expcompack:'0;
    assign li_mshr_rxreq_tracetag_s0   = (rxreqflitv == 1'b1)? rxreqflit.tracetag  :'0;

    //rxreq L-credit
    assign li_req_crd_rtn_s0 = !rxreq_retry_enable_s0 && rxreqflitv == 1'b1;

    //retry transaction sent
    assign li_retack_tx_s1 = txrsp_mshr_retryack_won_s1;

    assign rxreq_crd_cnt_zero_sx = (rxreq_crd_cnt_s1_q == {`HNF_LCRD_REQ_CNT_WIDTH{1'b0}});
    assign rxreq_crd_rtn_sx      = {1'b0, li_req_crd_rtn_s0} + {1'b0, li_retack_tx_s1};
    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxreq_crd_grant_sx    = rxcrd_en & ((~rxreq_crd_cnt_zero_sx) | (|rxreq_crd_rtn_sx));
    assign rxreqcrdv_ns_s0       = rxreq_crd_grant_sx;
    assign rxreq_crd_cnt_upd_s1  = rxreq_crd_grant_sx | (|rxreq_crd_rtn_sx);
    assign rxreq_crd_cnt_nxt_s1  = rxreq_crd_cnt_s1_q - {{(`HNF_LCRD_REQ_CNT_WIDTH-1){1'b0}}, rxreq_crd_grant_sx}
                                                     + {{(`HNF_LCRD_REQ_CNT_WIDTH-2){1'b0}}, rxreq_crd_rtn_sx};
    assign rxreq_crd_cnt_full    = (rxreq_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNF_LCRD_REQ_CNT_WIDTH-1:0]);


    always_ff @(posedge clk or posedge rst) begin: rxreq_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxreq_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else if (rxreq_crd_cnt_upd_s1 == 1'b1)
            rxreq_crd_cnt_s1_q <= rxreq_crd_cnt_nxt_s1;
    end

    always_ff @(posedge clk or posedge rst) begin: rxreqcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxreqcrdv_s1_q <= 1'b0;
        else
            rxreqcrdv_s1_q <= rxreqcrdv_ns_s0;
    end

    assign rxreq_lcrdv = rxreqcrdv_s1_q;
    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO

    always_ff @(posedge clk)begin
        if(rxreqflitv)begin
            `display_info($sformatf("HNF RXREQ received a flit\n opcode: %h\n srcid: %h\n txnid: %h\n size: %h\n addr: %h\n allowretry: %h\n order: %h\n memattr: %h\n lpid: %h\n excl: %h\n expcompack: %h\n Time: %0d\n",li_mshr_rxreq_opcode_s0,li_mshr_rxreq_srcid_s0,li_mshr_rxreq_txnid_s0,li_mshr_rxreq_size_s0,li_mshr_rxreq_addr_s0,li_mshr_rxreq_allowretry_s0,li_mshr_rxreq_order_s0,li_mshr_rxreq_memattr_s0,li_mshr_rxreq_lpid_s0,li_mshr_rxreq_excl_s0,li_mshr_rxreq_expcompack_s0,$time()));
        end
    end
`endif

    //-----------------------------------------------------------------------------
    // DISPLAY FATAL
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_FATAL
    // hnf_mshr_ctl classifies every admitted opcode and answers an unserviced one
    // with Sec 9.1's (p.9-334) NDERR, which is what Sec 4.5.1 (p.4-197, MUST)
    // requires of every transaction but PCrdReturn and PrefetchTgt -- so the only
    // opcode this rejects is the link flit, which FLITV must never carry
    // (Sec 13.11 p.13-442).
    always_comb begin
        `display_fatal( (!((rxreqflitv == 1'b1))) || (rxreqflit.opcode != chie_pkg::REQ_REQLCRDRETURN),$sformatf("Fatal info: RXREQ received a link flit with FLITV asserted, opcode: %h",rxreqflit.opcode));
    end
`endif
endmodule
