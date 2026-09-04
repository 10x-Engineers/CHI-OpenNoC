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

`include "chie_defines.svh"
`include "axi4_defines.svh"
`include "snf_defines.svh"
`include "snf_param.svh"

module snf `SNF_PARAM
    (
        input  wire                               CLK,
        input  wire                               RST,

    //CHIE interface
        output  wire                               TXLINKACTIVEREQ,
        input  wire                               TXLINKACTIVEACK,
        input  wire                               RXLINKACTIVEREQ,
        output  wire                               RXLINKACTIVEACK,
        output  wire                               TXSACTIVE,
        input  wire                               RXSACTIVE,
        input  wire                               RXREQFLITV,
        input  chie_pkg::req_flit_s               RXREQFLIT,
        input  wire                               RXREQFLITPEND,
        output  wire                               RXREQLCRDV,
        input  wire                               RXDATFLITV,
        input  chie_pkg::dat_flit_s               RXDATFLIT,
        input  wire                               RXDATFLITPEND,
        output  wire                               RXDATLCRDV,
        output  wire                               TXRSPFLITV,
        output  chie_pkg::rsp_flit_s               TXRSPFLIT,
        output  wire                               TXRSPFLITPEND,
        input  wire                               TXRSPLCRDV,
        output  wire                               TXDATFLITV,
        output  chie_pkg::dat_flit_s               TXDATFLIT,
        output  wire                               TXDATFLITPEND,
        input  wire                               TXDATLCRDV,

    //AXI interface
        output  wire [`AXI4_ARID_WIDTH-1:0]        ARID,
        output  wire [`AXI4_ARADDR_WIDTH-1:0]      ARADDR,
        output  wire [`AXI4_ARLEN_WIDTH-1:0]       ARLEN,
        output  wire [`AXI4_ARSIZE_WIDTH-1:0]      ARSIZE,
        output  wire [`AXI4_ARBURST_WIDTH-1:0]     ARBURST,
        output  wire [`AXI4_ARLOCK_WIDTH-1:0]      ARLOCK,
        output  wire [`AXI4_ARCACHE_WIDTH-1:0]     ARCACHE,
        output  wire [`AXI4_ARPROT_WIDTH-1:0]      ARPROT,
        output  wire [`AXI4_ARQOS_WIDTH-1:0]       ARQOS,
        output  wire [`AXI4_ARREGION_WIDTH-1:0]    ARREGION,
        output  wire                               ARVALID,
        input  wire                               ARREADY,
        input  wire [`AXI4_RID_WIDTH-1:0]         RID,
        input  wire [`AXI4_RDATA_WIDTH-1:0]       RDATA,
        input  wire [`AXI4_RRESP_WIDTH-1:0]       RRESP,
        input  wire [`AXI4_RLAST_WIDTH-1:0]       RLAST,
        input  wire                               RVALID,
        output  wire                               RREADY,
        output  wire [`AXI4_AWID_WIDTH-1:0]        AWID,
        output  wire [`AXI4_AWADDR_WIDTH-1:0]      AWADDR,
        output  wire [`AXI4_AWLEN_WIDTH-1:0]       AWLEN,
        output  wire [`AXI4_AWSIZE_WIDTH-1:0]      AWSIZE,
        output  wire [`AXI4_AWBURST_WIDTH-1:0]     AWBURST,
        output  wire [`AXI4_AWLOCK_WIDTH-1:0]      AWLOCK,
        output  wire [`AXI4_AWCACHE_WIDTH-1:0]     AWCACHE,
        output  wire [`AXI4_AWPROT_WIDTH-1:0]      AWPROT,
        output  wire [`AXI4_AWQOS_WIDTH-1:0]       AWQOS,
        output  wire [`AXI4_AWREGION_WIDTH-1:0]    AWREGION,
        output  wire                               AWVALID,
        input  wire                               AWREADY,
        output  wire [`AXI4_WDATA_WIDTH-1:0]       WDATA,
        output  wire [`AXI4_WSTRB_WIDTH-1:0]       WSTRB,
        output  wire                               WLAST,
        output  wire                               WVALID,
        input  wire                               WREADY,
        input  wire [`AXI4_BID_WIDTH-1:0]         BID,
        input  wire [`AXI4_BRESP_WIDTH-1:0]       BRESP,
        input  wire                               BVALID,
        output  wire                               BREADY
    );
    wire                                        rxreq_retry_enable_s0;
    wire                                        txrsp_retryack_won_s1;
    wire                                        rxreq_valid_s0;
    chie_pkg::req_flit_s                        rxreqflit_s0;
    wire                                        rxreq_alloc_en_s0;
    chie_pkg::req_flit_s                        rxreq_alloc_flit_s0;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          mshr_entry_idx_alloc_s0;
    wire                                        qos_txrsp_retryack_valid_s1;snf_pkg::retry_ackq_s           qos_txrsp_retryack_fifo_s1;
    wire                                        qos_txrsp_pcrdgnt_valid_s2;snf_pkg::pcrdgrantq_s           qos_txrsp_pcrdgnt_fifo_s2;
    wire                                        txrsp_valid_sx;
    logic [3:0]         txrsp_qos_sx;
    logic [chie_pkg::NID_WIDTH-1:0]       txrsp_tgtid_sx;
    logic [11:0]       txrsp_txnid_sx;
    chie_pkg::rsp_opcode_e      txrsp_opcode_sx;
    chie_pkg::resp_err_e     txrsp_resperr_sx;
    chie_pkg::resp_state_e        txrsp_resp_sx;
    logic [11:0]        txrsp_dbid_sx;
    logic [chie_pkg::NID_WIDTH-1:0]       txrsp_srcid_sx;
    wire                                        qos_active_sx;
    wire                                        rxreq_dbf_wrzero_s1;
    logic    txrsp_tracetag_sx;
    wire                                        txrsp_pcrdgnt_won_s2;
    wire                                        txrsp_won_sx;
    wire                                        rxdat_valid_s0;
    chie_pkg::dat_flit_s                        rxdatflit_s0;
    wire                                        dbf_txdat_valid_sx;
    chie_pkg::dat_flit_s                        txdat_flit;
    wire                                        txdat_dbf_rdy_s1;
    wire                                        txdat_dbf_won_sx;
    wire                                        mshr_retired_valid_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          mshr_retired_idx_sx;
    wire                                        rxreq_dbf_en_s1;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          rxreq_dbf_entry_idx_s1;
    wire                                        rxreq_dbf_wr_s1;
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]        rxreq_dbf_addr_s1;
    chie_pkg::size_e        rxreq_dbf_size_s1;
    wire [`AXI4_AXLEN_WIDTH-1:0]                rxreq_dbf_axlen_s1;
    wire                                        mshr_txdat_en_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          mshr_txdat_entry_idx_sx;
     logic [chie_pkg::NID_WIDTH-1:0]       mshr_txdat_tgtid_sx;
     logic [11:0]       mshr_txdat_txnid_sx;
     chie_pkg::dat_opcode_e      mshr_txdat_opcode_sx;
     chie_pkg::resp_state_e        mshr_txdat_resp_sx;
     chie_pkg::resp_err_e     mshr_txdat_resperr_sx;
     logic [11:0]        mshr_txdat_dbid_sx;
     logic [1:0]      mshr_txdat_dataid_sx;
     logic    mshr_txdat_tracetag_sx;
     logic [chie_pkg::NID_WIDTH-1:0]       mshr_txdat_srcid_sx;
     logic [chie_pkg::NID_WIDTH-1:0]     mshr_txdat_homenid_sx;
    wire                                        mshr_wdat_en_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          mshr_wdat_entry_idx_sx;
    wire                                        mshr_txdat_won_sx;
    wire                                        dbf_mshr_rxdat_ok_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          dbf_mshr_rxdat_ok_idx_sx;
    wire                                        dbf_mshr_rxdat_cancel_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          dbf_mshr_rxdat_cancel_idx_sx;
    wire                                        dbf_mshr_rdata_en_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]          dbf_mshr_rdata_idx_sx;
    wire [3:0]                                  dbf_mshr_rdata_cdmask_sx;
    wire                                        rxreq_lcrdv_o;
    wire                                        rxdat_lcrdv_o;
    wire                                        txrsp_lcrdv_o;
    wire                                        txdat_lcrdv_o;
    wire                                        run_state;

    logic txlinkactivereq_q;
    logic rxlinkactiveack_q;
    logic [`SNF_LL_REQ_CRD_CNT_RANGE]             rxreq_out_crd_q;
    logic [`SNF_LL_DAT_CRD_CNT_RANGE]             rxdat_out_crd_q;
    wire                                        rxreq_out_crd_upd_sx;
    wire                                        rxdat_out_crd_upd_sx;
    wire                                        rx_all_crd_returned_sx;
    wire                                        rx_deact_done_sx;
    wire                                        tx_deactivate_sx;
    wire                                        txlink_run_sx;

    // L-Credits this Receiver has granted and not yet seen consumed. CHI E.b
    // Sec 14.2 (MUST): every flit transfer consumes exactly one L-Credit, an
    // L-Credit return flit included, so the count is grants minus flits.
    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            rxreq_out_crd_q <= {`SNF_LL_REQ_CRD_CNT_WIDTH{1'b0}};
        else if (rxreq_out_crd_upd_sx)
            rxreq_out_crd_q <= RXREQLCRDV ? (rxreq_out_crd_q + `SNF_LL_CRD_INCDEC_ONE)
                                          : (rxreq_out_crd_q - `SNF_LL_CRD_INCDEC_ONE);
    end

    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            rxdat_out_crd_q <= {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}};
        else if (rxdat_out_crd_upd_sx)
            rxdat_out_crd_q <= RXDATLCRDV ? (rxdat_out_crd_q + `SNF_LL_CRD_INCDEC_ONE)
                                          : (rxdat_out_crd_q - `SNF_LL_CRD_INCDEC_ONE);
    end

    assign rxreq_out_crd_upd_sx   = RXREQLCRDV ^ RXREQFLITV;
    assign rxdat_out_crd_upd_sx   = RXDATLCRDV ^ RXDATFLITV;
    assign rx_all_crd_returned_sx = (rxreq_out_crd_q == {`SNF_LL_REQ_CRD_CNT_WIDTH{1'b0}}) &
                                    (rxdat_out_crd_q == {`SNF_LL_DAT_CRD_CNT_WIDTH{1'b0}});

    // CHI E.b Table 14-2 DEACTIVATE (p.14-450, MUST): "The Receiver must wait for
    // all credits to be returned before deasserting LINKACTIVEACK", and Sec 14.6.3
    // (p.14-458, MUST): "The deassertion of RXACK must not occur before the
    // deassertion of TXREQ".
    assign rx_deact_done_sx = ~RXLINKACTIVEREQ & rx_all_crd_returned_sx & ~txlinkactivereq_q;

    // CHI E.b Sec 14.1.3: TXLINKACTIVEREQ and RXLINKACTIVEACK must be deasserted
    // THROUGHOUT reset, so both reset asynchronously -- a synchronous reset still
    // drives the old value on the first reset cycle, and cannot deassert at all
    // while the clock is stopped.
    //
    // The assertion is gated on this node's own TXLINKACTIVEREQ, which is both of
    // Sec 14.6.3's obligations on it at once: (p.14-458, MUST) "The assertion of
    // RXACK must not occur before the assertion of TXREQ" bars it in TxStop, and
    // (p.14-459, MUST) "a component that observes the input race is required to
    // wait for both signals before changing any output signals" bars it in
    // TxDeact -- Figure 14-5's (p.14-455) TxDeact/RxAct, reached when the peer
    // takes Sec 14.6.2's (p.14-456) permitted diagonal out of TxStop/RxDeact and
    // its two outputs are observed in different cycles.
    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            rxlinkactiveack_q <= 1'b0;
        else if (~rxlinkactiveack_q)
            rxlinkactiveack_q <= RXLINKACTIVEREQ & txlinkactivereq_q;  // ACTIVATE -> RUN
        else if (rx_deact_done_sx)
            rxlinkactiveack_q <= 1'b0;                                 // DEACTIVATE -> STOP
    end

    // CHI E.b Sec 14.6.1 (p.14-454, MUST): "If the RXLINK moves to the DEACTIVATE
    // state ... it is required that the TXLINK also moves to the DEACTIVATE state,
    // in a timely manner", and the converse for ACTIVATE. Sec 14.6.3 (p.14-458,
    // MUST) then orders this output against the one above: TXREQ may only assert
    // once RXACK is deasserted, and may only deassert once RXACK is asserted.
    // A constant 1'b1 also left the Transmit link permanently requesting
    // ACTIVATE, so Sec 14.5's RUN -> DEACTIVATE -> STOP edge was unreachable.
    always_ff @(posedge CLK or posedge RST) begin
        if (RST)
            txlinkactivereq_q <= 1'b0;
        // Sec 14.6.3 (p.14-459, MUST): "a component that observes the input race is
        // required to wait for both signals before changing any output signals",
        // and Table 14-1 (p.14-449) gives ACTIVATE only RUN as a successor -- so
        // TXLINKACTIVEREQ is held until TXLINKACTIVEACK arrives, however early the
        // peer lowers its own request. The same ack holds it low through
        // DEACTIVATE, whose only successor is STOP.
        else if (txlinkactivereq_q)
            txlinkactivereq_q <= RXLINKACTIVEREQ | ~TXLINKACTIVEACK;
        else
            txlinkactivereq_q <= RXLINKACTIVEREQ & ~rxlinkactiveack_q & ~TXLINKACTIVEACK;
    end

    assign RXLINKACTIVEACK = rxlinkactiveack_q;
    assign TXLINKACTIVEREQ = txlinkactivereq_q;
    // CHI E.b Sec 14.7.2 (p.14-463, MUST): a Subordinate "must assert TXSACTIVE
    // after receiving a transaction initiating flit and it must be asserted before
    // or in the same cycle in which its first Response flit is sent", and Sec 14.7.4
    // (p.14-463) makes it "orthogonal to the LINKACTIVE states" -- so it tracks the
    // Protocol layer's outstanding work, not the link handshake.
    assign TXSACTIVE = qos_active_sx & (~RST);

    assign run_state = RXLINKACTIVEREQ & RXLINKACTIVEACK;

    // CHI E.b Table 14-2 DEACTIVATE (p.14-450, MUST): "The Transmitter must return
    // credits using Protocol flits or L-Credit return flits", so the TXRSP/TXDAT
    // Transmitters are told when their own link is in that state.
    assign tx_deactivate_sx = ~txlinkactivereq_q & TXLINKACTIVEACK;

    // Table 14-1 (p.14-449): the TXLINK state as THIS node observes it -- its own
    // request and the ack it has received. Table 14-3 (p.14-451, MUST) gates every
    // Protocol flit on it; Sec 14.6.3 (p.14-459, MUST) is why the peer's own view
    // cannot stand in for it.
    assign txlink_run_sx = txlinkactivereq_q & TXLINKACTIVEACK;

    //module
    snf_rxreq `SNF_PARAM_INST
        u_snf_rxreq(
            .clk(CLK),
            .rst(RST),
            .run_state(run_state),
            .rxreqflitv(RXREQFLITV),
            .rxreqflit(RXREQFLIT),
            .rxreqflitpend(RXREQFLITPEND),
            .rxreq_retry_enable_s0(rxreq_retry_enable_s0),
            .txrsp_retryack_won_s1(txrsp_retryack_won_s1),
            .rxreq_lcrdv(RXREQLCRDV),
            .rxreq_valid_s0(rxreq_valid_s0),
            .rxreqflit_s0(rxreqflit_s0)
            );

    snf_txrsp `SNF_PARAM_INST
        u_snf_txrsp(
            .clk(CLK),
            .rst(RST),
            .txrsp_lcrdv(TXRSPLCRDV),
            .tx_deactivate(tx_deactivate_sx),
            .txlink_run(txlink_run_sx),
            .qos_txrsp_retryack_valid_s1(qos_txrsp_retryack_valid_s1),
            .qos_txrsp_retryack_fifo_s1(qos_txrsp_retryack_fifo_s1),
            .qos_txrsp_pcrdgnt_valid_s2(qos_txrsp_pcrdgnt_valid_s2),
            .qos_txrsp_pcrdgnt_fifo_s2(qos_txrsp_pcrdgnt_fifo_s2),
            .txrsp_valid_sx(txrsp_valid_sx),
            .txrsp_qos_sx(txrsp_qos_sx),
            .txrsp_tgtid_sx(txrsp_tgtid_sx),
            .txrsp_txnid_sx(txrsp_txnid_sx),
            .txrsp_opcode_sx(txrsp_opcode_sx),
            .txrsp_resperr_sx(txrsp_resperr_sx),
            .txrsp_resp_sx(txrsp_resp_sx),
            .txrsp_dbid_sx(txrsp_dbid_sx),
            .txrsp_tracetag_sx(txrsp_tracetag_sx),
            .txrsp_srcid_sx(txrsp_srcid_sx),
            .txrspflitv(TXRSPFLITV),
            .txrspflit(TXRSPFLIT),
            .txrspflitpend(TXRSPFLITPEND),
            .txrsp_retryack_won_s1(txrsp_retryack_won_s1),
            .txrsp_pcrdgnt_won_s2(txrsp_pcrdgnt_won_s2),
            .txrsp_won_sx(txrsp_won_sx)
        );

    snf_rxdat `SNF_PARAM_INST
        u_snf_rxdat(
            .clk(CLK),
            .rst(RST),
            .run_state(run_state),
            .rxdatflitv(RXDATFLITV),
            .rxdatflit(RXDATFLIT),
            .rxdatflitpend(RXDATFLITPEND),
            .rxdat_lcrdv(RXDATLCRDV),
            .rxdat_valid_s0(rxdat_valid_s0),
            .rxdatflit_s0(rxdatflit_s0)
        );

    snf_txdat `SNF_PARAM_INST
        u_snf_txdat(
            .clk(CLK),
            .rst(RST),
            .txdat_lcrdv(TXDATLCRDV),
            .tx_deactivate(tx_deactivate_sx),
            .txlink_run(txlink_run_sx),
            .dbf_txdat_valid_sx(dbf_txdat_valid_sx),
            .txdat_flit(txdat_flit),
            .txdatflitv(TXDATFLITV),
            .txdatflit(TXDATFLIT),
            .txdatflitpend(TXDATFLITPEND),
            .txdat_dbf_rdy_s1(txdat_dbf_rdy_s1),
            .txdat_dbf_won_sx(txdat_dbf_won_sx)
        );

    snf_qos `SNF_PARAM_INST
        u_snf_qos(
            .clk(CLK),
            .rst(RST),
            .rxreq_valid_s0(rxreq_valid_s0),
            .rxreqflit_s0(rxreqflit_s0),
            .txrsp_retryack_won_s1(txrsp_retryack_won_s1),
            .txrsp_pcrdgnt_won_s2(txrsp_pcrdgnt_won_s2),
            .mshr_retired_valid_sx(mshr_retired_valid_sx),
            .mshr_retired_idx_sx(mshr_retired_idx_sx),
            .qos_txrsp_retryack_valid_s1(qos_txrsp_retryack_valid_s1),
            .qos_txrsp_retryack_fifo_s1(qos_txrsp_retryack_fifo_s1),
            .qos_txrsp_pcrdgnt_valid_s2(qos_txrsp_pcrdgnt_valid_s2),
            .qos_txrsp_pcrdgnt_fifo_s2(qos_txrsp_pcrdgnt_fifo_s2),
            .rxreq_retry_enable_s0(rxreq_retry_enable_s0),
            .rxreq_alloc_en_s0(rxreq_alloc_en_s0),
            .rxreq_alloc_flit_s0(rxreq_alloc_flit_s0),
            .mshr_entry_idx_alloc_s0(mshr_entry_idx_alloc_s0),
            .qos_active_sx(qos_active_sx)
        );

    snf_data_buffer `SNF_PARAM_INST
        u_snf_data_buffer(
            .clk(CLK),
            .rst(RST),
            .rxdat_valid_s0(rxdat_valid_s0),
            .rxdatflit_s0(rxdatflit_s0),
            .rxreq_dbf_en_s1(rxreq_dbf_en_s1),
            .rxreq_dbf_entry_idx_s1(rxreq_dbf_entry_idx_s1),
            .rxreq_dbf_wr_s1(rxreq_dbf_wr_s1),
            .rxreq_dbf_wrzero_s1(rxreq_dbf_wrzero_s1),
            .rxreq_dbf_addr_s1(rxreq_dbf_addr_s1),
            .rxreq_dbf_size_s1(rxreq_dbf_size_s1),
            .rxreq_dbf_axlen_s1(rxreq_dbf_axlen_s1),
            .mshr_retired_valid_sx(mshr_retired_valid_sx),
            .mshr_retired_idx_sx(mshr_retired_idx_sx),
            .mshr_wdat_en_sx(mshr_wdat_en_sx),
            .mshr_wdat_entry_idx_sx(mshr_wdat_entry_idx_sx),
            .mshr_txdat_en_sx(mshr_txdat_en_sx),
            .mshr_txdat_entry_idx_sx(mshr_txdat_entry_idx_sx),
            .mshr_txdat_txnid_sx(mshr_txdat_txnid_sx),
            .mshr_txdat_opcode_sx(mshr_txdat_opcode_sx),
            .mshr_txdat_resp_sx(mshr_txdat_resp_sx),
            .mshr_txdat_resperr_sx(mshr_txdat_resperr_sx),
            .mshr_txdat_dbid_sx(mshr_txdat_dbid_sx),
            .mshr_txdat_dataid_sx(mshr_txdat_dataid_sx),
            .mshr_txdat_tracetag_sx(mshr_txdat_tracetag_sx),
            .mshr_txdat_srcid_sx(mshr_txdat_srcid_sx),
            .mshr_txdat_homenid_sx(mshr_txdat_homenid_sx),
            .mshr_txdat_tgtid_sx(mshr_txdat_tgtid_sx),
            .txdat_dbf_rdy_s1(txdat_dbf_rdy_s1),
            .txdat_dbf_won_sx(txdat_dbf_won_sx),
            .dbf_txdat_valid_sx(dbf_txdat_valid_sx),
            .txdat_flit(txdat_flit),
            .mshr_txdat_won_sx(mshr_txdat_won_sx),
            .dbf_mshr_rxdat_ok_sx(dbf_mshr_rxdat_ok_sx),
            .dbf_mshr_rxdat_ok_idx_sx(dbf_mshr_rxdat_ok_idx_sx),
            .dbf_mshr_rxdat_cancel_sx(dbf_mshr_rxdat_cancel_sx),
            .dbf_mshr_rxdat_cancel_idx_sx(dbf_mshr_rxdat_cancel_idx_sx),
            .dbf_mshr_rdata_en_sx(dbf_mshr_rdata_en_sx),
            .dbf_mshr_rdata_idx_sx(dbf_mshr_rdata_idx_sx),
            .dbf_mshr_rdata_cdmask_sx(dbf_mshr_rdata_cdmask_sx),
            .rid(RID),
            .rdata(RDATA),
            .rresp(RRESP),
            .rlast(RLAST),
            .rvalid(RVALID),
            .rready(RREADY),
            .wdata(WDATA),
            .wstrb(WSTRB),
            .wlast(WLAST),
            .wvalid(WVALID),
            .wready(WREADY)
        );

    snf_mshr `SNF_PARAM_INST
        u_snf_mshr(
            .clk(CLK),
            .rst(RST),
            .rxreq_alloc_en_s0(rxreq_alloc_en_s0),
            .rxreq_alloc_flit_s0(rxreq_alloc_flit_s0),
            .mshr_entry_idx_alloc_s0(mshr_entry_idx_alloc_s0),
            .txrsp_valid_sx(txrsp_valid_sx),
            .txrsp_qos_sx(txrsp_qos_sx),
            .txrsp_tgtid_sx(txrsp_tgtid_sx),
            .txrsp_txnid_sx(txrsp_txnid_sx),
            .txrsp_opcode_sx(txrsp_opcode_sx),
            .txrsp_resperr_sx(txrsp_resperr_sx),
            .txrsp_resp_sx(txrsp_resp_sx),
            .txrsp_dbid_sx(txrsp_dbid_sx),
            .txrsp_srcid_sx(txrsp_srcid_sx),
            .txrsp_tracetag_sx(txrsp_tracetag_sx),
            .txrsp_won_sx(txrsp_won_sx),
            .rxreq_dbf_en_s1(rxreq_dbf_en_s1),
            .rxreq_dbf_wr_s1(rxreq_dbf_wr_s1),
            .rxreq_dbf_wrzero_s1(rxreq_dbf_wrzero_s1),
            .rxreq_dbf_entry_idx_s1(rxreq_dbf_entry_idx_s1),
            .rxreq_dbf_addr_s1(rxreq_dbf_addr_s1),
            .rxreq_dbf_size_s1(rxreq_dbf_size_s1),
            .rxreq_dbf_axlen_s1(rxreq_dbf_axlen_s1),
            .dbf_mshr_rdata_en_sx(dbf_mshr_rdata_en_sx),
            .dbf_mshr_rdata_idx_sx(dbf_mshr_rdata_idx_sx),
            .dbf_mshr_rdata_cdmask_sx(dbf_mshr_rdata_cdmask_sx),
            .dbf_mshr_rxdat_ok_sx(dbf_mshr_rxdat_ok_sx),
            .dbf_mshr_rxdat_ok_idx_sx(dbf_mshr_rxdat_ok_idx_sx),
            .dbf_mshr_rxdat_cancel_sx(dbf_mshr_rxdat_cancel_sx),
            .dbf_mshr_rxdat_cancel_idx_sx(dbf_mshr_rxdat_cancel_idx_sx),
            .mshr_txdat_en_sx(mshr_txdat_en_sx),
            .mshr_txdat_entry_idx_sx(mshr_txdat_entry_idx_sx),
            .mshr_txdat_txnid_sx(mshr_txdat_txnid_sx),
            .mshr_txdat_opcode_sx(mshr_txdat_opcode_sx),
            .mshr_txdat_resp_sx(mshr_txdat_resp_sx),
            .mshr_txdat_resperr_sx(mshr_txdat_resperr_sx),
            .mshr_txdat_dbid_sx(mshr_txdat_dbid_sx),
            .mshr_txdat_dataid_sx(mshr_txdat_dataid_sx),
            .mshr_txdat_tgtid_sx(mshr_txdat_tgtid_sx),
            .mshr_txdat_srcid_sx(mshr_txdat_srcid_sx),
            .mshr_txdat_homenid_sx(mshr_txdat_homenid_sx),
            .mshr_txdat_tracetag_sx(mshr_txdat_tracetag_sx),
            .mshr_wdat_en_sx(mshr_wdat_en_sx),
            .mshr_wdat_entry_idx_sx(mshr_wdat_entry_idx_sx),
            .mshr_txdat_won_sx(mshr_txdat_won_sx),
            .mshr_retired_valid_sx(mshr_retired_valid_sx),
            .mshr_retired_idx_sx(mshr_retired_idx_sx),
            .arid_sx(ARID),
            .araddr_sx(ARADDR),
            .arlen_sx(ARLEN),
            .arsize_sx(ARSIZE),
            .arburst_sx(ARBURST),
            .arlock_sx(ARLOCK),
            .arcache_sx(ARCACHE),
            .arprot_sx(ARPROT),
            .arqos_sx(ARQOS),
            .arregion_sx(ARREGION),
            .arvalid_sx(ARVALID),
            .arready_sx(ARREADY),
            .awid_sx(AWID),
            .awaddr_sx(AWADDR),
            .awlen_sx(AWLEN),
            .awsize_sx(AWSIZE),
            .awburst_sx(AWBURST),
            .awlock_sx(AWLOCK),
            .awcache_sx(AWCACHE),
            .awprot_sx(AWPROT),
            .awqos_sx(AWQOS),
            .awregion_sx(AWREGION),
            .awvalid_sx(AWVALID),
            .awready_sx(AWREADY),
            .bid_sx(BID),
            .bresp_sx(BRESP),
            .bvalid_sx(BVALID),
            .bready_sx(BREADY)
        );
endmodule
