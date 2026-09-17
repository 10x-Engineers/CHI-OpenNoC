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

`ifndef RNF_PARAM_V
`define RNF_PARAM_V

// SS4.6 (p.4-209) makes cache capacity, associativity and replacement policy
// IMPLEMENTATION DEFINED, so the geometry below is a declaration rather than a
// constant the spec fixes. Line size is not: SS2.10.1 (p.2-134) fixes it at 64B.
// RNF_EXCL_LP_NUM_PARAM is how many Logical Processors hold an exclusive monitor
// at once (SS6.2.1 p.6-283); a further LP's Load displaces the oldest, whose
// Exclusive Store then fails rather than passing unmonitored.
//
// RNF_NID_PARAM defaults to 8, the first entry of hnf_param.svh's
// RNF_NID_LIST_PARAM {48,16,40,8}, so a default-parameterised RN-F and HN-F pair
// up without either being overridden.
`define RNF_PARAM #( \
    parameter CHIE_NID_WIDTH_PARAM       = chie_pkg::NID_WIDTH,         \
    parameter CHIE_REQ_ADDR_WIDTH_PARAM  = chie_pkg::REQ_ADDR_WIDTH,    \
    parameter CHIE_SNP_ADDR_WIDTH_PARAM  = chie_pkg::SNP_ADDR_WIDTH,    \
    parameter CHIE_DATA_WIDTH_PARAM      = chie_pkg::DATA_WIDTH,        \
    parameter CHIE_BE_WIDTH_PARAM        = chie_pkg::BE_WIDTH,          \
    parameter CHIE_POISON_WIDTH_PARAM    = chie_pkg::POISON_WIDTH,      \
    parameter CHIE_DATACHECK_WIDTH_PARAM = chie_pkg::DATACHECK_WIDTH,   \
    parameter CHIE_REQ_RSVDC_WIDTH_PARAM = chie_pkg::REQ_RSVDC_WIDTH,   \
    parameter CHIE_DAT_RSVDC_WIDTH_PARAM = chie_pkg::DAT_RSVDC_WIDTH,   \
    parameter CHIE_MPAM_WIDTH_PARAM      = chie_pkg::MPAM_WIDTH,        \
    parameter RNF_LCRD_NUM_PARAM         = 15,                          \
    parameter AXI4_PA_WIDTH_PARAM        = chie_pkg::REQ_ADDR_WIDTH,    \
    parameter AXI4_AXDATA_WIDTH_PARAM    = 128,                         \
    parameter RNF_CACHE_SETS_PARAM       = 16,                          \
    parameter RNF_CACHE_WAYS_PARAM       = 2,                           \
    parameter RNF_MSHR_ENTRIES_PARAM     = 8,                           \
    parameter RNF_EXCL_LP_NUM_PARAM      = 4,                           \
    parameter HNF_NID_PARAM              = 0,                           \
    parameter RNF_NID_PARAM              = 8    )

`define RNF_PARAM_INST #( \
    .CHIE_NID_WIDTH_PARAM           (CHIE_NID_WIDTH_PARAM        ), \
    .CHIE_REQ_ADDR_WIDTH_PARAM      (CHIE_REQ_ADDR_WIDTH_PARAM   ), \
    .CHIE_SNP_ADDR_WIDTH_PARAM      (CHIE_SNP_ADDR_WIDTH_PARAM   ), \
    .CHIE_DATA_WIDTH_PARAM          (CHIE_DATA_WIDTH_PARAM       ), \
    .CHIE_BE_WIDTH_PARAM            (CHIE_BE_WIDTH_PARAM         ), \
    .CHIE_POISON_WIDTH_PARAM        (CHIE_POISON_WIDTH_PARAM     ), \
    .CHIE_DATACHECK_WIDTH_PARAM     (CHIE_DATACHECK_WIDTH_PARAM  ), \
    .CHIE_REQ_RSVDC_WIDTH_PARAM     (CHIE_REQ_RSVDC_WIDTH_PARAM  ), \
    .CHIE_DAT_RSVDC_WIDTH_PARAM     (CHIE_DAT_RSVDC_WIDTH_PARAM  ), \
    .CHIE_MPAM_WIDTH_PARAM          (CHIE_MPAM_WIDTH_PARAM       ), \
    .RNF_LCRD_NUM_PARAM             (RNF_LCRD_NUM_PARAM          ), \
    .AXI4_PA_WIDTH_PARAM            (AXI4_PA_WIDTH_PARAM         ), \
    .AXI4_AXDATA_WIDTH_PARAM        (AXI4_AXDATA_WIDTH_PARAM     ), \
    .RNF_CACHE_SETS_PARAM           (RNF_CACHE_SETS_PARAM        ), \
    .RNF_CACHE_WAYS_PARAM           (RNF_CACHE_WAYS_PARAM        ), \
    .RNF_MSHR_ENTRIES_PARAM         (RNF_MSHR_ENTRIES_PARAM      ), \
    .RNF_EXCL_LP_NUM_PARAM          (RNF_EXCL_LP_NUM_PARAM       ), \
    .HNF_NID_PARAM                  (HNF_NID_PARAM               ), \
    .RNF_NID_PARAM                  (RNF_NID_PARAM               ))

`endif
