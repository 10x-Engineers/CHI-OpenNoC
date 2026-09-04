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
*/

`ifndef OPENNOC_RNI_PKG_SV
`define OPENNOC_RNI_PKG_SV

`include "axi4_defines.svh"
`include "rni_defines.svh"

// RN-I's AXI port is the manager side, so its address width is the full PA and
// not the 32 bits SN-F and HN-I face memory with. Seeded by `define so the
// integration that instantiates the node can override it, exactly as chie_pkg's
// SS16.1 widths are.
`ifndef AXI4_PA_WIDTH
  `define AXI4_PA_WIDTH 44
`endif
`ifndef AXI4_DATA_WIDTH
  `define AXI4_DATA_WIDTH 128
`endif

// The name is prefixed because this design is compiled into whatever
// namespace integrates it, and a node-local package name like rni_pkg or
// hnf_pkg is one an integrator is likely to have already.
package opennoc_rni_pkg;

  // ---------------------------------------------------------------------------
  // AXI4 channels, as types rather than bit ranges. AMBA AXI4 (IHI 0022) A2
  // names the signals; the packing below is RN-I's own -- the channels are
  // internal to this node, since its port list carries every AXI signal
  // separately -- and was a running-sum macro set with the same unchecked
  // ranges the CHI flits had.
  //
  // Field order is MSB-first, so the declaration reads as the packet diagram
  // does. No enums: within RN-I these fields are plumbed, never decoded
  // against a named encoding, so an enum would buy waveform naming at the cost
  // of a cast on every masked-OR select.
  // ---------------------------------------------------------------------------
  parameter int PA_WIDTH   = `AXI4_PA_WIDTH;
  parameter int DATA_WIDTH = `AXI4_DATA_WIDTH;
  parameter int STRB_WIDTH = DATA_WIDTH / 8;
  parameter int ID_WIDTH   = `AXI4_AWID_WIDTH;

  typedef struct packed {
    logic [3:0]           region;
    logic [3:0]           qos;
    logic [2:0]           prot;
    logic [3:0]           cache;
    logic                 lock;
    logic [1:0]           burst;
    logic [2:0]           size;
    logic [7:0]           len;
    logic [PA_WIDTH-1:0]  addr;
    logic [ID_WIDTH-1:0]  id;
  } ax_ch_s;                       // AW and AR carry the same fields

  typedef struct packed {
    logic                   last;
    logic [STRB_WIDTH-1:0]  strb;
    logic [DATA_WIDTH-1:0]  data;
  } w_ch_s;

  typedef struct packed {
    logic [1:0]           resp;
    logic [ID_WIDTH-1:0]  id;
  } b_ch_s;

  typedef struct packed {
    logic                   last;
    logic [1:0]             resp;
    logic [DATA_WIDTH-1:0]  data;
    logic [ID_WIDTH-1:0]    id;
  } r_ch_s;

  // The read-data FIFO entry: an R beat plus the byte count RN-I tracks
  // alongside it, which the AXI R channel has no field for.
  typedef struct packed {
    logic [`RNI_BC_WIDTH-1:0] bc;
    r_ch_s                    r;
  } r_bc_s;

  // What the RSP parse stage forwards to the AR and AW controllers when a
  // PCrdGrant lands: the grant has to be matched to the request that was
  // retried, which SS2.11 (p.2-145) keys on the pair plus PCrdType.
  typedef struct packed {
    logic [3:0]                     pcrdtype;
    logic [chie_pkg::NID_WIDTH-1:0] srcid;
    logic [chie_pkg::NID_WIDTH-1:0] tgtid;
  } pcrdgrant_pkt_s;

  // One AXI write response held between the CHI completion and the B channel.
  typedef struct packed {
    logic [`AXI4_BID_WIDTH-1:0] axid;
    chie_pkg::resp_err_e        resperr;
    logic                       last;
  } brsp_fifo_s;

endpackage

`endif
