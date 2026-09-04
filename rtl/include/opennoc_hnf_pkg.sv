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

`ifndef OPENNOC_HNF_PKG_SV
`define OPENNOC_HNF_PKG_SV

// The name is prefixed because this design is compiled into whatever
// namespace integrates it, and a node-local package name like rni_pkg or
// hnf_pkg is one an integrator is likely to have already.
package opennoc_hnf_pkg;

  // The SNP flit together with the snoopee it is addressed to. Table 13-8
  // (SS13.6 p.13-421) gives the SNP channel no TgtID -- the interconnect routes
  // the snoop -- so this NodeID is HN-F's own routing envelope and travels
  // beside the flit rather than in it.
  typedef struct packed {
    logic [chie_pkg::NID_WIDTH-1:0] tgtid;
    chie_pkg::snp_flit_s            flit;
  } snp_routed_s;

endpackage

`endif
