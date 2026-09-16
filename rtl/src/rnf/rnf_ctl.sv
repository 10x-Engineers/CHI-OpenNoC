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
`include "axi4_defines.svh"

// The RN-F's coherent read path: an AXI4 read is served from the cache, or by a
// ReadShared that fills it.
//
// Reads only, deliberately. A line this engine installs is only ever SC or UC,
// and Table 4-32 (SS4.6 p.4-209) permits a silent eviction from either -- so a
// victim needs no CopyBack and the node owes no write-back. Adding stores is
// what makes UD reachable and a WriteBackFull necessary with it.
//
// One transaction at a time: SS2.5.2 (p.2-87) bounds TxnID reuse by what is
// outstanding, so a single context needs no MSHR to stay legal.
module rnf_ctl `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    // AXI4 subordinate, read channels only
    input  wire [`AXI4_ARID_WIDTH-1:0]          ARID,
    input  wire [`AXI4_ARADDR_WIDTH-1:0]        ARADDR,
    input  wire [`AXI4_ARLEN_WIDTH-1:0]         ARLEN,
    input  wire [`AXI4_ARSIZE_WIDTH-1:0]        ARSIZE,
    input  wire                                 ARVALID,
    output wire                                 ARREADY,
    output wire [`AXI4_RID_WIDTH-1:0]           RID,
    output wire [`AXI4_RDATA_WIDTH-1:0]         RDATA,
    output wire [`AXI4_RRESP_WIDTH-1:0]         RRESP,
    output wire                                 RLAST,
    output wire                                 RVALID,
    input  wire                                 RREADY,

    // Cache
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_lu_addr_o,
    input  wire                                 cache_lu_hit_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_lu_state_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_lu_data_i,
    input  wire [`RNF_WAY_W-1:0]                cache_vic_way_i,
    output wire                                 cache_fill_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_fill_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_fill_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_fill_state_o,
    output wire [`RNF_LINE_BITS-1:0]            cache_fill_data_o,

    // Protocol layer, to the link
    output chie_pkg::req_flit_s                 prot_txreqflit_o,
    output wire                                 prot_txreqflitv_o,
    input  wire                                 prot_txreqflit_sent_i,
    output chie_pkg::rsp_flit_s                 prot_txrspflit_o,
    output wire                                 prot_txrspflitv_o,
    input  wire                                 prot_txrspflit_sent_i,
    input  wire                                 prot_rxdatflitv_i,
    input  chie_pkg::dat_flit_s                 prot_rxdatflit_i,
    input  wire                                 prot_rxrspflitv_i,
    input  chie_pkg::rsp_flit_s                 prot_rxrspflit_i,

    // Table 15-1 (p.15-468): only Coherency Enabled permits a transaction that
    // caches a coherent location.
    input  wire                                 coh_enabled_i,
    input  wire                                 link_run_i,

    output wire                                 txn_active_o
    );

    localparam logic [2:0] S_IDLE  = 3'd0;
    localparam logic [2:0] S_REQ   = 3'd1;
    localparam logic [2:0] S_DATA  = 3'd2;
    localparam logic [2:0] S_ACK   = 3'd3;
    localparam logic [2:0] S_RESP  = 3'd4;

    logic [2:0]                                 st_q;
    logic [`AXI4_ARID_WIDTH-1:0]                id_q;
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       addr_q;
    logic [11:0]                                txnid_q;
    logic [`RNF_LINE_BITS-1:0]                  line_q;
    logic [`RNF_CS_WIDTH-1:0]                   fill_state_q;
    logic                                       got_lo_q, got_hi_q, got_rsp_q;
    logic                                       fill_v_q;
    logic                                       hit_q;

    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] line_addr =
        {ARADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};

    assign cache_lu_addr_o = (st_q == S_IDLE) ? line_addr : addr_q;

    // Accept a read only with the link in RUN and the interface in Coherency
    // Enabled -- SS15.2.1 (p.15-467, MUST) forbids issuing a caching transaction
    // before SYSCOACK.
    assign ARREADY = (st_q == S_IDLE) && link_run_i && coh_enabled_i;

    // Table 4-4 (SS4.2.1 p.4-167) permits ReadShared from Invalid, and Table 2-8
    // (SS2.8.3 p.2-117) makes CompAck required for it at an RN-F.
    always_comb begin
        prot_txreqflit_o              = '0;
        prot_txreqflit_o.qos          = 4'd0;
        prot_txreqflit_o.tgtid        = CHIE_NID_WIDTH_PARAM'(HNF_NID_PARAM);
        prot_txreqflit_o.srcid        = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txreqflit_o.txnid        = txnid_q;
        prot_txreqflit_o.opcode       = chie_pkg::REQ_READSHARED;
        prot_txreqflit_o.size         = chie_pkg::SIZE_64B;
        prot_txreqflit_o.addr         = addr_q;
        prot_txreqflit_o.allowretry   = 1'b1;
        prot_txreqflit_o.order        = chie_pkg::ORDER_NONE;
        prot_txreqflit_o.memattr.allocate     = 1'b1;
        prot_txreqflit_o.memattr.cacheable    = 1'b1;
        prot_txreqflit_o.memattr.device       = 1'b0;
        prot_txreqflit_o.memattr.early_wr_ack = 1'b1;
        prot_txreqflit_o.snpattr.snpattr      = 1'b1;
        prot_txreqflit_o.expcompack   = 1'b1;
    end

    assign prot_txreqflitv_o = (st_q == S_REQ);

    // SS2.8.3 (p.2-116): CompAck names the transaction by its own TxnID.
    always_comb begin
        prot_txrspflit_o        = '0;
        prot_txrspflit_o.tgtid  = CHIE_NID_WIDTH_PARAM'(HNF_NID_PARAM);
        prot_txrspflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txrspflit_o.txnid  = txnid_q;
        prot_txrspflit_o.opcode = chie_pkg::RSP_COMPACK;
    end

    assign prot_txrspflitv_o = (st_q == S_ACK);

    // SS2.3.1 (p.2-44) gives a read two completion shapes and Table 4-33
    // (SS4.7.1 p.4-211) gives every read the separate column, so a Requester that
    // decodes only CompData stalls against a conformant Home: the combined form
    // is CompData, the separate one RespSepData on RSP then DataSepResp on DAT.
    wire rx_dat_mine = prot_rxdatflitv_i && (prot_rxdatflit_i.txnid == txnid_q) &&
                       ((prot_rxdatflit_i.opcode == chie_pkg::DAT_COMPDATA) ||
                        (prot_rxdatflit_i.opcode == chie_pkg::DAT_DATASEPRESP));
    wire rx_dat_comb = rx_dat_mine &&
                       (prot_rxdatflit_i.opcode == chie_pkg::DAT_COMPDATA);
    wire rx_rsp_mine = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q) &&
                       (prot_rxrspflit_i.opcode == chie_pkg::RSP_RESPSEPDATA);

    // Table 4-33 (SS4.7.1 p.4-211) names the states a read completion may grant;
    // chie_pkg reads a CompData's 010/110/111 as UC/UD_PD/SD_PD.
    function automatic logic [`RNF_CS_WIDTH-1:0] cs_of_resp(chie_pkg::resp_state_e r);
        case (r)
            chie_pkg::RESP_SC:     return `RNF_CS_SC;
            chie_pkg::RESP_UC_UD:  return `RNF_CS_UC;
            chie_pkg::RESP_UC_PD:  return `RNF_CS_UD;
            chie_pkg::RESP_SD_PD:  return `RNF_CS_SD;
            chie_pkg::RESP_SD:     return `RNF_CS_SD;
            chie_pkg::RESP_SC_PD:  return `RNF_CS_SD;
            default:               return `RNF_CS_I;
        endcase
    endfunction

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            st_q         <= S_IDLE;
            id_q         <= '0;
            addr_q       <= '0;
            txnid_q      <= '0;
            line_q       <= '0;
            fill_state_q <= `RNF_CS_I;
            got_lo_q     <= 1'b0;
            got_hi_q     <= 1'b0;
            got_rsp_q    <= 1'b0;
            fill_v_q     <= 1'b0;
            hit_q        <= 1'b0;
        end
        else begin
            fill_v_q <= 1'b0;
            case (st_q)
                S_IDLE: begin
                    if (ARVALID && ARREADY) begin
                        id_q     <= ARID;
                        addr_q   <= line_addr;
                        got_lo_q  <= 1'b0;
                        got_hi_q  <= 1'b0;
                        got_rsp_q <= 1'b0;
                        if (cache_lu_hit_i) begin
                            line_q <= cache_lu_data_i;
                            hit_q  <= 1'b1;
                            st_q   <= S_RESP;
                        end
                        else begin
                            hit_q <= 1'b0;
                            st_q  <= S_REQ;
                        end
                    end
                end

                S_REQ: begin
                    if (prot_txreqflit_sent_i) st_q <= S_DATA;
                end

                S_DATA: begin
                    // The response half: RespSepData in the separate form,
                    // CompData in the combined one, both carrying the granted
                    // state Table 4-33 (SS4.7.1 p.4-211) names.
                    if (rx_rsp_mine) begin
                        fill_state_q <= cs_of_resp(prot_rxrspflit_i.resp);
                        got_rsp_q    <= 1'b1;
                    end
                    if (rx_dat_comb) fill_state_q <= cs_of_resp(prot_rxdatflit_i.resp);

                    // SS2.10.4 (p.2-136): a 64-byte transfer at Data_Width 256 is
                    // two packets, DataID 0 then 2.
                    if (rx_dat_mine) begin
                        if (prot_rxdatflit_i.dataid == 2'd0) begin
                            line_q[255:0] <= prot_rxdatflit_i.data;
                            got_lo_q      <= 1'b1;
                        end
                        else begin
                            line_q[511:256] <= prot_rxdatflit_i.data;
                            got_hi_q        <= 1'b1;
                        end
                    end

                    if ((got_lo_q || (rx_dat_mine && (prot_rxdatflit_i.dataid == 2'd0))) &&
                        (got_hi_q || (rx_dat_mine && (prot_rxdatflit_i.dataid != 2'd0))) &&
                        (got_rsp_q || rx_rsp_mine || rx_dat_comb)) begin
                        fill_v_q <= 1'b1;
                        st_q     <= S_ACK;
                    end
                end

                S_ACK: begin
                    if (prot_txrspflit_sent_i) st_q <= S_RESP;
                end

                S_RESP: begin
                    if (RREADY) begin
                        st_q    <= S_IDLE;
                        txnid_q <= txnid_q + 12'd1;
                    end
                end

                default: st_q <= S_IDLE;
            endcase
        end
    end

    assign cache_fill_v_o     = fill_v_q;
    assign cache_fill_addr_o  = addr_q;
    assign cache_fill_way_o   = cache_vic_way_i;
    assign cache_fill_state_o = fill_state_q;
    assign cache_fill_data_o  = line_q;

    // The 128-bit chunk the access falls in. A fixed set of slices rather than a
    // variable base, so the select cannot read past the line.
    logic [`AXI4_RDATA_WIDTH-1:0] rdata_c;
    always_comb begin
        case (addr_q[5:4])
            2'd0:    rdata_c = line_q[127:0];
            2'd1:    rdata_c = line_q[255:128];
            2'd2:    rdata_c = line_q[383:256];
            default: rdata_c = line_q[511:384];
        endcase
    end

    assign RVALID = (st_q == S_RESP);
    assign RDATA  = rdata_c;
    assign RID    = id_q;
    assign RRESP  = 2'b00;
    assign RLAST  = 1'b1;

    assign txn_active_o = (st_q != S_IDLE);

endmodule
