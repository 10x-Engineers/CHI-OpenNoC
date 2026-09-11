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
*    Li Zhao <lizhao@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

`ifndef AXI_DEFINES
`define AXI_DEFINES

// ---------------------------------------------------------------------------
// USER sidebands. AMBA AXI4 (IHI 0022) A2 leaves the width and meaning of the
// *USER signals IMPLEMENTATION DEFINED, which is what lets a CHI field with no
// native AXI encoding cross this boundary at all.
//
// CHI E.b section 9.5 (p.9-347, MUST): "The Poison value, once set, must be
// propagated along with the data", at one bit per 64 bits of data. AXI4 has no
// poison bit, so without this sideband a poisoned write reaching memory would be
// stored clean and served back clean, which that MUST forbids.
//
// The layout is a contract with whatever drives the other side of the port. The CHI
// VIP's axi4_if (10x-Engineers/amba-chi-vip) mirrors it, and opennoc_axi_width_check
// holds the two equal. Fields are appended at the MSB end, so adding MTE's Tag/TU
// later does not move Poison.
//
// CHI E.b section 11.3 (p.11-365) gives MPAM the address channels, and section 11.3.4
// (p.11-366, MUST) makes a Home's downstream request carry the MPAM of the request that
// generated it -- at an HN-I that downstream face is this AXI port. The width does not
// follow `CHIE_MPAM_PRESENT: AXI USER has no presence property and a zero-width port is
// illegal, so the sideband is always here and the CHI side decides what reads it.
//
//   W/RUSER[P-1:0]   Poison,  P = data width / 64
//   AW/ARUSER[10:0]  MPAM,    section 11.3 Figure 11-3's subdivision
// ---------------------------------------------------------------------------
`define AXI4_POISON_WIDTH        (`AXI4_WDATA_WIDTH/64)
`define AXI4_WUSER_WIDTH         `AXI4_POISON_WIDTH
`define AXI4_RUSER_WIDTH         `AXI4_POISON_WIDTH
`define AXI4_USER_POISON_RANGE   `AXI4_POISON_WIDTH-1:0
`define AXI4_MPAM_WIDTH          11
`define AXI4_AWUSER_WIDTH        `AXI4_MPAM_WIDTH
`define AXI4_ARUSER_WIDTH        `AXI4_MPAM_WIDTH
`define AXI4_USER_MPAM_RANGE     `AXI4_MPAM_WIDTH-1:0

// AXI4 interface
// AXI4 write address channel fields
`define AXI4_AWID_WIDTH       11
`define AXI4_AWID_LSB         0
`define AXI4_AWID_MSB         10
`define AXI4_AWID_RANGE       10:0
`define AXI4_AWADDR_WIDTH     AXI4_PA_WIDTH_PARAM
`define AXI4_AWADDR_LSB       11
`define AXI4_AWADDR_MSB       AXI4_PA_WIDTH_PARAM+11-1
`define AXI4_AWADDR_RANGE     AXI4_PA_WIDTH_PARAM+11-1:11
`define AXI4_AWLEN_WIDTH      8
`define AXI4_AWLEN_LSB        AXI4_PA_WIDTH_PARAM+11
`define AXI4_AWLEN_MSB        AXI4_PA_WIDTH_PARAM+11+8-1
`define AXI4_AWLEN_RANGE      AXI4_PA_WIDTH_PARAM+11+8-1:AXI4_PA_WIDTH_PARAM+11
`define AXI4_AWSIZE_WIDTH     3 
`define AXI4_AWSIZE_LSB       AXI4_PA_WIDTH_PARAM+11+8
`define AXI4_AWSIZE_MSB       AXI4_PA_WIDTH_PARAM+11+8+3-1
`define AXI4_AWSIZE_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3-1:AXI4_PA_WIDTH_PARAM+11+8
`define AXI4_AWBURST_WIDTH    2 
`define AXI4_AWBURST_LSB      AXI4_PA_WIDTH_PARAM+11+8+3
`define AXI4_AWBURST_MSB      AXI4_PA_WIDTH_PARAM+11+8+3+2-1
`define AXI4_AWBURST_RANGE    AXI4_PA_WIDTH_PARAM+11+8+3+2-1:AXI4_PA_WIDTH_PARAM+11+8+3
`define AXI4_AWLOCK_WIDTH     1 
`define AXI4_AWLOCK_LSB       AXI4_PA_WIDTH_PARAM+11+8+3+2
`define AXI4_AWLOCK_MSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1-1
`define AXI4_AWLOCK_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3+2+1-1:AXI4_PA_WIDTH_PARAM+11+8+3+2
`define AXI4_AWCACHE_WIDTH    4 
`define AXI4_AWCACHE_LSB      AXI4_PA_WIDTH_PARAM+11+8+3+2+1
`define AXI4_AWCACHE_MSB      AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4-1
`define AXI4_AWCACHE_RANGE    AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1
`define AXI4_AWPROT_WIDTH     3 
`define AXI4_AWPROT_LSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4
`define AXI4_AWPROT_MSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3-1
`define AXI4_AWPROT_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4
`define AXI4_AWQOS_WIDTH      4 
`define AXI4_AWQOS_LSB        AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3
`define AXI4_AWQOS_MSB        AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4-1
`define AXI4_AWQOS_RANGE      AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3
`define AXI4_AWREGION_WIDTH   4 
`define AXI4_AWREGION_LSB     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4
`define AXI4_AWREGION_MSB     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1
`define AXI4_AWREGION_RANGE   AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4
`define AXI4_AW_RANGE         AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1:0

