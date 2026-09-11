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
*    Ziqing Li <liziqing@bosc.ac.cn>
*    Wenhao Li <liwenhao@bosc.ac.cn>
*/

`include "rni_param.svh"
`include "rni_defines.svh"
`include "axi4_defines.svh"

module rni_misc `RNI_PARAM
    (
    // global inputs
    input  wire                             clk_i,
    input  wire                             rst_i,

    // rni_link_ctl Interface
    input  wire                             rxrspflitv_d1_i,
    input  chie_pkg::rsp_flit_s             rxrspflit_d1_q_i,

    // rni_aw_ctl Interface
    output wire                             pcrdgnt_pkt_v_d2_o,
    output opennoc_rni_pkg::pcrdgrant_pkt_s pcrdgnt_pkt_d2_o,
    input  wire                             ar_pcrdgnt_l_present_d3_i,
    input  wire                             ar_pcrdgnt_h_present_d3_i,
    input  wire                             aw_pcrdgnt_l_present_d3_i,
    input  wire                             aw_pcrdgnt_h_present_d3_i,
    output wire                             ar_pcrdgnt_l_win_d3_o,
    output wire                             ar_pcrdgnt_h_win_d3_o,
    output wire                             aw_pcrdgnt_l_win_d3_o,
    output wire                             aw_pcrdgnt_h_win_d3_o,

    // "This channel still has an entry allocated", so a RetryAck can still arrive
    // for it -- see pcrd_surplus_w.
    input  wire                             arctrl_entry_any_v_i,
    input  wire                             awctrl_entry_any_v_i,

    // rni_link_ctl Interface -- the PCrdReturn source
    output chie_pkg::req_flit_s             misc_txreqflit_s4_o,
    output wire                             misc_txreqflitv_s4_o,
    input  wire                             misc_txreqflit_sent_s4_i
    );

    //wire
    wire                             pcrdgnt_recv_d1_w;
    wire                             pcrdgnt_claimed_d3_w;
    wire [3:0]                       pcrdgnt_pcrdtype_d1_w;
    wire [`PCRD_TYPE_NUM-1:0]        pcrd_held_vec_w;
    logic [3:0]                      pcrd_nxt_type_r;
    logic [3:0]                      pcrd_cand_r;
    wire                             pcrd_cur_held_w;
    wire                             pcrd_rotate_w;
    wire                             pcrd_settled_w;
    wire                             pcrd_unclaimed_w;
    wire                             pcrd_surplus_w;
    wire                             pcrd_return_sent_w;
    wire                             nxt_h_pcrdgnt_ptr_w;
    wire                             nxt_l_pcrdgnt_ptr_w;
    wire                             l_arb_lost_w;
    wire                             l_disable_h_cnt_inc_w;
    wire                             l_disable_h_cnt_rst_w;
    wire                             l_disable_h_cnt_upd_w;
    wire [`L_DISABLE_CNT_WIDTH-1:0]  nxt_l_disable_h_cnt_w;
    wire                             l_disable_h_w;

    //reg
    logic [`PCRD_CNT_WIDTH-1:0]      pcrd_cnt_q[`PCRD_TYPE_NUM];
    logic [3:0]                      pcrd_cur_type_q;
    logic [1:0]                      pcrd_settle_cnt_q;
    logic                            pcrd_return_v_q;
    logic [3:0]                      pcrd_return_type_q;
    logic                            h_pcrdgnt_ptr_q;
    logic                            l_pcrdgnt_ptr_q;
    logic [`L_DISABLE_CNT_WIDTH-1:0] l_disable_h_cnt_q;

    //local param
    localparam L_DISABLE_H_EN     = 1'b0;

    //main function
    // SS2.11 (p.2-146): "There is no fixed relationship between credits and
    // particular transactions ... The Requester is free to choose the most
    // appropriate transaction from the list of transactions that receives a
    // RetryAck response with that particular Protocol Credit Type." So a held
    // credit is a COUNT PER TYPE, not a queue entry, and the only thing that binds
    // it to a transaction is Table 13-31's (SS13.10.36 p.13-434) PCrdType.
    // Presenting grants in arrival order instead lets one type no entry is waiting
    // for hold up every credit behind it.
    // Only this bridge's own Home can grant it a credit, so the grant's node IDs
    // are checked here rather than carried per credit -- SS2.6.5 (p.2-112) fixes
    // both: "The TgtID is set to the same value as the SrcID of the request. The
    // SrcID is a fixed value for the Completer."
    assign pcrdgnt_recv_d1_w      = rxrspflitv_d1_i & (rxrspflit_d1_q_i.opcode == chie_pkg::RSP_PCRDGRANT)
                                    & (rxrspflit_d1_q_i.srcid == HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0])
                                    & (rxrspflit_d1_q_i.tgtid == RNI_NID_PARAM[chie_pkg::NID_WIDTH-1:0]);
    assign pcrdgnt_pcrdtype_d1_w  = rxrspflit_d1_q_i.pcrdtype;
    assign pcrdgnt_claimed_d3_w   = (ar_pcrdgnt_l_present_d3_i | ar_pcrdgnt_h_present_d3_i | aw_pcrdgnt_l_present_d3_i | aw_pcrdgnt_h_present_d3_i);

    genvar t;
    generate
        for (t = 0; t < `PCRD_TYPE_NUM; t = t + 1) begin: pcrd_pool
            wire inc_w = pcrdgnt_recv_d1_w   & (pcrdgnt_pcrdtype_d1_w  == t[3:0]);
            wire dec_w = (pcrdgnt_claimed_d3_w & (pcrd_cur_type_q    == t[3:0]))
                       | (pcrd_return_sent_w  & (pcrd_return_type_q == t[3:0]));
            assign pcrd_held_vec_w[t] = (pcrd_cnt_q[t] != {`PCRD_CNT_WIDTH{1'b0}});
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)
                    pcrd_cnt_q[t] <= {`PCRD_CNT_WIDTH{1'b0}};
                else if (inc_w ^ dec_w)
                    pcrd_cnt_q[t] <= inc_w ? (pcrd_cnt_q[t] + 1'b1) : (pcrd_cnt_q[t] - 1'b1);
            end
        end
    endgenerate

    // One type is offered to the two channels at a time, because the AR/AW match
    // and its arbitration are a two-stage path (present at d2, win at d3) and need
    // the offer to stand still across it. Rotation is what removes the head-of-line
    // block: a type nobody claims is stepped over, not parked on.
    assign pcrd_cur_held_w = pcrd_held_vec_w[pcrd_cur_type_q];
    assign pcrd_settled_w  = (pcrd_settle_cnt_q == 2'd3);
    assign pcrd_unclaimed_w = pcrd_settled_w & ~pcrdgnt_claimed_d3_w;
    assign pcrd_rotate_w   = ~pcrd_return_v_q &
                             (pcrdgnt_claimed_d3_w | pcrd_return_sent_w |
                              (pcrd_unclaimed_w & ~pcrd_surplus_w) | ~pcrd_cur_held_w);

    // Round-robin over the types that hold a credit. Descending k so the nearest
    // one wins the last assignment; k == PCRD_TYPE_NUM wraps to the current type,
    // which is what keeps a single held type presented.
    always_comb begin: pcrd_nxt_type_sel
        pcrd_nxt_type_r = pcrd_cur_type_q;
        pcrd_cand_r     = pcrd_cur_type_q;
        for (int k = `PCRD_TYPE_NUM; k > 0; k = k - 1) begin
            pcrd_cand_r = pcrd_cur_type_q + k[3:0];
            if (pcrd_held_vec_w[pcrd_cand_r]) pcrd_nxt_type_r = pcrd_cand_r;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            pcrd_cur_type_q <= 4'd0;
        else if (pcrd_rotate_w == 1'b1)
            pcrd_cur_type_q <= pcrd_nxt_type_r;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            pcrd_settle_cnt_q <= 2'd0;
        else if (pcrd_rotate_w | ~pcrd_cur_held_w)
            pcrd_settle_cnt_q <= 2'd0;
        else if (~pcrd_settled_w)
            pcrd_settle_cnt_q <= pcrd_settle_cnt_q + 1'b1;
    end

    assign pcrdgnt_pkt_d2_o   = '{pcrdtype: pcrd_cur_type_q,
                                  srcid   : HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0],
                                  tgtid   : RNI_NID_PARAM[chie_pkg::NID_WIDTH-1:0]};
    assign pcrdgnt_pkt_v_d2_o = pcrd_cur_held_w & ~pcrdgnt_claimed_d3_w & ~pcrd_return_v_q;

    // SS2.11.1 (p.2-147, MUST): "Any credits that are not required must be returned
    // in a timely manner". A credit is surplus once no request of this bridge can
    // still be RetryAck'd -- SS2.11 (p.2-145, MUST) makes the Requester "record the
    // credit it has received, including the credit type, so that it can assign the
    // credit appropriately when it does receive the RetryAck response", so a credit
    // held while an entry is still allocated may yet be the one that entry needs.
    // With no entry allocated there is no outstanding request, so no RetryAck is
    // coming and the whole pool is surplus. SS2.11.1 bounds "timely" with no cycle
    // count, event or transaction count, so quiescence is the first point at which
    // the verdict is unambiguous.
    // pcrd_settled_w also covers the d2->d3 shadow of the AR/AW match: an entry
    // that deallocated in the last two cycles can still be driving a stale
    // present_d3, and a credit must not be both claimed and returned.
    assign pcrd_surplus_w      = pcrd_cur_held_w & pcrd_settled_w & ~pcrdgnt_claimed_d3_w
                                 & ~arctrl_entry_any_v_i & ~awctrl_entry_any_v_i;
    assign pcrd_return_sent_w  = pcrd_return_v_q & misc_txreqflit_sent_s4_i;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            pcrd_return_v_q    <= 1'b0;
            pcrd_return_type_q <= 4'd0;
        end
        else if (pcrd_return_v_q == 1'b0) begin
            pcrd_return_v_q    <= pcrd_surplus_w;
            pcrd_return_type_q <= pcrd_cur_type_q;
        end
        else if (misc_txreqflit_sent_s4_i == 1'b1) begin
            pcrd_return_v_q    <= 1'b0;
        end
    end

    // Table A-2 (p.A-483) leaves a PCrdReturn only QoS, TgtID, SrcID, Opcode,
    // PCrdType, RSVDC and TraceTag applicable; every other field is "0a --
    // Inapplicable. Field value must be set to zero" (Table A-1 p.A-482), which
    // the all-zero default below gives, including SS2.6.6 (p.2-112)'s TxnID and
    // SS13.10.19 (p.13-427)'s Addr.
    always_comb begin: misc_txreqflit_build
        misc_txreqflit_s4_o          = '0;
        misc_txreqflit_s4_o.opcode   = chie_pkg::REQ_PCRDRETURN;
        // SS3.3.1 (p.3-152, MUST): "The target ID provided by the Request Node must
        // match the source ID included in the prior PCrdGrant which provided the
        // credit being returned."
        misc_txreqflit_s4_o.tgtid    = HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0];
        misc_txreqflit_s4_o.srcid    = RNI_NID_PARAM[chie_pkg::NID_WIDTH-1:0];
        // SS2.11.2 (p.2-147, MUST): "A PCrdReturn transaction must have the credit
        // type set to the value of the credit type that is being returned."
        misc_txreqflit_s4_o.pcrdtype = pcrd_return_type_q;
    end

    assign misc_txreqflitv_s4_o = pcrd_return_v_q;

    // ar and aw H arbitration
    assign nxt_h_pcrdgnt_ptr_w = (ar_pcrdgnt_h_present_d3_i & aw_pcrdgnt_h_present_d3_i & (h_pcrdgnt_ptr_q == 1'b0))? 1 : (ar_pcrdgnt_h_present_d3_i & aw_pcrdgnt_h_present_d3_i & (h_pcrdgnt_ptr_q == 1'b1))? 0 : h_pcrdgnt_ptr_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            h_pcrdgnt_ptr_q <= 1'b0;
        else
            h_pcrdgnt_ptr_q <= nxt_h_pcrdgnt_ptr_w;
    end

    assign ar_pcrdgnt_h_win_d3_o = ~l_disable_h_w & ar_pcrdgnt_h_present_d3_i & (~aw_pcrdgnt_h_present_d3_i | (h_pcrdgnt_ptr_q == 1'b0));
    assign aw_pcrdgnt_h_win_d3_o = ~l_disable_h_w & aw_pcrdgnt_h_present_d3_i & (~ar_pcrdgnt_h_present_d3_i | (h_pcrdgnt_ptr_q == 1'b1));

    // ar and aw L arbitration
    assign nxt_l_pcrdgnt_ptr_w = (ar_pcrdgnt_l_present_d3_i & aw_pcrdgnt_l_present_d3_i & (l_pcrdgnt_ptr_q == 1'b0))? 1 : (ar_pcrdgnt_l_present_d3_i & aw_pcrdgnt_l_present_d3_i & (l_pcrdgnt_ptr_q == 1'b1))? 0 : l_pcrdgnt_ptr_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            l_pcrdgnt_ptr_q <= 1'b0;
        else
            l_pcrdgnt_ptr_q <= nxt_l_pcrdgnt_ptr_w;
    end

    assign ar_pcrdgnt_l_win_d3_o = ar_pcrdgnt_l_present_d3_i & ~ar_pcrdgnt_h_win_d3_o & ~aw_pcrdgnt_h_win_d3_o & (~aw_pcrdgnt_l_present_d3_i | (l_pcrdgnt_ptr_q == 1'b0));
    assign aw_pcrdgnt_l_win_d3_o = aw_pcrdgnt_l_present_d3_i & ~ar_pcrdgnt_h_win_d3_o & ~aw_pcrdgnt_h_win_d3_o & (~ar_pcrdgnt_l_present_d3_i | (l_pcrdgnt_ptr_q == 1'b1));

    assign l_arb_lost_w = (ar_pcrdgnt_l_present_d3_i | aw_pcrdgnt_l_present_d3_i) & ~(ar_pcrdgnt_l_win_d3_o | aw_pcrdgnt_l_win_d3_o);

    assign l_disable_h_cnt_inc_w = l_arb_lost_w;
    assign l_disable_h_cnt_rst_w = (ar_pcrdgnt_l_win_d3_o | aw_pcrdgnt_l_win_d3_o);
    assign l_disable_h_cnt_upd_w = (l_disable_h_cnt_inc_w | l_disable_h_cnt_rst_w);
    assign nxt_l_disable_h_cnt_w = l_disable_h_cnt_inc_w? (l_disable_h_cnt_q + 1'b1) : {`L_DISABLE_CNT_WIDTH{1'b0}};

    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i == 1'b1)
            l_disable_h_cnt_q <= {`L_DISABLE_CNT_WIDTH{1'b0}};
        else if(l_disable_h_cnt_upd_w == 1'b1)
            l_disable_h_cnt_q <= nxt_l_disable_h_cnt_w;
    end

    assign l_disable_h_w = (l_disable_h_cnt_q == `L_DISABLE_H_MAX_VAL) & (ar_pcrdgnt_l_present_d3_i | aw_pcrdgnt_l_present_d3_i) & L_DISABLE_H_EN;

endmodule
