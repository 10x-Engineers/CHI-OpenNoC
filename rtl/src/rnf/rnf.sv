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

// RN-F, the coherent Request Node. The channel set is Figure 13-5's (p.13-399)
// for a Requester with a snoop port: TX REQ/RSP/DAT out, RX RSP/DAT/SNP in --
// and no RXREQ or TXSNP, which are the Home's.
//
// The port names and directions are the ones tools/mesh_generator's
// mesh_wrapper.j2 already expects of an 'RNF' node, so a generated mesh or ring
// connects this without a template change.
module rnf `RNF_PARAM
    (
    // global ports
    input  wire                 CLK,
    input  wire                 RST,

    // Chapter 15 system coherency interface. Not carried by the mesh: SS15.1
    // (p.15-466) makes it a direct pair between the Requester and the
    // interconnect, as hnf.sv has it.
    output wire                 SYSCOREQ,
    input  wire                 SYSCOACK,
    // SS15.2 (p.15-467): entering and leaving coherency is the Request Node's
    // own decision, and what prompts it is outside the CHI interface.
    input  wire                 COHERENCY_EN,

    // link handshake
    output wire                 TXSACTIVE,
    input  wire                 RXSACTIVE,
    output wire                 TXLINKACTIVEREQ,
    input  wire                 TXLINKACTIVEACK,
    input  wire                 RXLINKACTIVEREQ,
    output wire                 RXLINKACTIVEACK,

    // CHI transmit channels
    output wire                 TXREQFLITPEND,
    output wire                 TXREQFLITV,
    output chie_pkg::req_flit_s TXREQFLIT,
    input  wire                 TXREQLCRDV,
    output wire                 TXRSPFLITPEND,
    output wire                 TXRSPFLITV,
    output chie_pkg::rsp_flit_s TXRSPFLIT,
    input  wire                 TXRSPLCRDV,
    output wire                 TXDATFLITPEND,
    output wire                 TXDATFLITV,
    output chie_pkg::dat_flit_s TXDATFLIT,
    input  wire                 TXDATLCRDV,

    // CHI receive channels
    input  wire                 RXRSPFLITPEND,
    input  wire                 RXRSPFLITV,
    input  chie_pkg::rsp_flit_s RXRSPFLIT,
    output wire                 RXRSPLCRDV,
    input  wire                 RXDATFLITPEND,
    input  wire                 RXDATFLITV,
    input  chie_pkg::dat_flit_s RXDATFLIT,
    output wire                 RXDATLCRDV,
    input  wire                 RXSNPFLITPEND,
    input  wire                 RXSNPFLITV,
    input  chie_pkg::snp_flit_s RXSNPFLIT,
    output wire                 RXSNPLCRDV,

    // Core-side AXI4 subordinate: reads and writes both, the writes being what
    // makes a line Dirty and a CopyBack owed with it.
    input  wire [`AXI4_ARID_WIDTH-1:0]   ARID,
    input  wire [`AXI4_ARADDR_WIDTH-1:0] ARADDR,
    input  wire [`AXI4_ARLEN_WIDTH-1:0]  ARLEN,
    input  wire [`AXI4_ARSIZE_WIDTH-1:0] ARSIZE,
    input  wire                          ARVALID,
    output wire                          ARREADY,
    output wire [`AXI4_RID_WIDTH-1:0]    RID,
    output wire [`AXI4_RDATA_WIDTH-1:0]  RDATA,
    output wire [`AXI4_RRESP_WIDTH-1:0]  RRESP,
    output wire                          RLAST,
    output wire                          RVALID,
    input  wire                          RREADY,
    input  wire [`AXI4_AWID_WIDTH-1:0]   AWID,
    input  wire [`AXI4_AWADDR_WIDTH-1:0] AWADDR,
    input  wire [`AXI4_AWLEN_WIDTH-1:0]  AWLEN,
    input  wire [`AXI4_AWSIZE_WIDTH-1:0] AWSIZE,
    input  wire                          AWVALID,
    output wire                          AWREADY,
    input  wire [`AXI4_WDATA_WIDTH-1:0]  WDATA,
    input  wire [`AXI4_WSTRB_WIDTH-1:0]  WSTRB,
    input  wire                          WLAST,
    input  wire                          WVALID,
    output wire                          WREADY,
    output wire [`AXI4_BID_WIDTH-1:0]    BID,
    output wire [`AXI4_BRESP_WIDTH-1:0]  BRESP,
    output wire                          BVALID,
    input  wire                          BREADY
    );

    chie_pkg::req_flit_s prot_txreqflit;
    chie_pkg::rsp_flit_s prot_txrspflit;
    chie_pkg::dat_flit_s prot_txdatflit;
    wire                 prot_txreqflitv;
    wire                 prot_txrspflitv;
    wire                 prot_txdatflitv;
    wire                 prot_txreqflit_sent;
    wire                 prot_txrspflit_sent;
    wire                 prot_txdatflit_sent;
    chie_pkg::rsp_flit_s prot_rxrspflit;
    chie_pkg::dat_flit_s prot_rxdatflit;
    chie_pkg::snp_flit_s prot_rxsnpflit;
    wire                 prot_rxrspflitv;
    wire                 prot_rxdatflitv;
    wire                 prot_rxsnpflitv;
    wire                 prot_link_run;
    wire                 sysco_transition;

    wire                                 snp_lu_hit;
    wire [`RNF_CS_WIDTH-1:0]             snp_lu_state;
    wire [`RNF_WAY_W-1:0]                snp_lu_way;
    wire [`RNF_LINE_BITS-1:0]            snp_lu_data;
    wire                                 snp_lu_err;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_lu_addr;
    wire                                 snp_upd_v;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_upd_addr;
    wire [`RNF_WAY_W-1:0]                snp_upd_way;
    wire [`RNF_CS_WIDTH-1:0]             snp_upd_state;
    chie_pkg::rsp_flit_s                 snp_txrspflit;
    wire                                 snp_txrspflitv;
    chie_pkg::dat_flit_s                 snp_txdatflit;
    wire                                 snp_txdatflitv;
    wire                                 snp_busy;
    chie_pkg::rsp_flit_s                 ctl_txrspflit;
    wire                                 ctl_txrspflitv;

    chie_pkg::dat_flit_s                 ctl_txdatflit;
    wire                                 ctl_txdatflitv;
    wire                                 snp_pop;
    wire                                 ctl_defer_v;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] ctl_defer_addr;

    // A snoop response takes TXDAT ahead of a CopyBack, for the same reason it
    // takes TXRSP: SS4.11.1 (p.4-242, MUST) has the RN-F answer a snoop without
    // making it wait on a request of its own.
    assign prot_txdatflit  = snp_txdatflitv ? snp_txdatflit  : ctl_txdatflit;
    assign prot_txdatflitv = snp_txdatflitv | ctl_txdatflitv;

    wire                                 coh_enabled;
    wire                                 snoop_service_req;
    wire                                 txn_active;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_lu_addr;
    wire                                 cache_lu_hit;
    wire [`RNF_CS_WIDTH-1:0]             cache_lu_state;
    wire [`RNF_WAY_W-1:0]                cache_lu_way;
    wire [`RNF_LINE_BITS-1:0]            cache_lu_data;
    wire                                 cache_lu_err;
    wire [`RNF_WAY_W-1:0]                cache_vic_way;
    wire [`RNF_CS_WIDTH-1:0]             cache_vic_state;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_vic_addr;
    wire [`RNF_LINE_BITS-1:0]            cache_vic_data;
    wire                                 cache_vic_err;
    wire                                 cache_any_valid;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_flush_addr;
    wire [`RNF_WAY_W-1:0]                cache_flush_way;
    wire [`RNF_CS_WIDTH-1:0]             cache_flush_state;
    wire [`RNF_LINE_BITS-1:0]            cache_flush_data;
    wire                                 cache_flush_err;
    wire                                 ctl_upd_v;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] ctl_upd_addr;
    wire [`RNF_WAY_W-1:0]                ctl_upd_way;
    wire [`RNF_CS_WIDTH-1:0]             ctl_upd_state;
    wire                                 cache_fill_v;
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_fill_addr;
    wire [`RNF_WAY_W-1:0]                cache_fill_way;
    wire [`RNF_CS_WIDTH-1:0]             cache_fill_state;
    wire [`RNF_LINE_BITS-1:0]            cache_fill_data;
    wire                                 cache_fill_err;

    rnf_cache `RNF_PARAM_INST u_rnf_cache(
                      .clk_i        ( CLK              )
                     ,.rst_i        ( RST              )
                     ,.lu_addr_i    ( cache_lu_addr    )
                     ,.lu_hit_o     ( cache_lu_hit     )
                     ,.lu_state_o   ( cache_lu_state   )
                     ,.lu_way_o     ( cache_lu_way     )
                     ,.lu_data_o    ( cache_lu_data    )
                     ,.lu_err_o     ( cache_lu_err     )
                     ,.vic_way_o    ( cache_vic_way    )
                     ,.vic_state_o  ( cache_vic_state  )
                     ,.vic_addr_o   ( cache_vic_addr   )
                     ,.vic_data_o   ( cache_vic_data   )
                     ,.vic_err_o    ( cache_vic_err    )
                     ,.any_valid_o  ( cache_any_valid  )
                     ,.flush_addr_o ( cache_flush_addr )
                     ,.flush_way_o  ( cache_flush_way  )
                     ,.flush_state_o( cache_flush_state)
                     ,.flush_data_o ( cache_flush_data )
                     ,.flush_err_o  ( cache_flush_err  )
                     ,.fill_v_i     ( cache_fill_v     )
                     ,.fill_addr_i  ( cache_fill_addr  )
                     ,.fill_way_i   ( cache_fill_way   )
                     ,.fill_state_i ( cache_fill_state )
                     ,.fill_data_i  ( cache_fill_data  )
                     ,.fill_err_i   ( cache_fill_err   )
                     ,.snp_addr_i   ( snp_lu_addr      )
                     ,.snp_hit_o    ( snp_lu_hit       )
                     ,.snp_state_o  ( snp_lu_state     )
                     ,.snp_way_o    ( snp_lu_way       )
                     ,.snp_data_o   ( snp_lu_data      )
                     ,.snp_err_o    ( snp_lu_err       )
                     ,.upd_v_i      ( snp_upd_v        )
                     ,.upd_addr_i   ( snp_upd_addr     )
                     ,.upd_way_i    ( snp_upd_way      )
                     ,.upd_state_i  ( snp_upd_state    )
                     ,.upd2_v_i     ( ctl_upd_v        )
                     ,.upd2_addr_i  ( ctl_upd_addr     )
                     ,.upd2_way_i   ( ctl_upd_way      )
                     ,.upd2_state_i ( ctl_upd_state    )
                 );

    rnf_snp `RNF_PARAM_INST u_rnf_snp(
                      .clk_i                 ( CLK              )
                     ,.rst_i                 ( RST              )
                     ,.prot_rxsnpflitv_i     ( prot_rxsnpflitv  )
                     ,.prot_rxsnpflit_i      ( prot_rxsnpflit   )
                     ,.snp_pop_o             ( snp_pop          )
                     ,.defer_v_i             ( ctl_defer_v      )
                     ,.defer_addr_i          ( ctl_defer_addr   )
                     ,.cache_lu_addr_o       ( snp_lu_addr      )
                     ,.cache_lu_hit_i        ( snp_lu_hit       )
                     ,.cache_lu_state_i      ( snp_lu_state     )
                     ,.cache_lu_way_i        ( snp_lu_way       )
                     ,.cache_lu_data_i       ( snp_lu_data      )
                     ,.cache_lu_err_i        ( snp_lu_err       )
                     ,.cache_upd_v_o         ( snp_upd_v        )
                     ,.cache_upd_addr_o      ( snp_upd_addr     )
                     ,.cache_upd_way_o       ( snp_upd_way      )
                     ,.cache_upd_state_o     ( snp_upd_state    )
                     ,.snp_txrspflit_o       ( snp_txrspflit    )
                     ,.snp_txrspflitv_o      ( snp_txrspflitv   )
                     ,.snp_txrspflit_sent_i  ( prot_txrspflit_sent &  snp_txrspflitv )
                     ,.snp_txdatflit_o       ( snp_txdatflit    )
                     ,.snp_txdatflitv_o      ( snp_txdatflitv   )
                     ,.snp_txdatflit_sent_i  ( prot_txdatflit_sent )
                     ,.snp_busy_o            ( snp_busy         )
                 );

    // A snoop response takes the channel first: it is what releases the Home's
    // own transaction, and the CompAck behind it is this node's to hold.
    assign prot_txrspflit  = snp_txrspflitv ? snp_txrspflit  : ctl_txrspflit;
    assign prot_txrspflitv = snp_txrspflitv | ctl_txrspflitv;

    rnf_ctl `RNF_PARAM_INST u_rnf_ctl(
                      .clk_i                 ( CLK                  )
                     ,.rst_i                 ( RST                  )
                     ,.ARID                  ( ARID                 )
                     ,.ARADDR                ( ARADDR               )
                     ,.ARLEN                 ( ARLEN                )
                     ,.ARSIZE                ( ARSIZE               )
                     ,.ARVALID               ( ARVALID              )
                     ,.ARREADY               ( ARREADY              )
                     ,.RID                   ( RID                  )
                     ,.RDATA                 ( RDATA                )
                     ,.RRESP                 ( RRESP                )
                     ,.RLAST                 ( RLAST                )
                     ,.RVALID                ( RVALID               )
                     ,.RREADY                ( RREADY               )
                     ,.AWID                  ( AWID                 )
                     ,.AWADDR                ( AWADDR               )
                     ,.AWLEN                 ( AWLEN                )
                     ,.AWSIZE                ( AWSIZE               )
                     ,.AWVALID               ( AWVALID              )
                     ,.AWREADY               ( AWREADY              )
                     ,.WDATA                 ( WDATA                )
                     ,.WSTRB                 ( WSTRB                )
                     ,.WLAST                 ( WLAST                )
                     ,.WVALID                ( WVALID               )
                     ,.WREADY                ( WREADY               )
                     ,.BID                   ( BID                  )
                     ,.BRESP                 ( BRESP                )
                     ,.BVALID                ( BVALID               )
                     ,.BREADY                ( BREADY               )
                     ,.cache_lu_addr_o       ( cache_lu_addr        )
                     ,.cache_lu_hit_i        ( cache_lu_hit         )
                     ,.cache_lu_state_i      ( cache_lu_state       )
                     ,.cache_lu_way_i        ( cache_lu_way         )
                     ,.cache_lu_data_i       ( cache_lu_data        )
                     ,.cache_lu_err_i        ( cache_lu_err         )
                     ,.cache_vic_way_i       ( cache_vic_way        )
                     ,.cache_vic_state_i     ( cache_vic_state      )
                     ,.cache_vic_addr_i      ( cache_vic_addr       )
                     ,.cache_vic_data_i      ( cache_vic_data       )
                     ,.cache_vic_err_i       ( cache_vic_err        )
                     ,.cache_fill_v_o        ( cache_fill_v         )
                     ,.cache_fill_addr_o     ( cache_fill_addr      )
                     ,.cache_fill_way_o      ( cache_fill_way       )
                     ,.cache_fill_state_o    ( cache_fill_state     )
                     ,.cache_fill_data_o     ( cache_fill_data      )
                     ,.cache_fill_err_o      ( cache_fill_err       )
                     ,.cache_upd_v_o         ( ctl_upd_v            )
                     ,.cache_upd_addr_o      ( ctl_upd_addr         )
                     ,.cache_upd_way_o       ( ctl_upd_way          )
                     ,.cache_upd_state_o     ( ctl_upd_state        )
                     ,.snp_upd_v_i           ( snp_upd_v            )
                     ,.snp_upd_addr_i        ( snp_upd_addr         )
                     ,.snp_upd_way_i         ( snp_upd_way          )
                     ,.snp_upd_state_i       ( snp_upd_state        )
                     ,.prot_txreqflit_o      ( prot_txreqflit       )
                     ,.prot_txreqflitv_o     ( prot_txreqflitv      )
                     ,.prot_txreqflit_sent_i ( prot_txreqflit_sent  )
                     ,.prot_txrspflit_o      ( ctl_txrspflit        )
                     ,.prot_txrspflitv_o     ( ctl_txrspflitv       )
                     ,.prot_txrspflit_sent_i ( prot_txrspflit_sent & ~snp_txrspflitv )
                     ,.prot_txdatflit_o      ( ctl_txdatflit        )
                     ,.prot_txdatflitv_o     ( ctl_txdatflitv       )
                     ,.prot_txdatflit_sent_i ( prot_txdatflit_sent & ~snp_txdatflitv )
                     ,.prot_rxdatflitv_i     ( prot_rxdatflitv      )
                     ,.prot_rxdatflit_i      ( prot_rxdatflit       )
                     ,.prot_rxrspflitv_i     ( prot_rxrspflitv      )
                     ,.prot_rxrspflit_i      ( prot_rxrspflit       )
                     ,.coh_enabled_i         ( coh_enabled          )
                     ,.coh_req_i             ( COHERENCY_EN         )
                     ,.cache_any_valid_i     ( cache_any_valid      )
                     ,.cache_flush_addr_i    ( cache_flush_addr     )
                     ,.cache_flush_way_i     ( cache_flush_way      )
                     ,.cache_flush_state_i   ( cache_flush_state    )
                     ,.cache_flush_data_i    ( cache_flush_data     )
                     ,.cache_flush_err_i     ( cache_flush_err      )
                     ,.link_run_i            ( prot_link_run        )
                     ,.defer_v_o             ( ctl_defer_v          )
                     ,.defer_addr_o          ( ctl_defer_addr       )
                     ,.txn_active_o          ( txn_active           )
                 );

    rnf_link_ctl `RNF_PARAM_INST u_rnf_link_ctl(
                      .clk_i                 ( CLK                 )
                     ,.rst_i                 ( RST                 )
                     ,.TXLINKACTIVEREQ       ( TXLINKACTIVEREQ     )
                     ,.TXLINKACTIVEACK       ( TXLINKACTIVEACK     )
                     ,.RXLINKACTIVEREQ       ( RXLINKACTIVEREQ     )
                     ,.RXLINKACTIVEACK       ( RXLINKACTIVEACK     )
                     ,.TXREQFLITPEND         ( TXREQFLITPEND       )
                     ,.TXREQFLITV            ( TXREQFLITV          )
                     ,.TXREQFLIT             ( TXREQFLIT           )
                     ,.TXREQLCRDV            ( TXREQLCRDV          )
                     ,.TXRSPFLITPEND         ( TXRSPFLITPEND       )
                     ,.TXRSPFLITV            ( TXRSPFLITV          )
                     ,.TXRSPFLIT             ( TXRSPFLIT           )
                     ,.TXRSPLCRDV            ( TXRSPLCRDV          )
                     ,.TXDATFLITPEND         ( TXDATFLITPEND       )
                     ,.TXDATFLITV            ( TXDATFLITV          )
                     ,.TXDATFLIT             ( TXDATFLIT           )
                     ,.TXDATLCRDV            ( TXDATLCRDV          )
                     ,.RXRSPFLITPEND         ( RXRSPFLITPEND       )
                     ,.RXRSPFLITV            ( RXRSPFLITV          )
                     ,.RXRSPFLIT             ( RXRSPFLIT           )
                     ,.RXRSPLCRDV            ( RXRSPLCRDV          )
                     ,.RXDATFLITPEND         ( RXDATFLITPEND       )
                     ,.RXDATFLITV            ( RXDATFLITV          )
                     ,.RXDATFLIT             ( RXDATFLIT           )
                     ,.RXDATLCRDV            ( RXDATLCRDV          )
                     ,.RXSNPFLITPEND         ( RXSNPFLITPEND       )
                     ,.RXSNPFLITV            ( RXSNPFLITV          )
                     ,.RXSNPFLIT             ( RXSNPFLIT           )
                     ,.RXSNPLCRDV            ( RXSNPLCRDV          )
                     ,.prot_txreqflit_i      ( prot_txreqflit      )
                     ,.prot_txreqflitv_i     ( prot_txreqflitv     )
                     ,.prot_txreqflit_sent_o ( prot_txreqflit_sent )
                     ,.prot_txrspflit_i      ( prot_txrspflit      )
                     ,.prot_txrspflitv_i     ( prot_txrspflitv     )
                     ,.prot_txrspflit_sent_o ( prot_txrspflit_sent )
                     ,.prot_txdatflit_i      ( prot_txdatflit      )
                     ,.prot_txdatflitv_i     ( prot_txdatflitv     )
                     ,.prot_txdatflit_sent_o ( prot_txdatflit_sent )
                     ,.prot_rxrspflitv_o     ( prot_rxrspflitv     )
                     ,.prot_rxrspflit_o      ( prot_rxrspflit      )
                     ,.prot_rxdatflitv_o     ( prot_rxdatflitv     )
                     ,.prot_rxdatflit_o      ( prot_rxdatflit      )
                     ,.prot_rxsnpflitv_o     ( prot_rxsnpflitv     )
                     ,.prot_rxsnpflit_o      ( prot_rxsnpflit      )
                     ,.prot_snp_pop_i        ( snp_pop             )
                     ,.link_hold_i           ( COHERENCY_EN | snoop_service_req )
                     ,.prot_link_run_o       ( prot_link_run       )
                 );

    rnf_sysco u_rnf_sysco(
                      .clk_i                     ( CLK              )
                     ,.rst_i                     ( RST              )
                     ,.SYSCOREQ                  ( SYSCOREQ         )
                     ,.SYSCOACK                  ( SYSCOACK         )
                     ,.coh_req_i                 ( COHERENCY_EN     )
                     ,.caching_txn_outstanding_i ( txn_active | snp_busy )
                     ,.holds_coherent_data_i     ( cache_any_valid  )
                     ,.coh_enabled_o             ( coh_enabled      )
                     ,.snoop_service_req_o       ( snoop_service_req )
                     ,.sysco_transition_o        ( sysco_transition )
                 );

    // SS14.7.1 (p.14-460): TXSACTIVE reports "a transaction either in progress or
    // about to start", which SS14.7.4 (p.14-463) makes orthogonal to LINKACTIVE --
    // so it is derived from this node's own work, never from the handshake.
    // SS15.2.1 (p.15-467, MUST) adds the coherency transitions: SACTIVE must be
    // asserted across them "to guarantee the SYSCOACK transition occurs".
    assign TXSACTIVE = (txn_active | snp_busy | prot_txreqflitv | prot_txrspflitv | prot_txdatflitv
                        | sysco_transition) & (~RST);

endmodule
