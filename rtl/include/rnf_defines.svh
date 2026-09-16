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

`ifndef RNF_DEFINES_V
`define RNF_DEFINES_V

// CHI E.b SS4.1 (p.4-160): the seven cache states an RN-F line can hold.
// SS4.1.1 (p.4-161) makes UCE ownership without valid bytes, and UDP a Unique
// Dirty line only some of whose bytes are valid.
`define RNF_CS_WIDTH   3
`define RNF_CS_I       3'd0
`define RNF_CS_SC      3'd1
`define RNF_CS_UC      3'd2
`define RNF_CS_UD      3'd3
`define RNF_CS_SD      3'd4
`define RNF_CS_UCE     3'd5
`define RNF_CS_UDP     3'd6

// A line is 64 bytes throughout CHI (SS2.10.1 p.2-133).
`define RNF_LINE_BYTES 64
`define RNF_LINE_BITS  512
`define RNF_LINE_OFFSET_W 6

`define RNF_SET_W  ((RNF_CACHE_SETS_PARAM == 1) ? 1 : $clog2(RNF_CACHE_SETS_PARAM))
`define RNF_WAY_W  ((RNF_CACHE_WAYS_PARAM == 1) ? 1 : $clog2(RNF_CACHE_WAYS_PARAM))
`define RNF_TAG_W  (CHIE_REQ_ADDR_WIDTH_PARAM - `RNF_LINE_OFFSET_W - `RNF_SET_W)

`define RNF_MSHR_W ((RNF_MSHR_ENTRIES_PARAM == 1) ? 1 : $clog2(RNF_MSHR_ENTRIES_PARAM))

`endif
