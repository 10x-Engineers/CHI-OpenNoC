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

`include "axi4_defines.svh"
`include "snf_defines.svh"
`include "snf_param.svh"

module snf_rxdat `SNF_PARAM
    (
        //global inputs
        input  wire                  clk,
        input  wire                  rst,
        input  wire                  run_state,

        //inputs from snf_link
        input  wire                  rxdatflitv,
        input  chie_pkg::dat_flit_s  rxdatflit,
        input  wire                  rxdatflitpend,

        //outputs to snf_link
        output wire                  rxdat_lcrdv,

        //outputs to snf_data_buffer
        output wire                  rxdat_valid_s0,
        output chie_pkg::dat_flit_s  rxdatflit_s0
    );

    //internal reg signals
    logic                                             rxdatflitv_en_q;
    logic  [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]            rxdat_crd_cnt_s1_q;
    logic                                             rxdatcrdv_s1_q;

    //internal wire signals
    wire                                            snf_rxcrd_enable_s0;
    wire                                            rxdat_crd_cnt_zero;
    wire [`SNF_LL_DAT_CRD_CNT_RANGE]                rxdat_crd_cnt_nxt_s0;
    wire                                            rxdatcrdv_ns_s0;
    wire                                            rxdat_link_flit_s0;

    //main function
    always_ff @(posedge clk or posedge rst) begin:rxdatflitv_en_q_logic_t
        if(rst == 1'b1)
            rxdatflitv_en_q <= 1'b0;
        else if(rxdatflitpend == 1'b1)
            rxdatflitv_en_q <= 1'b1;
        else
            rxdatflitv_en_q <= 1'b0;
    end

    // to dbf
    // CHI E.b Sec 13.11: "A link flit is identified by a zero value in the Opcode
    // field." It carries no write data -- only the L-Credit it returns -- so it is
    // dropped here and only the credit accounting below sees it.
    assign rxdat_link_flit_s0 = (rxdatflitv == 1'b1) &&
           (rxdatflit.opcode == chie_pkg::DAT_DATLCRDRETURN);
    assign rxdat_valid_s0  = (rxdatflitv == 1'b1) && !rxdat_link_flit_s0;
    assign rxdatflit_s0    = (rxdat_valid_s0 == 1'b1)? rxdatflit : '0;

    // The Receiver's pool of L-Credits not yet granted to the peer.
    //   into the pool  : an arriving flit hands back the credit it was sent under;
    //   out of the pool: only in RUN -- CHI E.b Table 14-2 (p.14-450, MUST) has the
    //     Receiver send no credits in STOP/ACTIVATE and stop sending them in
    //     DEACTIVATE, which is precisely when the peer returns its own.
    // The returns are counted in every state: Table 14-2 has the Transmitter return
    // every held L-Credit while the link sits in DEACTIVATE, so a pool that ignored
    // them would come back from STOP empty and never grant again.
    assign snf_rxcrd_enable_s0 = run_state;
    assign rxdat_crd_cnt_zero  = (rxdat_crd_cnt_s1_q == {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}});

    assign rxdatcrdv_ns_s0     = snf_rxcrd_enable_s0 & (~rxdat_crd_cnt_zero | rxdatflitv);

    assign rxdat_crd_cnt_nxt_s0 = rxdat_crd_cnt_s1_q
                                + {{(`SNF_LL_DAT_CRD_CNT_WIDTH-1){1'b0}}, rxdatflitv}
                                - {{(`SNF_LL_DAT_CRD_CNT_WIDTH-1){1'b0}}, rxdatcrdv_ns_s0};

    always_ff @(posedge clk or posedge rst) begin: rxdat_crd_cnt_s1_q_logic_t
        if (rst == 1'b1)
            rxdat_crd_cnt_s1_q <= XP_LCRD_NUM_PARAM;
        else
            rxdat_crd_cnt_s1_q <= rxdat_crd_cnt_nxt_s0;
    end

    always_ff @(posedge clk or posedge rst) begin: rxdatcrdv_s1_q_logic_t
        if (rst == 1'b1)
            rxdatcrdv_s1_q <= 1'b0;
        else
            rxdatcrdv_s1_q <= rxdatcrdv_ns_s0;
    end

    assign rxdat_lcrdv = rxdatcrdv_s1_q;

endmodule
