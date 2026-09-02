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
*    Li Zhao <lizhao@bosc.ac.cn>
*/

`include "chie_defines.v"
`include "hnf_defines.v"
`include "hnf_param.v"

module hnf_link_rxdat_parse `HNF_PARAM
    (
        //global inputs
        clk,
        rst,

        //inputs from hnf_link
        rxdatflitv,
        rxdatflit,
        rxdatflitpend,
        rxcrd_en,
        rxdat_crd_cnt_full,

        //outputs to hnf_link
        rxdat_lcrdv,

        //outputs to hnf_mshr
        li_mshr_rxdat_valid_s0,
        li_mshr_rxdat_txnid_s0,
        li_mshr_rxdat_opcode_s0,
        li_mshr_rxdat_resp_s0,
        li_mshr_rxdat_resperr_s0,
        li_mshr_rxdat_fwdstate_s0,
        li_mshr_rxdat_dataid_s0,

        //outputs to hnf_data_buffer
        li_dbf_rxdat_valid_s0,
        li_dbf_rxdat_txnid_s0,
        li_dbf_rxdat_opcode_s0,
        li_dbf_rxdat_dataid_s0,
        li_dbf_rxdat_be_s0,
        li_dbf_rxdat_data_s0
    );

    //global inputs
    input wire                                      clk;
    input wire                                      rst;

    //inputs from hnf_link
    input wire                                      rxdatflitv;
    input wire [`CHIE_DAT_FLIT_RANGE]               rxdatflit;
    input wire                                      rxdatflitpend;
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input wire                                      rxcrd_en;
    output wire                                     rxdat_crd_cnt_full;

    //outputs to hnf_link
    output wire                                     rxdat_lcrdv;

    //outputs to hnf_mshr
    output wire                                     li_mshr_rxdat_valid_s0;
    output wire [`CHIE_DAT_FLIT_TXNID_WIDTH-1:0]    li_mshr_rxdat_txnid_s0;
    output wire [`CHIE_DAT_FLIT_OPCODE_WIDTH-1:0]   li_mshr_rxdat_opcode_s0;
    output wire [`CHIE_DAT_FLIT_RESP_WIDTH-1:0]     li_mshr_rxdat_resp_s0;
    output wire [`CHIE_DAT_FLIT_RESPERR_WIDTH-1:0]  li_mshr_rxdat_resperr_s0;
    output wire [`CHIE_DAT_FLIT_FWDSTATE_WIDTH-1:0] li_mshr_rxdat_fwdstate_s0;
    output wire [`CHIE_DAT_FLIT_DATAID_WIDTH-1:0]   li_mshr_rxdat_dataid_s0;

    //outputs to hnf_data_buffer
    output wire                                     li_dbf_rxdat_valid_s0;
    output wire [`MSHR_ENTRIES_WIDTH-1:0]           li_dbf_rxdat_txnid_s0;
    output wire [`CHIE_DAT_FLIT_OPCODE_WIDTH-1:0]   li_dbf_rxdat_opcode_s0;
    output wire [`CHIE_DAT_FLIT_DATAID_WIDTH-1:0]   li_dbf_rxdat_dataid_s0;
    output wire [`CHIE_DAT_FLIT_BE_WIDTH-1:0]       li_dbf_rxdat_be_s0;
    output wire [`CHIE_DAT_FLIT_DATA_WIDTH-1:0]     li_dbf_rxdat_data_s0;

    //internal reg signals
    reg                                             rxdatflitv_en_q;
    reg  [`HNF_LCRD_DAT_CNT_WIDTH-1:0]            rxdat_crd_cnt_s1_q;
    reg                                             rxdatcrdv_s1_q;

    //internal wire signals
    wire [`CHIE_DAT_FLIT_TXNID_WIDTH-1:0]           li_dbf_rxdat_txnid_s0_raw;
    wire                                            rxdat_crd_cnt_zero;
    wire                                            rxdat_crd_cnt_upd_s0;
    wire                                            rxdat_crd_grant_s0;
    wire [`HNF_LCRD_DAT_CNT_RANGE]                rxdat_crd_cnt_nxt_s0;
    wire                                            rxdatcrdv_ns_s0;

    //main function
    always @(posedge clk or posedge rst) begin:rxdatflitv_en_q_logic_t
        if(rst == 1'b1)
            rxdatflitv_en_q <= 1'b0;
        else if(rxdatflitpend == 1'b1)
            rxdatflitv_en_q <= 1'b1;
        else
            rxdatflitv_en_q <= 1'b0;
    end

    //rxdat decode
    assign li_mshr_rxdat_valid_s0    = (rxdatflitv == 1'b1);
    assign li_mshr_rxdat_txnid_s0    = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_TXNID_RANGE]    : {`CHIE_DAT_FLIT_TXNID_WIDTH{1'b0}};
    assign li_mshr_rxdat_opcode_s0   = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_OPCODE_RANGE]   : {`CHIE_DAT_FLIT_OPCODE_WIDTH{1'b0}};
    assign li_mshr_rxdat_resp_s0     = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_RESP_RANGE]     : {`CHIE_DAT_FLIT_RESP_WIDTH{1'b0}};
    assign li_mshr_rxdat_resperr_s0  = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_RESPERR_RANGE]  : {`CHIE_DAT_FLIT_RESPERR_WIDTH{1'b0}};
    assign li_mshr_rxdat_fwdstate_s0 = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_FWDSTATE_RANGE] : {`CHIE_DAT_FLIT_FWDSTATE_WIDTH{1'b0}};
    assign li_mshr_rxdat_dataid_s0   = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_DATAID_RANGE]   : {`CHIE_DAT_FLIT_DATAID_WIDTH{1'b0}};

    assign li_dbf_rxdat_valid_s0     = (rxdatflitv == 1'b1);
    assign li_dbf_rxdat_txnid_s0_raw = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_TXNID_RANGE]    : {`CHIE_DAT_FLIT_TXNID_WIDTH{1'b0}};
    assign li_dbf_rxdat_txnid_s0     = li_dbf_rxdat_txnid_s0_raw[`MSHR_ENTRIES_WIDTH-1:0];
    assign li_dbf_rxdat_opcode_s0    = (rxdatflitv == 1'b1 && ((|rxdatflit[`CHIE_DAT_FLIT_BE_RANGE]) || (rxdatflit[`CHIE_DAT_FLIT_OPCODE_RANGE] == `CHIE_COMPDATA)))? rxdatflit[`CHIE_DAT_FLIT_OPCODE_RANGE] :`CHIE_WRITEDATACANCEL;
    assign li_dbf_rxdat_dataid_s0    = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_DATAID_RANGE]   : {`CHIE_DAT_FLIT_DATAID_WIDTH{1'b0}};
    assign li_dbf_rxdat_be_s0        = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_BE_RANGE]       : {`CHIE_DAT_FLIT_BE_WIDTH{1'b0}};
    assign li_dbf_rxdat_data_s0      = (rxdatflitv == 1'b1)? rxdatflit[`CHIE_DAT_FLIT_DATA_RANGE]     : {`CHIE_DAT_FLIT_DATA_WIDTH{1'b0}};

    //if lcrd is zero
    assign rxdat_crd_cnt_zero = (rxdat_crd_cnt_s1_q == {`HNF_LCRD_DAT_CNT_WIDTH{1'b0}});

    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxdat_crd_grant_s0   = rxcrd_en & ((~rxdat_crd_cnt_zero) | li_mshr_rxdat_valid_s0);
    assign rxdatcrdv_ns_s0      = rxdat_crd_grant_s0;
    assign rxdat_crd_cnt_upd_s0 = rxdat_crd_grant_s0 | li_mshr_rxdat_valid_s0;
    assign rxdat_crd_cnt_nxt_s0 = rxdat_crd_cnt_s1_q - rxdat_crd_grant_s0 + li_mshr_rxdat_valid_s0;
    assign rxdat_crd_cnt_full   = (rxdat_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNF_LCRD_DAT_CNT_WIDTH-1:0]);

    always @(posedge clk or posedge rst) begin: rxdat_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxdat_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else if (rxdat_crd_cnt_upd_s0 == 1'b1)
            rxdat_crd_cnt_s1_q <= rxdat_crd_cnt_nxt_s0;
    end

    always @(posedge clk or posedge rst) begin: rxdatcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxdatcrdv_s1_q <= 1'b0;
        else
            rxdatcrdv_s1_q <= rxdatcrdv_ns_s0;
    end

    assign rxdat_lcrdv = rxdatcrdv_s1_q;
    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always@(posedge clk)begin
        if(rxdatflitv)begin
            `display_info($sformatf("HNF RXDAT received a flit\n opcode: %h\n srcid: %h\n txnid: %h\n resp: %h\n fwdstate: %h\n dataid: %h\n be: %h\n data: %h\n Time: %0d\n",li_mshr_rxdat_opcode_s0,rxdatflit[`CHIE_DAT_FLIT_SRCID_RANGE],li_mshr_rxdat_txnid_s0,li_mshr_rxdat_resp_s0,li_mshr_rxdat_fwdstate_s0,li_mshr_rxdat_dataid_s0,li_dbf_rxdat_be_s0,li_dbf_rxdat_data_s0,$time()));
        end
    end
`endif
    //-----------------------------------------------------------------------------
    // DISPLAY FATAL
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_FATAL
    always@(*)begin
        `display_fatal( (!li_mshr_rxdat_valid_s0) || (li_mshr_rxdat_opcode_s0 == `CHIE_DATLCRDRETURN)||(li_mshr_rxdat_opcode_s0 == `CHIE_SNPRESPDATA)||(li_mshr_rxdat_opcode_s0 == `CHIE_COPYBACKWRDATA)||(li_mshr_rxdat_opcode_s0 == `CHIE_NONCOPYBACKWRDATA)||(li_mshr_rxdat_opcode_s0 == `CHIE_COMPDATA)||(li_mshr_rxdat_opcode_s0 == `CHIE_SNPRESPDATAFWDED)||(li_mshr_rxdat_opcode_s0 == `CHIE_WRITEDATACANCEL)||(li_mshr_rxdat_opcode_s0 == `CHIE_NCBWRDATACOMPACK),$sformatf("Fatal info: RXDAT received a unsupported flit with opcode: %h",li_mshr_rxdat_opcode_s0));
    end
`endif

endmodule
