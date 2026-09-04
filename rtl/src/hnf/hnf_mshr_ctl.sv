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
*    Jianhong Zhang <zhangjianhong@bosc.ac.cn>
*    Jianxing Wang <wangjianxing@bosc.ac.cn>
*    Ziqing Li <liziqing@bosc.ac.cn>
*    Hongyu Gao <gaohongyu@bosc.ac.cn>
*    Bingcheng Jin <jinbingcheng@bosc.ac.cn>
*    Wenhao Li <liwenhao@bosc.ac.cn>
*    Li Zhao <lizhao@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*    Qichao Xie <xieqichao@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Guo Bing <guobing@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_mshr_ctl `HNF_PARAM
    (
    //global inputs
    input wire clk,
    input wire rst,

    //inputs related to request handling from hnf_link_rxreq_parse
    input wire li_mshr_rxreq_valid_s0,
    input wire [3:0] li_mshr_rxreq_qos_s0,
    input wire [chie_pkg::NID_WIDTH-1:0] li_mshr_rxreq_srcid_s0,
    input wire [11:0] li_mshr_rxreq_txnid_s0,
    input chie_pkg::req_opcode_e li_mshr_rxreq_opcode_s0,
    input chie_pkg::size_e li_mshr_rxreq_size_s0,
    input wire [chie_pkg::REQ_ADDR_WIDTH-1:0] li_mshr_rxreq_addr_s0,
    input wire li_mshr_rxreq_ns_s0,
    input wire li_mshr_rxreq_allowretry_s0,
    input chie_pkg::order_e li_mshr_rxreq_order_s0,
    input wire [3:0] li_mshr_rxreq_pcrdtype_s0,
    input chie_pkg::memattr_s li_mshr_rxreq_memattr_s0,
    input wire [7:0] li_mshr_rxreq_lpid_s0,
    input wire li_mshr_rxreq_excl_s0,
    input wire li_mshr_rxreq_expcompack_s0,
    input wire li_mshr_rxreq_tracetag_s0,

    //inputs related to data handling from hnf_link_rxreq_parse
    input wire li_mshr_rxdat_valid_s0,
    input wire [11:0] li_mshr_rxdat_txnid_s0,
    input chie_pkg::dat_opcode_e li_mshr_rxdat_opcode_s0,
    input chie_pkg::resp_state_e li_mshr_rxdat_resp_s0,
    input chie_pkg::resp_err_e li_mshr_rxdat_resperr_s0,
    input wire [3:0] li_mshr_rxdat_fwdstate_s0,
    input wire [1:0] li_mshr_rxdat_dataid_s0,

    //inputs related to response handling from hnf_link_rxreq_parse
    input wire li_mshr_rxrsp_valid_s0,
    input wire [chie_pkg::NID_WIDTH-1:0] li_mshr_rxrsp_srcid_s0,
    input wire [11:0] li_mshr_rxrsp_txnid_s0,
    input chie_pkg::rsp_opcode_e li_mshr_rxrsp_opcode_s0,
    input chie_pkg::resp_state_e li_mshr_rxrsp_resp_s0,
    input chie_pkg::resp_err_e li_mshr_rxrsp_resperr_s0,
    input wire [2:0] li_mshr_rxrsp_fwdstate_s0,
    input wire [11:0] li_mshr_rxrsp_dbid_s0,
    input wire [3:0] li_mshr_rxrsp_pcrdtype_s0,

    //inputs from hnf_mshr_global_monitor
    input wire excl_pass_s1,
    input wire excl_fail_s1,

    //inputs from hnf_mshr_bypass
    input wire txreq_mshr_bypass_lost_s1,
    input wire txrsp_mshr_bypass_lost_s1,

    //inputs from hnf_mshr_qos
    input wire mshr_alloc_en_s0,
    input wire mshr_alloc_en_s1_q,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s0,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s1_q,

    //inputs from hnf_mshr_addr_buffer
    input wire rxreq_cam_hazard_s1_q,
    input wire [`MSHR_ENTRIES_NUM-1:0] rxreq_cam_hazard_entry_s1_q,
    input wire mshr_l3_hazard_valid_sx3_q,
    input wire [`MSHR_ENTRIES_NUM-1:0] pipe_cam_hazard_entry_sx3_q,
    input wire [`MSHR_ENTRIES_NUM-1:0] pipe_sleep_entry_sx3_q,

    //inputs from hnf_link_txreq_wrap
    input wire txreq_mshr_won_sx1,

    //inputs from hnf_link_txrsp_wrap
    input wire txrsp_mshr_won_sx1,

    //inputs from hnf_link_txsnp_wrap
    input wire txsnp_mshr_busy_sx1,

    //inputs from hnf_link_txdat_wrap
    input wire txdat_mshr_busy_sx,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] txdat_mshr_rd_idx_sx2,
    input wire txdat_mshr_clr_dbf_busy_valid_sx3,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] txdat_mshr_clr_dbf_busy_idx_sx3,

    //inputs from hnf_cache_pipeline
    input chie_pkg::req_opcode_e l3_opcode_sx7_q,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] l3_mshr_entry_sx7_q,
    input wire l3_memrd_sx7_q,
    input wire l3_hit_sx7_q,
    input wire l3_sfhit_sx7_q,
    input wire l3_pipeval_sx7_q,
    input wire l3_mshr_wr_op_sx7_q,
    input wire l3_snpdirect_sx7_q,
    input wire l3_snpbrd_sx7_q,
    input wire [HNF_MSHR_RNF_NUM_PARAM-1:0] l3_snp_bit_sx7_q,
    input wire l3_replay_sx7_q,
    input wire l3_hit_d_sx7_q,
    input wire l3_evict_sx7_q,

    //outputs to hnf_data_buffer
    output logic  [`MSHR_ENTRIES_WIDTH-1:0] mshr_dbf_rd_idx_sx1_q,
    output logic mshr_dbf_rd_valid_sx1_q,
    // Sec 9.4.4 (p.9-342, MUST): an errored read still returns its data packets, so
    // the buffer is stamped present for an entry no fill will ever reach.
    output logic  [`MSHR_ENTRIES_WIDTH-1:0] mshr_dbf_err_fill_idx_sx1_q,
    output logic mshr_dbf_err_fill_valid_sx1_q,
    output logic  [`MSHR_ENTRIES_WIDTH-1:0] mshr_dbf_retired_idx_sx1_q,
    output logic mshr_dbf_retired_valid_sx1_q,

    //outputs to hnf_link_txreq_wrap
    output logic mshr_txreq_valid_sx1_q,
    output wire  [3:0] mshr_txreq_qos_sx1,
    output logic  [11:0] mshr_txreq_txnid_sx1_q,
    output wire [chie_pkg::NID_WIDTH-1:0] mshr_txreq_returnnid_sx1,
    output wire [12-1:0] mshr_txreq_returntxnid_sx1,
    output chie_pkg::req_opcode_e mshr_txreq_opcode_sx1,
    output chie_pkg::size_e mshr_txreq_size_sx1,
    output wire mshr_txreq_ns_sx1,
    output wire mshr_txreq_allowretry_sx1,
    output chie_pkg::order_e mshr_txreq_order_sx1,
    output wire [3:0] mshr_txreq_pcrdtype_sx1,
    output chie_pkg::memattr_s mshr_txreq_memattr_sx1,
    output wire mshr_txreq_dodwt_sx1,
    output wire mshr_txreq_tracetag_sx1,

    //outputs to hnf_link_txrsp_wrap
    output logic mshr_txrsp_valid_sx1_q,
    output wire [3:0] mshr_txrsp_qos_sx1,
    output wire [chie_pkg::NID_WIDTH-1:0] mshr_txrsp_tgtid_sx1,
    output logic  [11:0] mshr_txrsp_txnid_sx1_q,
    output chie_pkg::rsp_opcode_e mshr_txrsp_opcode_sx1,
    output chie_pkg::resp_err_e mshr_txrsp_resperr_sx1,
    output chie_pkg::resp_state_e mshr_txrsp_resp_sx1,
    output wire [11:0] mshr_txrsp_dbid_sx1,
    output wire mshr_txrsp_tracetag_sx1,

    //outputs to hnf_link_txsnp_wrap
    output logic mshr_txsnp_valid_sx1_q,
    output wire [3:0] mshr_txsnp_qos_sx1,
    output logic  [11:0] mshr_txsnp_txnid_sx1_q,
    output wire [chie_pkg::NID_WIDTH-1:0] mshr_txsnp_fwdnid_sx1,
    output wire [11:0] mshr_txsnp_fwdtxnid_sx1,
    output chie_pkg::snp_opcode_e mshr_txsnp_opcode_sx1,
    output wire mshr_txsnp_ns_sx1,
    output wire mshr_txsnp_rettosrc_sx1,
    output wire mshr_txsnp_tracetag_sx1,
    output wire [HNF_MSHR_RNF_NUM_PARAM-1:0] mshr_txsnp_rn_vec_sx1,

    //outputs to hnf_link_txdat_wrap
    output logic  [chie_pkg::NID_WIDTH-1:0] mshr_txdat_tgtid_sx2,
    output logic  [11:0] mshr_txdat_txnid_sx2,
    output chie_pkg::dat_opcode_e mshr_txdat_opcode_sx2,
    output chie_pkg::resp_state_e mshr_txdat_resp_sx2,
    output chie_pkg::resp_err_e mshr_txdat_resperr_sx2,
    output logic  [11:0] mshr_txdat_dbid_sx2,
    output logic  [1:0] mshr_txdat_ccid_sx2,
    output logic mshr_txdat_tracetag_sx2,

    //outputs to hnf_cache_pipeline
    output logic mshr_l3_fill_sx1_q,
    output logic  [CHIE_NID_WIDTH_PARAM-1:0] mshr_l3_rnf_sx1_q,
    output logic mshr_l3_seq_retire_sx1_q,
    output chie_pkg::req_opcode_e mshr_l3_opcode_sx1_q,
    output logic mshr_l3_req_en_sx1_q,
    output logic  [`MSHR_ENTRIES_WIDTH-1:0] mshr_l3_entry_idx_sx1_q,
    output logic mshr_l3_fill_dirty_sx1_q,



    output wire [`MSHR_ENTRIES_NUM-1:0] mshr_mem_busy_sx,  //outputs to hnf_mshr_addr_buffer
    input wire [`MSHR_ENTRIES_NUM-1:0] abf_internal_evict_addr_valid_sx_q  //inputs from hnf_mshr_addr_buffer
    );
    //internal signals
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_entry_valid_sx_q;
    // only through this structure.
    // every sleeper but the last -- unrecoverably, since sleep_sx_q is cleared
    // writeback blocks every request to that line, and a single slot would lose
    // One bit per sleeper, not one successor index: an entry that owes a victim
    logic [`MSHR_ENTRIES_NUM-1:0]                 need_to_wakeup_vec_sx_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 sleep_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_can_alloc_entry_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rdnosnp_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_ro_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rdnosd_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_ru_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rc_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wrnosnp_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wrnosnpp_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wu_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wup_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wuf_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wb_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wc_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_we_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_mu_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_cu_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_evi_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_cs_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_ci_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_seq_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_err_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_errrd_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_errwrdat_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_errgrant_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_excl_fail_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_sn_order_s1_q;
    chie_pkg::req_opcode_e       mshr_opcode_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [3:0]          mshr_qos_s1_q[0:`MSHR_ENTRIES_NUM-1];
    chie_pkg::memattr_s      mshr_memattr_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::NID_WIDTH-1:0]        mshr_srcid_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [11:0]        mshr_txnid_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_excl_s1_q;
    chie_pkg::size_e         mshr_size_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]         mshr_addr_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic     mshr_tracetag_s1_q[0:`MSHR_ENTRIES_NUM-1];
    chie_pkg::resp_err_e      mshr_dn_resperr_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic           mshr_ns_s1_q[0:`MSHR_ENTRIES_NUM-1];
    chie_pkg::order_e        mshr_order_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_compack_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dwt_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_l3dat_sn_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_neednosnp_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_l3_entry_vec_sx8_q;
    logic [`MSHR_SNPCNT_WIDTH-1:0]                l3_snp_cnt;
    logic [`RNF_NUM-1:0]                          mshr_snp_bit_sx8_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snpdirect_sx8_q;
    logic [`MSHR_SNPCNT_WIDTH-1:0]                mshr_snpcnt_sx_q[0:`MSHR_ENTRIES_NUM-1];
    chie_pkg::snp_opcode_e       mshr_snpcode_sx8_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_retosrc_sx8_q;
    chie_pkg::resp_state_e         mshr_l3_resp_sx8_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snprsp_entry_vec_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_wuf_neednosnp_vec_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snpdat_entry_vec_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snpdat_getone_s1_q;
    logic [`MSHR_SNPCNT_WIDTH-1:0]                mshr_snp_getnum_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snp_d_s1_q;
    logic [1:0]                                   mshr_snp_getid_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dct_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_entry_vec_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_rngetone_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_memgetone_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_old_get_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_new_get_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_cancel_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dat_stop_cb_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_cb_wr_mem_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rn_dat_get_d_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_get_compack_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_get_dbid_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dbid_entry_vec_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_comp_entry_vec_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_get_comp_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_get_rd_receipt_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_get_retry_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_retry_s1_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_resent_s1_q;
    logic [3:0]     mshr_pcrdtype_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshr_pcrdtype_cnt_s1_q[0:`MSHR_PCRDTYPE_NUMS-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dmt_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dct_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 l3_rd_busy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 l3_fill_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 l3_rd_rdy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 l3_fill_rdy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 l3_fill_data_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_snp_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_txsnp_rdy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_mem_rd_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_mem_wr_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_mem_rd_rdy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_mem_wr_rdy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rn_data_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_sn_data_busy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_txdat_rn_rdy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_txdat_sn_rdy_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_dbid_rdy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_rd_receipt_rdy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_comp_rdy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_comp_busy_s2_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_compack_busy_sx_q;
    chie_pkg::snp_opcode_e       mshr_snpcode_sx7;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshrageq_v_sx2_q;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshrageq_mshr_idx_sx2_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshrageq_alloc_entry_ptr_sx1;
    logic                                         found_mshrageq_alloc_entry;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshrageq_shift;
    logic                                         mshr_dbf_retired_valid_sx2_q;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshrageq_mshr_idx_sx1[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_WIDTH-1:0]               rxreq_cam_hazard_idx_s1;
    logic                                         found_rxreq_cam_hazard_idx;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               pipe_sleep_idx_sx3;
    logic                                         found_pipe_sleep_idx;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               pipe_cam_hazard_idx_sx3;
    logic                                         found_pipe_cam_hazard_idx;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_l3hit_sx8_q;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_l3hit_d_sx8_q;
    logic [11:0]         mshr_dbid_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [11:0]         mshr_dwt_dbid_s1_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshr_txrsp_idx_sx1_q;
    logic                                         mshr_retire_busy_sx1_q;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshr_retire_min_idx_sx;
    logic                                         found_retire_min_idx;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               mshr_retire_oldest_idx_sx;
    logic                                         found_retire_oldest_idx;
    logic                                         mshr_oldest_is_retire;
    logic                                         mshr_l3_seq_min_idx_retire_sx1;
    logic                                         mshr_l3_seq_oldest_idx_retire_sx1;
    logic                                         mshr_pcrdgrant_frist_s0;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txdat_wrap_other_ptr;
    logic                                         found_txdat_wrap_other_ptr;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               txdat_wrap_other_idx;
    logic  [`MSHR_ENTRIES_NUM-1:0]                txdat_wrap_other_ptr_vector;
    logic [`MSHR_ENTRIES_NUM-1:0]                 cpl_wrap_other_ptr;
    logic                                         found_cpl_wrap_other_ptr;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               cpl_rob;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               cpl_wrap_other_idx;
    logic [`MSHR_ENTRIES_NUM-1:0]                 cpl_wrap_other_ptr_vector;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txsnp_wrap_other_ptr;
    logic                                         found_txsnp_wrap_other_ptr;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               txsnp_wrap_other_idx;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txsnp_wrap_other_ptr_vector;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txrsp_wrap_other_ptr;
    logic                                         found_txrsp_wrap_other_ptr;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               txrsp_wrap_other_idx;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txrsp_wrap_other_ptr_vector;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txreq_wrap_other_ptr;
    logic                                         found_txreq_wrap_other_ptr;
    logic [`MSHR_ENTRIES_WIDTH-1:0]               txreq_wrap_other_idx;
    logic [`MSHR_ENTRIES_NUM-1:0]                 txreq_wrap_other_ptr_vector;
    logic                                         mshr_retry_ageq_sel_success;
    logic [`MSHR_ENTRIES_NUM-1:0]                 mshr_retry_rdy_entry_s1_q;
    wire                                        op_rdnosnp;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosnp_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosnp_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosnp_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosnp_s0_w;
    wire                                        op_ro;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ro_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ro_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ro_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ro_s0_w;
    wire                                        op_rdnosd;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosd_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosd_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosd_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rdnosd_s0_w;
    wire                                        op_ru;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ru_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ru_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ru_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ru_s0_w;
    wire                                        op_rc;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rc_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rc_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rc_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rc_s0_w;
    wire                                        op_wrnosnpf;
    wire                                        op_wrnosnp;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnp_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnp_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnp_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnp_s0_w;
    wire                                        op_wrnosnpp;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnpp_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnpp_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnpp_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wrnosnpp_s0_w;
    wire                                        op_wu;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wu_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wu_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wu_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wu_s0_w;
    wire                                        op_wuf;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wuf_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wuf_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wuf_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wuf_s0_w;
    wire                                        op_wup;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wup_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wup_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wup_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wup_s0_w;
    wire                                        op_wb;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wb_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wb_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wb_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wb_s0_w;
    wire                                        op_wc;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wc_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wc_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wc_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wc_s0_w;
    wire                                        op_we;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_we_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_we_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_we_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_we_s0_w;
    wire                                        op_mu;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mu_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mu_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mu_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mu_s0_w;
    wire                                        op_cu;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cu_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cu_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cu_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cu_s0_w;
    wire                                        op_evi;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_evi_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_evi_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_evi_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_evi_s0_w;
    wire                                        op_cs;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cs_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cs_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cs_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_cs_s0_w;
    wire                                        op_ci;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ci_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ci_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ci_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_ci_s0_w;
    wire                                        op_seq;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_seq_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_seq_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_seq_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_seq_s0_w;
    wire                                        op_drop;
    wire                                        op_serviced;
    wire                                        op_err;
    wire                                        op_errrd;
    wire                                        op_errwrdat;
    wire                                        op_cw;
    wire                                        op_errgrant;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_err_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_err_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_err_upd_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_errrd_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_errwrdat_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_errgrant_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dbf_err_fill_entry_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_req_set_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_req_clr_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dct_set_sx8;
    wire                                        mshr_sn_order_set_s1;
    wire                                        mshr_order_reqord;
    wire                                        mshr_order_owo;
    wire                                        mshr_request_excl;
    wire                                        mshr_excl_or_owo;
    wire                                        mshr_excl_or_reqord;
    wire                                        mshr_request_order;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_memattr_allocate_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_l3rd_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_memrd_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_memwr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_datbuf_sn_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_dbid_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_rd_receipt_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_comp_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_dmt_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_dwt_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_l3fill_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_alloc_snp_s1;
    wire                                        mshr_snprsp_s0;
    wire                                        mshr_snprspfwd_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snprsp_entry_vec_s0;
    wire [11:0]       mshr_snprsp_entry_s0;
    wire                                        mshr_snprsp_v_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snprsp_getone_s0;
    wire                                        mshr_snpdat_s0;
    wire                                        mshr_snpdatfwd_s0;
    wire                                        mshr_snpdat_v_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snpdat_entry_vec_s0;
    wire [11:0]       mshr_snpdat_entry_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snpdat_gettwo_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_d_set_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_d_clr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_getid_set_0_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_getid_set_1_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_getid_clr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dct_set_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dct_clr_s1;
    wire                                        mshr_snp_d_s0;
    wire [1:0]      mshr_snpdatid_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3dat_rn_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3dat_sn_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_evict_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dat_entry_vec_s0;
    wire [11:0]       mshr_dat_entry_s0;
    wire                                        mshr_dat_v_s0;
    wire                                        mshr_mem_dat_s0;
    wire                                        mshr_rn_dat_s0;
    wire                                        mshr_cb_dat_s0;
    wire                                        mshr_ncb_dat_s0;
    wire                                        mshr_snp_get_64B_s0;
    wire                                        mshr_rn_dat_getall_s0;
    wire                                        mshr_datcancel_s0;
    wire                                        mshr_set_stop_cb_s0;
    wire                                        mshr_rn_dat_get_i_sc_s0;
    wire                                        mshr_rn_dat_get_i_s0;
    wire                                        mshr_rn_dat_get_uc_s0;
    wire                                        mshr_rn_dat_get_sc_s0;
    chie_pkg::resp_state_e        mshr_data_state_s0;
    wire                                        mshr_rn_dat_get_d_s0;
    wire                                        mshr_rsp_v_s0;
    wire                                        mshr_getrsp_compack_s0;
    wire                                        mshr_getdat_compack_s0;
    wire [11:0]       mshr_rsp_entry_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rsp_entry_vec_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_retosrc_entry_vec_sx8;
    wire                                        mshr_get_dbid_s0;
    wire                                        mshr_get_comp_s0;
    wire                                        mshr_get_rd_receipt_s0;
    wire                                        mshr_get_retry_s0;
    wire                                        mshr_retry_alloc_s0;
    wire                                        mshr_get_pcrd_s0;
    wire                                        mshr_pcrd_alloc_s0;
    wire [3:0]    mshr_pcrd_type_get_s0;
    wire [`MSHR_PCRDTYPE_NUMS-1:0]              mshr_pcrdtype_cnt_upd_s1;
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_pcrdtype_cnt_s1[0:`MSHR_PCRDTYPE_NUMS-1];
    wire                                        mshr_l3_dmt_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_dmt_s1;
    // `MSHR_ENTRIES_WIDTH. Named once here rather than truncated at every use.
    // Sec 13.10.5 (p.13-427) makes TxnID 12 bits; an MSHR index is
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_snpdat_entry_idx_s0;
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_dat_entry_idx_s0;
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_txreq_entry_idx_sx1;
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_txsnp_entry_idx_sx1;
    assign mshr_snpdat_entry_idx_s0 = mshr_snpdat_entry_s0[`MSHR_ENTRIES_WIDTH-1:0];
    assign mshr_dat_entry_idx_s0    = mshr_dat_entry_s0[`MSHR_ENTRIES_WIDTH-1:0];
    assign mshr_txreq_entry_idx_sx1 = mshr_txreq_txnid_sx1_q[`MSHR_ENTRIES_WIDTH-1:0];
    assign mshr_txsnp_entry_idx_sx1 = mshr_txsnp_txnid_sx1_q[`MSHR_ENTRIES_WIDTH-1:0];
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_memrd_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_getall_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_get_64B_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_clr_l3busy_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_rd_l3fill_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_replay_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_all_dat_alloc_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_new_dat_l3fill_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_old_dat_l3fill_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_neednosnp_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_needsnp_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_memrd_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dat_to_rn_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_memwr_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_memwr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_wup_memwr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_rd_l3fill_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_entry_vec_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_can_retire_entry_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_can_alloc_entry_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_rd_busy_set_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_rd_busy_clr_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_rd_rdy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_rd_rdy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_rdy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_rdy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_data_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                l3_fill_data_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_snp_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_rd_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_rd_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_wr_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_wr_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_rd_rdy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_rd_rdy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_wr_rdy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_mem_wr_rdy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rn_data_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rn_data_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_sn_data_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_sn_data_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txdat_rn_rdy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txdat_rn_rdy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txdat_sn_rdy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txdat_sn_rdy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dbid_rdy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dbid_rdy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rd_receipt_rdy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rd_receipt_rdy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_comp_rdy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_comp_rdy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_comp_busy_set_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_comp_busy_clr_s2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_compack_busy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_compack_busy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txsnp_rdy_set_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txsnp_rdy_clr_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_pipeline_busy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_pipeline_rdy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txreq_rdy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_datbuf_busy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txdat_rdy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_rsp_busy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txrsp_rdy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_entry_busy_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_retire_rdy;
    wire                                        mshr_retire_sx;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_resent_entry_vec_s0;
    wire [`MSHR_ENTRIES_WIDTH-1:0]              mshr_dbf_retired_idx_sx;
    wire                                        mshr_l3_seq_retire_sx;
    wire                                        mshr_l3_val_sx7;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_alloc_entry_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_retire_entry_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_shift_sx2;
    wire                                        ageq_needs_shift_sx2;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_load_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_v_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshrageq_flop_en_s1;
    wire [`MSHR_ENTRIES_NUM-1:0]                txreq_wrap_ageq_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                txreq_wrap_other_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txreq_entry_vec_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                txrsp_wrap_ageq_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                txrsp_wrap_other_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txrsp_entry_vec_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                txsnp_wrap_ageq_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                txsnp_wrap_other_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_txsnp_entry_vec_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                txdat_wrap_ageq_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                txdat_wrap_other_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_dbf_rd_entry_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                cpl_wrap_ageq_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                cpl_wrap_other_vec;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_l3_entry_vec_sx1;
    wire [`MSHR_ENTRIES_NUM-1:0]                txdat_mshr_clr_dbf_busy_entry_vec_sx3;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_retry_rdy_ageq_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_retry_rdy_vec_s0;
    wire [`MSHR_ENTRIES_NUM-1:0]                mshr_retry_rdy_entry_s0;
    wire                                        retry_entry_found;

    //main function
    genvar entry;

    //************************************************************************//

    //                mshr allocate s0 stage opcode decode logic

    //************************************************************************//

    assign op_rdnosnp              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READNOSNP);
    assign mshr_rdnosnp_set_s0     = {`MSHR_ENTRIES_NUM{op_rdnosnp}} & mshr_can_alloc_entry_s0;
    assign mshr_rdnosnp_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_rdnosnp_upd_sx     = mshr_rdnosnp_set_s0 | mshr_rdnosnp_clr_sx1;
    assign mshr_rdnosnp_s0_w       = mshr_rdnosnp_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_rdnosnp_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_rdnosnp_s1_q[entry] <= 1'b0;
                else if(mshr_rdnosnp_upd_sx[entry] == 1'b1)
                    mshr_rdnosnp_s1_q[entry] <= mshr_rdnosnp_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_ro              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READONCE);
    assign mshr_ro_set_s0     = {`MSHR_ENTRIES_NUM{op_ro}} & mshr_can_alloc_entry_s0;
    assign mshr_ro_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_ro_upd_sx     = mshr_ro_set_s0 | mshr_ro_clr_sx1;
    assign mshr_ro_s0_w       = mshr_ro_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_ro_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_ro_s1_q[entry] <= 1'b0;
                else if(mshr_ro_upd_sx[entry] == 1'b1)
                    mshr_ro_s1_q[entry] <= mshr_ro_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_rdnosd              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READNOTSHAREDDIRTY);
    assign mshr_rdnosd_set_s0     = {`MSHR_ENTRIES_NUM{op_rdnosd}} & mshr_can_alloc_entry_s0;
    assign mshr_rdnosd_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_rdnosd_upd_sx     = mshr_rdnosd_set_s0 | mshr_rdnosd_clr_sx1;
    assign mshr_rdnosd_s0_w       = mshr_rdnosd_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_rdnosd_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_rdnosd_s1_q[entry] <= 1'b0;
                else if(mshr_rdnosd_upd_sx[entry] == 1'b1)
                    mshr_rdnosd_s1_q[entry] <= mshr_rdnosd_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_ru              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READUNIQUE);
    assign mshr_ru_set_s0     = {`MSHR_ENTRIES_NUM{op_ru}} & mshr_can_alloc_entry_s0;
    assign mshr_ru_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_ru_upd_sx     = mshr_ru_set_s0 | mshr_ru_clr_sx1;
    assign mshr_ru_s0_w       = mshr_ru_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_ru_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_ru_s1_q[entry] <= 1'b0;
                else if(mshr_ru_upd_sx[entry] == 1'b1)
                    mshr_ru_s1_q[entry] <= mshr_ru_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_rc              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READCLEAN);
    assign mshr_rc_set_s0     = {`MSHR_ENTRIES_NUM{op_rc}} & mshr_can_alloc_entry_s0;
    assign mshr_rc_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_rc_upd_sx     = mshr_rc_set_s0 | mshr_rc_clr_sx1;
    assign mshr_rc_s0_w       = mshr_rc_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_rc_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_rc_s1_q[entry] <= 1'b0;
                else if(mshr_rc_upd_sx[entry] == 1'b1)
                    mshr_rc_s1_q[entry] <= mshr_rc_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wrnosnpf             = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULL);
    assign op_wrnosnp              = op_wrnosnpf | op_wrnosnpp;
    assign mshr_wrnosnp_set_s0     = {`MSHR_ENTRIES_NUM{op_wrnosnp}} & mshr_can_alloc_entry_s0;
    assign mshr_wrnosnp_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wrnosnp_upd_sx     = mshr_wrnosnp_set_s0 | mshr_wrnosnp_clr_sx1;
    assign mshr_wrnosnp_s0_w       = mshr_wrnosnp_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wrnosnp_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wrnosnp_s1_q[entry] <= 1'b0;
                else if(mshr_wrnosnp_upd_sx[entry] == 1'b1)
                    mshr_wrnosnp_s1_q[entry] <= mshr_wrnosnp_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wrnosnpp             = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTL);
    assign mshr_wrnosnpp_set_s0     = {`MSHR_ENTRIES_NUM{op_wrnosnpp}} & mshr_can_alloc_entry_s0;
    assign mshr_wrnosnpp_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wrnosnpp_upd_sx     = mshr_wrnosnpp_set_s0 | mshr_wrnosnpp_clr_sx1;
    assign mshr_wrnosnpp_s0_w       = mshr_wrnosnpp_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wrnosnpp_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wrnosnpp_s1_q[entry] <= 1'b0;
                else if(mshr_wrnosnpp_upd_sx[entry] == 1'b1)
                    mshr_wrnosnpp_s1_q[entry] <= mshr_wrnosnpp_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wuf             = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULL);
    assign mshr_wuf_set_s0     = {`MSHR_ENTRIES_NUM{op_wuf}} & mshr_can_alloc_entry_s0;
    assign mshr_wuf_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wuf_upd_sx     = mshr_wuf_set_s0 | mshr_wuf_clr_sx1;
    assign mshr_wuf_s0_w       = mshr_wuf_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wuf_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wuf_s1_q[entry] <= 1'b0;
                else if(mshr_wuf_upd_sx[entry] == 1'b1)
                    mshr_wuf_s1_q[entry] <= mshr_wuf_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wup              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTL);
    assign mshr_wup_set_s0     = {`MSHR_ENTRIES_NUM{op_wup}} & mshr_can_alloc_entry_s0;
    assign mshr_wup_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wup_upd_sx     = mshr_wup_set_s0 | mshr_wup_clr_sx1;
    assign mshr_wup_s0_w       = mshr_wup_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wup_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wup_s1_q[entry] <= 1'b0;
                else if(mshr_wup_upd_sx[entry] == 1'b1)
                    mshr_wup_s1_q[entry] <= mshr_wup_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wu             = op_wuf | op_wup;
    assign mshr_wu_set_s0     = {`MSHR_ENTRIES_NUM{op_wu}} & mshr_can_alloc_entry_s0;
    assign mshr_wu_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wu_upd_sx     = mshr_wu_set_s0 | mshr_wu_clr_sx1;
    assign mshr_wu_s0_w       = mshr_wu_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wu_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wu_s1_q[entry] <= 1'b0;
                else if(mshr_wu_upd_sx[entry] == 1'b1)
                    mshr_wu_s1_q[entry] <= mshr_wu_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wb              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULL);
    assign mshr_wb_set_s0     = {`MSHR_ENTRIES_NUM{op_wb}} & mshr_can_alloc_entry_s0;
    assign mshr_wb_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wb_upd_sx     = mshr_wb_set_s0 | mshr_wb_clr_sx1;
    assign mshr_wb_s0_w       = mshr_wb_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wb_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wb_s1_q[entry] <= 1'b0;
                else if(mshr_wb_upd_sx[entry] == 1'b1)
                    mshr_wb_s1_q[entry] <= mshr_wb_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_wc              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULL);
    assign mshr_wc_set_s0     = {`MSHR_ENTRIES_NUM{op_wc}} & mshr_can_alloc_entry_s0;
    assign mshr_wc_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_wc_upd_sx     = mshr_wc_set_s0 | mshr_wc_clr_sx1;
    assign mshr_wc_s0_w       = mshr_wc_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wc_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_wc_s1_q[entry] <= 1'b0;
                else if(mshr_wc_upd_sx[entry] == 1'b1)
                    mshr_wc_s1_q[entry] <= mshr_wc_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_we              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEEVICTFULL);
    assign mshr_we_set_s0     = {`MSHR_ENTRIES_NUM{op_we}} & mshr_can_alloc_entry_s0;
    assign mshr_we_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_we_upd_sx     = mshr_we_set_s0 | mshr_we_clr_sx1;
    assign mshr_we_s0_w       = mshr_we_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_we_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_we_s1_q[entry] <= 1'b0;
                else if(mshr_we_upd_sx[entry] == 1'b1)
                    mshr_we_s1_q[entry] <= mshr_we_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_mu              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_MAKEUNIQUE);
    assign mshr_mu_set_s0     = {`MSHR_ENTRIES_NUM{op_mu}} & mshr_can_alloc_entry_s0;
    assign mshr_mu_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_mu_upd_sx     = mshr_mu_set_s0 | mshr_mu_clr_sx1;
    assign mshr_mu_s0_w       = mshr_mu_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_mu_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_mu_s1_q[entry] <= 1'b0;
                else if(mshr_mu_upd_sx[entry] == 1'b1)
                    mshr_mu_s1_q[entry] <= mshr_mu_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_cu              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_CLEANUNIQUE);
    assign mshr_cu_set_s0     = {`MSHR_ENTRIES_NUM{op_cu}} & mshr_can_alloc_entry_s0;
    assign mshr_cu_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_cu_upd_sx     = mshr_cu_set_s0 | mshr_cu_clr_sx1;
    assign mshr_cu_s0_w       = mshr_cu_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_cu_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_cu_s1_q[entry] <= 1'b0;
                else if(mshr_cu_upd_sx[entry] == 1'b1)
                    mshr_cu_s1_q[entry] <= mshr_cu_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_evi              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_EVICT);
    assign mshr_evi_set_s0     = {`MSHR_ENTRIES_NUM{op_evi}} & mshr_can_alloc_entry_s0;
    assign mshr_evi_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_evi_upd_sx     = mshr_evi_set_s0 | mshr_evi_clr_sx1;
    assign mshr_evi_s0_w       = mshr_evi_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_evi_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_evi_s1_q[entry] <= 1'b0;
                else if(mshr_evi_upd_sx[entry] == 1'b1)
                    mshr_evi_s1_q[entry] <= mshr_evi_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_cs              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHARED);
    assign mshr_cs_set_s0     = {`MSHR_ENTRIES_NUM{op_cs}} & mshr_can_alloc_entry_s0;
    assign mshr_cs_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_cs_upd_sx     = mshr_cs_set_s0 | mshr_cs_clr_sx1;
    assign mshr_cs_s0_w       = mshr_cs_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_cs_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_cs_s1_q[entry] <= 1'b0;
                else if(mshr_cs_upd_sx[entry] == 1'b1)
                    mshr_cs_s1_q[entry] <= mshr_cs_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_ci              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_CLEANINVALID);
    assign mshr_ci_set_s0     = {`MSHR_ENTRIES_NUM{op_ci}} & mshr_can_alloc_entry_s0;
    assign mshr_ci_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_ci_upd_sx     = mshr_ci_set_s0 | mshr_ci_clr_sx1;
    assign mshr_ci_s0_w       = mshr_ci_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_ci_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_ci_s1_q[entry] <= 1'b0;
                else if(mshr_ci_upd_sx[entry] == 1'b1)
                    mshr_ci_s1_q[entry] <= mshr_ci_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    assign op_seq              = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_SNOOPFILTEREVICT);
    assign mshr_seq_set_s0     = {`MSHR_ENTRIES_NUM{op_seq}} & mshr_can_alloc_entry_s0;
    assign mshr_seq_clr_sx1    = mshr_can_retire_entry_sx1;
    assign mshr_seq_upd_sx     = mshr_seq_set_s0 | mshr_seq_clr_sx1;
    assign mshr_seq_s0_w       = mshr_seq_set_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_seq_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_seq_s1_q[entry] <= 1'b0;
                else if(mshr_seq_upd_sx[entry] == 1'b1)
                    mshr_seq_s1_q[entry] <= mshr_seq_s0_w[entry];
                else
                    ;
            end
        end
    endgenerate

    // CHI E.b Sec 4.5.1 (p.4-197, MUST): "A completion response is required for all
    // transactions except PCrdReturn and PrefetchTgt." Every request the link admits
    // is therefore classified here; anything outside the serviced set above owes the
    // structural error answer Sec 9.1 (p.9-334) names for "an attempt to use a
    // transaction type that is not supported", with Sec 9.4.4's (p.9-342, MUST)
    // transaction structure intact -- so the class carries its shape (grant, write
    // data, read data) as well as its NDERR.
    assign op_drop      = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_PREFETCHTGT)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_PCRDRETURN)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_REQLCRDRETURN);
    assign op_serviced  = op_rdnosnp | op_ro | op_rdnosd | op_ru | op_rc
                        | op_wrnosnp | op_wu | op_wb | op_wc | op_we
                        | op_mu | op_cu | op_evi | op_cs | op_ci | op_seq;
    assign op_err       = li_mshr_rxreq_valid_s0 & ~(op_serviced | op_drop);
    // Table 4-6 (p.4-168) / Table 4-8 (p.4-171): a read is completed by CompData, so
    // the error rides on the data response (Table 9-2 p.9-337).
    assign op_errrd     = op_err & ((li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READSHARED)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READNOSNPSEP)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READONCECLEANINVALID)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READONCEMAKEINVALID)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READPREFERUNIQUE)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_MAKEREADUNIQUE));
    // Table 4-17 (p.4-182)'s Combined Writes, enumerated rather than taken as an
    // opcode range: the gaps inside that range are RESERVED, and a reserved opcode
    // answered write-shaped would wait for data no Requester owes it.
    assign op_cw     = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANINV)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANINV)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANINV)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULLCLEANSH)
                        | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP);
    // Sec 9.4.4 (p.9-342, MUST) keeps an errored write's data transfer, so these owe
    // a DBID and consume their write data before completing.
    assign op_errwrdat  = op_err & ((li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKPTL)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEEVICTOREVICT)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLSTASH)
                                  | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLSTASH)
                                  | ((li_mshr_rxreq_opcode_s0 >= chie_pkg::REQ_ATOMICSTORE_ADD)
                                   & (li_mshr_rxreq_opcode_s0 <= chie_pkg::REQ_ATOMICCOMPARE))
                                  | op_cw);
    // Table 4-39 (p.4-219) gives a Write Zero no WriteData response but still a DBID,
    // so it joins the errored writes in owing a CompDBIDResp without owing data.
    assign op_errgrant  = op_errwrdat
                        | (op_err & ((li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEZERO)
                                   | (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPZERO)));

    assign mshr_err_set_s0      = {`MSHR_ENTRIES_NUM{op_err}}      & mshr_can_alloc_entry_s0;
    assign mshr_errrd_set_s0    = {`MSHR_ENTRIES_NUM{op_errrd}}    & mshr_can_alloc_entry_s0;
    assign mshr_errwrdat_set_s0 = {`MSHR_ENTRIES_NUM{op_errwrdat}} & mshr_can_alloc_entry_s0;
    assign mshr_errgrant_set_s0 = {`MSHR_ENTRIES_NUM{op_errgrant}} & mshr_can_alloc_entry_s0;
    assign mshr_err_clr_sx1     = mshr_can_retire_entry_sx1;
    assign mshr_err_upd_sx      = mshr_err_set_s0 | mshr_err_clr_sx1;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_err_s1_q_timing_logic
                if(rst == 1'b1)begin
                    mshr_err_s1_q[entry]       <= 1'b0;
                    mshr_errrd_s1_q[entry]     <= 1'b0;
                    mshr_errwrdat_s1_q[entry]  <= 1'b0;
                    mshr_errgrant_s1_q[entry]  <= 1'b0;
                end
                else if(mshr_err_upd_sx[entry] == 1'b1)begin
                    mshr_err_s1_q[entry]       <= mshr_err_set_s0[entry];
                    mshr_errrd_s1_q[entry]     <= mshr_errrd_set_s0[entry];
                    mshr_errwrdat_s1_q[entry]  <= mshr_errwrdat_set_s0[entry];
                    mshr_errgrant_s1_q[entry]  <= mshr_errgrant_set_s0[entry];
                end
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//

    //          mshr allocate s0 stage request fields decode logic

    //************************************************************************//

    assign mshr_req_set_s0      = mshr_can_alloc_entry_s0;
    assign mshr_req_clr_sx1     = mshr_can_retire_entry_sx1;
    assign mshr_dct_set_sx8     = {`MSHR_ENTRIES_NUM{(l3_snpdirect_sx7_q & ~l3_hit_sx7_q)}} & ~mshr_excl_s1_q & (mshr_ro_s1_q | mshr_rc_s1_q | mshr_rdnosd_s1_q | mshr_ru_s1_q);
    assign mshr_sn_order_set_s1 = (li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READNOSNP | li_mshr_rxreq_opcode_s0 == chie_pkg::REQ_READONCE) && (!li_mshr_rxreq_expcompack_s0);

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk)begin : mshr_qos_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_qos_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_qos_s1_q[entry] <= li_mshr_rxreq_qos_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_srcid_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_srcid_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_srcid_s1_q[entry] <= li_mshr_rxreq_srcid_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_txnid_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_txnid_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_txnid_s1_q[entry] <= li_mshr_rxreq_txnid_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_opcode_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_opcode_s1_q[entry] <= chie_pkg::REQ_REQLCRDRETURN;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_opcode_s1_q[entry] <= li_mshr_rxreq_opcode_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_size_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_size_s1_q[entry] <= chie_pkg::SIZE_1B;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_size_s1_q[entry] <= li_mshr_rxreq_size_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_addr_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_addr_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_addr_s1_q[entry] <= li_mshr_rxreq_addr_s0;
                else
                    ;
            end

            // Sec 11.5.1 (p.11-368, MUST): a component that receives a packet with
            // TraceTag set "must preserve and reflect the value back in any response
            // packet or spawned packet generated in response to the received packet".
            always_ff @(posedge clk)begin : mshr_tracetag_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_tracetag_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_tracetag_s1_q[entry] <= li_mshr_rxreq_tracetag_s0;
                else
                    ;
            end

            // Sec 9.1 (p.9-334, MUST): "The Home is required to pass-back the NDERR
            // in the response to the Requester." The bit is sticky from whichever
            // inbound flit reported it until the entry retires.
            always_ff @(posedge clk or posedge rst)begin : mshr_dn_resperr_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dn_resperr_s1_q[entry] <= chie_pkg::RESP_ERR_NORM_OK;
                else if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_dn_resperr_s1_q[entry] <= chie_pkg::RESP_ERR_NORM_OK;
                else if(mshr_rsp_entry_vec_s0[entry] && li_mshr_rxrsp_resperr_s0[1])
                    mshr_dn_resperr_s1_q[entry] <= li_mshr_rxrsp_resperr_s0;
                else if(mshr_dat_entry_vec_s0[entry] && li_mshr_rxdat_resperr_s0[1])
                    mshr_dn_resperr_s1_q[entry] <= li_mshr_rxdat_resperr_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_ns_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_ns_s1_q[entry] <= 1'b0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_ns_s1_q[entry] <= li_mshr_rxreq_ns_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_order_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_order_s1_q[entry] <= chie_pkg::ORDER_NONE;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_order_s1_q[entry] <= li_mshr_rxreq_order_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_memattr_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_memattr_s1_q[entry] <= '0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_memattr_s1_q[entry] <= li_mshr_rxreq_memattr_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_excl_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_excl_s1_q[entry] <= 1'b0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_excl_s1_q[entry] <= li_mshr_rxreq_excl_s0;
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_compack_s1_q_timing_logic
                if(mshr_req_clr_sx1[entry] == 1'b1)
                    mshr_compack_s1_q[entry] <= 1'b0;
                else if(mshr_req_set_s0[entry] == 1'b1)
                    mshr_compack_s1_q[entry] <= li_mshr_rxreq_expcompack_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_sn_order_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_sn_order_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_sn_order_s1_q[entry] <= 1'b0;
                else if(mshr_can_alloc_entry_s0[entry] && mshr_sn_order_set_s1)
                    mshr_sn_order_s1_q[entry] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//

    //                   mshr allocate s1 stage decode logic

    //************************************************************************//

    assign mshr_order_reqord        = (mshr_order_s1_q[mshr_entry_idx_alloc_s1_q] == 2'b10) & (mshr_compack_s1_q[mshr_entry_idx_alloc_s1_q] == 1'b0);
    assign mshr_order_owo           = (mshr_order_s1_q[mshr_entry_idx_alloc_s1_q] == 2'b10) & (mshr_compack_s1_q[mshr_entry_idx_alloc_s1_q] == 1'b1);
    assign mshr_request_excl        = (mshr_excl_s1_q[mshr_entry_idx_alloc_s1_q] == 1'b1);
    assign mshr_excl_or_owo         = (mshr_order_owo) | (mshr_request_excl);
    assign mshr_excl_or_reqord      = (mshr_order_reqord) | (mshr_request_excl);
    assign mshr_request_order       = (mshr_order_s1_q[mshr_entry_idx_alloc_s1_q] == 2'b10) | (mshr_order_s1_q[mshr_entry_idx_alloc_s1_q] == 2'b11);

    assign mshr_memattr_allocate_s1 = (mshr_can_alloc_entry_s1_q) & ({`MSHR_ENTRIES_NUM{mshr_memattr_s1_q[mshr_entry_idx_alloc_s1_q][3]}});
    assign mshr_alloc_l3rd_s1       = (mshr_can_alloc_entry_s1_q) & (mshr_ro_s1_q | mshr_rdnosd_s1_q | mshr_ru_s1_q | mshr_rc_s1_q | mshr_wu_s1_q | mshr_mu_s1_q | mshr_cu_s1_q | mshr_evi_s1_q | mshr_cs_s1_q | mshr_ci_s1_q);
    assign mshr_alloc_l3fill_s1     = (mshr_can_alloc_entry_s1_q) & (((mshr_wu_s1_q | mshr_wb_s1_q) & mshr_memattr_allocate_s1) | (mshr_we_s1_q));
    assign mshr_alloc_snp_s1        = (mshr_can_alloc_entry_s1_q) & (mshr_ro_s1_q | mshr_rdnosd_s1_q | mshr_ru_s1_q | mshr_rc_s1_q | mshr_wu_s1_q | mshr_mu_s1_q | mshr_cu_s1_q | mshr_evi_s1_q | mshr_cs_s1_q | mshr_ci_s1_q | mshr_seq_s1_q);
    assign mshr_alloc_memrd_s1      = (mshr_can_alloc_entry_s1_q) & (mshr_rdnosnp_s1_q);
    assign mshr_alloc_memwr_s1      = (mshr_can_alloc_entry_s1_q) & (mshr_wrnosnp_s1_q | (mshr_wu_s1_q & ~mshr_wup_s1_q & ~mshr_memattr_allocate_s1));
    assign mshr_alloc_datbuf_sn_s1  = (mshr_can_alloc_entry_s1_q) & (({`MSHR_ENTRIES_NUM{mshr_excl_or_owo}} & mshr_wrnosnp_s1_q) | (mshr_wc_s1_q) | ((mshr_wb_s1_q) & ~mshr_memattr_allocate_s1) | (mshr_wuf_s1_q & ~mshr_memattr_allocate_s1 & {`MSHR_ENTRIES_NUM{mshr_order_owo}}));
    assign mshr_alloc_comp_s1       = (mshr_can_alloc_entry_s1_q) & (mshr_wrnosnp_s1_q | mshr_wb_s1_q | mshr_wc_s1_q | mshr_we_s1_q | mshr_cu_s1_q | mshr_cs_s1_q | mshr_ci_s1_q | mshr_mu_s1_q | mshr_evi_s1_q | mshr_wu_s1_q | (mshr_err_s1_q & ~mshr_errrd_s1_q));
    assign mshr_alloc_dbid_s1       = (mshr_can_alloc_entry_s1_q) & (mshr_wrnosnp_s1_q | mshr_wu_s1_q | mshr_wb_s1_q | mshr_wc_s1_q | mshr_we_s1_q | mshr_errgrant_s1_q);
    assign mshr_alloc_rd_receipt_s1 = (mshr_can_alloc_entry_s1_q) & ({`MSHR_ENTRIES_NUM{mshr_request_order}} & (mshr_ro_s1_q | mshr_rdnosnp_s1_q));
    assign mshr_alloc_dmt_s1        = (mshr_can_alloc_entry_s1_q) & ((mshr_rdnosnp_s1_q | mshr_ro_s1_q) & (~{`MSHR_ENTRIES_NUM{mshr_excl_or_reqord}}));
    assign mshr_alloc_dwt_s1        = (mshr_can_alloc_entry_s1_q) & ((mshr_wrnosnp_s1_q | (mshr_wuf_s1_q & ~mshr_memattr_allocate_s1)) & ~{`MSHR_ENTRIES_NUM{mshr_order_owo}} & ~{`MSHR_ENTRIES_NUM{mshr_request_excl}});

    //************************************************************************//

    //                       mshr snp dat/rsp channel decode logic

    //************************************************************************//

    //snprsp decode
    assign mshr_snprsp_s0       = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_SNPRESP);
    assign mshr_snprspfwd_s0    = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_SNPRESPFWDED);
    assign mshr_snprsp_v_s0     = li_mshr_rxrsp_valid_s0 & (mshr_snprsp_s0 | mshr_snprspfwd_s0);
    assign mshr_snprsp_entry_s0 = li_mshr_rxrsp_txnid_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin:snprsp_entry_comb_logic
            assign mshr_snprsp_entry_vec_s0[entry] = ((mshr_snprsp_entry_s0 == entry) & (mshr_snprsp_v_s0))? 1'b1:1'b0;
            assign mshr_snprsp_getone_s0[entry] = ((mshr_snprsp_entry_s0 == entry) & (mshr_snprsp_v_s0))? 1'b1:1'b0;
        end
    endgenerate

    always_ff @(posedge clk or posedge rst)begin : mshr_snprsp_entry_vec_s1_q_timing_logic
        if(rst ==  1'b1)
            mshr_snprsp_entry_vec_s1_q <= {`MSHR_ENTRIES_NUM{1'b0}};
        else
            mshr_snprsp_entry_vec_s1_q <= mshr_snprsp_entry_vec_s0;
    end

    //snpdat decode
    assign mshr_snpdat_s0       = (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATA);
    assign mshr_snpdatfwd_s0    = (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATAFWDED);
    assign mshr_snpdat_v_s0     = li_mshr_rxdat_valid_s0 & (mshr_snpdat_s0 | mshr_snpdatfwd_s0);
    assign mshr_snp_d_s0        = li_mshr_rxdat_resp_s0[3-1];
    assign mshr_snpdat_entry_s0 = li_mshr_rxdat_txnid_s0;
    assign mshr_snpdatid_s0     = li_mshr_rxdat_dataid_s0;
    assign mshr_snp_get_64B_s0  = mshr_snpdat_v_s0 & ((mshr_snp_getid_s1_q[mshr_snpdat_entry_idx_s0][1] == 1'b1 & mshr_snpdatid_s0 == 2'b00) | (mshr_snp_getid_s1_q[mshr_snpdat_entry_idx_s0][0] == 1'b1 & mshr_snpdatid_s0 == 2'b10));

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_snp_decode_comb_logic

            assign mshr_snpdat_entry_vec_s0[entry] = (mshr_snpdat_entry_s0 == entry) & (mshr_snpdat_v_s0);
            assign mshr_snpdat_gettwo_s0[entry]    = (mshr_snpdat_entry_vec_s0[entry])? mshr_snpdat_getone_s1_q[entry]:1'b0;
            assign mshr_snp_d_set_s1[entry]        = (mshr_snpdat_entry_vec_s0[entry] & mshr_snp_d_s0) ? 1'b1 : 1'b0;
            assign mshr_snp_d_clr_s1[entry]        = (mshr_can_retire_entry_sx1[entry]);
            assign mshr_snp_getid_set_0_s1[entry]  = (mshr_snpdat_entry_vec_s0[entry] & (mshr_snpdatid_s0 == 2'b00));
            assign mshr_snp_getid_set_1_s1[entry]  = (mshr_snpdat_entry_vec_s0[entry] & (mshr_snpdatid_s0 == 2'b10));
            assign mshr_snp_getid_clr_s1[entry]    = (mshr_can_retire_entry_sx1[entry]);
            assign mshr_dct_set_s1[entry]          = (mshr_snpdat_entry_vec_s0[entry] & mshr_snpdatfwd_s0) ||
                   (mshr_snprsp_entry_vec_s0[entry] & mshr_snprspfwd_s0);
            assign mshr_dct_clr_s1[entry]          = (mshr_can_retire_entry_sx1[entry]);
            assign mshr_snp_dmt_s1[entry]          = (mshr_snp_memrd_s1[entry] & mshr_ru_s1_q[entry]);
            assign mshr_snp_getall_s1[entry]       = ((mshr_snp_getnum_s1_q[entry] == mshr_snpcnt_sx_q[entry]) & (mshr_snpcnt_sx_q[entry] != {`MSHR_SNPCNT_WIDTH{1'b0}}));
            assign mshr_snp_get_64B_s1[entry]      = (mshr_snp_getid_s1_q[entry][0] & mshr_snp_getid_s1_q[entry][1]);
            assign mshr_snp_memrd_s1[entry]        = (mshr_snp_getall_s1[entry] & ~mshr_l3hit_sx8_q[entry] & ~mshr_dct_s1_q[entry] & ~mshr_snp_get_64B_s1[entry] & (mshr_snprsp_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry]) & (mshr_ro_s1_q[entry] |
                    mshr_ru_s1_q[entry] | mshr_rdnosd_s1_q[entry] | mshr_rc_s1_q[entry] | (mshr_wup_s1_q[entry] & mshr_memattr_s1_q[entry][3])));
            assign mshr_snp_memwr_s1[entry]        = (mshr_snp_get_64B_s1[entry] & mshr_snp_d_s1_q[entry] & (mshr_cu_s1_q[entry] | mshr_cs_s1_q[entry] | mshr_ci_s1_q[entry] | mshr_seq_s1_q[entry] | mshr_ro_s1_q[entry]));
            assign mshr_wup_memwr_s1[entry]        = (mshr_wup_s1_q[entry] & ~mshr_memattr_s1_q[entry][3] & (mshr_snp_getall_s1[entry] & (mshr_snpdat_entry_vec_s1_q[entry] | mshr_snprsp_entry_vec_s1_q[entry])));
            assign mshr_snp_rd_l3fill_s1[entry]    = (mshr_snp_get_64B_s1[entry] & mshr_snpdat_entry_vec_s1_q[entry] & (mshr_rdnosd_s1_q[entry] | mshr_rc_s1_q[entry]));
            assign mshr_retry_rdy_vec_s0[entry]    = ((mshr_pcrdtype_s1_q[entry] == mshr_pcrd_type_get_s0) & mshr_pcrd_alloc_s0 & mshr_get_retry_s1_q[entry]);
            assign mshr_retry_rdy_ageq_s0[entry]   = (mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0] == entry) & mshr_retry_rdy_vec_s0[entry]);
        end
    endgenerate

    poll_with_start_entry #(
                             .ENTRIES_NUM ( `MSHR_ENTRIES_NUM )
                         )
                         retry_entry_find (
                             .entry_vec      ( mshr_retry_rdy_vec_s0     ),
                             .start_entry    ( mshr_retry_rdy_entry_s1_q ),
                             .entry_ptr_sel  ( mshr_retry_rdy_entry_s0   ),
                             .found          ( retry_entry_found         )
                         );

    always_comb begin
        mshr_retry_ageq_sel_success = 1'b0;
        if(|mshr_retry_rdy_ageq_s0)begin
            mshr_retry_ageq_sel_success = 1'b1;
        end
    end

    assign mshr_resent_entry_vec_s0 = mshr_retry_ageq_sel_success? mshr_retry_rdy_ageq_s0 : retry_entry_found? mshr_retry_rdy_entry_s0 : {`MSHR_ENTRIES_NUM{1'b0}};

    always_ff @(posedge clk or posedge rst) begin
        if(rst == 1'b1)begin
            mshr_retry_rdy_entry_s1_q <= {{(`MSHR_ENTRIES_NUM-1){1'b0}},{1'b1}};
        end
        else if(retry_entry_found & ~mshr_retry_ageq_sel_success)begin
            mshr_retry_rdy_entry_s1_q <= mshr_retry_rdy_entry_s0;
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_snpdat_entry_vec_s1_q_timing_logic
        if(rst ==  1'b1)
            mshr_snpdat_entry_vec_s1_q <= {`MSHR_ENTRIES_NUM{1'b0}};
        else
            mshr_snpdat_entry_vec_s1_q <= mshr_snpdat_entry_vec_s0;
    end

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_snpdat_getone_s1_q_timing_logic
            always_ff @(posedge clk or posedge rst)begin
                if (rst == 1'b1)
                    mshr_snpdat_getone_s1_q[entry] <= 1'b0;
                else if (mshr_snpdat_entry_vec_s0[entry])
                    mshr_snpdat_getone_s1_q[entry] <= ~mshr_snpdat_getone_s1_q[entry];
                else
                    ;
            end
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_snp_getnum_s1_q_timing_logic
            always_ff @(posedge clk or posedge rst)begin
                if(rst == 1'b1)
                    mshr_snp_getnum_s1_q[entry] <= {`MSHR_SNPCNT_WIDTH{1'b0}};
                else if(mshr_snpdat_gettwo_s0[entry] && mshr_snprsp_getone_s0[entry])
                    mshr_snp_getnum_s1_q[entry] <= (mshr_snp_getnum_s1_q[entry] + 2'b10);
                else if (mshr_snpdat_gettwo_s0[entry] || mshr_snprsp_getone_s0[entry])
                    mshr_snp_getnum_s1_q[entry] <= (mshr_snp_getnum_s1_q[entry] + 2'b01);
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_snp_getnum_s1_q[entry] <= {`MSHR_SNPCNT_WIDTH{1'b0}};
                else
                    ;
            end
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_dct_s1_qtiming_logic
            always_ff @(posedge clk or posedge rst)begin
                if(rst == 1'b1)
                    mshr_dct_s1_q[entry] <= 1'b0;
                else if(mshr_dct_set_s1[entry])
                    mshr_dct_s1_q[entry] <= 1'b1;
                else if(mshr_dct_clr_s1[entry])
                    mshr_dct_s1_q[entry] <= 1'b0;
            end
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_snp_d_s1_q_timing_logic
            always_ff @(posedge clk or posedge rst)begin
                if(rst == 1'b1)
                    mshr_snp_d_s1_q[entry] <= 1'b0;
                else if(mshr_snp_d_clr_s1[entry])
                    mshr_snp_d_s1_q[entry] <= 1'b0;
                else if(mshr_snp_d_set_s1[entry])
                    mshr_snp_d_s1_q[entry] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_snp_getid_s1_q_timing_logic
            always_ff @(posedge clk or posedge rst)begin
                if(rst == 1'b1)
                    mshr_snp_getid_s1_q[entry] <= 2'b00;
                else if(mshr_snp_getid_clr_s1[entry])
                    mshr_snp_getid_s1_q[entry] <= 2'b00;
                else if(mshr_snp_getid_set_0_s1[entry])
                    mshr_snp_getid_s1_q[entry][0] <= 1'b1;
                else if(mshr_snp_getid_set_1_s1[entry])
                    mshr_snp_getid_s1_q[entry][1] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    always_comb begin:mshr_pcrdgrant_frist_s0_comb_logic
        integer i;
        mshr_pcrdgrant_frist_s0 = mshr_pcrd_alloc_s0;
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(mshr_pcrd_alloc_s0 && (mshr_pcrdtype_s1_q[i] == mshr_pcrd_type_get_s0) && (mshr_get_retry_s1_q[i]))
                mshr_pcrdgrant_frist_s0 = 1'b0;
            else
                mshr_pcrdgrant_frist_s0 = mshr_pcrdgrant_frist_s0;
        end
    end

    //************************************************************************//

    //                       mshr dat channel decode logic

    //************************************************************************//

    assign mshr_dat_v_s0           = li_mshr_rxdat_valid_s0;
    assign mshr_dat_entry_s0       = li_mshr_rxdat_txnid_s0;
    assign mshr_getdat_compack_s0  = (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK);
    assign mshr_mem_dat_s0         = mshr_dat_v_s0 & (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_COMPDATA);
    assign mshr_cb_dat_s0          = mshr_dat_v_s0 & (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_COPYBACKWRDATA);
    assign mshr_ncb_dat_s0         = mshr_dat_v_s0 & (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK | li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA);
    assign mshr_rn_dat_s0          = mshr_cb_dat_s0 | mshr_ncb_dat_s0 | mshr_datcancel_s0;
    assign mshr_rn_dat_getall_s0   = (mshr_dat_rngetone_s1_q[mshr_dat_entry_idx_s0] | mshr_size_s1_q[mshr_dat_entry_idx_s0] != 3'b110) & mshr_rn_dat_s0;
    assign mshr_datcancel_s0       = mshr_dat_v_s0 & (li_mshr_rxdat_opcode_s0 == chie_pkg::DAT_WRITEDATACANCEL);
    assign mshr_set_stop_cb_s0     = mshr_rn_dat_s0 & ((mshr_rn_dat_get_i_sc_s0 & (mshr_wb_s1_q[mshr_dat_entry_idx_s0] | mshr_we_s1_q[mshr_dat_entry_idx_s0])) |
            ((mshr_rn_dat_get_i_sc_s0 | mshr_rn_dat_get_uc_s0) & mshr_wc_s1_q[mshr_dat_entry_idx_s0]) |
            (mshr_wb_s1_q[mshr_dat_entry_idx_s0] & ~mshr_memattr_s1_q[mshr_dat_entry_idx_s0][3:3] & mshr_rn_dat_get_uc_s0));
    assign mshr_data_state_s0      = li_mshr_rxdat_valid_s0? li_mshr_rxdat_resp_s0:chie_pkg::RESP_I;
    assign mshr_rn_dat_get_i_s0    = mshr_rn_dat_s0 & (mshr_data_state_s0 == chie_pkg::RESP_I);
    assign mshr_rn_dat_get_uc_s0   = mshr_rn_dat_s0 & (mshr_data_state_s0 == chie_pkg::RESP_UC_UD);
    assign mshr_rn_dat_get_d_s0    = (mshr_rn_dat_s0 & (mshr_data_state_s0 == chie_pkg::RESP_UC_PD)) | (mshr_ncb_dat_s0 & mshr_wu_s1_q[mshr_dat_entry_idx_s0] & mshr_memattr_s1_q[mshr_dat_entry_idx_s0][3:3]);
    assign mshr_rn_dat_get_sc_s0   = mshr_rn_dat_s0 & (mshr_data_state_s0 == chie_pkg::RESP_SC);
    assign mshr_rn_dat_get_i_sc_s0 = mshr_rn_dat_get_i_s0 | mshr_rn_dat_get_sc_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_dat_decode_comb_logic

            assign mshr_dat_entry_vec_s0[entry]  = (mshr_dat_entry_s0 == entry) & (mshr_mem_dat_s0 | mshr_rn_dat_s0);
            assign mshr_all_dat_alloc_s1[entry]  = (mshr_dat_new_get_s1_q[entry]) & (mshr_dat_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | mshr_l3_entry_vec_sx8_q[entry]) &
                   (mshr_dat_old_get_s1_q[entry] | mshr_l3hit_sx8_q[entry]) & mshr_wup_s1_q[entry] & mshr_memattr_s1_q[entry][3];
            assign mshr_dat_to_rn_s1[entry]      = ((mshr_dat_old_get_s1_q[entry] | (mshr_dat_memgetone_s1_q[entry] & mshr_size_s1_q[entry] != 3'b110)) & (mshr_snp_getnum_s1_q[entry] == mshr_snpcnt_sx_q[entry]) &
                                                    (mshr_dat_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | mshr_snprsp_entry_vec_s1_q[entry]) & !mshr_dct_s1_q[entry] &
                                                    (mshr_rdnosnp_s1_q[entry] | mshr_ro_s1_q[entry] | mshr_ru_s1_q[entry] | mshr_rc_s1_q[entry] | mshr_rdnosd_s1_q[entry]));
            assign mshr_new_dat_l3fill_s1[entry] = (mshr_dat_new_get_s1_q[entry] & (mshr_dat_entry_vec_s1_q[entry]) & (((mshr_wb_s1_q[entry]) & mshr_memattr_s1_q[entry][3]) |
                                                    mshr_we_s1_q[entry])) |
                   (mshr_dat_new_get_s1_q[entry] & (mshr_dat_entry_vec_s1_q[entry] | mshr_l3_entry_vec_sx8_q[entry]) & (!l3_rd_busy_s2_q[entry]) & ((mshr_wu_s1_q[entry] & ~mshr_wup_s1_q[entry]) & mshr_memattr_s1_q[entry][3]));
            assign mshr_old_dat_l3fill_s1[entry] = mshr_dat_old_get_s1_q[entry] & (mshr_ro_s1_q[entry] | mshr_rc_s1_q[entry] | mshr_rdnosd_s1_q[entry]) & (mshr_snp_getnum_s1_q[entry] == mshr_snpcnt_sx_q[entry]);
        end
    endgenerate

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_dat_entry_vec_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_entry_vec_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry])
                    mshr_dat_entry_vec_s1_q[entry] <= 1'b1;
                else
                    mshr_dat_entry_vec_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_cancel_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_cancel_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_cancel_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_datcancel_s0)
                    mshr_cancel_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dat_stop_cb_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_stop_cb_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dat_stop_cb_s1_q[entry] <= 1'b0;
                else if(mshr_set_stop_cb_s0 && mshr_dat_entry_vec_s0[entry] && mshr_dat_rngetone_s1_q[entry])
                    mshr_dat_stop_cb_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_dat_memgetone_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_memgetone_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dat_memgetone_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_mem_dat_s0)
                    mshr_dat_memgetone_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_dat_old_get_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_old_get_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dat_old_get_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_mem_dat_s0)
                    mshr_dat_old_get_s1_q[entry] <= mshr_dat_memgetone_s1_q[entry];
                else if((mshr_snpdat_entry_vec_s0[entry]) & mshr_snp_get_64B_s0)
                    mshr_dat_old_get_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_dat_rngetone_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_rngetone_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dat_rngetone_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_rn_dat_s0)
                    mshr_dat_rngetone_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_dat_new_get_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dat_new_get_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dat_new_get_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_rn_dat_s0)
                    mshr_dat_new_get_s1_q[entry] <= mshr_rn_dat_getall_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_cb_wr_mem_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_cb_wr_mem_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_cb_wr_mem_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_rn_dat_s0)
                    mshr_cb_wr_mem_s1_q[entry] <= mshr_rn_dat_getall_s0 & mshr_rn_dat_get_d_s0 & ((mshr_wb_s1_q[entry] & (~mshr_memattr_s1_q[entry][3])) | (mshr_wc_s1_q[entry]));
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst) begin: mshr_rn_dat_get_d_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_rn_dat_get_d_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_rn_dat_get_d_s1_q[entry] <= 1'b0;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_rn_dat_s0)
                    mshr_rn_dat_get_d_s1_q[entry] <= mshr_rn_dat_get_d_s0;
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//

    //                        mshr rsp channel decode logic

    //************************************************************************//

    //rsp flit decode
    assign mshr_rsp_v_s0         = li_mshr_rxrsp_valid_s0;
    assign mshr_rsp_entry_s0     = li_mshr_rxrsp_txnid_s0;
    assign mshr_pcrd_type_get_s0 = li_mshr_rxrsp_pcrdtype_s0;

    //opcode decode
    assign mshr_getrsp_compack_s0 = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_COMPACK);
    assign mshr_get_dbid_s0       = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_COMPDBIDRESP | li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_DBIDRESP);
    assign mshr_get_comp_s0       = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_COMPDBIDRESP | li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_COMP);
    assign mshr_get_rd_receipt_s0 = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_READRECEIPT);
    assign mshr_get_retry_s0      = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_RETRYACK);
    assign mshr_get_pcrd_s0       = (li_mshr_rxrsp_opcode_s0 == chie_pkg::RSP_PCRDGRANT);
    assign mshr_retry_alloc_s0    = mshr_rsp_v_s0 & mshr_get_retry_s0;
    assign mshr_pcrd_alloc_s0     = mshr_rsp_v_s0 & mshr_get_pcrd_s0;

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_rsp_entry_vec_s0_comb_logic
            assign mshr_rsp_entry_vec_s0[entry]      = (mshr_rsp_entry_s0 == entry) & mshr_rsp_v_s0;
            assign mshr_retosrc_entry_vec_sx8[entry] = (mshr_ro_s1_q[entry] & ~l3_snpdirect_sx7_q) ||
                   (mshr_ru_s1_q[entry] & ~l3_snpdirect_sx7_q & ~l3_hit_sx7_q) ||
                   (mshr_rdnosd_s1_q[entry]) ||
                   (mshr_rc_s1_q[entry]) ||
                   (mshr_wup_s1_q[entry] & mshr_memattr_s1_q[entry][3] & ~l3_hit_sx7_q);
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_get_comp_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_get_comp_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_get_comp_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_comp_s0)
                    mshr_get_comp_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dbid_entry_vec_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dbid_entry_vec_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry])
                    mshr_dbid_entry_vec_s1_q[entry] <= mshr_get_dbid_s0;
                else
                    mshr_dbid_entry_vec_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_comp_entry_vec_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_comp_entry_vec_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry])
                    mshr_comp_entry_vec_s1_q[entry] <= mshr_get_comp_s0;
                else
                    mshr_comp_entry_vec_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_get_retry_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_get_retry_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_retry_s0 && (mshr_pcrdtype_cnt_s1_q[mshr_pcrd_type_get_s0] == {`MSHR_ENTRIES_WIDTH{1'b0}}))
                    mshr_get_retry_s1_q[entry] <= 1'b1;
                else if(mshr_resent_entry_vec_s0[entry])
                    mshr_get_retry_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_retry_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_retry_s1_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry] || mshr_l3_evict_sx7[entry])
                    mshr_retry_s1_q[entry] <= 1'b0;
                else if (mshr_retry_alloc_s0 && mshr_rsp_entry_vec_s0[entry])
                    mshr_retry_s1_q[entry] <= (mshr_pcrdtype_cnt_s1_q[mshr_pcrd_type_get_s0] != {`MSHR_ENTRIES_WIDTH{1'b0}});
                else if(mshr_resent_entry_vec_s0[entry])
                    mshr_retry_s1_q[entry] <= 1'b1;
            end
        end
    endgenerate

    generate
        for (entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_resent_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_resent_s1_q[entry] <= 1'b0;
                else if (mshr_rsp_entry_vec_s0[entry] && mshr_get_retry_s0)
                    mshr_resent_s1_q[entry] <= (mshr_pcrdtype_cnt_s1_q[mshr_pcrd_type_get_s0] != {`MSHR_ENTRIES_WIDTH{1'b0}});
                else if(mshr_resent_entry_vec_s0[entry])
                    mshr_resent_s1_q[entry] <= 1'b1;
                else
                    mshr_resent_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_get_compack_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_get_compack_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_getrsp_compack_s0)
                    mshr_get_compack_s1_q[entry] <= 1'b1;
                else if(mshr_dat_entry_vec_s0[entry] && mshr_getdat_compack_s0)
                    mshr_get_compack_s1_q[entry] <= 1'b1;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_get_compack_s1_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_get_dbid_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_get_dbid_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_dbid_s0)
                    mshr_get_dbid_s1_q[entry] <= 1'b1;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_get_dbid_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dbid_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dbid_s1_q[entry] <= '0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_dbid_s0)
                    mshr_dbid_s1_q[entry] <= li_mshr_rxrsp_dbid_s0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dbid_s1_q[entry] <= '0;
            end

            // Under DWT the Subordinate grants the buffer, and Table 13-21
            // (p.13-430) addresses its DBIDResp to ReturnNID/ReturnTxnID -- the
            // Requester -- so this Home never sees it. The Subordinate's Comp
            // does come here (Table 3-1 p.3-153) and carries the same DBID that
            // Sec 2.5.9 (p.2-90, MUST) obliges it to repeat, which is the only
            // place the Home can learn the value its own Comp must echo.
            always_ff @(posedge clk or posedge rst)begin : mshr_dwt_dbid_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_dwt_dbid_s1_q[entry] <= '0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_comp_s0 && mshr_dwt_s2_q[entry])
                    mshr_dwt_dbid_s1_q[entry] <= li_mshr_rxrsp_dbid_s0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dwt_dbid_s1_q[entry] <= '0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_get_rd_receipt_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_get_rd_receipt_s1_q[entry] <= 1'b0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_rd_receipt_s0)
                    mshr_get_rd_receipt_s1_q[entry] <= 1'b1;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_get_rd_receipt_s1_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_pcrdtype_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_pcrdtype_s1_q[entry] <= '0;
                else if(mshr_rsp_entry_vec_s0[entry] && mshr_get_retry_s0)
                    mshr_pcrdtype_s1_q[entry] <= mshr_pcrd_type_get_s0;
                else
                    ;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`MSHR_PCRDTYPE_NUMS;entry=entry+1)begin : mshr_pcrdtype_cnt_s1_comb_logic
            assign mshr_pcrdtype_cnt_upd_s1[entry] = (mshr_pcrdgrant_frist_s0 & (mshr_pcrd_type_get_s0 == entry)) ||
                   ((mshr_retry_alloc_s0 & (mshr_pcrdtype_cnt_s1_q[entry] != {`MSHR_ENTRIES_WIDTH{1'b0}}) & mshr_pcrd_type_get_s0 == entry));
            // Sec 2.11 (p.2-145): more than one P-Credit of a type can be outstanding,
            // so this is a count, not a flag.
            assign mshr_pcrdtype_cnt_s1[entry]     = (mshr_pcrdgrant_frist_s0 & (mshr_pcrd_type_get_s0 == entry)) ?
                   (mshr_pcrdtype_cnt_s1_q[entry] + {{(`MSHR_ENTRIES_WIDTH-1){1'b0}},1'b1}) :
                   (mshr_pcrdtype_cnt_s1_q[entry] - {{(`MSHR_ENTRIES_WIDTH-1){1'b0}},1'b1});
        end
    endgenerate

    generate
        for(entry=0;entry<`MSHR_PCRDTYPE_NUMS;entry=entry+1)
            always_ff @(posedge clk or posedge rst)begin : mshr_pcrdtype_cnt_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_pcrdtype_cnt_s1_q[entry] <= {`MSHR_ENTRIES_WIDTH{1'b0}};
                else if(mshr_pcrdtype_cnt_upd_s1[entry])
                    mshr_pcrdtype_cnt_s1_q[entry] <= mshr_pcrdtype_cnt_s1[entry];
                else
                    ;
            end
    endgenerate


    //************************************************************************//

    //                        mshr cpl decode logic

    //************************************************************************//

    assign mshr_l3_val_sx7  = l3_pipeval_sx7_q & !l3_replay_sx7_q;
    assign mshr_l3_dmt_sx7  = mshr_l3_val_sx7 & !l3_hit_sx7_q & !l3_sfhit_sx7_q & (mshr_excl_s1_q[l3_mshr_entry_sx7_q] == 1'b0) & ~((mshr_order_s1_q[l3_mshr_entry_sx7_q] == 2'b10) | (mshr_order_s1_q[l3_mshr_entry_sx7_q] == 2'b11) &
            (mshr_compack_s1_q[l3_mshr_entry_sx7_q] == 1'b0)) & (l3_opcode_sx7_q == chie_pkg::REQ_READUNIQUE | l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN | l3_opcode_sx7_q == chie_pkg::REQ_READNOTSHAREDDIRTY);

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_l3dat_sn_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_l3dat_sn_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_l3dat_sn_sx8_q[entry] <= 1'b0;
                else if(mshr_l3dat_sn_sx7[entry])
                    mshr_l3dat_sn_sx8_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_l3_entry_vec_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_l3_entry_vec_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry])
                    mshr_l3_entry_vec_sx8_q[entry] <= 1'b1;
                else
                    mshr_l3_entry_vec_sx8_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_l3hit_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_l3hit_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_l3hit_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_l3hit_sx8_q[entry] <= l3_hit_sx7_q;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_l3hit_d_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_l3hit_d_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_l3hit_d_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_l3hit_d_sx8_q[entry] <= l3_hit_d_sx7_q;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_snpdirect_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_snpdirect_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_snpdirect_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_snpdirect_sx8_q[entry] <= l3_snpdirect_sx7_q;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_retosrc_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_retosrc_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_retosrc_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_retosrc_sx8_q[entry] <= mshr_retosrc_entry_vec_sx8[entry];
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_wuf_neednosnp_vec_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_wuf_neednosnp_vec_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && !l3_sfhit_sx7_q && l3_rd_busy_s2_q[entry])
                    mshr_wuf_neednosnp_vec_sx8_q[entry] <= 1'b1;
                else
                    mshr_wuf_neednosnp_vec_sx8_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_neednosnp_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_neednosnp_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_neednosnp_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry] && !l3_snpdirect_sx7_q && !l3_snpbrd_sx7_q)
                    mshr_neednosnp_sx8_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_snpcnt_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_snpcnt_sx_q[entry] <= {`MSHR_SNPCNT_WIDTH{1'b0}};
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_snpcnt_sx_q[entry] <= {`MSHR_SNPCNT_WIDTH{1'b0}};
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_snpcnt_sx_q[entry] <= l3_snp_cnt;
                else if(mshr_seq_s1_q[entry] && mshr_can_alloc_entry_s1_q[entry])
                    mshr_snpcnt_sx_q[entry] <= `RNF_NUM;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dmt_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_dmt_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dmt_sx8_q[entry] <= 1'b0;
                else if(mshr_can_alloc_entry_s1_q[entry])
                    mshr_dmt_sx8_q[entry] <= mshr_alloc_dmt_s1[entry];
                else if(mshr_l3_entry_vec_sx7[entry])
                    mshr_dmt_sx8_q[entry] <= (mshr_l3_dmt_sx7 | mshr_dmt_sx8_q[entry]);
                else if(mshr_snp_dmt_s1[entry])
                    mshr_dmt_sx8_q[entry] <= 1'b1;
                else if(mshr_ro_s1_q[entry] && (l3_fill_busy_sx_q[entry] || mshr_snp_d_s1_q[entry]))
                    mshr_dmt_sx8_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dct_sx8_q_timing_logic
                if(rst == 1'b1)
                    mshr_dct_sx8_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dct_sx8_q[entry] <= 1'b0;
                else if(mshr_l3_entry_vec_sx7[entry])
                    mshr_dct_sx8_q[entry] <= mshr_dct_set_sx8[entry];
                else
                    ;
            end
        end
    endgenerate

    always_comb begin: compute_snp_cnt_comb_logic
        integer i;
        l3_snp_cnt = 0;
        for (i = 0; i < `RNF_NUM; i = i + 1) begin
            if (l3_snp_bit_sx7_q[i] == 1'b1) begin
                l3_snp_cnt = l3_snp_cnt + 1;
            end
        end
    end

    generate
        for(entry=0;entry<`MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk)begin : mshr_snp_bit_sx8_q_timing_logic
                if(mshr_can_retire_entry_sx1[entry])
                    mshr_snp_bit_sx8_q[entry] <= {`RNF_NUM{1'b0}};
                else if(mshr_l3_entry_vec_sx7[entry] && l3_rd_busy_s2_q[entry])
                    mshr_snp_bit_sx8_q[entry] <= l3_snp_bit_sx7_q;
                else if(mshr_seq_s1_q[entry] && mshr_can_alloc_entry_s1_q[entry])
                    mshr_snp_bit_sx8_q[entry] <= {`RNF_NUM{1'b1}};
                else
                    ;
            end

            always_ff @(posedge clk)begin : mshr_snpcode_sx8_q_timing_logic
                if(mshr_can_retire_entry_sx1[entry])
                    mshr_snpcode_sx8_q[entry] <= chie_pkg::SNP_SNPLCRDRETURN;
                else if(mshr_l3_entry_vec_sx7[entry])
                    mshr_snpcode_sx8_q[entry] <= mshr_snpcode_sx7;
                else if(mshr_seq_s1_q[entry])
                    mshr_snpcode_sx8_q[entry] <= chie_pkg::SNP_SNPCLEANINVALID;
                else
                    ;
            end
        end
    endgenerate

    always_comb begin : l3_opcode_decode_comb_logic
        case(l3_opcode_sx7_q)
            chie_pkg::REQ_READONCE           :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPONCE;
            // Table 4-24 (Sec 4.4.2 p.4-194) gives ReadUnique the snoop SnpUnique, and
            // Sec 4.4.2 (p.4-196) permits replacing an Invalidating snoop only by
            // SnpUnique or SnpCleanInvalid. SnpMakeInvalid is not reachable from a
            // read: Sec 2.3.9 (p.2-84) allows it only SnpResp, so a Snoopee holding
            // the line Dirty would discard it and the L3 copy would be served stale.
            chie_pkg::REQ_READUNIQUE         :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPUNIQUE;
            chie_pkg::REQ_READNOTSHAREDDIRTY :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPNOTSHAREDDIRTY;
            chie_pkg::REQ_READCLEAN          :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPCLEAN;
            chie_pkg::REQ_WRITEUNIQUEPTL     :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPUNIQUE;
            chie_pkg::REQ_WRITEUNIQUEFULL    :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPMAKEINVALID;
            chie_pkg::REQ_CLEANSHARED        :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPCLEANSHARED;
            chie_pkg::REQ_CLEANUNIQUE        :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPCLEANINVALID;
            chie_pkg::REQ_CLEANINVALID       :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPCLEANINVALID;
            chie_pkg::REQ_MAKEUNIQUE         :
                mshr_snpcode_sx7 = chie_pkg::SNP_SNPMAKEINVALID;
            default mshr_snpcode_sx7 = chie_pkg::SNP_SNPLCRDRETURN;
        endcase
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_l3_resp_sx8_q_timing_logic
                if(rst == 1'b1)begin
                    mshr_l3_resp_sx8_q[entry] <= chie_pkg::RESP_I;
                end
                else if(mshr_can_retire_entry_sx1[entry])begin
                    mshr_l3_resp_sx8_q[entry] <= chie_pkg::RESP_I;
                end
                else if(mshr_l3_entry_vec_sx7[entry])begin
                    case(l3_opcode_sx7_q)
                        chie_pkg::REQ_READUNIQUE          :
                            mshr_l3_resp_sx8_q[entry] <= l3_hit_d_sx7_q? chie_pkg::RESP_UC_PD:chie_pkg::RESP_UC_UD;
                        chie_pkg::REQ_READCLEAN           :
                            mshr_l3_resp_sx8_q[entry] <= ((!l3_sfhit_sx7_q & !(l3_hit_d_sx7_q & l3_hit_sx7_q))||((l3_hit_d_sx7_q & l3_hit_sx7_q) & !l3_sfhit_sx7_q))? chie_pkg::RESP_UC_UD:chie_pkg::RESP_SC;
                        chie_pkg::REQ_READNOTSHAREDDIRTY  :
                            mshr_l3_resp_sx8_q[entry] <= (!l3_sfhit_sx7_q & l3_hit_d_sx7_q)? chie_pkg::RESP_UC_PD: (!l3_sfhit_sx7_q & !l3_hit_d_sx7_q)? chie_pkg::RESP_UC_UD:chie_pkg::RESP_SC;
                        default:
                            mshr_l3_resp_sx8_q[entry] <= chie_pkg::RESP_I;
                    endcase
                end
                else
                    ;
            end
        end
    endgenerate

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_l3_decode_comb_logic
            assign mshr_l3_replay_sx7[entry]
                   = (l3_mshr_entry_sx7_q == entry) & l3_pipeval_sx7_q & l3_replay_sx7_q;
            assign mshr_l3_entry_vec_sx7[entry] = mshr_l3_val_sx7 & (l3_mshr_entry_sx7_q == entry);
            assign mshr_clr_l3busy_sx7[entry]   = mshr_l3_entry_vec_sx7[entry];
            assign mshr_l3_rd_l3fill_sx7[entry] = mshr_l3_entry_vec_sx7[entry] & ((!l3_hit_sx7_q & l3_sfhit_sx7_q & (mshr_rdnosd_s1_q[entry] | mshr_rc_s1_q[entry])));
            assign mshr_neednosnp_sx7[entry]    = mshr_l3_entry_vec_sx7[entry] & l3_rd_busy_s2_q[entry] & ((!l3_snpdirect_sx7_q & ~l3_snpbrd_sx7_q) | (l3_hit_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_READONCE | l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN | l3_opcode_sx7_q == chie_pkg::REQ_READNOTSHAREDDIRTY)));
            assign mshr_needsnp_sx7[entry]      = mshr_l3_entry_vec_sx7[entry] & (l3_snpdirect_sx7_q | l3_snpbrd_sx7_q) & ~(l3_hit_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_READONCE | l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN | l3_opcode_sx7_q == chie_pkg::REQ_READNOTSHAREDDIRTY));
            assign mshr_l3_memrd_sx7[entry]     = mshr_l3_entry_vec_sx7[entry] & ((l3_memrd_sx7_q & (l3_opcode_sx7_q != chie_pkg::REQ_WRITEUNIQUEPTL)) | (l3_memrd_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_WRITEUNIQUEPTL) & mshr_memattr_s1_q[entry][3] & (~l3_hit_sx7_q) & (~l3_sfhit_sx7_q)));
            assign mshr_l3_evict_sx7[entry]     = mshr_l3_entry_vec_sx7[entry] & l3_evict_sx7_q;
            assign mshr_l3_memwr_sx7[entry]     = mshr_l3_entry_vec_sx7[entry] & ((l3_hit_d_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_CLEANSHARED | l3_opcode_sx7_q == chie_pkg::REQ_CLEANINVALID | l3_opcode_sx7_q == chie_pkg::REQ_CLEANUNIQUE | (!l3_sfhit_sx7_q & l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN))) |
                    ((l3_opcode_sx7_q == chie_pkg::REQ_WRITEUNIQUEPTL) & ~mshr_memattr_s1_q[entry][3] & ~l3_sfhit_sx7_q & l3_rd_busy_s2_q[entry]));
            assign mshr_l3dat_rn_sx7[entry]     = mshr_l3_entry_vec_sx7[entry] & l3_hit_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_READONCE | l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN | l3_opcode_sx7_q == chie_pkg::REQ_READNOTSHAREDDIRTY | l3_opcode_sx7_q == chie_pkg::REQ_READUNIQUE);
            assign mshr_l3dat_sn_sx7[entry]     = (mshr_l3_entry_vec_sx7[entry] & l3_hit_d_sx7_q & (l3_opcode_sx7_q == chie_pkg::REQ_CLEANUNIQUE | l3_opcode_sx7_q == chie_pkg::REQ_CLEANSHARED | l3_opcode_sx7_q == chie_pkg::REQ_CLEANINVALID | (l3_opcode_sx7_q == chie_pkg::REQ_READCLEAN & !l3_sfhit_sx7_q))) | (l3_evict_sx7_q & mshr_l3_entry_vec_sx7[entry]);
        end
    endgenerate

    //************************************************************************//

    //                        mshr set/clr busy/rdy logic

    //************************************************************************//

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_busy_rdy_deocde_comb_logic
            assign l3_rd_busy_set_s1[entry]
                   = (mshr_alloc_l3rd_s1[entry] & ~excl_fail_s1);
            assign l3_rd_busy_clr_s1[entry]          = (mshr_clr_l3busy_sx7[entry]);
            assign l3_fill_busy_set_sx[entry]        = (mshr_alloc_l3fill_s1[entry]) ||
                   (mshr_l3_rd_l3fill_sx7[entry]);
            assign l3_fill_busy_clr_sx[entry]        = (mshr_clr_l3busy_sx7[entry] & (~l3_rd_busy_s2_q[entry])) ||
                   (mshr_dat_stop_cb_s1_q[entry] & mshr_dat_entry_vec_s1_q[entry]);
            assign l3_rd_rdy_set_s2[entry]           = (mshr_alloc_l3rd_s1[entry] & (~excl_fail_s1)) ||
                   (mshr_l3_replay_sx7[entry] & l3_rd_busy_s2_q[entry]);
            assign l3_rd_rdy_clr_s2[entry]           = (~l3_mshr_wr_op_sx7_q & mshr_l3_entry_vec_sx1[entry]);
            assign l3_fill_rdy_set_s2[entry]         = (l3_fill_data_busy_sx_q[entry] & (mshr_all_dat_alloc_s1[entry] | mshr_new_dat_l3fill_s1[entry]) & ~mshr_dat_stop_cb_s1_q[entry]) ||
                   (l3_fill_data_busy_sx_q[entry] & mshr_old_dat_l3fill_s1[entry] & ~mshr_compack_busy_sx_q[entry] & ~mshr_rn_data_busy_sx_q[entry]) ||
                   (mshr_l3_replay_sx7[entry] & ~l3_rd_busy_s2_q[entry]);
            assign l3_fill_rdy_clr_s2[entry]         = (~l3_mshr_wr_op_sx7_q & ~l3_rd_rdy_s2_q[entry] & mshr_l3_entry_vec_sx1[entry]);
            assign l3_fill_data_busy_set_sx[entry]   = (mshr_alloc_l3fill_s1[entry]) ||
                   (mshr_l3_rd_l3fill_sx7[entry]);
            assign l3_fill_data_busy_clr_sx[entry]   = (mshr_all_dat_alloc_s1[entry]) ||
                   (mshr_new_dat_l3fill_s1[entry]) ||
                   (mshr_old_dat_l3fill_s1[entry] & ~mshr_compack_busy_sx_q[entry] & ~mshr_rn_data_busy_sx_q[entry]);
            assign mshr_snp_busy_set_sx[entry]       = (mshr_alloc_snp_s1[entry] & ~excl_fail_s1);
            assign mshr_snp_busy_clr_sx[entry]       = (mshr_neednosnp_sx7[entry]) ||
                   (mshr_snp_getall_s1[entry]);
            assign mshr_mem_rd_busy_set_sx[entry]    = (mshr_alloc_memrd_s1[entry]) || (mshr_l3_memrd_sx7[entry]) || (mshr_snp_memrd_s1[entry]);
            assign mshr_mem_rd_busy_clr_sx[entry]    = (mshr_dat_to_rn_s1[entry]) ||
                   (mshr_get_compack_s1_q[entry] & mshr_dmt_sx8_q[entry]) ||
                   (mshr_get_rd_receipt_s1_q[entry]) ||
                   (mshr_all_dat_alloc_s1[entry]);
            assign mshr_mem_wr_busy_set_sx[entry]    = (mshr_alloc_memwr_s1[entry] & ~excl_fail_s1) ||
                   (mshr_cb_wr_mem_s1_q[entry] & mshr_dat_entry_vec_s1_q[entry]) ||
                   (mshr_l3_memwr_sx7[entry]) ||
                   (mshr_snp_memwr_s1[entry] & mshr_snpdat_entry_vec_s1_q[entry]) ||
                   (mshr_wup_memwr_s1[entry]) ||
                   (mshr_l3_evict_sx7[entry]);
            assign mshr_mem_wr_busy_clr_sx[entry]    = (mshr_comp_entry_vec_s1_q[entry]);
            assign mshr_mem_rd_rdy_set_sx[entry]     = (mshr_alloc_memrd_s1[entry] && txreq_mshr_bypass_lost_s1) ||
                   (mshr_l3_memrd_sx7[entry]) ||
                   (mshr_snp_memrd_s1[entry]) ||
                   (mshr_mem_rd_busy_sx_q[entry] & mshr_resent_s1_q[entry]);
            assign mshr_mem_rd_rdy_clr_sx[entry]     = (txreq_mshr_won_sx1 & mshr_txreq_entry_vec_sx1[entry]);
            assign mshr_mem_wr_rdy_set_sx[entry]     = (mshr_alloc_memwr_s1[entry] & txreq_mshr_bypass_lost_s1 & ~excl_fail_s1) ||
                   (mshr_cb_wr_mem_s1_q[entry] & mshr_dat_entry_vec_s1_q[entry]) ||
                   (mshr_l3_memwr_sx7[entry]) ||
                   (mshr_snp_memwr_s1[entry] & mshr_snpdat_entry_vec_s1_q[entry]) ||
                   (mshr_wup_memwr_s1[entry]) ||
                   (mshr_l3_evict_sx7[entry]) ||
                   (mshr_mem_wr_busy_sx_q[entry] & mshr_resent_s1_q[entry]);
            assign mshr_mem_wr_rdy_clr_sx[entry]     = (txreq_mshr_won_sx1 & mshr_txreq_entry_vec_sx1[entry]);
            assign mshr_rn_data_busy_set_sx[entry]   = (mshr_dat_to_rn_s1[entry]) || (mshr_l3dat_rn_sx7[entry]) ||
                   (mshr_errrd_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_rn_data_busy_clr_sx[entry]   = (txdat_mshr_clr_dbf_busy_entry_vec_sx3[entry]);
            assign mshr_sn_data_busy_set_sx[entry]   = (mshr_alloc_datbuf_sn_s1[entry]) ||
                   (mshr_l3_memwr_sx7[entry]) ||
                   (mshr_snp_memwr_s1[entry] & mshr_snpdat_entry_vec_s1_q[entry]) ||
                   (mshr_wup_memwr_s1[entry]) ||
                   (mshr_l3_evict_sx7[entry]) ||
                   (mshr_errwrdat_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_sn_data_busy_clr_sx[entry]   = (mshr_excl_fail_s2_q[entry] & mshr_dat_new_get_s1_q[entry]) ||
                   (~mshr_rn_data_busy_sx_q[entry] & txdat_mshr_clr_dbf_busy_entry_vec_sx3[entry]) ||
                   (mshr_dat_stop_cb_s1_q[entry] & mshr_dat_entry_vec_s1_q[entry]) ||
                   (mshr_errwrdat_s1_q[entry] & mshr_dat_new_get_s1_q[entry]);
            // Sec 4.11.2 (p.4-243, MUST): "While a Snoop transaction response is
            // pending, the only transaction responses that are permitted to be
            // sent to the same address are ... RetryAck and, if applicable, a
            // ReadReceipt for a Read request type." So the L3-hit release takes
            // the same (neednosnp | snp_getall) gate mshr_comp_rdy_set_s2 gives
            // a Dataless request. The deferred arm is a pulse, not a level: the
            // ready flop gives set priority over clear.
            assign mshr_txdat_rn_rdy_set_sx[entry]   = (mshr_dat_to_rn_s1[entry]) ||
                   (mshr_l3dat_rn_sx7[entry] & mshr_neednosnp_sx7[entry]) ||
                   (mshr_l3hit_sx8_q[entry] & mshr_ru_s1_q[entry] & mshr_snp_getall_s1[entry] &
                    (mshr_snprsp_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry])) ||
                   (mshr_errrd_s1_q[entry] & mshr_dbf_err_fill_entry_sx1[entry]);
            assign mshr_txdat_rn_rdy_clr_sx[entry]   = (mshr_dbf_rd_entry_sx1[entry] & ~txdat_mshr_busy_sx);
            assign mshr_txdat_sn_rdy_set_sx[entry]   = (mshr_wu_s1_q[entry] & ~mshr_memattr_s1_q[entry][3] & mshr_dat_new_get_s1_q[entry] & mshr_get_dbid_s1_q[entry] & (mshr_snp_getall_s1[entry] | ((mshr_snpcnt_sx_q[entry]==0) & (l3_rd_busy_s2_q[entry] == 0))) & (mshr_dat_entry_vec_s1_q[entry] | mshr_dbid_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | mshr_snprsp_entry_vec_s1_q[entry] | mshr_l3_entry_vec_sx8_q[entry])) ||
                   ((mshr_wrnosnp_s1_q[entry])&(mshr_dat_new_get_s1_q[entry] & mshr_get_dbid_s1_q[entry]) & (mshr_dat_entry_vec_s1_q[entry] | mshr_dbid_entry_vec_s1_q[entry])) ||
                   ((mshr_wb_s1_q[entry] | mshr_wc_s1_q[entry]) & (mshr_dat_new_get_s1_q[entry] & mshr_rn_dat_get_d_s1_q[entry] & mshr_get_dbid_s1_q[entry]) & (mshr_dat_entry_vec_s1_q[entry] | mshr_dbid_entry_vec_s1_q[entry])) ||
                   ((mshr_l3dat_sn_sx8_q[entry] | mshr_snp_memwr_s1[entry]) & mshr_get_dbid_s1_q[entry] & (mshr_snpdat_entry_vec_s1_q[entry] | mshr_l3_entry_vec_sx8_q[entry] | mshr_dbid_entry_vec_s1_q[entry]));
            assign mshr_txdat_sn_rdy_clr_sx[entry]   = (~mshr_txdat_rn_rdy_sx_q[entry] & mshr_dbf_rd_entry_sx1[entry] & ~txdat_mshr_busy_sx);
            // The err class is invisible to hnf_mshr_bypass, so txrsp_mshr_bypass_lost_s1
            // is never asserted for it; its arms hang off the allocation instead.
            assign mshr_dbid_rdy_set_s2[entry]       = (mshr_alloc_dbid_s1[entry] & txrsp_mshr_bypass_lost_s1 & ~mshr_alloc_dwt_s1[entry]) ||
                   (mshr_errgrant_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_dbid_rdy_clr_s2[entry]       = (mshr_txrsp_entry_vec_sx1[entry] & txrsp_mshr_won_sx1);
            assign mshr_rd_receipt_rdy_set_s2[entry] = (mshr_alloc_rd_receipt_s1[entry] & txrsp_mshr_bypass_lost_s1);
            assign mshr_rd_receipt_rdy_clr_s2[entry] = (mshr_txrsp_entry_vec_sx1[entry] & txrsp_mshr_won_sx1);
            assign mshr_comp_rdy_set_s2[entry]       = (mshr_wu_s1_q[entry] & (mshr_snp_getall_s1[entry] | mshr_neednosnp_sx8_q[entry]) & mshr_get_comp_s1_q[entry] & mshr_dwt_s2_q[entry] & (mshr_snprsp_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | mshr_comp_entry_vec_s1_q[entry] | mshr_wuf_neednosnp_vec_sx8_q[entry])) ||
                   (mshr_wu_s1_q[entry] & ~mshr_dwt_s2_q[entry] & (mshr_snp_getall_s1[entry] | mshr_neednosnp_sx7[entry]) & (mshr_snprsp_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | (mshr_l3_entry_vec_sx7[entry] & ~l3_sfhit_sx7_q & l3_rd_busy_s2_q[entry]))) ||
                   ((mshr_wb_s1_q[entry] | mshr_wc_s1_q[entry] | mshr_we_s1_q[entry] | mshr_wrnosnp_s1_q[entry]) & mshr_alloc_comp_s1[entry] & txrsp_mshr_bypass_lost_s1 & (~mshr_dwt_s2_q[entry])) ||
                   ((mshr_wrnosnp_s1_q[entry]) & (mshr_get_comp_s1_q[entry]) & mshr_comp_entry_vec_s1_q[entry] & mshr_dwt_s2_q[entry]) ||
                   ((mshr_cu_s1_q[entry] | mshr_cs_s1_q[entry] | mshr_ci_s1_q[entry] | mshr_mu_s1_q[entry] | mshr_evi_s1_q[entry]) & (mshr_neednosnp_sx7[entry] | mshr_snp_getall_s1[entry]) & (mshr_snprsp_entry_vec_s1_q[entry] | mshr_snpdat_entry_vec_s1_q[entry] | mshr_l3_entry_vec_sx7[entry])) ||
                   (mshr_cu_s1_q[entry] & excl_fail_s1 & mshr_can_alloc_entry_s1_q[entry]) ||
                   (mshr_err_s1_q[entry] & ~mshr_errrd_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_comp_rdy_clr_s2[entry]       = (mshr_txrsp_entry_vec_sx1[entry] & txrsp_mshr_won_sx1);
            assign mshr_comp_busy_set_s2[entry]      = (mshr_alloc_comp_s1[entry] & txrsp_mshr_bypass_lost_s1) ||
                   (mshr_can_alloc_entry_s1_q[entry] & (mshr_cu_s1_q[entry] | mshr_cs_s1_q[entry] | mshr_ci_s1_q[entry] | mshr_mu_s1_q[entry] | mshr_evi_s1_q[entry] | mshr_wu_s1_q[entry])) ||
                   (mshr_alloc_dwt_s1[entry]) ||
                   (mshr_err_s1_q[entry] & ~mshr_errrd_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_comp_busy_clr_s2[entry]      = (mshr_txrsp_entry_vec_sx1[entry] & txrsp_mshr_won_sx1 & mshr_comp_rdy_s2_q[entry]);
            assign mshr_compack_busy_set_sx[entry]   = (mshr_can_alloc_entry_s0[entry] & li_mshr_rxreq_expcompack_s0);
            assign mshr_compack_busy_clr_sx[entry]   = (mshr_get_compack_s1_q[entry]);
            assign mshr_txsnp_rdy_set_sx[entry]      = (mshr_needsnp_sx7[entry]) ||
                   (mshr_seq_s1_q[entry] & mshr_can_alloc_entry_s1_q[entry]);
            assign mshr_txsnp_rdy_clr_sx[entry]      = (mshr_txsnp_entry_vec_sx1[entry] & ~txsnp_mshr_busy_sx1);
        end
    endgenerate

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_excl_fail_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_excl_fail_s2_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_excl_fail_s2_q[entry] <= 1'b0;
                else if(mshr_can_alloc_entry_s1_q[entry])
                    mshr_excl_fail_s2_q[entry] <= excl_fail_s1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dwt_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_dwt_s2_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_dwt_s2_q[entry] <= 1'b0;
                else if(mshr_alloc_dwt_s1[entry])
                    mshr_dwt_s2_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_entry_valid_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(mshr_can_retire_entry_sx1[entry])
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(mshr_can_alloc_entry_s1_q[entry])
                    mshr_entry_valid_sx_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : l3_rd_busy_s2_q_timing_logic
                if(rst == 1'b1)
                    l3_rd_busy_s2_q[entry] <= 1'b0;
                else if(l3_rd_busy_set_s1[entry])
                    l3_rd_busy_s2_q[entry] <= 1'b1;
                else if(l3_rd_busy_clr_s1[entry])
                    l3_rd_busy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : l3_fill_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    l3_fill_busy_sx_q[entry] <= 1'b0;
                else if(l3_fill_busy_set_sx[entry])
                    l3_fill_busy_sx_q[entry] <= 1'b1;
                else if(l3_fill_busy_clr_sx[entry])
                    l3_fill_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : l3_rd_rdy_s2_q_timing_logic
                if(rst == 1'b1)
                    l3_rd_rdy_s2_q[entry] <= 1'b0;
                else if(l3_rd_rdy_set_s2[entry])
                    l3_rd_rdy_s2_q[entry] <= 1'b1;
                else if(l3_rd_rdy_clr_s2[entry])
                    l3_rd_rdy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : l3_fill_rdy_s2_q_timing_logic
                if(rst == 1'b1)
                    l3_fill_rdy_s2_q[entry] <= 1'b0;
                else if(l3_fill_rdy_set_s2[entry])
                    l3_fill_rdy_s2_q[entry] <= 1'b1;
                else if(l3_fill_rdy_clr_s2[entry])
                    l3_fill_rdy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : l3_fill_data_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    l3_fill_data_busy_sx_q[entry] <= 1'b0;
                else if(l3_fill_data_busy_set_sx[entry])
                    l3_fill_data_busy_sx_q[entry] <= 1'b1;
                else if(l3_fill_data_busy_clr_sx[entry])
                    l3_fill_data_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_snp_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_snp_busy_sx_q[entry] <= 1'b0;
                else if(mshr_snp_busy_set_sx[entry])
                    mshr_snp_busy_sx_q[entry] <= 1'b1;
                else if(mshr_snp_busy_clr_sx[entry])
                    mshr_snp_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_mem_rd_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_mem_rd_busy_sx_q[entry] <= 1'b0;
                else if(mshr_mem_rd_busy_set_sx[entry])
                    mshr_mem_rd_busy_sx_q[entry] <= 1'b1;
                else if(mshr_mem_rd_busy_clr_sx[entry])
                    mshr_mem_rd_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_mem_wr_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_mem_wr_busy_sx_q[entry] <= 1'b0;
                else if(mshr_mem_wr_busy_set_sx[entry])
                    mshr_mem_wr_busy_sx_q[entry] <= 1'b1;
                else if(mshr_mem_wr_busy_clr_sx[entry])
                    mshr_mem_wr_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_mem_rd_rdy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_mem_rd_rdy_sx_q[entry] <= 1'b0;
                else if(mshr_mem_rd_rdy_set_sx[entry])
                    mshr_mem_rd_rdy_sx_q[entry] <= 1'b1;
                else if(mshr_mem_rd_rdy_clr_sx[entry])
                    mshr_mem_rd_rdy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_mem_wr_rdy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_mem_wr_rdy_sx_q[entry] <= 1'b0;
                else if(mshr_mem_wr_rdy_set_sx[entry])
                    mshr_mem_wr_rdy_sx_q[entry] <= 1'b1;
                else if(mshr_mem_wr_rdy_clr_sx[entry])
                    mshr_mem_wr_rdy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_rn_data_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_rn_data_busy_sx_q[entry] <= 1'b0;
                else if(mshr_rn_data_busy_set_sx[entry])
                    mshr_rn_data_busy_sx_q[entry] <= 1'b1;
                else if(mshr_rn_data_busy_clr_sx[entry])
                    mshr_rn_data_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_sn_data_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_sn_data_busy_sx_q[entry] <= 1'b0;
                else if(mshr_sn_data_busy_set_sx[entry])
                    mshr_sn_data_busy_sx_q[entry] <= 1'b1;
                else if(mshr_sn_data_busy_clr_sx[entry])
                    mshr_sn_data_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_txdat_rn_rdy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_txdat_rn_rdy_sx_q[entry] <= 1'b0;
                else if(mshr_txdat_rn_rdy_set_sx[entry])
                    mshr_txdat_rn_rdy_sx_q[entry] <= 1'b1;
                else if(mshr_txdat_rn_rdy_clr_sx[entry])
                    mshr_txdat_rn_rdy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_txdat_sn_rdy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_txdat_sn_rdy_sx_q[entry] <= 1'b0;
                else if(mshr_txdat_sn_rdy_set_sx[entry])
                    mshr_txdat_sn_rdy_sx_q[entry] <= 1'b1;
                else if(mshr_txdat_sn_rdy_clr_sx[entry])
                    mshr_txdat_sn_rdy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_dbid_rdy_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_dbid_rdy_s2_q[entry] <= 1'b0;
                else if(mshr_dbid_rdy_set_s2[entry])
                    mshr_dbid_rdy_s2_q[entry] <= 1'b1;
                else if(mshr_dbid_rdy_clr_s2[entry])
                    mshr_dbid_rdy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_rd_receipt_rdy_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_rd_receipt_rdy_s2_q[entry] <= 1'b0;
                else if(mshr_rd_receipt_rdy_set_s2[entry])
                    mshr_rd_receipt_rdy_s2_q[entry] <= 1'b1;
                else if(mshr_rd_receipt_rdy_clr_s2[entry])
                    mshr_rd_receipt_rdy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_comp_rdy_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_comp_rdy_s2_q[entry] <= 1'b0;
                else if (mshr_comp_rdy_set_s2[entry])
                    mshr_comp_rdy_s2_q[entry] <= 1'b1;
                else if(mshr_comp_rdy_clr_s2[entry])
                    mshr_comp_rdy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_comp_busy_s2_q_timing_logic
                if(rst == 1'b1)
                    mshr_comp_busy_s2_q[entry] <= 1'b0;
                else if(mshr_comp_busy_set_s2[entry])
                    mshr_comp_busy_s2_q[entry] <= 1'b1;
                else if(mshr_comp_busy_clr_s2[entry])
                    mshr_comp_busy_s2_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_compack_busy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_compack_busy_sx_q[entry] <= 1'b0;
                else if(mshr_compack_busy_set_sx[entry])
                    mshr_compack_busy_sx_q[entry] <= 1'b1;
                else if(mshr_compack_busy_clr_sx[entry])
                    mshr_compack_busy_sx_q[entry] <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_txsnp_rdy_sx_q_timing_logic
                if(rst == 1'b1)
                    mshr_txsnp_rdy_sx_q[entry] <= 1'b0;
                else if(mshr_txsnp_rdy_set_sx[entry])
                    mshr_txsnp_rdy_sx_q[entry] <= 1'b1;
                else if(mshr_txsnp_rdy_clr_sx[entry])
                    mshr_txsnp_rdy_sx_q[entry] <= 1'b0;
                else
                    ;
            end
        end
    endgenerate

    generate
        for (entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_busy_rdy_set_comb_logic
            assign mshr_pipeline_busy_sx[entry]
                   = l3_rd_busy_s2_q[entry] | l3_fill_busy_sx_q[entry];
            assign mshr_mem_busy_sx[entry]      = mshr_mem_rd_busy_sx_q[entry] | mshr_mem_wr_busy_sx_q[entry];
            assign mshr_datbuf_busy_sx[entry]   = mshr_rn_data_busy_sx_q[entry] | mshr_sn_data_busy_sx_q[entry];
            assign mshr_rsp_busy_sx[entry]      = mshr_comp_busy_s2_q[entry] | mshr_dbid_rdy_s2_q[entry] | mshr_rd_receipt_rdy_s2_q[entry];
            assign mshr_txdat_rdy_sx[entry]     = mshr_txdat_rn_rdy_sx_q[entry] | mshr_txdat_sn_rdy_sx_q[entry];
            assign mshr_txreq_rdy_sx[entry]     = mshr_mem_rd_rdy_sx_q[entry] | mshr_mem_wr_rdy_sx_q[entry];
            assign mshr_pipeline_rdy_sx[entry]  = l3_rd_rdy_s2_q[entry] | l3_fill_rdy_s2_q[entry];
            assign mshr_txrsp_rdy_sx[entry]     = mshr_comp_rdy_s2_q[entry] | mshr_dbid_rdy_s2_q[entry] | mshr_rd_receipt_rdy_s2_q[entry];
            assign mshr_entry_busy_sx[entry]    = mshr_pipeline_busy_sx[entry] | mshr_mem_busy_sx[entry] | mshr_datbuf_busy_sx[entry] | mshr_rsp_busy_sx[entry] | mshr_snp_busy_sx_q[entry] | mshr_compack_busy_sx_q[entry];
        end
    endgenerate

    //************************************************************************//

    //                            mshr retire logic

    //************************************************************************//

    assign mshr_retire_rdy =  mshr_entry_valid_sx_q & ~mshr_entry_busy_sx & ~sleep_sx_q & {`MSHR_ENTRIES_NUM{~mshr_retire_busy_sx1_q}};

    assign mshr_retire_sx = |mshr_retire_rdy;

    always_ff @(posedge clk or posedge rst)begin : mshr_dbf_retired_valid_sx1_q_timing_logic
        if (rst == 1'b1)
            mshr_dbf_retired_valid_sx1_q <= 1'b0;
        else
            mshr_dbf_retired_valid_sx1_q <= mshr_retire_sx;
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_retire_busy_sx1_q_timing_logic
        if (rst == 1'b1)
            mshr_retire_busy_sx1_q <= 1'b0;
        else
            mshr_retire_busy_sx1_q <= mshr_retire_sx;
    end

    always_comb begin:find_mshr_retire_min_idx_comb_logic
        integer i;
        mshr_retire_min_idx_sx             = {`MSHR_ENTRIES_WIDTH{1'b0}};
        found_retire_min_idx               = 1'b0;
        mshr_l3_seq_min_idx_retire_sx1     = 1'b0;
        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1) begin:find_mshr_retire_min_idx
            if(mshr_retire_rdy[i] == 1'b1 && !found_retire_min_idx)begin
                mshr_retire_min_idx_sx         = i[`MSHR_ENTRIES_WIDTH-1:0];
                mshr_l3_seq_min_idx_retire_sx1 = mshr_seq_s1_q[i];
                found_retire_min_idx           = 1'b1;
            end
            else begin
                mshr_retire_min_idx_sx         = mshr_retire_min_idx_sx;
                mshr_l3_seq_min_idx_retire_sx1 = mshr_l3_seq_min_idx_retire_sx1;
                found_retire_min_idx           = found_retire_min_idx;
            end
        end
    end

    assign mshr_dbf_retired_idx_sx = mshr_oldest_is_retire? mshr_retire_oldest_idx_sx : mshr_retire_min_idx_sx;

    always_ff @(posedge clk or posedge rst)begin : mshr_dbf_retired_idx_sx1_q_timing_logic
        if(rst == 1'b1)
            mshr_dbf_retired_idx_sx1_q <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        else if(mshr_retire_sx == 1'b1)
            mshr_dbf_retired_idx_sx1_q <= mshr_dbf_retired_idx_sx;
        else
            mshr_dbf_retired_idx_sx1_q <= mshr_dbf_retired_idx_sx1_q;
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_retire_entry_comb_logic
            assign mshr_can_retire_entry_sx1[entry]
                   = mshr_dbf_retired_valid_sx1_q & (mshr_dbf_retired_idx_sx1_q == entry);
        end
    endgenerate

    //************************************************************************//

    //                            mshr seq retire logic

    //************************************************************************//

    always_comb begin:find_the_oldest_idx_entry
        integer i;
        mshr_retire_oldest_idx_sx             = {`MSHR_ENTRIES_WIDTH{1'b0}};
        mshr_oldest_is_retire                 = 1'b0;
        found_retire_oldest_idx               = 1'b0;
        mshr_l3_seq_oldest_idx_retire_sx1     = 1'b0;
        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin : find_mshr_retire_oldest_idx
            if(mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0] == i[`MSHR_ENTRIES_WIDTH-1:0]) & ~mshr_entry_busy_sx[i] & ~sleep_sx_q[i] & !found_retire_oldest_idx)begin
                mshr_retire_oldest_idx_sx         = i[`MSHR_ENTRIES_WIDTH-1:0];
                mshr_l3_seq_oldest_idx_retire_sx1 = mshr_seq_s1_q[i];
                mshr_oldest_is_retire             = 1'b1;
                found_retire_oldest_idx           = 1'b1;
            end
            else begin
                mshr_retire_oldest_idx_sx         = mshr_retire_oldest_idx_sx;
                mshr_l3_seq_oldest_idx_retire_sx1 = mshr_l3_seq_oldest_idx_retire_sx1;
                mshr_oldest_is_retire             = mshr_oldest_is_retire;
                found_retire_oldest_idx           = found_retire_oldest_idx;
            end
        end
    end

    assign mshr_l3_seq_retire_sx = mshr_oldest_is_retire? mshr_l3_seq_oldest_idx_retire_sx1 : mshr_l3_seq_min_idx_retire_sx1;

    always_ff @(posedge clk or posedge rst)begin : mshr_l3_seq_retire_sx1_q_timing_logic
        if(rst == 1'b1)
            mshr_l3_seq_retire_sx1_q <= 1'b0;
        else if(mshr_retire_sx == 1'b1)
            mshr_l3_seq_retire_sx1_q <= mshr_l3_seq_retire_sx;
        else
            mshr_l3_seq_retire_sx1_q <= 1'b0;
    end

    //************************************************************************//

    //                              mshrageq logic

    //************************************************************************//

    //mshrageq valid logic
    always_comb begin: find_next_ageq_alloc_entry_comb_logic
        integer entry;
        mshrageq_alloc_entry_ptr_sx1                 = {`MSHR_ENTRIES_NUM{1'b0}};
        found_mshrageq_alloc_entry                   = 1'b0;
        if (mshrageq_v_sx2_q[`MSHR_ENTRIES_NUM-1] == 1'b1)
            mshrageq_alloc_entry_ptr_sx1               = {`MSHR_ENTRIES_NUM{1'b0}};
        else if (mshrageq_v_sx2_q[`MSHR_ENTRIES_NUM-1:0] == {`MSHR_ENTRIES_NUM{1'b0}})
            mshrageq_alloc_entry_ptr_sx1[0]            = 1'b1;
        else begin
            for (entry=`MSHR_ENTRIES_NUM-1; entry>=1; entry=entry-1) begin : nxt_ageq_alloc_entry
                if ((mshrageq_v_sx2_q[entry] == 1'b0) && (mshrageq_v_sx2_q[entry-1] == 1'b1) && !found_mshrageq_alloc_entry) begin
                    mshrageq_alloc_entry_ptr_sx1[entry] = 1'b1;
                    found_mshrageq_alloc_entry          = 1'b1;
                end
                else begin
                    mshrageq_alloc_entry_ptr_sx1[entry] = mshrageq_alloc_entry_ptr_sx1[entry];
                    found_mshrageq_alloc_entry          = found_mshrageq_alloc_entry;
                end
            end
        end
    end

    //determine mshrageq allocate entry logic
    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            assign mshrageq_alloc_entry_s1[entry]
                   = mshr_alloc_en_s1_q & mshrageq_alloc_entry_ptr_sx1[entry];
        end
    endgenerate

    //mshrageq shift logic
    //entry[0] no needs shift

    always_comb begin: mshrageq_shift_comb_logic
        integer i;
        mshrageq_shift = {`MSHR_ENTRIES_NUM{1'b0}};
        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1) begin
            if(i == 0)
                mshrageq_shift[i] = ~mshrageq_v_sx2_q[i];
            else
                mshrageq_shift[i] = mshrageq_shift[i-1] | ~mshrageq_v_sx2_q[i];
        end
    end

    //determine mshrageq retire entry logic
    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            assign mshrageq_retire_entry_sx1[entry]
                   = mshrageq_v_sx2_q[entry] & mshr_dbf_retired_valid_sx1_q & (mshr_dbf_retired_idx_sx1_q == mshrageq_mshr_idx_sx2_q[entry]);
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin: update_retire_valid_timing_logic
        if(rst == 1'b1)
            mshr_dbf_retired_valid_sx2_q <= 1'b0;
        else
            mshr_dbf_retired_valid_sx2_q <= mshr_dbf_retired_valid_sx1_q;
    end

    //mshr_ageq load new transaction
    assign mshrageq_shift_sx2   = {`MSHR_ENTRIES_NUM{mshr_dbf_retired_valid_sx2_q}} & mshrageq_shift;
    assign ageq_needs_shift_sx2 = |(mshrageq_v_sx2_q & mshrageq_shift_sx2);

    assign mshrageq_load_sx1 = (ageq_needs_shift_sx2 & mshr_dbf_retired_valid_sx2_q)? {1'b0, mshrageq_alloc_entry_s1[`MSHR_ENTRIES_NUM-1:1]}:
           mshrageq_alloc_entry_s1;

    assign mshrageq_flop_en_s1 = mshrageq_load_sx1         |
           mshrageq_retire_entry_sx1 |
           mshrageq_shift_sx2        ;

    assign mshrageq_v_sx1 = mshrageq_load_sx1 |
           (mshrageq_shift & {1'b0, mshrageq_v_sx2_q[`MSHR_ENTRIES_NUM-1:1] } & { 1'b0, ~mshrageq_retire_entry_sx1[`MSHR_ENTRIES_NUM-1:1] });  // shift and not done

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: update_mshrageq_valid_timing_logic
                if (rst == 1'b1)
                    mshrageq_v_sx2_q[entry] <= 1'b0;
                else if (mshrageq_flop_en_s1[entry] == 1'b1)
                    mshrageq_v_sx2_q[entry] <= mshrageq_v_sx1[entry];
                else
                    mshrageq_v_sx2_q[entry] <= mshrageq_v_sx2_q[entry];
            end
        end
    endgenerate

    //mshr_ageq index logic
    always_comb begin: mshrageq_idx_comb_logic
        integer i;
        //last entry
        mshrageq_mshr_idx_sx1[`MSHR_ENTRIES_NUM-1] = mshrageq_load_sx1[`MSHR_ENTRIES_NUM-1]? mshr_entry_idx_alloc_s1_q: mshrageq_mshr_idx_sx2_q[`MSHR_ENTRIES_NUM-1];
        //rest entries
        for(i=0; i<`MSHR_ENTRIES_NUM-1; i=i+1) begin
            mshrageq_mshr_idx_sx1[i] = mshrageq_load_sx1[i]? mshr_entry_idx_alloc_s1_q: mshrageq_mshr_idx_sx2_q[i+1];
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin
            always_ff @(posedge clk) begin: update_mshrageq_idx_timing_logic
                if(rst == 1'b1)
                    mshrageq_mshr_idx_sx2_q[entry] <= {`MSHR_ENTRIES_WIDTH{1'b0}};
                else if (mshrageq_flop_en_s1[entry] == 1'b1)
                    mshrageq_mshr_idx_sx2_q[entry] <= mshrageq_mshr_idx_sx1[entry];
                else
                    mshrageq_mshr_idx_sx2_q[entry] <= mshrageq_mshr_idx_sx2_q[entry];
            end
        end
    endgenerate

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_alloc_entry_comb_logic
            assign mshr_can_alloc_entry_s0[entry]
                   = mshr_alloc_en_s0 & (mshr_entry_idx_alloc_s0 == entry);
        end
    endgenerate

    always_ff @(posedge clk or posedge rst)begin : mshr_can_alloc_entry_s1_q_timing_logic
        if(rst == 1'b1)begin
            mshr_can_alloc_entry_s1_q <= {`MSHR_ENTRIES_NUM{1'b0}};
        end
        else begin
            mshr_can_alloc_entry_s1_q <= mshr_can_alloc_entry_s0;
        end
    end

    //************************************************************************//

    //                      mshr sleep/hazard/wakeup logic

    //************************************************************************//

    always_comb begin: rxreq_cam_hazard_entry_convert_to_idx
        integer i;
        found_rxreq_cam_hazard_idx     = 1'b0;
        rxreq_cam_hazard_idx_s1        = {`MSHR_ENTRIES_WIDTH{1'b0}};
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(rxreq_cam_hazard_entry_s1_q[i] == 1'b1 && !found_rxreq_cam_hazard_idx)begin
                rxreq_cam_hazard_idx_s1    = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_rxreq_cam_hazard_idx = 1'b1;
            end
            else begin
                rxreq_cam_hazard_idx_s1    = rxreq_cam_hazard_idx_s1;
                found_rxreq_cam_hazard_idx = found_rxreq_cam_hazard_idx;
            end
        end
    end

    always_comb begin: pipe_sleep_entry_convert_to_idx
        integer i;
        found_pipe_sleep_idx     = 1'b0;
        pipe_sleep_idx_sx3       = {`MSHR_ENTRIES_WIDTH{1'b0}};
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(pipe_sleep_entry_sx3_q[i] == 1'b1 && !found_pipe_sleep_idx)begin
                pipe_sleep_idx_sx3   = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_pipe_sleep_idx = 1'b1;
            end
            else begin
                pipe_sleep_idx_sx3   = pipe_sleep_idx_sx3;
                found_pipe_sleep_idx = found_pipe_sleep_idx;
            end
        end
    end

    always_comb begin: pipe_cam_hazard_entry_convert_to_idx
        integer i;
        found_pipe_cam_hazard_idx     = 1'b0;
        pipe_cam_hazard_idx_sx3       = {`MSHR_ENTRIES_WIDTH{1'b0}};
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(pipe_cam_hazard_entry_sx3_q[i] == 1'b1 && !found_pipe_cam_hazard_idx)begin
                pipe_cam_hazard_idx_sx3   = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_pipe_cam_hazard_idx = 1'b1;
            end
            else begin
                pipe_cam_hazard_idx_sx3   = pipe_cam_hazard_idx_sx3;
                found_pipe_cam_hazard_idx = found_pipe_cam_hazard_idx;
            end
        end
    end

    wire rxreq_hz_sx = rxreq_cam_hazard_s1_q
         & ~((rxreq_cam_hazard_entry_s1_q == mshr_can_retire_entry_sx1) & mshr_dbf_retired_valid_sx1_q);
    wire pipe_hz_sx  = mshr_l3_hazard_valid_sx3_q
         & ~((pipe_cam_hazard_entry_sx3_q == mshr_can_retire_entry_sx1) & mshr_dbf_retired_valid_sx1_q);

    generate
        for(entry=0; entry<`MSHR_ENTRIES_NUM; entry=entry+1) begin : mshr_sleep_wakeup_gen
            wire wake_fire_sx = (mshr_dbf_retired_valid_sx1_q & (mshr_dbf_retired_idx_sx1_q == entry))
                              | (l3_evict_sx7_q               & (l3_mshr_entry_sx7_q        == entry));

            wire sleep_set_sx = (rxreq_hz_sx & (mshr_entry_idx_alloc_s1_q == entry))
                              | (pipe_hz_sx  & (pipe_sleep_idx_sx3        == entry));

            wire sleep_clr_sx = (mshr_dbf_retired_valid_sx1_q & need_to_wakeup_vec_sx_q[mshr_dbf_retired_idx_sx1_q][entry])
                              | (l3_evict_sx7_q               & need_to_wakeup_vec_sx_q[l3_mshr_entry_sx7_q       ][entry]);

            // Set beats clear: the coincidence means released from an old blocker
            // and slept for a fresh hazard in one cycle, and the fresh hazard's
            // own bit is recorded below in the same cycle.
            always_ff @(posedge clk or posedge rst) begin : mshr_sleep_timing_logic
                if(rst)               sleep_sx_q[entry] <= 1'b0;
                else if(sleep_set_sx) sleep_sx_q[entry] <= 1'b1;
                else if(sleep_clr_sx) sleep_sx_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst) begin : need_to_wakeup_vec_timing_logic
                integer s;
                if(rst)
                    need_to_wakeup_vec_sx_q[entry] <= {`MSHR_ENTRIES_NUM{1'b0}};
                else
                    for(s=0; s<`MSHR_ENTRIES_NUM; s=s+1)
                        if((rxreq_hz_sx & (rxreq_cam_hazard_idx_s1 == entry) & (mshr_entry_idx_alloc_s1_q == s[`MSHR_ENTRIES_WIDTH-1:0]))
                         | (pipe_hz_sx  & (pipe_cam_hazard_idx_sx3 == entry) & (pipe_sleep_idx_sx3        == s[`MSHR_ENTRIES_WIDTH-1:0])))
                            need_to_wakeup_vec_sx_q[entry][s] <= 1'b1;
                        else if(wake_fire_sx)
                            need_to_wakeup_vec_sx_q[entry][s] <= 1'b0;
            end
        end
    endgenerate

    //************************************************************************//

    //                   mshr find 1 entry to send logic

    //************************************************************************//

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_determine_entry_comb_logic
            assign txreq_wrap_ageq_vec[entry]
                   = mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0]==entry) & mshr_txreq_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] &
                   (txreq_mshr_won_sx1 | (~mshr_txreq_valid_sx1_q)) & (((~mshr_txreq_valid_sx1_q)) | (mshr_txreq_txnid_sx1_q!=entry));

            assign txreq_wrap_other_vec[entry] = mshr_txreq_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (txreq_mshr_won_sx1 | (~mshr_txreq_valid_sx1_q)) &
                   (((~mshr_txreq_valid_sx1_q)) | (mshr_txreq_txnid_sx1_q!=entry));

            assign txrsp_wrap_ageq_vec[entry] = mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0]==entry) & mshr_txrsp_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] &
                   (txrsp_mshr_won_sx1 | (~mshr_txrsp_valid_sx1_q)) & (((~mshr_txrsp_valid_sx1_q)) | (mshr_txrsp_idx_sx1_q!=entry));

            assign txrsp_wrap_other_vec[entry] = mshr_txrsp_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (txrsp_mshr_won_sx1 | (~mshr_txrsp_valid_sx1_q)) &
                   (((~mshr_txrsp_valid_sx1_q)) | (mshr_txrsp_idx_sx1_q!=entry));

            assign txsnp_wrap_ageq_vec[entry] = mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0]==entry) & mshr_txsnp_rdy_sx_q[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (~txsnp_mshr_busy_sx1) &
                   ((~mshr_txsnp_valid_sx1_q) | (mshr_txsnp_txnid_sx1_q!=entry));

            assign txsnp_wrap_other_vec[entry] = mshr_txsnp_rdy_sx_q[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (~txsnp_mshr_busy_sx1) & ((~mshr_txsnp_valid_sx1_q) | (mshr_txsnp_txnid_sx1_q!=entry));

            assign txdat_wrap_ageq_vec[entry] = mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0]==entry) & mshr_txdat_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (~txdat_mshr_busy_sx) &
                   ((~mshr_dbf_rd_valid_sx1_q) | (mshr_dbf_rd_idx_sx1_q!=entry));

            assign txdat_wrap_other_vec[entry] = mshr_txdat_rdy_sx[entry] & (~sleep_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (~txdat_mshr_busy_sx) & ((!mshr_dbf_rd_valid_sx1_q) | (mshr_dbf_rd_idx_sx1_q!=entry));

            assign cpl_wrap_ageq_vec[entry] = mshrageq_v_sx2_q[0] & (mshrageq_mshr_idx_sx2_q[0]==entry) & mshr_pipeline_rdy_sx[entry] & (~sleep_sx_q[entry]) & (~(l3_mshr_wr_op_sx7_q & mshr_l3_req_en_sx1_q)) & mshr_entry_valid_sx_q[entry] &
                   ((~mshr_l3_req_en_sx1_q) | (mshr_l3_entry_idx_sx1_q!=entry));

            assign cpl_wrap_other_vec[entry] = mshr_pipeline_rdy_sx[entry] & (~sleep_sx_q[entry]) & (~(l3_mshr_wr_op_sx7_q & mshr_l3_req_en_sx1_q)) & mshr_entry_valid_sx_q[entry] & ((~mshr_l3_req_en_sx1_q) | (mshr_l3_entry_idx_sx1_q!=entry));
        end
    endgenerate

    //************************************************************************//

    //                      mshr txreqflit wrap logic

    //************************************************************************//

    always_comb begin: txreq_wrap_other_ptr_comb_logic
        integer i;
        txreq_wrap_other_ptr_vector = {`MSHR_ENTRIES_NUM{1'b0}};
        txreq_wrap_other_ptr        = {`MSHR_ENTRIES_NUM{1'b0}};
        found_txreq_wrap_other_ptr  = 1'b0;
        txreq_wrap_other_idx        = {`MSHR_ENTRIES_WIDTH{1'b0}};

        for (i=1; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txreq_wrap_other_ptr_vector[i] = txreq_wrap_other_ptr_vector[i-1] | txreq_wrap_other_vec[i-1];
        end

        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txreq_wrap_other_ptr[i] = ~txreq_wrap_other_ptr_vector[i] & txreq_wrap_other_vec[i];
            if(txreq_wrap_other_ptr[i] == 1'b1 & found_txreq_wrap_other_ptr == 1'b0)begin
                txreq_wrap_other_idx = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_txreq_wrap_other_ptr = 1'b1;
            end
            else begin
                txreq_wrap_other_idx = txreq_wrap_other_idx;
                found_txreq_wrap_other_ptr = found_txreq_wrap_other_ptr;
            end
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_txreq_timing_logic
        if(rst == 1'b1)begin
            mshr_txreq_valid_sx1_q     <= 1'b0;
            mshr_txreq_txnid_sx1_q     <= '0;
        end
        else if(txreq_wrap_ageq_vec[mshrageq_mshr_idx_sx2_q[0]])begin
            mshr_txreq_valid_sx1_q     <= 1'b1;
            mshr_txreq_txnid_sx1_q     <= {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, mshrageq_mshr_idx_sx2_q[0]};
        end
        else if(txreq_wrap_other_ptr[txreq_wrap_other_idx])begin
            mshr_txreq_valid_sx1_q     <= 1'b1;
            mshr_txreq_txnid_sx1_q     <= {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, txreq_wrap_other_idx};
        end
        else if(txreq_mshr_won_sx1 && mshr_txreq_valid_sx1_q)begin
            mshr_txreq_valid_sx1_q     <= 1'b0;
            mshr_txreq_txnid_sx1_q     <= '0;
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_txreq_entry_vec_sx1_comb_logic
            assign mshr_txreq_entry_vec_sx1[entry]
                   = (mshr_txreq_txnid_sx1_q == entry) & mshr_txreq_valid_sx1_q;
        end
    endgenerate

    assign mshr_txreq_qos_sx1         = (mshr_qos_s1_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_returnnid_sx1   = ((mshr_dmt_sx8_q[mshr_txreq_entry_idx_sx1] | mshr_dwt_s2_q[mshr_txreq_entry_idx_sx1])?mshr_srcid_s1_q[mshr_txreq_entry_idx_sx1]:HNF_NID_PARAM);
    assign mshr_txreq_returntxnid_sx1 = ((mshr_dmt_sx8_q[mshr_txreq_entry_idx_sx1] | mshr_dwt_s2_q[mshr_txreq_entry_idx_sx1])?mshr_txnid_s1_q[mshr_txreq_entry_idx_sx1]:mshr_txreq_txnid_sx1_q);
    assign mshr_txreq_opcode_sx1      = (mshr_mem_rd_busy_sx_q[mshr_txreq_entry_idx_sx1]?chie_pkg::REQ_READNOSNP:(mshr_wup_s1_q[mshr_txreq_entry_idx_sx1] | mshr_wrnosnpp_s1_q[mshr_txreq_entry_idx_sx1])?chie_pkg::REQ_WRITENOSNPPTL:chie_pkg::REQ_WRITENOSNPFULL);
    assign mshr_txreq_size_sx1        = (((mshr_wup_s1_q[mshr_txreq_entry_idx_sx1] & ((mshr_memattr_s1_q[mshr_txreq_entry_idx_sx1][3]) | (~mshr_memattr_s1_q[mshr_txreq_entry_idx_sx1][3] & (mshr_l3hit_sx8_q[mshr_txreq_entry_idx_sx1] | mshr_dat_old_get_s1_q[mshr_txreq_entry_idx_sx1])))) | (mshr_seq_s1_q[mshr_txreq_entry_idx_sx1]))? chie_pkg::SIZE_64B : mshr_size_s1_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_ns_sx1          = (mshr_ns_s1_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_allowretry_sx1  = (!mshr_retry_s1_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_order_sx1       = ((mshr_sn_order_s1_q[mshr_txreq_entry_idx_sx1] & mshr_dmt_sx8_q[mshr_txreq_entry_idx_sx1])?chie_pkg::ORDER_RSVD:chie_pkg::ORDER_NONE);
    assign mshr_txreq_pcrdtype_sx1    = (mshr_retry_s1_q[mshr_txreq_entry_idx_sx1]?mshr_pcrdtype_s1_q[mshr_txreq_entry_idx_sx1]:0);
    // Sec 2.9.3 (p.2-129, MUST): a ReadNoSnp or WriteNoSnp "generated within the
    // interconnect due to a Prefetch from Home or an eviction from the System
    // cache" carries EWA, Cacheable and Allocate all 1 and Device 0.
    // mshr_seq_s1_q = snoop-filter evict; abf_internal_evict_addr_valid_sx_q =
    // SLC victim.
    assign mshr_txreq_memattr_sx1     = (mshr_seq_s1_q[mshr_txreq_entry_idx_sx1] | abf_internal_evict_addr_valid_sx_q[mshr_txreq_entry_idx_sx1]) ? 4'b1101 : (mshr_memattr_s1_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_dodwt_sx1       = (mshr_dwt_s2_q[mshr_txreq_entry_idx_sx1]);
    assign mshr_txreq_tracetag_sx1    = mshr_tracetag_s1_q[mshr_txreq_entry_idx_sx1];

    //************************************************************************//

    //                      mshr txrspflit wrap logic

    //************************************************************************//

    always_comb begin: txrsp_wrap_other_ptr_comb_logic
        integer i;
        txrsp_wrap_other_ptr_vector = {`MSHR_ENTRIES_NUM{1'b0}};
        txrsp_wrap_other_ptr        = {`MSHR_ENTRIES_NUM{1'b0}};
        found_txrsp_wrap_other_ptr  = 1'b0;
        txrsp_wrap_other_idx        = {`MSHR_ENTRIES_WIDTH{1'b0}};

        for (i=1; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txrsp_wrap_other_ptr_vector[i] = txrsp_wrap_other_ptr_vector[i-1] | txrsp_wrap_other_vec[i-1];
        end

        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txrsp_wrap_other_ptr[i] = ~txrsp_wrap_other_ptr_vector[i] & txrsp_wrap_other_vec[i];
            if(txrsp_wrap_other_ptr[i] == 1'b1 & found_txrsp_wrap_other_ptr == 1'b0)begin
                txrsp_wrap_other_idx = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_txrsp_wrap_other_ptr = 1'b1;
            end
            else begin
                txrsp_wrap_other_idx = txrsp_wrap_other_idx;
                found_txrsp_wrap_other_ptr = found_txrsp_wrap_other_ptr;
            end
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_txrsp_timing_logic
        if(rst == 1'b1) begin
            mshr_txrsp_valid_sx1_q  <= 1'b0;
            mshr_txrsp_txnid_sx1_q  <= '0;
            mshr_txrsp_idx_sx1_q    <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(txrsp_wrap_ageq_vec[mshrageq_mshr_idx_sx2_q[0]])begin
            mshr_txrsp_valid_sx1_q  <= 1'b1;
            mshr_txrsp_txnid_sx1_q  <= mshr_txnid_s1_q[mshrageq_mshr_idx_sx2_q[0]];
            mshr_txrsp_idx_sx1_q    <= mshrageq_mshr_idx_sx2_q[0];
        end
        else if(txrsp_wrap_other_ptr[txrsp_wrap_other_idx])begin
            mshr_txrsp_valid_sx1_q  <= 1'b1;
            mshr_txrsp_txnid_sx1_q  <= mshr_txnid_s1_q[txrsp_wrap_other_idx];
            mshr_txrsp_idx_sx1_q    <= txrsp_wrap_other_idx;
        end
        else if(txrsp_mshr_won_sx1 && mshr_txrsp_valid_sx1_q)begin
            mshr_txrsp_valid_sx1_q  <= 1'b0;
            mshr_txrsp_txnid_sx1_q  <= '0;
            mshr_txrsp_idx_sx1_q    <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_txrsp_entry_vec_sx1_comb_logic
            assign mshr_txrsp_entry_vec_sx1[entry]
                   = (mshr_txrsp_idx_sx1_q == entry) & mshr_txrsp_valid_sx1_q;
        end
    endgenerate

    assign mshr_txrsp_qos_sx1      = (mshr_qos_s1_q[mshr_txrsp_idx_sx1_q]);
    assign mshr_txrsp_tgtid_sx1    = (mshr_srcid_s1_q[mshr_txrsp_idx_sx1_q]);
    assign mshr_txrsp_opcode_sx1   = (mshr_rd_receipt_rdy_s2_q[mshr_txrsp_idx_sx1_q]?chie_pkg::RSP_READRECEIPT:(mshr_comp_rdy_s2_q[mshr_txrsp_idx_sx1_q] & mshr_dbid_rdy_s2_q[mshr_txrsp_idx_sx1_q])?chie_pkg::RSP_COMPDBIDRESP:mshr_comp_rdy_s2_q[mshr_txrsp_idx_sx1_q]?chie_pkg::RSP_COMP:chie_pkg::RSP_DBIDRESP);
    // Sec 9.1 (p.9-334): NDERR for "an attempt to use a transaction type that is not
    // supported", which Sec 9.4.4 (p.9-342, MUST) makes a Non-data Error -- the
    // transaction structure is intact, only its status says it was not serviced.
    // Table A-8 (p.A-488) gives ReadReceipt and DBIDResp a RespErr of 0, so a
    // status -- a Subordinate's included -- rides out on the Comp that follows,
    // never on the buffer grant or the request-accepted acknowledgement.
    assign mshr_txrsp_resperr_sx1  = ((mshr_txrsp_opcode_sx1 == chie_pkg::RSP_READRECEIPT) ||
                                      (mshr_txrsp_opcode_sx1 == chie_pkg::RSP_DBIDRESP)) ? chie_pkg::RESP_ERR_NORM_OK :
                                     mshr_err_s1_q[mshr_txrsp_idx_sx1_q] ? chie_pkg::RESP_ERR_NON_DATA :
                                     mshr_dn_resperr_s1_q[mshr_txrsp_idx_sx1_q][1] ? mshr_dn_resperr_s1_q[mshr_txrsp_idx_sx1_q] :
                                     (((mshr_cu_s1_q[mshr_txrsp_idx_sx1_q] | mshr_wrnosnp_s1_q[mshr_txrsp_idx_sx1_q]) & mshr_excl_s1_q[mshr_txrsp_idx_sx1_q] & (!mshr_excl_fail_s2_q[mshr_txrsp_idx_sx1_q]))? chie_pkg::RESP_ERR_EX_OK:chie_pkg::RESP_ERR_NORM_OK);
    assign mshr_txrsp_resp_sx1     = ((mshr_cu_s1_q[mshr_txrsp_idx_sx1_q] | mshr_mu_s1_q[mshr_txrsp_idx_sx1_q] | mshr_cs_s1_q[mshr_txrsp_idx_sx1_q])?chie_pkg::RESP_UC_UD:chie_pkg::RESP_I);
    // CHI E.b Sec 2.5.9 (p.2-90, MUST): "A Comp response message sent separate from
    // a DBIDResp or DBIDRespOrd message for a Write transaction must include the
    // same DBID field value in the Comp and DBIDResp or DBIDRespOrd message." The
    // MSHR index IS that value where this Home granted the buffer itself; under DWT
    // it never did, so the Comp echoes the DBID the Subordinate granted.
    assign mshr_txrsp_dbid_sx1     = mshr_dwt_s2_q[mshr_txrsp_idx_sx1_q]
                                   ? mshr_dwt_dbid_s1_q[mshr_txrsp_idx_sx1_q]
                                   : {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, mshr_txrsp_idx_sx1_q};
    assign mshr_txrsp_tracetag_sx1 = mshr_tracetag_s1_q[mshr_txrsp_idx_sx1_q];

    //************************************************************************//

    //                      mshr txsnpflit wrap logic

    //************************************************************************//

    always_comb begin: txsnp_wrap_other_ptr_comb_logic
        integer i;
        txsnp_wrap_other_ptr_vector = {`MSHR_ENTRIES_NUM{1'b0}};
        txsnp_wrap_other_ptr        = {`MSHR_ENTRIES_NUM{1'b0}};
        found_txsnp_wrap_other_ptr  = 1'b0;
        txsnp_wrap_other_idx        = {`MSHR_ENTRIES_WIDTH{1'b0}};

        for (i=1; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txsnp_wrap_other_ptr_vector[i] = txsnp_wrap_other_ptr_vector[i-1] | txsnp_wrap_other_vec[i-1];
        end

        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txsnp_wrap_other_ptr[i] = ~txsnp_wrap_other_ptr_vector[i] & txsnp_wrap_other_vec[i];
            if(txsnp_wrap_other_ptr[i] == 1'b1 & found_txsnp_wrap_other_ptr == 1'b0)begin
                txsnp_wrap_other_idx = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_txsnp_wrap_other_ptr = 1'b1;
            end
            else begin
                txsnp_wrap_other_idx = txsnp_wrap_other_idx;
                found_txsnp_wrap_other_ptr = found_txsnp_wrap_other_ptr;
            end
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_txsnp_timing_logic
        if(rst == 1'b1)begin
            mshr_txsnp_valid_sx1_q  <= 1'b0;
            mshr_txsnp_txnid_sx1_q  <= '0;
        end
        else if(txsnp_wrap_ageq_vec[mshrageq_mshr_idx_sx2_q[0]])begin
            mshr_txsnp_valid_sx1_q  <= 1'b1;
            mshr_txsnp_txnid_sx1_q  <= {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, mshrageq_mshr_idx_sx2_q[0]};
        end
        else if(txsnp_wrap_other_ptr[txsnp_wrap_other_idx])begin
            mshr_txsnp_valid_sx1_q  <= 1'b1;
            mshr_txsnp_txnid_sx1_q  <= {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, txsnp_wrap_other_idx};
        end
        else if(~txsnp_mshr_busy_sx1 && mshr_txsnp_valid_sx1_q)begin
            mshr_txsnp_valid_sx1_q  <= 1'b0;
            mshr_txsnp_txnid_sx1_q  <= '0;
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_txsnp_entry_vec_sx1_comb_logic
            assign mshr_txsnp_entry_vec_sx1[entry]
                   = (mshr_txsnp_txnid_sx1_q == entry) & mshr_txsnp_valid_sx1_q;
        end
    endgenerate

    assign mshr_txsnp_qos_sx1      = (mshr_qos_s1_q[mshr_txsnp_entry_idx_sx1]);
    assign mshr_txsnp_fwdnid_sx1   = mshr_dct_sx8_q[mshr_txsnp_entry_idx_sx1]? (mshr_srcid_s1_q[mshr_txsnp_entry_idx_sx1]) : '0;
    assign mshr_txsnp_fwdtxnid_sx1 = mshr_dct_sx8_q[mshr_txsnp_entry_idx_sx1]? (mshr_txnid_s1_q[mshr_txsnp_entry_idx_sx1]) : '0;
    assign mshr_txsnp_opcode_sx1   = (mshr_dct_sx8_q[mshr_txsnp_entry_idx_sx1]?chie_pkg::snp_opcode_e'(mshr_snpcode_sx8_q[mshr_txsnp_entry_idx_sx1] + 5'h10):mshr_snpcode_sx8_q[mshr_txsnp_entry_idx_sx1]);
    assign mshr_txsnp_ns_sx1       = (mshr_ns_s1_q[mshr_txsnp_entry_idx_sx1]);
    assign mshr_txsnp_rettosrc_sx1 = (mshr_retosrc_sx8_q[mshr_txsnp_entry_idx_sx1]);
    assign mshr_txsnp_tracetag_sx1 = mshr_tracetag_s1_q[mshr_txsnp_entry_idx_sx1];
    assign mshr_txsnp_rn_vec_sx1   = (mshr_snp_bit_sx8_q[mshr_txsnp_entry_idx_sx1]);

    //************************************************************************//

    //                      mshr request cpl wrap logic

    //************************************************************************//

    always_ff @(posedge clk or posedge rst)begin : cpl_rob_logic
        if(rst == 1'b1) begin
            cpl_rob <= 0;
        end
        else begin
            cpl_rob <= cpl_rob + 'b1;
        end
    end

    always_comb begin: cpl_wrap_other_ptr_comb_logic
        integer i;
        cpl_wrap_other_ptr_vector   = {`MSHR_ENTRIES_NUM{1'b0}};
        cpl_wrap_other_ptr          = {`MSHR_ENTRIES_NUM{1'b0}};
        found_cpl_wrap_other_ptr    = 1'b0;
        cpl_wrap_other_idx          = {`MSHR_ENTRIES_WIDTH{1'b0}};
        for (i=1; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            cpl_wrap_other_ptr_vector[i] = cpl_wrap_other_ptr_vector[i-1] | cpl_wrap_other_vec[i-1];
        end

        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            cpl_wrap_other_ptr[i] = ~cpl_wrap_other_ptr_vector[i] & cpl_wrap_other_vec[i];
            if(cpl_wrap_other_ptr[i] == 1'b1 & found_cpl_wrap_other_ptr == 1'b0)begin
                cpl_wrap_other_idx = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_cpl_wrap_other_ptr = 1'b1;
            end
            else begin
                cpl_wrap_other_idx = cpl_wrap_other_idx;
                found_cpl_wrap_other_ptr = found_cpl_wrap_other_ptr;
            end
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_l3_timing_logic
        if(rst == 1'b1) begin
            mshr_l3_req_en_sx1_q     <= 1'b0;
            mshr_l3_fill_sx1_q       <= 1'b0;
            mshr_l3_rnf_sx1_q        <= {CHIE_NID_WIDTH_PARAM{1'b0}};
            mshr_l3_opcode_sx1_q     <= chie_pkg::REQ_REQLCRDRETURN;
            mshr_l3_entry_idx_sx1_q  <= {`MSHR_ENTRIES_WIDTH{1'b0}};
            mshr_l3_fill_dirty_sx1_q <= 1'b0;
        end
        else if(cpl_wrap_ageq_vec[mshrageq_mshr_idx_sx2_q[0]])begin
            mshr_l3_req_en_sx1_q     <= 1'b1;
            mshr_l3_fill_sx1_q       <= (!l3_rd_rdy_s2_q[mshrageq_mshr_idx_sx2_q[0]]);
            mshr_l3_rnf_sx1_q        <= (mshr_srcid_s1_q[mshrageq_mshr_idx_sx2_q[0]]);
            mshr_l3_opcode_sx1_q     <= (mshr_opcode_s1_q[mshrageq_mshr_idx_sx2_q[0]]);
            mshr_l3_entry_idx_sx1_q  <= mshrageq_mshr_idx_sx2_q[0];
            mshr_l3_fill_dirty_sx1_q <= (mshr_snp_d_s1_q[mshrageq_mshr_idx_sx2_q[0]] | mshr_rn_dat_get_d_s1_q[mshrageq_mshr_idx_sx2_q[0]] | mshr_l3hit_d_sx8_q[mshrageq_mshr_idx_sx2_q[0]])&(!l3_rd_rdy_s2_q[mshrageq_mshr_idx_sx2_q[0]]);
        end
        else if(cpl_wrap_other_vec[cpl_rob])begin
            mshr_l3_req_en_sx1_q     <= 1'b1;
            mshr_l3_fill_sx1_q       <= (!l3_rd_rdy_s2_q[cpl_rob]);
            mshr_l3_rnf_sx1_q        <= (mshr_srcid_s1_q[cpl_rob]);
            mshr_l3_opcode_sx1_q     <= (mshr_opcode_s1_q[cpl_rob]);
            mshr_l3_entry_idx_sx1_q  <= cpl_rob;
            mshr_l3_fill_dirty_sx1_q <= (mshr_snp_d_s1_q[cpl_rob] | mshr_rn_dat_get_d_s1_q[cpl_rob] | mshr_l3hit_d_sx8_q[cpl_rob])&(!l3_rd_rdy_s2_q[cpl_rob]);
        end
        else if(cpl_wrap_other_ptr[cpl_wrap_other_idx])begin
            mshr_l3_req_en_sx1_q     <= 1'b1;
            mshr_l3_fill_sx1_q       <= (!l3_rd_rdy_s2_q[cpl_wrap_other_idx]);
            mshr_l3_rnf_sx1_q        <= (mshr_srcid_s1_q[cpl_wrap_other_idx]);
            mshr_l3_opcode_sx1_q     <= (mshr_opcode_s1_q[cpl_wrap_other_idx]);
            mshr_l3_entry_idx_sx1_q  <= cpl_wrap_other_idx;
            mshr_l3_fill_dirty_sx1_q <= (mshr_snp_d_s1_q[cpl_wrap_other_idx] | mshr_rn_dat_get_d_s1_q[cpl_wrap_other_idx] | mshr_l3hit_d_sx8_q[cpl_wrap_other_idx])&(!l3_rd_rdy_s2_q[cpl_wrap_other_idx]);
        end
        else if(!l3_mshr_wr_op_sx7_q && mshr_l3_req_en_sx1_q)begin
            mshr_l3_req_en_sx1_q     <= 1'b0;
            mshr_l3_fill_sx1_q       <= 1'b0;
            mshr_l3_rnf_sx1_q        <= {CHIE_NID_WIDTH_PARAM{1'b0}};
            mshr_l3_opcode_sx1_q     <= chie_pkg::REQ_REQLCRDRETURN;
            mshr_l3_entry_idx_sx1_q  <= {`MSHR_ENTRIES_WIDTH{1'b0}};
            mshr_l3_fill_dirty_sx1_q <= 1'b0;
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_l3_entry_vec_sx1_comb_logic
            assign mshr_l3_entry_vec_sx1[entry]
                   = (mshr_l3_entry_idx_sx1_q == entry) & mshr_l3_req_en_sx1_q;
        end
    endgenerate

    //************************************************************************//

    //                      mshr txdatflit wrap logic

    //************************************************************************//

    always_comb begin
        mshr_txdat_tgtid_sx2   = (mshr_rn_data_busy_sx_q[txdat_mshr_rd_idx_sx2]?mshr_srcid_s1_q[txdat_mshr_rd_idx_sx2]:SNF_NID_PARAM);
        mshr_txdat_txnid_sx2   = (mshr_rn_data_busy_sx_q[txdat_mshr_rd_idx_sx2]?mshr_txnid_s1_q[txdat_mshr_rd_idx_sx2]:mshr_dbid_s1_q[txdat_mshr_rd_idx_sx2]);
        mshr_txdat_opcode_sx2  = (mshr_rn_data_busy_sx_q[txdat_mshr_rd_idx_sx2]?chie_pkg::DAT_COMPDATA:chie_pkg::DAT_NONCOPYBACKWRDATA);
        mshr_txdat_resp_sx2    = (mshr_rn_data_busy_sx_q[txdat_mshr_rd_idx_sx2]?((mshr_snp_d_s1_q[txdat_mshr_rd_idx_sx2]&mshr_ru_s1_q[txdat_mshr_rd_idx_sx2])?chie_pkg::RESP_UC_PD:mshr_l3_resp_sx8_q[txdat_mshr_rd_idx_sx2]):chie_pkg::RESP_I);
        mshr_txdat_resperr_sx2 = mshr_err_s1_q[txdat_mshr_rd_idx_sx2] ? chie_pkg::RESP_ERR_NON_DATA :
                                 mshr_dn_resperr_s1_q[txdat_mshr_rd_idx_sx2][1] ? mshr_dn_resperr_s1_q[txdat_mshr_rd_idx_sx2] :
                                 ((mshr_rn_data_busy_sx_q[txdat_mshr_rd_idx_sx2] & mshr_excl_s1_q[txdat_mshr_rd_idx_sx2] & (~mshr_excl_fail_s2_q[txdat_mshr_rd_idx_sx2]))? chie_pkg::RESP_ERR_EX_OK:chie_pkg::RESP_ERR_NORM_OK);
        mshr_txdat_dbid_sx2    = {{(12-`MSHR_ENTRIES_WIDTH){1'b0}}, txdat_mshr_rd_idx_sx2};
        // Sec 2.10.6 (p.2-139, MUST): "The CCID field must match the value of
        // Addr[5:4] of the original request."
        mshr_txdat_ccid_sx2    = mshr_addr_s1_q[txdat_mshr_rd_idx_sx2][5:4];
        mshr_txdat_tracetag_sx2 = mshr_tracetag_s1_q[txdat_mshr_rd_idx_sx2];
    end

    always_comb begin: txdat_wrap_other_ptr_comb_logic
        integer i;
        txdat_wrap_other_ptr_vector = {`MSHR_ENTRIES_NUM{1'b0}};
        txdat_wrap_other_ptr        = {`MSHR_ENTRIES_NUM{1'b0}};
        found_txdat_wrap_other_ptr  = 1'b0;
        txdat_wrap_other_idx        = {`MSHR_ENTRIES_WIDTH{1'b0}};

        for (i=1; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txdat_wrap_other_ptr_vector[i] = txdat_wrap_other_ptr_vector[i-1] | txdat_wrap_other_vec[i-1];
        end

        for(i=0; i<`MSHR_ENTRIES_NUM; i=i+1)begin
            txdat_wrap_other_ptr[i] = ~txdat_wrap_other_ptr_vector[i] & txdat_wrap_other_vec[i];
            if(txdat_wrap_other_ptr[i] == 1'b1 & found_txdat_wrap_other_ptr == 1'b0)begin
                txdat_wrap_other_idx = i[`MSHR_ENTRIES_WIDTH-1:0];
                found_txdat_wrap_other_ptr = 1'b1;
            end
            else begin
                txdat_wrap_other_idx = txdat_wrap_other_idx;
                found_txdat_wrap_other_ptr = found_txdat_wrap_other_ptr;
            end
        end
    end

    // The error fill: one pulse per errored read at its allocation, carrying no data
    // -- Sec 9.5's (p.9-347) rule that unusable data must not be consumed applies to
    // a Non-data Error the same way, and Sec 9.4.4 (p.9-342, MUST) asks only that the
    // packets be sent. Registered so it lands the cycle mshr_txdat_rn_rdy is set.
    always_ff @(posedge clk or posedge rst)begin : mshr_dbf_err_fill_timing_logic
        if(rst == 1'b1) begin
            mshr_dbf_err_fill_valid_sx1_q <= 1'b0;
            mshr_dbf_err_fill_idx_sx1_q   <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(|(mshr_errrd_s1_q & mshr_can_alloc_entry_s1_q))begin
            mshr_dbf_err_fill_valid_sx1_q <= 1'b1;
            mshr_dbf_err_fill_idx_sx1_q   <= mshr_entry_idx_alloc_s1_q;
        end
        else begin
            mshr_dbf_err_fill_valid_sx1_q <= 1'b0;
            mshr_dbf_err_fill_idx_sx1_q   <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_dbf_rd_timing_logic
        if(rst == 1'b1) begin
            mshr_dbf_rd_valid_sx1_q <= 1'b0;
            mshr_dbf_rd_idx_sx1_q   <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(txdat_wrap_ageq_vec[mshrageq_mshr_idx_sx2_q[0]])begin
            mshr_dbf_rd_valid_sx1_q <= 1'b1;
            mshr_dbf_rd_idx_sx1_q   <= mshrageq_mshr_idx_sx2_q[0];
        end
        else if(txdat_wrap_other_ptr[txdat_wrap_other_idx])begin
            mshr_dbf_rd_valid_sx1_q <= 1'b1;
            mshr_dbf_rd_idx_sx1_q   <= txdat_wrap_other_idx;
        end
        else if(!txdat_mshr_busy_sx && mshr_dbf_rd_valid_sx1_q)begin
            mshr_dbf_rd_valid_sx1_q <= 1'b0;
            mshr_dbf_rd_idx_sx1_q   <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        end
    end

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : mshr_dbf_rd_entry_sx1_comb_logic
            assign mshr_dbf_rd_entry_sx1[entry]
                   = (mshr_dbf_rd_idx_sx1_q == entry) & mshr_dbf_rd_valid_sx1_q;
            assign mshr_dbf_err_fill_entry_sx1[entry] = (mshr_dbf_err_fill_idx_sx1_q == entry) & mshr_dbf_err_fill_valid_sx1_q;
        end
    endgenerate

    generate
        for(entry=0;
                entry<`MSHR_ENTRIES_NUM;
                entry=entry+1) begin : txdat_mshr_clr_dbf_busy_entry_vec_sx3_comb_logic
            assign txdat_mshr_clr_dbf_busy_entry_vec_sx3[entry]
                   = (txdat_mshr_clr_dbf_busy_idx_sx3 == entry) & txdat_mshr_clr_dbf_busy_valid_sx3;
        end
    endgenerate

    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO

    always_ff @(posedge clk)begin
        integer i;
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(mshr_entry_valid_sx_q[i])begin
                `display_info($sformatf("MSHR ENTRY %0h :\n sleep: %h\n need_to_wakeup_vec: %h\n l3_rd_busy: %h\n l3_rd_rdy: %h\n l3_fill_busy: %h\n l3_fill_rdy: %h\n mshr_snp_busy: %h\n mshr_txsnp_rdy: %h\n mshr_mem_rd_busy: %h\n mshr_mem_rd_rdy: %h\n mshr_mem_wr_busy: %h\n mshr_mem_wr_rdy: %h\n mshr_rn_data_busy: %h\n mshr_txdat_rn_rdy: %h\n mshr_sn_data_busy: %h\n mshr_txdat_sn_rdy: %h\n mshr_dbid_rdy: %h\n mshr_rd_receipt_rdy: %h\n mshr_comp_rdy: %h\n mshr_comp_busy: %h\n mshr_compack_busy: %h\n time:%0h\n",i,sleep_sx_q[i],need_to_wakeup_vec_sx_q[i],l3_rd_busy_s2_q[i],l3_rd_rdy_s2_q[i],l3_fill_busy_sx_q[i],l3_fill_rdy_s2_q[i],mshr_snp_busy_sx_q[i],mshr_txsnp_rdy_sx_q[i],mshr_mem_rd_busy_sx_q[i],mshr_mem_rd_rdy_sx_q[i],mshr_mem_wr_busy_sx_q[i],mshr_mem_wr_rdy_sx_q[i],mshr_rn_data_busy_sx_q[i],mshr_txdat_rn_rdy_sx_q[i],mshr_sn_data_busy_sx_q[i],mshr_txdat_sn_rdy_sx_q[i],mshr_dbid_rdy_s2_q[i],mshr_rd_receipt_rdy_s2_q[i],mshr_comp_rdy_s2_q[i],mshr_comp_busy_s2_q[i],mshr_compack_busy_sx_q[i],$time()));
            end
        end
    end
`endif
endmodule
