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

`ifndef MN_PARAM_H
`define MN_PARAM_H

// MN_RN_NID_LIST_PARAM names every DVM-capable RN-F and RN-D (SS16.1.1 p.16-473):
// the Requesters whose DVMOps the MN serves, and the snoopees it broadcasts to. It
// defaults to hnf_param.svh's RNF_NID_LIST_PARAM, so the default RN-F set pairs up.
// MN_RN_SNPDVM_NUM_PARAM is how many SnpDVMOps each accepts concurrently, which
// SS8.1.3 (p.8-308) makes at least two and two by default.
`define MN_PARAM #( \
    parameter CHIE_NID_WIDTH_PARAM       = chie_pkg::NID_WIDTH,         \
    parameter CHIE_REQ_RSVDC_WIDTH_PARAM = chie_pkg::REQ_RSVDC_WIDTH,   \
    parameter CHIE_DAT_RSVDC_WIDTH_PARAM = chie_pkg::DAT_RSVDC_WIDTH,   \
    parameter CHIE_MPAM_WIDTH_PARAM      = chie_pkg::MPAM_WIDTH,        \
    parameter XP_LCRD_NUM_PARAM          = 15,                          \
    parameter MN_NID_PARAM               = 4,                           \
    parameter MN_ENTRIES_NUM_PARAM       = 4,                           \
    parameter MN_ENTRIES_WIDTH_PARAM     = ((MN_ENTRIES_NUM_PARAM > 1) ? $clog2(MN_ENTRIES_NUM_PARAM) : 1), \
    parameter MN_RN_NUM_PARAM            = 4,                           \
    parameter MN_RN_NID_LIST_PARAM       = {CHIE_NID_WIDTH_PARAM'(48), CHIE_NID_WIDTH_PARAM'(16), \
                                            CHIE_NID_WIDTH_PARAM'(40), CHIE_NID_WIDTH_PARAM'(8)}, \
    parameter MN_RN_SNPDVM_NUM_PARAM     = 2    )

`define MN_PARAM_INST #( \
    .CHIE_NID_WIDTH_PARAM       (CHIE_NID_WIDTH_PARAM      ), \
    .CHIE_REQ_RSVDC_WIDTH_PARAM (CHIE_REQ_RSVDC_WIDTH_PARAM), \
    .CHIE_DAT_RSVDC_WIDTH_PARAM (CHIE_DAT_RSVDC_WIDTH_PARAM), \
    .CHIE_MPAM_WIDTH_PARAM      (CHIE_MPAM_WIDTH_PARAM     ), \
    .XP_LCRD_NUM_PARAM          (XP_LCRD_NUM_PARAM         ), \
    .MN_NID_PARAM               (MN_NID_PARAM              ), \
    .MN_ENTRIES_NUM_PARAM       (MN_ENTRIES_NUM_PARAM      ), \
    .MN_ENTRIES_WIDTH_PARAM     (MN_ENTRIES_WIDTH_PARAM    ), \
    .MN_RN_NUM_PARAM            (MN_RN_NUM_PARAM           ), \
    .MN_RN_NID_LIST_PARAM       (MN_RN_NID_LIST_PARAM      ), \
    .MN_RN_SNPDVM_NUM_PARAM     (MN_RN_SNPDVM_NUM_PARAM    ))

`endif
