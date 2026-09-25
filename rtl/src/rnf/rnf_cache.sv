/*
* Copyright (c) 2026 10xEngineers
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*/

`include "rnf_param.svh"
`include "rnf_defines.svh"

// The RN-F's coherent cache: SS4.1's (p.4-160) seven states, with the tag and
// data a line needs, and in meta_q its four Allocation Tags with their Clean or
// Dirty state (SS12.3 p.12-374). Capacity, associativity and replacement are
// SS4.6's (p.4-209) IMPLEMENTATION DEFINED axes and are declared as parameters;
// the 64-byte line is not, SS2.10.1 (p.2-134) fixes it.
//
// Replacement is round-robin per set -- one of SS4.6's permitted choices, and
// the one whose victim is a function of the set alone, so a fill never has to
// wait on a policy update.
module rnf_cache `RNF_PARAM
    (
    input  wire                                clk_i,
    input  wire                                rst_i,

    // Lookup, combinational in the access cycle.
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] lu_addr_i,
    output wire                                lu_hit_o,
    output wire [`RNF_CS_WIDTH-1:0]            lu_state_o,
    output wire [`RNF_WAY_W-1:0]               lu_way_o,
    output wire [`RNF_LINE_BITS-1:0]           lu_data_o,
    output wire [`RNF_META_W-1:0]             lu_meta_o,

    // Snoop lookup -- an independent read port, so a snoop is never queued behind
    // the core's own access.
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_addr_i,
    output wire                                snp_hit_o,
    output wire [`RNF_CS_WIDTH-1:0]            snp_state_o,
    output wire [`RNF_WAY_W-1:0]               snp_way_o,
    output wire [`RNF_LINE_BITS-1:0]           snp_data_o,
    output wire [`RNF_META_W-1:0]             snp_meta_o,
    // The way a fill of the snoop's line would take and what it holds: a Data
    // Pull (SS7.1.1 p.7-295) allocates there.
    output wire [`RNF_WAY_W-1:0]               snp_vic_way_o,
    output wire [`RNF_CS_WIDTH-1:0]            snp_vic_state_o,

    // The way a fill for this address would take, and what it would displace.
    // vic_data_o is what a CopyBack of a Dirty victim sends.
    output wire [`RNF_WAY_W-1:0]               vic_way_o,
    output wire [`RNF_CS_WIDTH-1:0]            vic_state_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] vic_addr_o,
    output wire [`RNF_LINE_BITS-1:0]           vic_data_o,
    output wire [`RNF_META_W-1:0]             vic_meta_o,

    // The first resident line, for the flush a Requester owes before it leaves
    // coherency: Table 15-1 (p.15-468) allows no coherent data in Disconnect.
    output wire                                any_valid_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] flush_addr_o,
    output wire [`RNF_WAY_W-1:0]               flush_way_o,
    output wire [`RNF_CS_WIDTH-1:0]            flush_state_o,
    output wire [`RNF_LINE_BITS-1:0]           flush_data_o,
    output wire [`RNF_META_W-1:0]             flush_meta_o,

    // Fill: install a line in a state, with its data and what is known about it
    // (rnf_defines.svh's RNF_META), which SS9.4.7 (p.9-345, MUST), SS9.4.3
    // (p.9-340, MUST) and SS9.5 (p.9-347, MUST) carry wherever the bytes are sent.
    input  wire                                fill_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] fill_addr_i,
    input  wire [`RNF_WAY_W-1:0]               fill_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]            fill_state_i,
    input  wire [`RNF_LINE_BITS-1:0]           fill_data_i,
    input  wire [`RNF_META_W-1:0]             fill_meta_i,

    // State-only update of a resident line (a snoop, or a silent transition).
    input  wire                                upd_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] upd_addr_i,
    input  wire [`RNF_WAY_W-1:0]               upd_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]            upd_state_i,

    // A second state-only port, for the core side. The two cannot be muxed: a
    // snoop retiring one line and a CopyBack invalidating another in the same
    // cycle are both real, and dropping either leaves the cache claiming a state
    // the node no longer holds.
    input  wire                                upd2_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] upd2_addr_i,
    input  wire [`RNF_WAY_W-1:0]               upd2_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]            upd2_state_i
    );

    localparam int SETS = RNF_CACHE_SETS_PARAM;
    localparam int WAYS = RNF_CACHE_WAYS_PARAM;

    logic [`RNF_TAG_W-1:0]    tag_q   [SETS][WAYS];
    logic [`RNF_CS_WIDTH-1:0] state_q [SETS][WAYS];
    logic [`RNF_LINE_BITS-1:0] data_q [SETS][WAYS];
    logic [`RNF_META_W-1:0]    meta_q [SETS][WAYS];
    logic [`RNF_WAY_W-1:0]    rr_q    [SETS];

    wire [`RNF_SET_W-1:0] lu_set = lu_addr_i[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    wire [`RNF_TAG_W-1:0] lu_tag = lu_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1 -: `RNF_TAG_W];

    logic                    hit_c;
    logic [`RNF_WAY_W-1:0]   hit_way_c;

    always_comb begin
        hit_c     = 1'b0;
        hit_way_c = '0;
        for (int w = 0; w < WAYS; w++) begin
            if ((state_q[lu_set][w] != `RNF_CS_I) && (tag_q[lu_set][w] == lu_tag)) begin
                hit_c     = 1'b1;
                hit_way_c = `RNF_WAY_W'(w);
            end
        end
    end

    assign lu_hit_o   = hit_c;
    assign lu_way_o   = hit_way_c;
    assign lu_state_o = hit_c ? state_q[lu_set][hit_way_c] : `RNF_CS_I;
    assign lu_data_o  = data_q[lu_set][hit_way_c];
    assign lu_meta_o  = meta_q[lu_set][hit_way_c];

    wire [`RNF_SET_W-1:0] snp_set = snp_addr_i[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    wire [`RNF_TAG_W-1:0] snp_tag = snp_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1 -: `RNF_TAG_W];

    logic                  snp_hit_c;
    logic [`RNF_WAY_W-1:0] snp_way_c;

    always_comb begin
        snp_hit_c = 1'b0;
        snp_way_c = '0;
        for (int w = 0; w < WAYS; w++) begin
            if ((state_q[snp_set][w] != `RNF_CS_I) && (tag_q[snp_set][w] == snp_tag)) begin
                snp_hit_c = 1'b1;
                snp_way_c = `RNF_WAY_W'(w);
            end
        end
    end

    assign snp_hit_o   = snp_hit_c;
    assign snp_way_o   = snp_way_c;
    assign snp_state_o = snp_hit_c ? state_q[snp_set][snp_way_c] : `RNF_CS_I;
    assign snp_data_o  = data_q[snp_set][snp_way_c];
    assign snp_meta_o  = meta_q[snp_set][snp_way_c];

    logic                  snp_free_v_c;
    logic [`RNF_WAY_W-1:0] snp_free_way_c;
    always_comb begin
        snp_free_v_c   = 1'b0;
        snp_free_way_c = '0;
        for (int w = 0; w < WAYS; w++) begin
            if (!snp_free_v_c && (state_q[snp_set][w] == `RNF_CS_I)) begin
                snp_free_v_c   = 1'b1;
                snp_free_way_c = `RNF_WAY_W'(w);
            end
        end
    end
    assign snp_vic_way_o   = snp_free_v_c ? snp_free_way_c : rr_q[snp_set];
    assign snp_vic_state_o = state_q[snp_set][snp_vic_way_o];

    // An invalid way is taken before the round-robin victim, so a cold cache
    // fills before it ever evicts.
    logic                  free_v_c;
    logic [`RNF_WAY_W-1:0] free_way_c;

    always_comb begin
        free_v_c   = 1'b0;
        free_way_c = '0;
        for (int w = 0; w < WAYS; w++) begin
            if (!free_v_c && (state_q[lu_set][w] == `RNF_CS_I)) begin
                free_v_c   = 1'b1;
                free_way_c = `RNF_WAY_W'(w);
            end
        end
    end

    wire [`RNF_WAY_W-1:0] victim_way = free_v_c ? free_way_c : rr_q[lu_set];

    assign vic_way_o   = victim_way;
    assign vic_state_o = state_q[lu_set][victim_way];
    assign vic_addr_o  = {tag_q[lu_set][victim_way], lu_set,
                          {`RNF_LINE_OFFSET_W{1'b0}}};
    assign vic_data_o  = data_q[lu_set][victim_way];
    assign vic_meta_o  = meta_q[lu_set][victim_way];

    logic                  fl_v_c;
    logic [`RNF_SET_W-1:0] fl_set_c;
    logic [`RNF_WAY_W-1:0] fl_way_c;

    always_comb begin
        fl_v_c   = 1'b0;
        fl_set_c = '0;
        fl_way_c = '0;
        for (int st = 0; st < SETS; st++) begin
            for (int w = 0; w < WAYS; w++) begin
                if (!fl_v_c && (state_q[st][w] != `RNF_CS_I)) begin
                    fl_v_c   = 1'b1;
                    fl_set_c = `RNF_SET_W'(st);
                    fl_way_c = `RNF_WAY_W'(w);
                end
            end
        end
    end

    assign any_valid_o   = fl_v_c;
    assign flush_way_o   = fl_way_c;
    assign flush_state_o = state_q[fl_set_c][fl_way_c];
    assign flush_data_o  = data_q[fl_set_c][fl_way_c];
    assign flush_meta_o  = meta_q[fl_set_c][fl_way_c];
    assign flush_addr_o  = {tag_q[fl_set_c][fl_way_c], fl_set_c, {`RNF_LINE_OFFSET_W{1'b0}}};

    wire [`RNF_SET_W-1:0] fill_set = fill_addr_i[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    wire [`RNF_TAG_W-1:0] fill_tag = fill_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1 -: `RNF_TAG_W];
    wire [`RNF_SET_W-1:0] upd_set  = upd_addr_i[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    wire [`RNF_SET_W-1:0] upd2_set = upd2_addr_i[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    wire [`RNF_TAG_W-1:0] upd_tag  = upd_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1 -: `RNF_TAG_W];
    wire [`RNF_TAG_W-1:0] upd2_tag = upd2_addr_i[CHIE_REQ_ADDR_WIDTH_PARAM-1 -: `RNF_TAG_W];

    // A fill taking the way an update names, for a different line: the update
    // belongs to the line the fill displaced, and landing it on the new one
    // discards a freshly installed copy -- with a Dirty one, SS4.6's (p.4-209)
    // silent transitions do not admit that, the data is the only copy.
    wire upd_displaced  = fill_v_i && (upd_set  == fill_set) &&
                          (upd_way_i  == fill_way_i) && (upd_tag  != fill_tag);
    wire upd2_displaced = fill_v_i && (upd2_set == fill_set) &&
                          (upd2_way_i == fill_way_i) && (upd2_tag != fill_tag);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            for (int s = 0; s < SETS; s++) begin
                rr_q[s] <= '0;
                for (int w = 0; w < WAYS; w++) begin
                    state_q[s][w] <= `RNF_CS_I;
                    tag_q[s][w]   <= '0;
                    data_q[s][w]  <= '0;
                    meta_q[s][w]  <= `RNF_META_FULL;
                end
            end
        end
        else begin
            if (fill_v_i == 1'b1) begin
                tag_q[fill_set][fill_way_i]   <= fill_tag;
                state_q[fill_set][fill_way_i] <= fill_state_i;
                data_q[fill_set][fill_way_i]  <= fill_data_i;
                meta_q[fill_set][fill_way_i]  <= fill_meta_i;
                rr_q[fill_set] <= (rr_q[fill_set] == `RNF_WAY_W'(WAYS-1)) ? '0
                                                                          : (rr_q[fill_set] + 1'b1);
            end
            if (upd_v_i == 1'b1 && !upd_displaced)
                state_q[upd_set][upd_way_i] <= upd_state_i;
            // Last, so that a CopyBack retiring the line it has just written back
            // wins over a snoop landing on it in the same cycle. The snoop's own
            // answer still stands: SS4.6's Table 4-32 (p.4-209) makes the drop to
            // Invalid behind it a permitted silent transition.
            if (upd2_v_i == 1'b1 && !upd2_displaced)
                state_q[upd2_set][upd2_way_i] <= upd2_state_i;
        end
    end

endmodule
