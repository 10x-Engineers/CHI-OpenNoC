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
*
* Author:
*    Nana Cai <cainana@bosc.ac.cn>
*    Li Zhao <lizhao@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*    Guo Bing <guobing@bosc.ac.cn>
*/

`ifndef SNI_DEFINES
`define SNI_DEFINES

`include "axi4_defines.svh"
`include "display_fatal.svh"

//////////////////////////////////////////////////////////////////////////S
// CHIE size constants

`define SNI_MSHR_ENTRIES_NUM               SNI_MSHR_ENTRIES_NUM_PARAM
`define SNI_MSHR_ENTRIES_WIDTH             ((SNI_MSHR_ENTRIES_NUM_PARAM > 1) ? $clog2(SNI_MSHR_ENTRIES_NUM_PARAM) : 1)

/////////////////////////////////////////////////////////////////////////
// MASK
`define SNI_MASK_CD_WIDTH                  4
`define SNI_MASK_CD_LSB                    0
`define SNI_MASK_CD_MSB                    3
`define SNI_MASK_PD_WIDTH                  4
`define SNI_MASK_PD_LSB                    0
`define SNI_MASK_PD_MSB                    3
`define SNI_MASK_WL_WIDTH                  4
`define SNI_MASK_WL_LSB                    0
`define SNI_MASK_WL_MSB                    3

////////////////////////////////////////////////////////////////////////
`define SNI_PKTS                           (chie_pkg::LINE_PKTS)
`define SNI_PKT_CHUNKS                     (chie_pkg::PKT_CHUNKS)
`define SNI_PKT_CHUNKS_LOG2                (chie_pkg::PKT_CHUNKS_LOG2)

////////////////////////////////////////////////////////////////////////
// sni_link_req_channel_lcredit
`define SNI_LL_REQ_CRD_CNT_WIDTH           4
`define SNI_LL_REQ_CRD_CNT_MSB             3
`define SNI_LL_REQ_CRD_CNT_LSB             0
`define SNI_LL_REQ_MAX_CRD_VALUE           XP_LCRD_NUM_PARAM
`define SNI_LL_CRD_INCDEC_ONE              1
`define SNI_LL_CRD_INCDEC_TWO              2
`define SNI_LL_CRD_INCDEC_THREE            3

////////////////////////////////////////////////////////////////////////
// sni_link_rsp_channel_lcredit
`define SNI_LL_RSP_CRD_CNT_WIDTH           4
`define SNI_LL_RSP_CRD_CNT_MSB             3
`define SNI_LL_RSP_CRD_CNT_LSB             0
`define SNI_LL_RSP_MAX_CRD_VALUE           XP_LCRD_NUM_PARAM

////////////////////////////////////////////////////////////////////////
// sni_link_dat_channel_lcredit
`define SNI_LL_DAT_CRD_CNT_WIDTH           4
`define SNI_LL_DAT_CRD_CNT_MSB             3
`define SNI_LL_DAT_CRD_CNT_LSB             0
`define SNI_LL_DAT_MAX_CRD_VALUE           XP_LCRD_NUM_PARAM

////////////////////////////////////////////////////////////////////////
// sni_mshr_qos
`define SNI_QOS_CNT_WIDTH                      ((SNI_MSHR_ENTRIES_NUM_PARAM > 1) ? $clog2(SNI_MSHR_ENTRIES_NUM_PARAM) : 1)
`define SNI_QOS_CLASS_WIDTH                    1
`define SNI_QOS_CLASS_HIGH                     `SNI_QOS_CLASS_WIDTH'd1
`define SNI_QOS_CLASS_LOW                      `SNI_QOS_CLASS_WIDTH'd0
`define SNI_QOS_HIGH_MIN                       8
`define SNI_QOS_LOW_MAX                        7
`define SNI_QOS_HIGH_POOL_NUM                  SNI_MSHR_ENTRIES_NUM_PARAM/2
`define SNI_QOS_LOW_POOL_NUM                   SNI_MSHR_ENTRIES_NUM_PARAM/2
`define SNI_RET_BANK_CNT_WIDTH                 10
`define SNI_RET_BANK_ENTRIES_NUM               SNI_MSHR_HNI_NUM_PARAM
`define SNI_RET_BANK_ENTRIES_WIDTH             ((SNI_MSHR_HNI_NUM_PARAM > 1) ? $clog2(SNI_MSHR_HNI_NUM_PARAM) : 1)
`define SNI_MAX_WAIT_CNT_WIDTH                 4
`define SNI_LOW2HIGH_MAX_CNT                   10

`define SNI_RETRY_ACKQ_DATA_DEPTH              15
`define SNI_PCRDGRANTQ_DATA_DEPTH              31

////////////////////////////////////////////////////////////////////////
// axi4 self_define
`define AXI4_AXID_WIDTH                         11
`define AXI4_AXADDR_WIDTH                       AXI4_PA_WIDTH_PARAM
`define AXI4_AXLEN_WIDTH                        `AXI4_AWLEN_WIDTH
`define AXI4_AXDATA_WIDTH                       AXI4_AXDATA_WIDTH_PARAM

`endif
