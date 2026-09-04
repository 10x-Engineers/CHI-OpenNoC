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

// The name is prefixed because this design is compiled into whatever
// namespace integrates it, and a node-local package name like rni_pkg or
// hnf_pkg is one an integrator is likely to have already.
package opennoc_rni_pkg;

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