// AXI4 write data channel fields
`define AXI4_WDATA_WIDTH      AXI4_AXDATA_WIDTH_PARAM
`define AXI4_WDATA_LSB        0
`define AXI4_WDATA_MSB        AXI4_AXDATA_WIDTH_PARAM-1
`define AXI4_WDATA_RANGE      AXI4_AXDATA_WIDTH_PARAM-1:0
`define AXI4_WSTRB_WIDTH      AXI4_AXDATA_WIDTH_PARAM/8
`define AXI4_WSTRB_LSB        AXI4_AXDATA_WIDTH_PARAM
`define AXI4_WSTRB_MSB        (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM-1
`define AXI4_WSTRB_RANGE      (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM-1:AXI4_AXDATA_WIDTH_PARAM
`define AXI4_WLAST_WIDTH      1
`define AXI4_WLAST_LSB        (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM
`define AXI4_WLAST_MSB        (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM+1-1
`define AXI4_WLAST_RANGE      (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM+1-1:(AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM
`define AXI4_W_RANGE          (AXI4_AXDATA_WIDTH_PARAM/8)+AXI4_AXDATA_WIDTH_PARAM+1-1:0

// AXI4 write response channel fields
`define AXI4_BID_WIDTH        11
`define AXI4_BID_LSB          0
`define AXI4_BID_MSB          10
`define AXI4_BID_RANGE        10:0
`define AXI4_BRESP_WIDTH      2
`define AXI4_BRESP_LSB        11
`define AXI4_BRESP_MSB        11+2-1
`define AXI4_BRESP_RANGE      11+2-1:11
`define AXI4_B_WIDTH          11+2
`define AXI4_B_RANGE          11+2-1:0

// AXI4 read address channel fields
`define AXI4_ARID_WIDTH       11
`define AXI4_ARID_LSB         0
`define AXI4_ARID_MSB         10
`define AXI4_ARID_RANGE       10:0
`define AXI4_ARADDR_WIDTH     AXI4_PA_WIDTH_PARAM
`define AXI4_ARADDR_LSB       11
`define AXI4_ARADDR_MSB       AXI4_PA_WIDTH_PARAM+11-1
`define AXI4_ARADDR_RANGE     AXI4_PA_WIDTH_PARAM+11-1:11
`define AXI4_ARLEN_WIDTH      8
`define AXI4_ARLEN_LSB        AXI4_PA_WIDTH_PARAM+11
`define AXI4_ARLEN_MSB        AXI4_PA_WIDTH_PARAM+11+8-1
`define AXI4_ARLEN_RANGE      AXI4_PA_WIDTH_PARAM+11+8-1:AXI4_PA_WIDTH_PARAM+11
`define AXI4_ARSIZE_WIDTH     3
`define AXI4_ARSIZE_LSB       AXI4_PA_WIDTH_PARAM+11+8
`define AXI4_ARSIZE_MSB       AXI4_PA_WIDTH_PARAM+11+8+3-1
`define AXI4_ARSIZE_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3-1:AXI4_PA_WIDTH_PARAM+11+8
`define AXI4_ARBURST_WIDTH    2
`define AXI4_ARBURST_LSB      AXI4_PA_WIDTH_PARAM+11+8+3
`define AXI4_ARBURST_MSB      AXI4_PA_WIDTH_PARAM+11+8+3+2-1
`define AXI4_ARBURST_RANGE    AXI4_PA_WIDTH_PARAM+11+8+3+2-1:AXI4_PA_WIDTH_PARAM+11+8+3
`define AXI4_ARLOCK_WIDTH     1
`define AXI4_ARLOCK_LSB       AXI4_PA_WIDTH_PARAM+11+8+3+2
`define AXI4_ARLOCK_MSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1-1
`define AXI4_ARLOCK_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3+2+1-1:AXI4_PA_WIDTH_PARAM+11+8+3+2 
`define AXI4_ARCACHE_WIDTH    4 
`define AXI4_ARCACHE_LSB      AXI4_PA_WIDTH_PARAM+11+8+3+2+1
`define AXI4_ARCACHE_MSB      AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4-1
`define AXI4_ARCACHE_RANGE    AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1
`define AXI4_ARPROT_WIDTH     3
`define AXI4_ARPROT_LSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4
`define AXI4_ARPROT_MSB       AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3-1
`define AXI4_ARPROT_RANGE     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4
`define AXI4_ARQOS_WIDTH      4
`define AXI4_ARQOS_LSB        AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3
`define AXI4_ARQOS_MSB        AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4-1
`define AXI4_ARQOS_RANGE      AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3
`define AXI4_ARREGION_WIDTH   4
`define AXI4_ARREGION_LSB     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4
`define AXI4_ARREGION_MSB     AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1
`define AXI4_ARREGION_RANGE   AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1:AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4
`define AXI4_AR_RANGE         AXI4_PA_WIDTH_PARAM+11+8+3+2+1+4+3+4+4-1:0

// AXI4 read data channel fields
`define AXI4_RID_WIDTH        11
`define AXI4_RID_LSB          0
`define AXI4_RID_MSB          10
`define AXI4_RID_RANGE        10:0
`define AXI4_RDATA_WIDTH      AXI4_AXDATA_WIDTH_PARAM
`define AXI4_RDATA_LSB        11
`define AXI4_RDATA_MSB        AXI4_AXDATA_WIDTH_PARAM+11-1
`define AXI4_RDATA_RANGE      AXI4_AXDATA_WIDTH_PARAM+11-1:11
`define AXI4_RRESP_WIDTH      2
`define AXI4_RRESP_LSB        AXI4_AXDATA_WIDTH_PARAM+11
`define AXI4_RRESP_MSB        AXI4_AXDATA_WIDTH_PARAM+11+2-1
`define AXI4_RRESP_RANGE      AXI4_AXDATA_WIDTH_PARAM+11+2-1:AXI4_AXDATA_WIDTH_PARAM+11
`define AXI4_RLAST_WIDTH      1
`define AXI4_RLAST_LSB        AXI4_AXDATA_WIDTH_PARAM+11+2
`define AXI4_RLAST_MSB        AXI4_AXDATA_WIDTH_PARAM+11+2+1-1
`define AXI4_RLAST_RANGE      AXI4_AXDATA_WIDTH_PARAM+11+2+1-1:AXI4_AXDATA_WIDTH_PARAM+11+2
`define AXI4_R_RANGE          AXI4_AXDATA_WIDTH_PARAM+11+2+1-1:0

`endif