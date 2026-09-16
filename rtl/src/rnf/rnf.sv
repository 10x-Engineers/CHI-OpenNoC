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
    output wire                 RXSNPLCRDV
    );

    // Protocol layer interface: this Requester presents no flit, so the link
    // carries none. Chapter 14 below answers no differently for it.
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

    assign prot_txreqflit  = '0;
    assign prot_txrspflit  = '0;
    assign prot_txdatflit  = '0;
    assign prot_txreqflitv = 1'b0;
    assign prot_txrspflitv = 1'b0;
    assign prot_txdatflitv = 1'b0;

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
                     ,.prot_link_run_o       ( prot_link_run       )
                 );

    rnf_sysco u_rnf_sysco(
                      .clk_i                     ( CLK              )
                     ,.rst_i                     ( RST              )
                     ,.SYSCOREQ                  ( SYSCOREQ         )
                     ,.SYSCOACK                  ( SYSCOACK         )
                     ,.coh_req_i                 ( COHERENCY_EN     )
                     ,.caching_txn_outstanding_i ( 1'b0             )
                     ,.holds_coherent_data_i     ( 1'b0             )
                     ,.coh_enabled_o             (                  )
                     ,.snoop_service_req_o       (                  )
                     ,.sysco_transition_o        ( sysco_transition )
                 );

    // SS14.7.1 (p.14-460): TXSACTIVE reports "a transaction either in progress or
    // about to start", which SS14.7.4 (p.14-463) makes orthogonal to LINKACTIVE --
    // so it is derived from this node's own work, never from the handshake.
    // SS15.2.1 (p.15-467, MUST) adds the coherency transitions: SACTIVE must be
    // asserted across them "to guarantee the SYSCOACK transition occurs".
    assign TXSACTIVE = (prot_txreqflitv | prot_txrspflitv | prot_txdatflitv
                        | sysco_transition) & (~RST);

endmodule
