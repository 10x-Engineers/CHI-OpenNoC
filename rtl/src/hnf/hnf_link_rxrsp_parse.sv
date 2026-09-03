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
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*/

`include "chie_defines.svh"
`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_rxrsp_parse `HNF_PARAM
    (
        //global inputs
        clk,
        rst,

        //inputs from hnf_link
        rxrspflitv,
        rxrspflit,
        rxrspflitpend,
        rxcrd_en,
        rxrsp_crd_cnt_full,

        //outputs to hnf_link
        rxrsp_lcrdv,

        //outputs to hnf_mshr
        li_mshr_rxrsp_valid_s0,
        li_mshr_rxrsp_srcid_s0,
        li_mshr_rxrsp_txnid_s0,
        li_mshr_rxrsp_opcode_s0,
        li_mshr_rxrsp_resp_s0,
        li_mshr_rxrsp_resperr_s0,
        li_mshr_rxrsp_fwdstate_s0,
        li_mshr_rxrsp_dbid_s0,
        li_mshr_rxrsp_pcrdtype_s0
    );

    //global inputs
    input wire                                      clk;
    input wire                                      rst;

    //inputs from hnf_link
    input wire                                      rxrspflitv;
    input wire [`CHIE_RSP_FLIT_RANGE]               rxrspflit;
    input wire                                      rxrspflitpend;
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input wire                                      rxcrd_en;
    output wire                                     rxrsp_crd_cnt_full;

    //outputs to hnf_link
    output wire                                     rxrsp_lcrdv;

    //outputs to hnf_mshr
    output wire                                     li_mshr_rxrsp_valid_s0;
    output wire [`CHIE_RSP_FLIT_SRCID_WIDTH-1:0]    li_mshr_rxrsp_srcid_s0;
    output wire [`CHIE_RSP_FLIT_TXNID_WIDTH-1:0]    li_mshr_rxrsp_txnid_s0;
    output wire [`CHIE_RSP_FLIT_OPCODE_WIDTH-1:0]   li_mshr_rxrsp_opcode_s0;
    output wire [`CHIE_RSP_FLIT_RESP_WIDTH-1:0]     li_mshr_rxrsp_resp_s0;
    output wire [`CHIE_RSP_FLIT_RESPERR_WIDTH-1:0]  li_mshr_rxrsp_resperr_s0;
    output wire [`CHIE_RSP_FLIT_FWDSTATE_WIDTH-1:0] li_mshr_rxrsp_fwdstate_s0;
    output wire [`CHIE_RSP_FLIT_DBID_WIDTH-1:0]     li_mshr_rxrsp_dbid_s0;
    output wire [`CHIE_RSP_FLIT_PCRDTYPE_WIDTH-1:0] li_mshr_rxrsp_pcrdtype_s0;

    //internal reg signals
    logic                                             rxrspflitv_en_q;
    logic  [`HNF_LCRD_RSP_CNT_WIDTH-1:0]            rxrsp_crd_cnt_s1_q;
    logic                                             rxrspcrdv_s1_q;

    //internal wire signals
    wire                                            rxrsp_crd_cnt_zero;
    wire                                            rxrsp_crd_cnt_upd_s0;
    wire                                            rxrsp_crd_grant_s0;
    wire [`HNF_LCRD_RSP_CNT_RANGE]                rxrsp_crd_cnt_nxt_s0;
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

    //rxrsp decode
    assign li_mshr_rxrsp_valid_s0      = (rxrspflitv == 1'b1);
    assign li_mshr_rxrsp_srcid_s0      = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_SRCID_RANGE]     :{`CHIE_RSP_FLIT_SRCID_WIDTH{1'b0}};
    assign li_mshr_rxrsp_txnid_s0      = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_TXNID_RANGE]     :{`CHIE_RSP_FLIT_TXNID_WIDTH{1'b0}};
    assign li_mshr_rxrsp_opcode_s0     = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_OPCODE_RANGE]    :{`CHIE_RSP_FLIT_OPCODE_WIDTH{1'b0}};
    assign li_mshr_rxrsp_resp_s0       = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_RESP_RANGE]      :{`CHIE_RSP_FLIT_RESP_WIDTH{1'b0}};
    assign li_mshr_rxrsp_resperr_s0    = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_RESPERR_RANGE]   :{`CHIE_RSP_FLIT_RESPERR_WIDTH{1'b0}};
    assign li_mshr_rxrsp_fwdstate_s0   = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_FWDSTATE_RANGE]  :{`CHIE_RSP_FLIT_FWDSTATE_WIDTH{1'b0}};
    assign li_mshr_rxrsp_dbid_s0       = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_DBID_RANGE]      :{`CHIE_RSP_FLIT_DBID_WIDTH{1'b0}};
    assign li_mshr_rxrsp_pcrdtype_s0   = (rxrspflitv == 1'b1)? rxrspflit[`CHIE_RSP_FLIT_PCRDTYPE_RANGE]  :{`CHIE_RSP_FLIT_PCRDTYPE_WIDTH{1'b0}};

    //if lcrd is zero
    assign rxrsp_crd_cnt_zero = (rxrsp_crd_cnt_s1_q == {`HNF_LCRD_RSP_CNT_WIDTH{1'b0}});

    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxrsp_crd_grant_s0   = rxcrd_en & ((~rxrsp_crd_cnt_zero) | li_mshr_rxrsp_valid_s0);
    assign rxrspcrdv_ns_s0      = rxrsp_crd_grant_s0;
    assign rxrsp_crd_cnt_upd_s0 = rxrsp_crd_grant_s0 | li_mshr_rxrsp_valid_s0;
    assign rxrsp_crd_cnt_nxt_s0 = rxrsp_crd_cnt_s1_q - rxrsp_crd_grant_s0 + li_mshr_rxrsp_valid_s0;
    assign rxrsp_crd_cnt_full   = (rxrsp_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNF_LCRD_RSP_CNT_WIDTH-1:0]);

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
    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(rxrspflitv)begin
            `display_info($sformatf("HNF RXRSP received a flit\n opcode: %h\n srcid: %h\n txnid: %h\n resp: %h\n fwdstate: %h\n dbid: %h\n pcrdtype: %h\n Time: %0d\n",li_mshr_rxrsp_opcode_s0,li_mshr_rxrsp_srcid_s0,li_mshr_rxrsp_txnid_s0,li_mshr_rxrsp_resp_s0,li_mshr_rxrsp_fwdstate_s0,li_mshr_rxrsp_dbid_s0,li_mshr_rxrsp_pcrdtype_s0,$time()));
        end
    end
`endif

    //-----------------------------------------------------------------------------
    // DISPLAY FATAL
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_FATAL
    always_comb begin
        `display_fatal( (!li_mshr_rxrsp_valid_s0) || (li_mshr_rxrsp_opcode_s0 == `CHIE_RSPLCRDRETURN)||(li_mshr_rxrsp_opcode_s0 == `CHIE_SNPRESP)||(li_mshr_rxrsp_opcode_s0 == `CHIE_COMPACK)||(li_mshr_rxrsp_opcode_s0 == `CHIE_RETRYACK)||(li_mshr_rxrsp_opcode_s0 == `CHIE_COMP)||(li_mshr_rxrsp_opcode_s0 == `CHIE_COMPDBIDRESP)||(li_mshr_rxrsp_opcode_s0 == `CHIE_DBIDRESP)||(li_mshr_rxrsp_opcode_s0 == `CHIE_PCRDGRANT)||(li_mshr_rxrsp_opcode_s0 ==  `CHIE_READRECEIPT)||(li_mshr_rxrsp_opcode_s0 == `CHIE_SNPRESPFWDED),$sformatf("Fatal info: RXRSP received a unsupported flit with opcode: %h",li_mshr_rxrsp_opcode_s0));
    end
`endif
endmodule
