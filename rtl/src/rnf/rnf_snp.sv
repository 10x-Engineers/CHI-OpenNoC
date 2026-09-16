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
// A line here is I, SC, UC, UD or SD: reads fill it, Table 4-33 (SS4.7.1
// p.4-211) lets the Home answer even a ReadShared with a PassDirty grant, and
// stores make it Dirty. It is UCE for as long as a CleanUnique whose line a
// snoop took away waits on the ReadUnique behind it (see rnf_ctl). UDP is never
// entered and is not decoded.
//
// Where a table offers the Snoopee a choice of final state this node takes the
// one that is legal for every modifier: the Clean family leaves a Dirty line SC
// with SnpRespData_SC_PD rather than SD, which Table 4-42's (p.4-223) own SC row
// admits and SS4.10's (p.4-241) DoNotGoToSD can never forbid.
//
// The forwarding, Stash and DVM snoops are not decoded at all: this node
// declares neither DCT nor Stash.
module rnf_snp `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    input  wire                                 prot_rxsnpflitv_i,
    input  chie_pkg::snp_flit_s                 prot_rxsnpflit_i,

    // A snoop taken off the queue, so its L-Credit can be granted again: SS14.2.1
    // (p.14-445) has a Receiver grant only what it can accept.
    output wire                                 snp_pop_o,

    // SS4.11.1 (p.4-242, MUST): a request of this node's own to the same line
    // that has received part of its data holds the snoop until the rest lands.
    input  wire                                 defer_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] defer_addr_i,

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
    logic                                 with_data_q;
    logic                                 pass_dirty_q;
    logic                                 dat_lo_sent_q;

    // SS4.4.1 (p.4-194): an invalidating snoop must leave the Snoopee Invalid.
    function automatic bit is_invalidating(chie_pkg::snp_opcode_e op);
        return (op == chie_pkg::SNP_SNPUNIQUE) ||
               (op == chie_pkg::SNP_SNPCLEANINVALID) ||
               (op == chie_pkg::SNP_SNPMAKEINVALID);
    endfunction

    // Table 4-41 (SS4.8.1 p.4-222) leaves SnpOnce's state as it was, and Table
    // 4-45 (p.4-226) has SnpQuery report a state without disturbing it.
    function automatic bit is_state_preserving(chie_pkg::snp_opcode_e op);
        return (op == chie_pkg::SNP_SNPONCE) || (op == chie_pkg::SNP_SNPQUERY);
    endfunction

    function automatic bit is_dirty(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UD) || (cs == `RNF_CS_SD);
    endfunction

    // Table 4-44 (p.4-225): SnpCleanShared strips the dirtiness and leaves the
    // sharing as it found it.
    function automatic logic [`RNF_CS_WIDTH-1:0]
        final_state(chie_pkg::snp_opcode_e op, logic [`RNF_CS_WIDTH-1:0] cur);
        if (is_invalidating(op))     return `RNF_CS_I;
        if (is_state_preserving(op)) return cur;
        if (cur == `RNF_CS_I)        return `RNF_CS_I;
        // Tables 4-42 (p.4-223) and 4-44 (p.4-225): with no valid bytes there is
        // nothing to keep shared, so every other snoop ends UCE Invalid.
        if (cur == `RNF_CS_UCE)      return `RNF_CS_I;
        if (op == chie_pkg::SNP_SNPCLEANSHARED)
            return (cur == `RNF_CS_UD) ? `RNF_CS_UC :
                   (cur == `RNF_CS_SD) ? `RNF_CS_SC : cur;
        return `RNF_CS_SC;
    endfunction

    // Table 13-30 (SS13.10.32) reads one field two ways; these are its
    // Snoop-response mnemonics. PassDirty is the top bit, and is only ever set
    // on a response whose final state is Clean.
    function automatic chie_pkg::resp_state_e
        resp_of(logic [`RNF_CS_WIDTH-1:0] fin, bit pass_dirty);
        case (fin)
            `RNF_CS_SC: return pass_dirty ? chie_pkg::RESP_SC_PD : chie_pkg::RESP_SC;
            `RNF_CS_UC: return pass_dirty ? chie_pkg::RESP_UC_PD : chie_pkg::RESP_UC_UD;
            `RNF_CS_UD: return chie_pkg::RESP_UC_UD;
            // Table 4-41 (p.4-222) and Table 4-45 (p.4-226): a UCE line that the
            // snoop leaves in place is reported SnpResp_UC.
            `RNF_CS_UCE: return chie_pkg::RESP_UC_UD;
            `RNF_CS_SD: return chie_pkg::RESP_SD;
            default:    return pass_dirty ? chie_pkg::RESP_I_PD  : chie_pkg::RESP_I;
        endcase
    endfunction

    // The Home may hold as many SNP L-Credits as this node grants, and so may send
    // that many snoops before the first is answered. Queued rather than dropped:
    // a snoop that arrived while another was being answered used to be lost, and
    // SS4.11.1 (p.4-242, MUST) owes every one a response.
    localparam int SNPQ_DEPTH = RNF_LCRD_NUM_PARAM;

    logic [chie_pkg::SNP_FLIT_WIDTH-1:0]  head_bits;
    logic                                 take;
    wire                                  q_empty;
    wire                                  q_full;
    wire [$clog2(SNPQ_DEPTH):0]           q_count;

    sync_fifo #(
        .FIFO_ENTRIES_WIDTH ( chie_pkg::SNP_FLIT_WIDTH ),
        .FIFO_ENTRIES_DEPTH ( SNPQ_DEPTH               )
    ) u_snp_q (
        .clk      ( clk_i             ),
        .rst      ( rst_i             ),
        .push     ( prot_rxsnpflitv_i ),
        .pop      ( take              ),
        .data_in  ( prot_rxsnpflit_i  ),
        .data_out ( head_bits         ),
        .empty    ( q_empty           ),
        .full     ( q_full            ),
        .count    ( q_count           )
    );

    chie_pkg::snp_flit_s head;
    assign head = chie_pkg::snp_flit_s'(head_bits);

    wire head_line_deferred =
        defer_v_i &&
        ({head.addr, 3'b000} >> `RNF_LINE_OFFSET_W) == (defer_addr_i >> `RNF_LINE_OFFSET_W);

    // One snoop at a time, and never the one SS4.11.1 has waiting. That also holds
    // the snoops behind it, but only for as long as the Home takes to send the rest
    // of a message it has already started -- SS4.11.2 (p.4-243) forbids it waiting
    // on anything to do so.
    assign take = (st_q == S_IDLE) && !q_empty && !head_line_deferred;
    assign snp_pop_o = take;

    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_addr =
        {head.addr, 3'b000};
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_addr_q =
        {snp_q.addr, 3'b000};

    assign cache_lu_addr_o = (st_q == S_IDLE) ? snp_addr : snp_addr_q;

    wire [`RNF_CS_WIDTH-1:0] cur_state = cache_lu_hit_i ? cache_lu_state_i : `RNF_CS_I;
    wire [`RNF_CS_WIDTH-1:0] nxt_state = final_state(head.opcode, cur_state);

    // SS4.9 (p.4-240): a Dirty line goes back whatever RetToSrc says, a Shared
    // Clean one only when RetToSrc is asserted, and a Unique Clean one is that
    // section's "optionally", which this node declines. SnpMakeInvalid is
    // excluded from the data rules outright, and SS4.3 (p.4-193, MUST) forbids
    // data on a SnpQuery.
    // SPEC-AMBIGUITY: SS4.9 qualifies the Shared Clean MUST with "and the
    // Snoopee retains a copy", which would exempt SnpUnique from SC -- but
    // Table 4-43 (p.4-224) gives that cell SnpRespData_I as its only response,
    // so the table governs.
    wire data_eligible = (head.opcode != chie_pkg::SNP_SNPMAKEINVALID) &&
                         (head.opcode != chie_pkg::SNP_SNPQUERY);
    wire want_data     = data_eligible &&
                         (is_dirty(cur_state) ||
                          ((cur_state == `RNF_CS_SC) && head.rettosrc));

    // A Dirty line whose snoop leaves it Clean hands the dirtiness to the Home
    // with it; one that stays Dirty keeps it (Table 4-41's SnpOnce UD -> UD).
    wire pass_dirty = is_dirty(cur_state) && want_data && !is_dirty(nxt_state);

    always_comb begin
        snp_txrspflit_o        = '0;
        snp_txrspflit_o.tgtid  = snp_q.srcid;
        snp_txrspflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        snp_txrspflit_o.txnid  = snp_q.txnid;
        snp_txrspflit_o.opcode = chie_pkg::RSP_SNPRESP;
        snp_txrspflit_o.resp   = resp_of(final_q, pass_dirty_q);
    end

    always_comb begin
        snp_txdatflit_o         = '0;
        snp_txdatflit_o.tgtid   = snp_q.srcid;
        snp_txdatflit_o.srcid   = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        snp_txdatflit_o.txnid   = snp_q.txnid;
        snp_txdatflit_o.opcode  = chie_pkg::DAT_SNPRESPDATA;
        snp_txdatflit_o.resp    = resp_of(final_q, pass_dirty_q);
        // SS2.10.4 (p.2-136): a 64-byte line is two packets at Data_Width 256.
        snp_txdatflit_o.dataid  = dat_lo_sent_q ? 2'd2 : 2'd0;
        snp_txdatflit_o.data    = dat_lo_sent_q ? data_q[511:256] : data_q[255:0];
        // SS2.10.3 (p.2-135): a SnpRespData asserts every byte enable.
        snp_txdatflit_o.be      = '1;
    end

    assign snp_txrspflitv_o  = (st_q == S_RSP) && !with_data_q;
    assign snp_txdatflitv_o  = (st_q == S_DAT);
    assign cache_upd_v_o     = take &&
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
            with_data_q   <= 1'b0;
            pass_dirty_q  <= 1'b0;
            dat_lo_sent_q <= 1'b0;
        end
        else begin
            case (st_q)
                S_IDLE: begin
                    if (take) begin
                        snp_q         <= head;
                        final_q       <= nxt_state;
                        data_q        <= cache_lu_data_i;
                        with_data_q   <= want_data;
                        pass_dirty_q  <= pass_dirty;
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

    // SS14.2.1 (p.14-445): a credit is granted back only when a snoop leaves the
    // queue, so the Home can never have more outstanding than the queue holds. A
    // push onto a full queue is that accounting broken.
`ifdef ASSERT_CHECKER_ON
    assert_checker #(
                       3,
                       "RN-F snoop queue overflowed: an SNP L-Credit was granted with no slot behind it")
                   SNPQ_OVERFLOW_check (
                       .clk   ( clk_i ),
                       .rst   ( rst_i ),
                       .cond  ( prot_rxsnpflitv_i && q_full && !take )
                   );
`endif

endmodule
