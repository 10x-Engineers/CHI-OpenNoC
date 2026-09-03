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

// Chapter 14 link-activation handshake, shared by every CHI node in this repo.
// Self-contained on purpose: a node includes only its own defines header, so the
// LINKACTIVE state encoding of Table 14-1 (p.14-449) lives here rather than in
// any one node's macro set.
module chi_link_handshake
    (
        // global input
        clk,
        rst,

        // link handshake interface
        TXLINKACTIVEREQ,
        TXLINKACTIVEACK,

        RXLINKACTIVEREQ,
        RXLINKACTIVEACK,

        txlink_state,
        rxlink_state,

        txflit_avail,
        rxcrd_cnt_full,

        lcrd_return_en,
        rxcrd_en,
        txlink_run
    );

    localparam LL_STATE_WIDTH = 2;
    localparam LL_STOP        = 2'b00;
    localparam LL_ACTIVATE    = 2'b10;
    localparam LL_RUN         = 2'b11;
    localparam LL_DEACTIVATE  = 2'b01;

    // global input
    input  wire                       clk;
    input  wire                       rst;

    // link handshake interface
    output wire                       TXLINKACTIVEREQ;
    input  wire                       TXLINKACTIVEACK;

    input  wire                       RXLINKACTIVEREQ;
    output wire                       RXLINKACTIVEACK;

    output wire [LL_STATE_WIDTH-1:0] txlink_state;
    output wire [LL_STATE_WIDTH-1:0] rxlink_state;

    input  wire                       txflit_avail;
    input  wire                       rxcrd_cnt_full;

    output wire                       lcrd_return_en;
    output wire                       rxcrd_en;
    output wire                       txlink_run;

    // wire

    // reg
    logic                               txlinkactivereq_s0;
    logic                               rxlinkactiveack_s0;
    logic                               txlinkactivereq_s1_q;
    logic                               txlinkactiveack_s1_q;
    logic                               rxlinkactivereq_s1_q;
    logic                               rxlinkactiveack_s1_q;

    // main function
    // TXLINKACTIVE
    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            txlinkactiveack_s1_q <= 1'b0;
        else
            txlinkactiveack_s1_q <= TXLINKACTIVEACK;
    end

    always_comb begin
        case(txlink_state)
            // Transition from STOP to ACTIVATE when:
            // 1. Need to send txflit and RXLINK state is NOT DEACTIVATE or RUN.
            // 2. Received RXLINKACTIVEREQ
            LL_STOP :
                txlinkactivereq_s0 = (txflit_avail & (rxlink_state == LL_STOP)) | (rxlink_state == LL_ACTIVATE);
            // Transition from RUN to DEACTIVATE when:
            // 1. Received RXLINKACTIVEREQ = 0
            LL_RUN  :
                txlinkactivereq_s0 = ~(rxlink_state == LL_DEACTIVATE);
            default  :
                txlinkactivereq_s0 = txlinkactivereq_s1_q;
        endcase
    end

    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            txlinkactivereq_s1_q <= 1'b0;
        else
            txlinkactivereq_s1_q <= txlinkactivereq_s0;
    end

    assign TXLINKACTIVEREQ = txlinkactivereq_s1_q;

    assign txlink_state = {txlinkactivereq_s1_q, txlinkactiveack_s1_q};

    // RXLINKACTIVE
    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            rxlinkactivereq_s1_q <= 1'b0;
        else
            rxlinkactivereq_s1_q <= RXLINKACTIVEREQ;
    end

    always_comb begin
        case(rxlink_state)
            // Transition from ACTIVATE to RUN when:
            // 1. TXLINK state is NOT DEACTIVATE
            LL_ACTIVATE   :
                rxlinkactiveack_s0 = (txlink_state != LL_DEACTIVATE);
            // Transition from DEACTIVATE to STOP when:
            // 1. All credits are received and TXLINK state is NOT ACTIVATE
            LL_DEACTIVATE :
                rxlinkactiveack_s0 = ~(rxcrd_cnt_full & (txlink_state != LL_ACTIVATE));
            default        :
                rxlinkactiveack_s0 = rxlinkactiveack_s1_q;
        endcase
    end

    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            rxlinkactiveack_s1_q <= 1'b0;
        else
            rxlinkactiveack_s1_q <= rxlinkactiveack_s0;
    end

    assign RXLINKACTIVEACK = rxlinkactiveack_s1_q;

    assign rxlink_state    = {rxlinkactivereq_s1_q, rxlinkactiveack_s1_q};

    // Table 14-3 (p.14-451, MUST): the Transmitter "must not send flits" in STOP.
    // ~TXLINKACTIVEREQ alone is STOP as well as DEACTIVATE, so the ack qualifies it
    // down to DEACTIVATE, where Table 14-2 (p.14-450) expects the returns.
    assign lcrd_return_en  = ~txlinkactivereq_s1_q & txlinkactiveack_s1_q;
    assign rxcrd_en        = (rxlink_state == LL_RUN);
    assign txlink_run      = (txlink_state == LL_RUN);

endmodule
