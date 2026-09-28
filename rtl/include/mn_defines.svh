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

`ifndef MN_DEFINES
`define MN_DEFINES

// SS2.11 (p.2-145): the PCrdType a RetryAck names and its PCrdGrant repays. The two
// classes are credited apart so a Sync can never take the entry SS8.1.3 (p.8-307,
// MUST) reserves for a Non-sync.
`define MN_PCRD_NONSYNC   4'd0
`define MN_PCRD_SYNC      4'd1

// SS14.2.1 (p.14-445): at most 15 L-Credits per channel.
`define MN_LL_CRD_CNT_WIDTH 4

// RetryAck'd DVMOps waiting for a PCrdGrant, per Requester and class: at most one
// per 12-bit TxnID the Requester can have outstanding.
`define MN_RETRY_CNT_WIDTH 13

`endif
