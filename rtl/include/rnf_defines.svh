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

// What a cached line carries beside its bytes: DERR on the data it was filled
// from (SS9.4.1 p.9-337), the Poison of each 64-bit chunk (SS9.5 p.9-347), and
// the bytes that are valid, which only a UDP line leaves short of all 64
// (SS4.1.1 p.4-161). SS9.8 (p.9-352) sets DERR and Poison independently.
`define RNF_META_W       73
`define RNF_META_DERR    72
`define RNF_META_POISON  71:64
`define RNF_META_VMASK   63:0
`define RNF_META_FULL    {1'b0, 8'h00, 64'hFFFF_FFFF_FFFF_FFFF}

`define RNF_MSHR_W ((RNF_MSHR_ENTRIES_PARAM == 1) ? 1 : $clog2(RNF_MSHR_ENTRIES_PARAM))

// Core-side intent, IMPLEMENTATION DEFINED. ARCOH qualifies ARVALID: the read a
// miss issues (Table 4-4 p.4-167). The ReadOnce family is non-allocating, so the
// line is not cached. 3'd7 is reserved and reads as SHARED.
`define RNF_AR_COH_W          3
`define RNF_AR_SHARED         3'd0
`define RNF_AR_CLEAN          3'd1
`define RNF_AR_PREFER_UNIQUE  3'd2
`define RNF_AR_UNIQUE         3'd3
`define RNF_AR_ONCE           3'd4
`define RNF_AR_ONCE_CLEAN_INV 3'd5
`define RNF_AR_ONCE_MAKE_INV  3'd6

// AWCOH qualifies AWVALID. READ_UNIQUE upgrades a Shared line with MakeReadUnique
// instead of CleanUnique; IMMEDIATE writes an uncached line with WriteUnique
// (Table 4-16 p.4-181), and IMMEDIATE_CLEANSH combines it with CleanShared.
// PARTIAL keeps a partial store of an uncached line as the bytes written: a
// CleanUnique from I ends UCE (Table 4-38 p.4-218) and the store makes it UDP
// (Table 4-32 p.4-209). 3'd5..3'd7 are reserved and read as CACHED.
`define RNF_AW_COH_W          3
`define RNF_AW_CACHED         3'd0
`define RNF_AW_READ_UNIQUE    3'd1
`define RNF_AW_IMMEDIATE      3'd2
`define RNF_AW_IMMEDIATE_CLSH 3'd3
`define RNF_AW_PARTIAL        3'd4

// Cache maintenance port: one operation on one line, answered on CMDONE/CMRESP.
`define RNF_CM_OP_W               4
`define RNF_CM_EVICT_SILENT       4'd0
`define RNF_CM_EVICT_NOTIFY       4'd1
`define RNF_CM_EVICT_RETURN       4'd2
`define RNF_CM_EVICT_OFFER        4'd3
`define RNF_CM_CLEAN              4'd4
`define RNF_CM_CLEAN_SHARED       4'd5
`define RNF_CM_CLEAN_SHARED_EVICT 4'd6
`define RNF_CM_CLEAN_INVALID      4'd7
`define RNF_CM_MAKE_INVALID       4'd8

`endif
