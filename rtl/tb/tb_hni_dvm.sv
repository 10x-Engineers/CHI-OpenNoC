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
// =============================================================================
// tb_hni_dvm -- the DVMOp an HN-I answers without being an MN (tb_home_dvm_peer.svh).
// The AXI side is tied ready and idle: an errored DVMOp reaches no endpoint.
// =============================================================================
`include "axi4_defines.svh"
`include "hni_defines.svh"
`include "hni_param.svh"

module tb_hni_dvm;

    localparam string BENCH = "tb_hni_dvm";
    localparam RN_NID       = 8;
    localparam HOME_NID     = 0;

`include "tb_home_dvm_peer.svh"

    hni u_hni (
        .CLK(CLK), .RST(RST),
        .TXLINKACTIVEREQ(TXLINKACTIVEREQ), .TXLINKACTIVEACK(TXLINKACTIVEACK),
        .RXLINKACTIVEREQ(RXLINKACTIVEREQ), .RXLINKACTIVEACK(RXLINKACTIVEACK),
        .TXSACTIVE(TXSACTIVE), .RXSACTIVE(RXSACTIVE),
        .RXREQFLITV(RXREQFLITV), .RXREQFLIT(RXREQFLIT), .RXREQFLITPEND(RXREQFLITPEND), .RXREQLCRDV(RXREQLCRDV),
        .RXRSPFLITV(RXRSPFLITV), .RXRSPFLIT(RXRSPFLIT), .RXRSPFLITPEND(RXRSPFLITPEND), .RXRSPLCRDV(RXRSPLCRDV),
        .RXDATFLITV(RXDATFLITV), .RXDATFLIT(RXDATFLIT), .RXDATFLITPEND(RXDATFLITPEND), .RXDATLCRDV(RXDATLCRDV),
        .TXRSPFLITV(TXRSPFLITV), .TXRSPFLIT(TXRSPFLIT), .TXRSPFLITPEND(TXRSPFLITPEND), .TXRSPLCRDV(TXRSPLCRDV),
        .TXDATFLITV(TXDATFLITV), .TXDATFLIT(TXDATFLIT), .TXDATFLITPEND(TXDATFLITPEND), .TXDATLCRDV(TXDATLCRDV),
        .ARID(), .ARADDR(), .ARLEN(), .ARSIZE(), .ARBURST(), .ARLOCK(), .ARCACHE(), .ARPROT(),
        .ARQOS(), .ARREGION(), .ARUSER(), .ARVALID(), .ARREADY(1'b1),
        .RID('0), .RDATA('0), .RUSER('0), .RRESP('0), .RLAST(1'b0), .RVALID(1'b0), .RREADY(),
        .AWID(), .AWADDR(), .AWLEN(), .AWSIZE(), .AWBURST(), .AWLOCK(), .AWCACHE(), .AWPROT(),
        .AWQOS(), .AWREGION(), .AWUSER(), .AWVALID(), .AWREADY(1'b1),
        .WDATA(), .WUSER(), .WSTRB(), .WLAST(), .WVALID(), .WREADY(1'b1),
        .BID('0), .BRESP('0), .BVALID(1'b0), .BREADY()
    );

endmodule
