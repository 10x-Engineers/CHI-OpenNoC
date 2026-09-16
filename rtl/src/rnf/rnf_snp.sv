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

// The RN-F's snoop port: section 4.8's response tables for the states this node
// can hold.
//
// Reads are the only thing that fills the cache today, so a line is only ever I,
// SC or UC and section 4.9's (p.4-240) data rules reduce to two:
//
//   - Shared Clean, RetToSrc=1, and the Snoopee retains a copy -> MUST return one.
//   - Shared Clean, RetToSrc=0 -> MUST NOT return one.
//
// Unique Clean is section 4.9's "optionally can return a copy", and this node
// does not. The Dirty rows of Tables 4-41..4-44 are unreachable until a store
// path exists, and are deliberately not written here rather than written blind.
module rnf_snp `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    input  wire                                 prot_rxsnpflitv_i,
    input  chie_pkg::snp_flit_s                 prot_rxsnpflit_i,

    // Cache
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_lu_addr_o,
    input  wire                                 cache_lu_hit_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_lu_state_i,
    input  wire [`RNF_WAY_W-1:0]                cache_lu_way_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_lu_data_i,
    output wire                                 cache_upd_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_upd_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_upd_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_upd_state_o,

    // Response, to the link
    output chie_pkg::rsp_flit_s                 snp_txrspflit_o,
    output wire                                 snp_txrspflitv_o,
    input  wire                                 snp_txrspflit_sent_i,
    output chie_pkg::dat_flit_s                 snp_txdatflit_o,
    output wire                                 snp_txdatflitv_o,
    input  wire                                 snp_txdatflit_sent_i,

    output wire                                 snp_busy_o
    );

    localparam logic [1:0] S_IDLE = 2'd0;
    localparam logic [1:0] S_RSP  = 2'd1;
    localparam logic [1:0] S_DAT  = 2'd2;

    logic [1:0]                           st_q;
    chie_pkg::snp_flit_s                  snp_q;
    logic [`RNF_CS_WIDTH-1:0]             final_q;
    logic [`RNF_LINE_BITS-1:0]            data_q;
    logic [`RNF_WAY_W-1:0]                way_q;
    logic                                 with_data_q;
    logic                                 dat_lo_sent_q;
    logic [`RNF_CS_WIDTH-1:0]             init_state_q;

    // SS4.4.1 (p.4-194): an invalidating snoop must leave the Snoopee Invalid.
    function automatic bit is_invalidating(chie_pkg::snp_opcode_e op);
        return (op == chie_pkg::SNP_SNPUNIQUE) ||
               (op == chie_pkg::SNP_SNPCLEANINVALID) ||
               (op == chie_pkg::SNP_SNPMAKEINVALID);
    endfunction

    // Table 4-41 (SS4.8.1 p.4-222): SnpOnce leaves the state as it was.
    function automatic logic [`RNF_CS_WIDTH-1:0]
        final_state(chie_pkg::snp_opcode_e op, logic [`RNF_CS_WIDTH-1:0] cur);
        if (is_invalidating(op))              return `RNF_CS_I;
        if (op == chie_pkg::SNP_SNPONCE)      return cur;
        if (cur == `RNF_CS_I)                 return `RNF_CS_I;
        return `RNF_CS_SC;
    endfunction

    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_addr =
        {prot_rxsnpflit_i.addr, 3'b000};
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_addr_q =
        {snp_q.addr, 3'b000};

    assign cache_lu_addr_o = (st_q == S_IDLE) ? snp_addr : snp_addr_q;

    wire [`RNF_CS_WIDTH-1:0] cur_state = cache_lu_hit_i ? cache_lu_state_i : `RNF_CS_I;
    wire [`RNF_CS_WIDTH-1:0] nxt_state = final_state(prot_rxsnpflit_i.opcode, cur_state);

    // SS4.9 (p.4-240): a Shared Clean line goes back only when RetToSrc is
    // asserted and the Snoopee keeps its copy; SnpMakeInvalid is excluded from
    // the data rules outright.
    wire retains_sc = (nxt_state == `RNF_CS_SC);
    wire want_data  = (cur_state == `RNF_CS_SC) && prot_rxsnpflit_i.rettosrc &&
                      retains_sc &&
                      (prot_rxsnpflit_i.opcode != chie_pkg::SNP_SNPMAKEINVALID);

    always_comb begin
        snp_txrspflit_o        = '0;
        snp_txrspflit_o.tgtid  = snp_q.srcid;
        snp_txrspflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        snp_txrspflit_o.txnid  = snp_q.txnid;
        snp_txrspflit_o.opcode = chie_pkg::RSP_SNPRESP;
        snp_txrspflit_o.resp   = (final_q == `RNF_CS_SC) ? chie_pkg::RESP_SC :
                                 (final_q == `RNF_CS_UC) ? chie_pkg::RESP_UC_UD :
                                                           chie_pkg::RESP_I;
    end

    always_comb begin
        snp_txdatflit_o         = '0;
        snp_txdatflit_o.tgtid   = snp_q.srcid;
        snp_txdatflit_o.srcid   = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        snp_txdatflit_o.txnid   = snp_q.txnid;
        snp_txdatflit_o.opcode  = chie_pkg::DAT_SNPRESPDATA;
        snp_txdatflit_o.resp    = (final_q == `RNF_CS_SC) ? chie_pkg::RESP_SC
                                                          : chie_pkg::RESP_I;
        // SS2.10.4 (p.2-136): a 64-byte line is two packets at Data_Width 256.
        snp_txdatflit_o.dataid  = dat_lo_sent_q ? 2'd2 : 2'd0;
        snp_txdatflit_o.data    = dat_lo_sent_q ? data_q[511:256] : data_q[255:0];
        // SS2.10.3 (p.2-135): a SnpRespData asserts every byte enable.
        snp_txdatflit_o.be      = '1;
    end

    assign snp_txrspflitv_o  = (st_q == S_RSP) && !with_data_q;
    assign snp_txdatflitv_o  = (st_q == S_DAT);
    assign cache_upd_v_o     = (st_q == S_IDLE) && prot_rxsnpflitv_i &&
                               cache_lu_hit_i && (nxt_state != cur_state);
    assign cache_upd_addr_o  = snp_addr;
    assign cache_upd_way_o   = cache_lu_way_i;
    assign cache_upd_state_o = nxt_state;
    assign snp_busy_o        = (st_q != S_IDLE);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            st_q          <= S_IDLE;
            snp_q         <= '0;
            final_q       <= `RNF_CS_I;
            data_q        <= '0;
            way_q         <= '0;
            with_data_q   <= 1'b0;
            dat_lo_sent_q <= 1'b0;
            init_state_q  <= `RNF_CS_I;
        end
        else begin
            case (st_q)
                S_IDLE: begin
                    if (prot_rxsnpflitv_i) begin
                        snp_q         <= prot_rxsnpflit_i;
                        final_q       <= nxt_state;
                        init_state_q  <= cur_state;
                        data_q        <= cache_lu_data_i;
                        way_q         <= cache_lu_way_i;
                        with_data_q   <= want_data;
                        dat_lo_sent_q <= 1'b0;
                        st_q          <= want_data ? S_DAT : S_RSP;
                    end
                end

                S_RSP: begin
                    if (snp_txrspflit_sent_i) st_q <= S_IDLE;
                end

                S_DAT: begin
                    if (snp_txdatflit_sent_i) begin
                        if (dat_lo_sent_q) st_q <= S_IDLE;
                        else               dat_lo_sent_q <= 1'b1;
                    end
                end

                default: st_q <= S_IDLE;
            endcase
        end
    end

endmodule
