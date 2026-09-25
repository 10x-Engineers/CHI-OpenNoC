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
  // The sideband layouts axi4_defines.svh declares: Poison plus the Chapter 12
  // tags on the data channels, MPAM plus TagOp/TagGroupID on the address ones.
  // `AXI4_WUSER_WIDTH is written over a module parameter, so the same layout is
  // restated here against this package's own DATA_WIDTH; opennoc_axi_user_check
  // holds the two equal.
  parameter int USER_WIDTH    = (DATA_WIDTH/64) + (DATA_WIDTH/32) + (DATA_WIDTH/128);
  parameter int AX_USER_WIDTH = `AXI4_AWUSER_WIDTH;
  parameter int B_USER_WIDTH  = `AXI4_BUSER_WIDTH;

  typedef struct packed {
    logic [AX_USER_WIDTH-1:0] user;
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
    logic [USER_WIDTH-1:0]  user;
    logic [STRB_WIDTH-1:0]  strb;
    logic [DATA_WIDTH-1:0]  data;
  } w_ch_s;

  typedef struct packed {
    logic [B_USER_WIDTH-1:0] user;
    logic [1:0]           resp;
    logic [ID_WIDTH-1:0]  id;
  } b_ch_s;

  typedef struct packed {
    logic                   last;
    logic [USER_WIDTH-1:0]  user;
    logic [1:0]             resp;
    logic [DATA_WIDTH-1:0]  data;
    logic [ID_WIDTH-1:0]    id;
  } r_ch_s;

  // AXI4 (IHI 0022) A4.4: AxCACHE Modifiable with a Read- or Write-Allocate
  // hint, the accesses this bridge carries as Cacheable CHI requests.
  function automatic logic axi_cacheable(logic [3:0] cache);
    return cache[1] & (|cache[3:2]);
  endfunction

  // SS2.10.4 (p.2-136), Table 2-15: a CHI data packet carries Data_Width/128 of the
  // line's 16-byte chunks, and its DataID is the first of them.
  parameter int PKT_CHUNKS = chie_pkg::DATA_WIDTH / 128;

  function automatic logic [3:0] dat_chunks(logic [1:0] dataid);
    return 4'(((5'd1 << PKT_CHUNKS) - 5'd1) << dataid);
  endfunction

  // The chunks of every packet that holds any of `chunks`.
  function automatic logic [3:0] pkt_cover(logic [3:0] chunks);
    for (int c = 0; c < 4; c++)
      pkt_cover[c] = |chunks[(c / PKT_CHUNKS) * PKT_CHUNKS +: PKT_CHUNKS];
  endfunction

  // SS2.10.4 (p.2-136): the packet count follows the Size field and the data width,
  // so a transaction's packets are those of its Size-aligned container (SS2.10.2
  // p.2-134), whichever of its bytes carry data.
  function automatic logic [3:0] size_pkts(chie_pkg::size_e size, logic [1:0] ccid);
    logic [3:0] chunks;
    case (size)
      chie_pkg::SIZE_64B: chunks = 4'b1111;
      chie_pkg::SIZE_32B: chunks = ccid[1] ? 4'b1100 : 4'b0011;
      default:            chunks = 4'b0001 << ccid;
    endcase
    return pkt_cover(chunks);
  endfunction

  // The chunks of the packet a Requester sends next from `pend`: the one holding the
  // critical chunk first, the rest in line order after it.
  function automatic logic [3:0] next_pkt(logic [3:0] pend, logic [1:0] ccid);
    logic [1:0] c;
    next_pkt = 4'b0000;
    for (int k = 3; k >= 0; k--) begin
      c = ccid + 2'(k);
      if (pend[c]) next_pkt = dat_chunks(c & 2'(~(PKT_CHUNKS - 1)));
    end
  endfunction

  // The read-data FIFO entry: an R beat plus the byte count RN-I tracks
  // alongside it, which the AXI R channel has no field for.
  typedef struct packed {
    logic [`RNI_BC_WIDTH-1:0] bc;
    r_ch_s                    r;
  } r_bc_s;

  // The one held credit rni_misc offers the AR and AW controllers at a time.
  // SS2.11 (p.2-146) gives a credit no identity beyond its type -- "There is no
  // fixed relationship between credits and particular transactions" -- so this is
  // an offer of a PCrdType, named with the node IDs SS2.6.5 (p.2-112) fixes for
  // the grant that produced it, not a copy of one arrived flit.
  typedef struct packed {
    logic [3:0]                     pcrdtype;
    logic [chie_pkg::NID_WIDTH-1:0] srcid;
    logic [chie_pkg::NID_WIDTH-1:0] tgtid;
  } pcrdgrant_pkt_s;

  // One AXI write response held between the CHI completion and the B channel.
  typedef struct packed {
    logic [`AXI4_BID_WIDTH-1:0]  axid;
    chie_pkg::resp_err_e         resperr;
    logic [`AXI4_BUSER_WIDTH-1:0] buser;
    logic                        last;
  } brsp_fifo_s;

endpackage

`endif
