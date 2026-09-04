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

// One CHI channel's link-layer signals. CHI E.b SS13.2 (p.13-394) gives every
// channel the same four: the flit, its FLITV, its FLITPEND, and the L-Credit the
// Receiver returns on. They are always used together, so travelling together is
// what stops one channel's FLITV reaching another channel's flit.
//
// Node port lists stay flat -- an integrator wires those -- so this is bound at
// the node top and carried inward from there.
`ifndef CHI_CHAN_IF_SV
`define CHI_CHAN_IF_SV

interface chi_chan_if #(parameter type FLIT_T = logic) ();

  logic  flitv;
  FLIT_T flit;
  logic  flitpend;
  logic  lcrdv;      // Receiver -> Transmitter, so it is the one signal that
                     // travels against the flit direction on both modports

  modport tx (output flitv, output flit, output flitpend, input  lcrdv);
  modport rx (input  flitv, input  flit, input  flitpend, output lcrdv);

endinterface

`endif
