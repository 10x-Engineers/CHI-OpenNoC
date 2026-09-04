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

module snf_txdat `SNF_PARAM
    (
        //global inputs
        input  wire                  clk,
        input  wire                  rst,

        //inputs from snf_link
        input  wire                  txdat_lcrdv,
        input  wire                  tx_deactivate,
        input  wire                  txlink_run,

        //inputs from snf_data_buffer
        input  wire                  dbf_txdat_valid_sx,
        input  chie_pkg::dat_flit_s  txdat_flit,

        //outputs to snf_link
        output logic                 txdatflitv,
        output chie_pkg::dat_flit_s  txdatflit,
        output wire                  txdatflitpend,

        //outputs to snf_dbf
        output wire                  txdat_dbf_rdy_s1,
        output wire                  txdat_dbf_won_sx
    );

    //internal reg signals
    logic [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]           txdat_crd_cnt_q;
    logic [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]           dat_crd_cnt_ns_s0;
    logic                                           txdat_dbf_won_q;

    //internal wire signals
    wire                                          dat_crd_cnt_not_zero_sx;
    wire                                          txdat_lcrd_rtn_s0;
    wire                                          txdat_crd_avail_s1;
    wire                                          txdatcrdv_s0;
    wire                                          txdat_crd_cnt_inc_sx;
    wire                                          txdat_crd_cnt_dec_sx;
    wire                                          update_dat_crd_cnt_s0;
    wire [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]          dat_crd_cnt_s1;
    wire                                          txdat_send_ok_sx;
    wire [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]          dat_crd_cnt_inc_s0;
    wire [`SNF_LL_DAT_CRD_CNT_WIDTH-1:0]          dat_crd_cnt_dec_s0;

    //main function
    assign dat_crd_cnt_not_zero_sx = (txdat_crd_cnt_q != {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}});
    // Sec 14.2.1 (p.14-445, MUST): "An L-Credit cannot be used in the cycle it is
    // received." txdat_crd_cnt_q already folds this cycle's grant in for the next
    // one, so the counted credits are the whole of what is spendable.
    assign txdat_crd_avail_s1      = dat_crd_cnt_not_zero_sx;
    // Table 14-3 (p.14-451, MUST): the Transmitter "must not send flits" in STOP
    // or ACTIVATE. Holding a credit is not that gate -- Sec 14.6.3 (p.14-459) has
    // the peer's ack legally in flight while it is already granting, so the link
    // state this node has itself observed is what a Protocol flit waits on. The
    // L-Credit return below is deliberately outside it: Table 14-2 DEACTIVATE
    // requires those flits in a state that is not RUN.
    assign txdat_send_ok_sx        = txdat_crd_avail_s1 & txlink_run;

    assign txdatcrdv_s0            = txdat_lcrdv;
    assign txdat_crd_cnt_inc_sx    = txdatcrdv_s0;

    assign dat_crd_cnt_s1          = txdat_crd_cnt_q;
    // CHI E.b Table 14-2 DEACTIVATE (p.14-450, MUST): "The Transmitter must return
    // credits using Protocol flits or L-Credit return flits", and Sec 14.6.3
    // (p.14-458): "A link must remain in the DEACTIVATE state until all L-Credits
    // are returned." A Protocol flit still wins the cycle.
    assign txdat_lcrd_rtn_s0       = tx_deactivate & (~dbf_txdat_valid_sx) & txdat_crd_avail_s1;

    assign txdat_crd_cnt_dec_sx    = (dbf_txdat_valid_sx & txdat_send_ok_sx) | txdat_lcrd_rtn_s0;
    assign txdatflitpend = 1'b1;
    assign txdat_dbf_rdy_s1 = txdat_send_ok_sx;

    //txdatflit sending logic
    always_ff @(posedge clk or posedge rst) begin: txdatflit_logic_t
        if(rst == 1'b1)begin
            txdatflit  <= '0;
            txdatflitv <= 1'b0;
        end
        else if((txdat_send_ok_sx == 1'b1) && (dbf_txdat_valid_sx == 1'b1))begin
            txdatflit  <= txdat_flit;
            txdatflitv <= 1'b1;
        end
        else if(txdat_lcrd_rtn_s0 == 1'b1)begin
            //DataLCrdReturn: opcode 0 with every other field zero (Table 13-21)
            txdatflit  <= '0;
            txdatflitv <= 1'b1;
        end
        else begin
            txdatflit  <= '0;
            txdatflitv <= 1'b0;
        end
    end

    assign txdat_dbf_won_sx        = dbf_txdat_valid_sx & txdat_send_ok_sx;

    //L-credit logic
    assign update_dat_crd_cnt_s0   = txdat_crd_cnt_inc_sx | txdat_crd_cnt_dec_sx;
    assign dat_crd_cnt_inc_s0      = (dat_crd_cnt_s1 + 1'b1);
    assign dat_crd_cnt_dec_s0      = (dat_crd_cnt_s1 - 1'b1);

    always_comb begin: dat_crd_cnt_ns_s0_logic_c
        casez({txdat_crd_cnt_inc_sx, txdat_crd_cnt_dec_sx})
            2'b00:
                dat_crd_cnt_ns_s0 = txdat_crd_cnt_q;     // hold
            2'b01:
                dat_crd_cnt_ns_s0 = dat_crd_cnt_dec_s0;  // dec
            2'b10:
                dat_crd_cnt_ns_s0 = dat_crd_cnt_inc_s0;  // inc
            2'b11:
                dat_crd_cnt_ns_s0 = txdat_crd_cnt_q;     // hold
            default:
                dat_crd_cnt_ns_s0 = {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            txdat_crd_cnt_q <= {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}};
        else if (update_dat_crd_cnt_s0 == 1'b1)
            txdat_crd_cnt_q <= dat_crd_cnt_ns_s0;
    end

endmodule
