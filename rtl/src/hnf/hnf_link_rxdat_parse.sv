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

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_rxdat_parse `HNF_PARAM
    (
    //global inputs
    input  wire                            clk,
    input  wire                            rst,

    //inputs from hnf_link
    input  wire                            rxdatflitv,
    input  chie_pkg::dat_flit_s            rxdatflit,
    input  wire                            rxdatflitpend,
    // CHI E.b Table 14-2 (p.14-450, MUST): the Receiver "must assert LINKACTIVEACK
    // and move to the RUN state before sending credits".
    input  wire                            rxcrd_en,
    output wire                            rxdat_crd_cnt_full,

    //outputs to hnf_link
    output wire                            rxdat_lcrdv,

    //outputs to hnf_mshr
    output wire                            li_mshr_rxdat_valid_s0,
    output wire [11:0]                     li_mshr_rxdat_txnid_s0,
    output chie_pkg::dat_opcode_e          li_mshr_rxdat_opcode_s0,
    output chie_pkg::resp_state_e          li_mshr_rxdat_resp_s0,
    output chie_pkg::resp_err_e            li_mshr_rxdat_resperr_s0,
    output wire [3:0]                      li_mshr_rxdat_fwdstate_s0,
    output wire [1:0]                      li_mshr_rxdat_dataid_s0,

    //outputs to hnf_data_buffer
    output wire                            li_dbf_rxdat_valid_s0,
    output wire [`MSHR_ENTRIES_WIDTH-1:0]  li_dbf_rxdat_txnid_s0,
    output chie_pkg::dat_opcode_e          li_dbf_rxdat_opcode_s0,
    output wire [1:0]                      li_dbf_rxdat_dataid_s0,
    output wire [chie_pkg::BE_WIDTH-1:0]   li_dbf_rxdat_be_s0,
    output wire [chie_pkg::DATA_WIDTH-1:0] li_dbf_rxdat_data_s0
    );

    //internal reg signals
    logic                               rxdatflitv_en_q;
    logic [`HNF_LCRD_DAT_CNT_WIDTH-1:0] rxdat_crd_cnt_s1_q;
    logic                               rxdatcrdv_s1_q;

    //internal wire signals
    wire [11:0]                         li_dbf_rxdat_txnid_s0_raw;
    wire                                rxdat_crd_cnt_zero;
    wire                                rxdat_crd_cnt_upd_s0;
    wire                                rxdat_crd_grant_s0;
    wire [`HNF_LCRD_DAT_CNT_WIDTH-1:0]  rxdat_crd_cnt_nxt_s0;
    wire                                rxdatcrdv_ns_s0;
    wire                                rxdat_link_flit_s0;

    //main function
    always_ff @(posedge clk or posedge rst) begin:rxdatflitv_en_q_logic_t
        if(rst == 1'b1)
            rxdatflitv_en_q <= 1'b0;
        else if(rxdatflitpend == 1'b1)
            rxdatflitv_en_q <= 1'b1;
        else
            rxdatflitv_en_q <= 1'b0;
    end

    //rxdat decode
    // CHI E.b Sec 13.11 (p.13-442): "A link flit is identified by a zero value in
    // the Opcode field." It carries no data, only the L-Credit it returns, so the
    // credit accounting below is the only thing that may see it.
    assign rxdat_link_flit_s0        = (rxdatflitv == 1'b1) &&
                                       (rxdatflit.opcode == chie_pkg::DAT_DATLCRDRETURN);
    assign li_mshr_rxdat_valid_s0    = (rxdatflitv == 1'b1) && !rxdat_link_flit_s0;
    assign li_mshr_rxdat_txnid_s0    = li_mshr_rxdat_valid_s0? rxdatflit.txnid    : '0;
    assign li_mshr_rxdat_opcode_s0   = li_mshr_rxdat_valid_s0? rxdatflit.opcode   : chie_pkg::DAT_DATLCRDRETURN;
    assign li_mshr_rxdat_resp_s0     = li_mshr_rxdat_valid_s0? rxdatflit.resp     : chie_pkg::RESP_I;
    assign li_mshr_rxdat_resperr_s0  = li_mshr_rxdat_valid_s0? rxdatflit.resperr  : chie_pkg::RESP_ERR_NORM_OK;
    assign li_mshr_rxdat_fwdstate_s0 = li_mshr_rxdat_valid_s0? rxdatflit.datasource.fwdstate : '0;
    assign li_mshr_rxdat_dataid_s0   = li_mshr_rxdat_valid_s0? rxdatflit.dataid   : '0;

    assign li_dbf_rxdat_valid_s0     = li_mshr_rxdat_valid_s0;
    assign li_dbf_rxdat_txnid_s0_raw = li_mshr_rxdat_valid_s0? rxdatflit.txnid    : '0;
    assign li_dbf_rxdat_txnid_s0     = li_dbf_rxdat_txnid_s0_raw[`MSHR_ENTRIES_WIDTH-1:0];
    assign li_dbf_rxdat_opcode_s0    = (li_mshr_rxdat_valid_s0 && ((|rxdatflit.be) || (rxdatflit.opcode == chie_pkg::DAT_COMPDATA)))? rxdatflit.opcode :chie_pkg::DAT_WRITEDATACANCEL;
    assign li_dbf_rxdat_dataid_s0    = li_mshr_rxdat_valid_s0? rxdatflit.dataid   : '0;
    assign li_dbf_rxdat_be_s0        = li_mshr_rxdat_valid_s0? rxdatflit.be       : '0;
    assign li_dbf_rxdat_data_s0      = li_mshr_rxdat_valid_s0? rxdatflit.data     : '0;

    //if lcrd is zero
    assign rxdat_crd_cnt_zero = (rxdat_crd_cnt_s1_q == {`HNF_LCRD_DAT_CNT_WIDTH{1'b0}});

    // A credit returned in the cycle the pool reads empty is re-granted at once.
    // Returns are counted even when rxcrd_en is low, or the pool could never
    // refill for a re-activation after a DEACTIVATE.
    assign rxdat_crd_grant_s0   = rxcrd_en & ((~rxdat_crd_cnt_zero) | rxdatflitv);
    assign rxdatcrdv_ns_s0      = rxdat_crd_grant_s0;
    assign rxdat_crd_cnt_upd_s0 = rxdat_crd_grant_s0 | rxdatflitv;
    assign rxdat_crd_cnt_nxt_s0 = rxdat_crd_cnt_s1_q - {{(`HNF_LCRD_DAT_CNT_WIDTH-1){1'b0}}, rxdat_crd_grant_s0} + {{(`HNF_LCRD_DAT_CNT_WIDTH-1){1'b0}}, rxdatflitv};
    assign rxdat_crd_cnt_full   = (rxdat_crd_cnt_s1_q == XP_LCRD_NUM_PARAM[`HNF_LCRD_DAT_CNT_WIDTH-1:0]);

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
    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(rxdatflitv)begin
            `display_info($sformatf("HNF RXDAT received a flit\n opcode: %h\n srcid: %h\n txnid: %h\n resp: %h\n fwdstate: %h\n dataid: %h\n be: %h\n data: %h\n Time: %0d\n",li_mshr_rxdat_opcode_s0,rxdatflit.srcid,li_mshr_rxdat_txnid_s0,li_mshr_rxdat_resp_s0,li_mshr_rxdat_fwdstate_s0,li_mshr_rxdat_dataid_s0,li_dbf_rxdat_be_s0,li_dbf_rxdat_data_s0,$time()));
        end
    end
`endif
    //-----------------------------------------------------------------------------
    // DISPLAY FATAL
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_FATAL
    always_comb begin
        `display_fatal( (!li_mshr_rxdat_valid_s0) || (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_DATLCRDRETURN)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATA)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_COPYBACKWRDATA)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_COMPDATA)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATAFWDED)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_WRITEDATACANCEL)||(li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK),$sformatf("Fatal info: RXDAT received a unsupported flit with opcode: %h",li_mshr_rxdat_opcode_s0));
    end
`endif

endmodule
