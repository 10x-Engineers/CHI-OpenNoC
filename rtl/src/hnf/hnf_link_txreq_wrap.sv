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
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_txreq_wrap `HNF_PARAM
    (
    //global inputs
    input  wire                                clk,
    input  wire                                rst,

    //inputs from hnf_link
    input  wire                                txreq_lcrdv,
    input  wire                                lcrd_return_en,
    input  wire                                txlink_run,
    output wire                                txreq_flit_avail,

    //inputs from hnf_mshr_bypass
    input  wire                                mshr_txreq_bypass_valid_s1,
    input  wire [3:0]                          mshr_txreq_bypass_qos_s1,
    input  wire [11:0]                         mshr_txreq_bypass_txnid_s1,
    input  wire [chie_pkg::NID_WIDTH-1:0]      mshr_txreq_bypass_returnnid_s1,
    input  wire [12-1:0]                       mshr_txreq_bypass_returntxnid_s1,
    input  chie_pkg::req_opcode_e              mshr_txreq_bypass_opcode_s1,
    input  chie_pkg::size_e                    mshr_txreq_bypass_size_s1,
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:0] mshr_txreq_bypass_addr_s1,
    input  wire                                mshr_txreq_bypass_ns_s1,
    input  wire                                mshr_txreq_bypass_allowretry_s1,
    input  chie_pkg::order_e                   mshr_txreq_bypass_order_s1,
    input  wire [3:0]                          mshr_txreq_bypass_pcrdtype_s1,
    input  chie_pkg::memattr_s                 mshr_txreq_bypass_memattr_s1,
    input  wire                                mshr_txreq_bypass_dodwt_s1,
    input  wire                                mshr_txreq_bypass_tracetag_s1,

    //inputs from hnf_mshr_ctl
    input  wire                                mshr_txreq_valid_sx1_q,
    input  wire [3:0]                          mshr_txreq_qos_sx1,
    input  wire [11:0]                         mshr_txreq_txnid_sx1_q,
    input  wire [chie_pkg::NID_WIDTH-1:0]      mshr_txreq_returnnid_sx1,
    input  wire [12-1:0]                       mshr_txreq_returntxnid_sx1,
    input  chie_pkg::req_opcode_e              mshr_txreq_opcode_sx1,
    input  chie_pkg::size_e                    mshr_txreq_size_sx1,
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:0] mshr_txreq_addr_sx1,
    input  wire                                mshr_txreq_ns_sx1,
    input  wire                                mshr_txreq_allowretry_sx1,
    input  chie_pkg::order_e                   mshr_txreq_order_sx1,
    input  wire [3:0]                          mshr_txreq_pcrdtype_sx1,
    input  chie_pkg::memattr_s                 mshr_txreq_memattr_sx1,
    input  wire                                mshr_txreq_dodwt_sx1,
    input  wire                                mshr_txreq_tracetag_sx1,

    //outputs to hnf_link
    output logic                               txreqflitv,
    output chie_pkg::req_flit_s                txreqflit,
    output wire                                txreqflitpend,

    //outputs to hnf_mshr_ctl
    output wire                                txreq_mshr_won_sx1,

    //outputs to hnf_mshr_bypass
    output wire                                txreq_mshr_bypass_won_s1
    );

    //internal reg signals
    logic [`HNF_LCRD_REQ_CNT_WIDTH-1:0] txreq_crd_cnt_q;
    chie_pkg::req_flit_s                txreqflit_bypass_s1;
    chie_pkg::req_flit_s                txreqflit_sx1;
    logic [`HNF_LCRD_REQ_CNT_WIDTH-1:0] req_crd_cnt_ns_s0;

    //internal wire signals
    wire                                req_crd_cnt_not_zero_sx;
    wire                                txreq_crd_avail_s1;
    wire                                txreq_busy_sx;
    wire                                txreqcrdv_s0;
    wire                                txreq_crd_cnt_inc_sx;
    wire                                txreq_req_s0;
    chie_pkg::req_flit_s                txreqflit_s0;
    wire                                txreqflitv_s0;
    wire                                txreq_crd_cnt_dec_sx;
    wire                                update_req_crd_cnt_s0;
    wire [`HNF_LCRD_REQ_CNT_WIDTH-1:0]  req_crd_cnt_s1;
    wire [`HNF_LCRD_REQ_CNT_WIDTH-1:0]  req_crd_cnt_inc_s0;
    wire [`HNF_LCRD_REQ_CNT_WIDTH-1:0]  req_crd_cnt_dec_s0;


    wire                                txreq_lcrd_rtn_sx;
    chie_pkg::memattr_s                 txreq_bypass_memattr_snf_s1;
    chie_pkg::memattr_s                 txreq_memattr_snf_sx1;

    //main function
    // CHI E.b Sec 2.9.3 (p.2-128): MemAttr is preserved on a Home to Subordinate
    // request, the one exception being Device, which "can be set to 0b0" when the
    // downstream memory is known to be Normal. Every request this channel sends is
    // addressed to SNF_NID_PARAM, and Sec 1.6 (p.1-29) makes an SN-F "a Subordinate
    // Node type used for Normal memory" -- so the exception's antecedent always
    // holds here, and Tables 4-2 (p.4-166) and 4-14 (p.4-179) then make taking it
    // mandatory: an ICN(HN-F) to SN-F request has no Device MemAttr row at all
    // (the Device rows are Tables 4-3/4-15, ICN(HN-I) to SN-I).
    // MemAttr[1] is Device (Table 13-19 p.13-429).
    assign txreq_bypass_memattr_snf_s1 = {mshr_txreq_bypass_memattr_s1[3:2], 1'b0,
                                          mshr_txreq_bypass_memattr_s1[0]};
    assign txreq_memattr_snf_sx1       = {mshr_txreq_memattr_sx1[3:2], 1'b0,
                                          mshr_txreq_memattr_sx1[0]};

    assign req_crd_cnt_not_zero_sx = (txreq_crd_cnt_q != 'd0);
    assign txreq_crd_avail_s1      = (txreq_lcrdv | req_crd_cnt_not_zero_sx);
    assign txreq_busy_sx           = ~txreq_crd_avail_s1 | (~txlink_run);

    assign txreq_mshr_bypass_won_s1    = (mshr_txreq_bypass_valid_s1 == 1'b1) && (~txreq_busy_sx);
    assign txreq_mshr_won_sx1      = (mshr_txreq_valid_sx1_q == 1'b1) && (mshr_txreq_bypass_valid_s1 == 1'b0) & ~txreq_busy_sx;
    assign txreqcrdv_s0            = txreq_lcrdv;
    assign txreq_crd_cnt_inc_sx    = txreqcrdv_s0;
    assign txreq_req_s0            = (mshr_txreq_bypass_valid_s1 | mshr_txreq_valid_sx1_q);


    always_comb begin
        txreqflit_bypass_s1.qos          =  mshr_txreq_bypass_qos_s1;
        txreqflit_bypass_s1.tgtid        = SNF_NID_PARAM;
        txreqflit_bypass_s1.srcid        = HNF_NID_PARAM;
        txreqflit_bypass_s1.txnid        =  mshr_txreq_bypass_txnid_s1;
        txreqflit_bypass_s1.returnnid    = mshr_txreq_bypass_returnnid_s1;
        txreqflit_bypass_s1.stashnidvalid.endian       = '0;
        txreqflit_bypass_s1.returntxnid  =  mshr_txreq_bypass_returntxnid_s1;
        txreqflit_bypass_s1.opcode       =  mshr_txreq_bypass_opcode_s1;
        txreqflit_bypass_s1.size         =  mshr_txreq_bypass_size_s1;
        txreqflit_bypass_s1.addr         =  mshr_txreq_bypass_addr_s1;
        txreqflit_bypass_s1.ns           =  mshr_txreq_bypass_ns_s1;
        txreqflit_bypass_s1.likelyshared = '0;
        txreqflit_bypass_s1.allowretry   =  mshr_txreq_bypass_allowretry_s1;
        txreqflit_bypass_s1.order        =  mshr_txreq_bypass_order_s1;
        txreqflit_bypass_s1.pcrdtype     =  mshr_txreq_bypass_pcrdtype_s1;
        txreqflit_bypass_s1.memattr      =  txreq_bypass_memattr_snf_s1;
        txreqflit_bypass_s1.snpattr.dodwt        =  mshr_txreq_bypass_dodwt_s1;
        txreqflit_bypass_s1.lpid         = '0;
        txreqflit_bypass_s1.excl         = '0;
        txreqflit_bypass_s1.expcompack   = '0;
        txreqflit_bypass_s1.tagop        = '0;
        txreqflit_bypass_s1.tracetag     =  mshr_txreq_bypass_tracetag_s1;
    end

    always_comb begin
        txreqflit_sx1.qos            = mshr_txreq_qos_sx1;
        txreqflit_sx1.tgtid          = SNF_NID_PARAM;
        txreqflit_sx1.srcid          = HNF_NID_PARAM;
        txreqflit_sx1.txnid          = mshr_txreq_txnid_sx1_q;
        txreqflit_sx1.returnnid      = mshr_txreq_returnnid_sx1;
        txreqflit_sx1.stashnidvalid.endian         = '0;
        txreqflit_sx1.returntxnid    = mshr_txreq_returntxnid_sx1;
        txreqflit_sx1.opcode         = mshr_txreq_opcode_sx1;
        txreqflit_sx1.size           = mshr_txreq_size_sx1;
        txreqflit_sx1.addr           = mshr_txreq_addr_sx1;
        txreqflit_sx1.ns             = mshr_txreq_ns_sx1;
        txreqflit_sx1.likelyshared   = '0;
        txreqflit_sx1.allowretry     = mshr_txreq_allowretry_sx1;
        txreqflit_sx1.order          = mshr_txreq_order_sx1;
        txreqflit_sx1.pcrdtype       = mshr_txreq_pcrdtype_sx1;
        txreqflit_sx1.memattr        = txreq_memattr_snf_sx1;
        txreqflit_sx1.snpattr.dodwt          = mshr_txreq_dodwt_sx1;
        txreqflit_sx1.lpid           = '0;
        txreqflit_sx1.excl           = '0;
        txreqflit_sx1.expcompack     = '0;
        txreqflit_sx1.tagop          = '0;
        txreqflit_sx1.tracetag       = mshr_txreq_tracetag_sx1;
    end

    assign txreqflit_s0 = ({chie_pkg::REQ_FLIT_WIDTH{txreq_mshr_bypass_won_s1}} & txreqflit_bypass_s1) |
           ({chie_pkg::REQ_FLIT_WIDTH{txreq_mshr_won_sx1  }} & txreqflit_sx1  ) ;

    assign req_crd_cnt_s1          = txreq_crd_cnt_q;
    assign txreqflitv_s0           = (txreq_req_s0 & ~txreq_busy_sx);
    assign txreq_crd_cnt_dec_sx    = (txreqflitv_s0 & txreq_crd_avail_s1) | txreq_lcrd_rtn_sx;
    assign txreq_lcrd_rtn_sx  = lcrd_return_en & req_crd_cnt_not_zero_sx;
    assign txreq_flit_avail   = txreq_req_s0;

    assign txreqflitpend = 1'b1;

    //txreqflit sending logic
    always_ff @(posedge clk or posedge rst) begin: txreqflit_logic_t
        if(rst == 1'b1)begin
            txreqflit <= '0;
            txreqflitv <= 1'b0;
        end
        else if(txreq_lcrd_rtn_sx == 1'b1)begin
            txreqflit  <= '0;
            txreqflitv <= 1'b1;
        end
        else if((txreqflitv_s0 == 1'b1) & (txreq_crd_avail_s1 == 1'b1))begin
            txreqflit <= txreqflit_s0;
            txreqflitv <= 1'b1;
        end
        else begin
            txreqflitv <= 1'b0;
        end
    end

    //L-credit logic
    assign update_req_crd_cnt_s0   = txreq_crd_cnt_inc_sx | txreq_crd_cnt_dec_sx;
    assign req_crd_cnt_inc_s0      = (req_crd_cnt_s1 + 1'b1);
    assign req_crd_cnt_dec_s0      = (req_crd_cnt_s1 - 1'b1);

    always_comb begin: req_crd_cnt_ns_s0_logic_c
        unique case({txreq_crd_cnt_inc_sx, txreq_crd_cnt_dec_sx})
            2'b00:
                req_crd_cnt_ns_s0   = txreq_crd_cnt_q;     // hold
            2'b01:
                req_crd_cnt_ns_s0   = req_crd_cnt_dec_s0;  // dec
            2'b10:
                req_crd_cnt_ns_s0   = req_crd_cnt_inc_s0;  // inc
            2'b11:
                req_crd_cnt_ns_s0   = txreq_crd_cnt_q;     // hold
            default:
                req_crd_cnt_ns_s0 = {`HNF_LCRD_REQ_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin: txreq_crd_cnt_q_logic_t
        if (rst == 1'b1)
            txreq_crd_cnt_q <= {`HNF_LCRD_REQ_CNT_WIDTH{1'b0}};
        else if (update_req_crd_cnt_s0 == 1'b1)
            txreq_crd_cnt_q <= req_crd_cnt_ns_s0;
    end
    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(txreqflitv)begin
            `display_info($sformatf("HNF TXREQ send a flit\n tgtid: %h\n opcode: %h\n txnid: %h\n returnnid: %h\n returntxnid: %h\n addr: %h\n allowretry: %h\n Time: %0d\n",txreqflit.tgtid,txreqflit.opcode,txreqflit.txnid,txreqflit.returnnid,txreqflit.returntxnid,txreqflit.addr,txreqflit.allowretry,$time()));
        end
    end
`endif
endmodule
