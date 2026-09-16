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

// Chapter 15 system coherency interface, Requester side -- the counterpart of
// the HN-F's SYSCOACK generation.
module rnf_sysco
    (
    input  wire clk_i,
    input  wire rst_i,

    output wire SYSCOREQ,
    input  wire SYSCOACK,

    // SS15.2 (p.15-467): "Requests to enter and exit coherency are always
    // initiated by the Request Node" -- what prompts one is outside CHI, so the
    // integration drives it.
    input  wire coh_req_i,

    // The two conditions SS15.2.1 (p.15-467, MUST) gates the SYSCOREQ fall on:
    // every transaction that permits caching a coherent location complete, and
    // Table 15-1's (p.15-468) "RN caches must not contain coherent data", which
    // already holds in Coherency Disconnect.
    input  wire caching_txn_outstanding_i,
    input  wire holds_coherent_data_i,

    output wire coh_enabled_o,
    output wire snoop_service_req_o,
    output wire sysco_transition_o
    );

    logic syscoreq_q;
    logic syscoack_q;
    logic syscoreq_d;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            syscoack_q <= 1'b0;
        else
            syscoack_q <= SYSCOACK;
    end

    // SS15.2 (p.15-467, MUST): "SYSCOREQ can only change when SYSCOACK is at the
    // same logic state", so each edge is taken from one of the two settled
    // states and never mid-handshake.
    always_comb begin
        syscoreq_d = syscoreq_q;
        if ((syscoreq_q == 1'b0) && (syscoack_q == 1'b0) && (coh_req_i == 1'b1))
            syscoreq_d = 1'b1;
        else if ((syscoreq_q == 1'b1) && (syscoack_q == 1'b1) && (coh_req_i == 1'b0)
                 && (caching_txn_outstanding_i == 1'b0)
                 && (holds_coherent_data_i == 1'b0))
            syscoreq_d = 1'b0;
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            syscoreq_q <= 1'b0;
        else
            syscoreq_q <= syscoreq_d;
    end

    assign SYSCOREQ = syscoreq_q;

    // Table 15-1 (p.15-468): only Coherency Enabled lets the RN "issue
    // transactions that cache a coherent location".
    assign coh_enabled_o = syscoreq_q & syscoack_q;

    // Every state but Coherency Disabled requires the RN to answer snoops;
    // SS15.2.1 (p.15-467, MUST) keeps that up "until SYSCOACK is sampled LOW".
    assign snoop_service_req_o = syscoreq_q | syscoack_q;

    // SS15.2.1 (p.15-467, MUST): "SACTIVE must be asserted during coherency
    // connect transition periods to guarantee the SYSCOACK transition occurs."
    assign sysco_transition_o = syscoreq_q ^ syscoack_q;

endmodule
