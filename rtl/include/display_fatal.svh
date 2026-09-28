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

// The design's own fatal checks, shared by every node that states one. Compiled
// only under DISPLAY_FATAL.

`ifndef DISPLAY_FATAL_SVH
`define DISPLAY_FATAL_SVH

`ifdef DISPLAY_FATAL
// Elaborate once per module that uses `display_fatal, beside its clk/rst: the
// checks are live from time 0 otherwise, over registers reset has not reached.
`define display_fatal_arm                                                     \
    logic __df_rst_applied = 1'b0;                                            \
    always @(posedge clk or posedge rst)                                      \
        if (rst === 1'b1) __df_rst_applied <= 1'b1;                           \
    wire  __df_armed = (rst === 1'b0) && (__df_rst_applied === 1'b1);
// Procedural form, for a check already inside a clocked always block.
`define display_fatal(flag,info)              if(__df_armed && !(flag)) $fatal(1, info);
// Module-scope form: samples in the Preponed region, so a check over signals
// that settle in different deltas cannot see a glitched combination.
`define display_fatal_sva(flag,info)                                          \
    assert property (@(posedge clk) disable iff (!__df_armed) (flag))         \
    else $fatal(1, info);
`endif

`endif
