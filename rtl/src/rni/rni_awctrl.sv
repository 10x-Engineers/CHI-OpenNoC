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
*    Ziqing Li <liziqing@bosc.ac.cn>
*    Wenhao Li <liwenhao@bosc.ac.cn>
*/

`include "rni_param.svh"
`include "rni_defines.svh"
`include "axi4_defines.svh"

module rni_awctrl `RNI_PARAM
    (
    // Global inputs
    input  wire                                clk_i,
    input  wire                                rst_i,

    /////////////////////////////////////////////////////////////
    // CHI face
    /////////////////////////////////////////////////////////////

    output chie_pkg::rsp_flit_s                awctrl_txrspflit_d0_o,
    output wire                                awctrl_txrspflitv_d0_o,
    input  wire                                awctrl_txrspflit_sent_d0_i,

    output chie_pkg::req_flit_s                awctrl_txreqflit_s4_o,
    output wire                                awctrl_txreqflitv_s4_o,
    input  wire                                awctrl_txreqflit_sent_s4_i,

    input  wire                                awctrl_rxrspflitv_d1_i,
    input  chie_pkg::rsp_flit_s                awctrl_rxrspflit_d1_i,

    /////////////////////////////////////////////////////////////
    // AMBA4 face
    /////////////////////////////////////////////////////////////

    input  wire                                AWVALID0,
    input  opennoc_rni_pkg::ax_ch_s            AW_CH_S0,
    output wire                                AWREADY0,

    ///////////////////////////////////////////////////////////////
    // Misc face
    ///////////////////////////////////////////////////////////////

    input  wire                                pcrdgnt_pkt_v_d2_i,
    input  opennoc_rni_pkg::pcrdgrant_pkt_s    pcrdgnt_pkt_d2_i,
    output wire                                awctrl_pcrdgnt_h_present_d3_o,
    output wire                                awctrl_pcrdgnt_l_present_d3_o,
    input  wire                                awctrl_pcrdgnt_h_win_d3_i,
    output wire                                awctrl_entry_any_v_o,
    input  wire                                awctrl_pcrdgnt_l_win_d3_i,

    output wire                                awctrl_alloc_valid_s2_o,
    output wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_alloc_entry_s2_o,
    output wire [`RNI_DMASK_CT_WIDTH-1:0]      awctrl_ctmask_s2_o,
    output wire [`RNI_DMASK_PD_WIDTH-1:0]      awctrl_pdmask_s2_o,
    output wire [`RNI_BCVEC_WIDTH-1:0]         awctrl_bc_vec_s2_o,

    // request deallocate
    output wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_dealloc_entry_o,

    // misc
    input  wire                                wb_req_fifo_pfull_d1_i,
    input  wire                                wb_req_done_d3_i,
    input  wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] wb_req_entry_d3_i,

    // txdatflit request
    input  wire                                wb_not_busy_d1_i,
    input  wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] wb_entry_all_be_i,
    input  wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] wb_entry_all_tu_i,
    // Sec 12.13 (p.12-390, MUST): the write data carries its request's TagOp.
    output wire [`AXI4_TAGOP_WIDTH-1:0]        awctrl_entry_tagop_o[RNI_AW_ENTRIES_NUM_PARAM-1:0],
    output wire                                awctrl_txdat_rdy_v_d2_o,
    output wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_txdat_rdy_entry_d2_o,
    output logic [3:0]                         awctrl_txdat_qos_d2_o,
    output wire                                awctrl_txdat_compack_d2_o,
    output logic [11:0]                        awctrl_txdat_dbid_d2_o,
    output logic                               awctrl_txdat_tracetag_d2_o,
    output logic [chie_pkg::NID_WIDTH-1:0]     awctrl_txdat_tgtid_d2_o,
    output logic [1:0]                         awctrl_txdat_ccid_d2_o,
    output wire [`RNI_DMASK_CT_WIDTH-1:0]      awctrl_txdat_ctmask_d2_o,
    input  wire                                awctrl_txdat_not_busy_d2_i,

    // B response request
    input  wire                                awctrl_brsp_fifo_pop_d3_i,
    output wire                                awctrl_brsp_rdy_v_d2_o,
    output wire                                awctrl_brsp_last_v_d2_o,
    output wire [`AXI4_BID_WIDTH-1:0]          awctrl_brsp_axid_d2_o,
    output chie_pkg::resp_err_e                awctrl_brsp_resperr_d2_o,
    // Sec 12.1 (p.12-372): the Tag Match verdict, for the B channel sideband.
    output wire [`AXI4_BUSER_WIDTH-1:0]        awctrl_brsp_buser_d2_o,

    // rni_ar_ctl Interface -- Sec 2.9.4's (p.2-130) cross-kind Device ordering
    output wire                                awctrl_device_ordered_pending_o,
    input  wire                                arctrl_device_ordered_pending_i,

    // An Atomic's returned data: CHI CompData in, one AXI R beat out (AXI5 atomics
    // answer on R with the AWID as well as on B).
    input  wire                                awctrl_rxdatflitv_d1_i,
    input  chie_pkg::dat_flit_s                awctrl_rxdatflit_d1_i,
    // SS2.10.5 (p.2-137): an Atomic's byte enables are exactly its operand window, so the
    // write buffer takes them from here rather than from WSTRB.
    output wire [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_atom_o,
    output wire [`WR_BUFFER_DATA_BANK_NUM*`AXI4_WSTRB_WIDTH-1:0] awctrl_entry_atom_be_o[RNI_AW_ENTRIES_NUM_PARAM-1:0],
    output wire                                awctrl_atr_valid_o,
    output opennoc_rni_pkg::r_ch_s             awctrl_atr_o,
    input  wire                                awctrl_atr_ready_i
    );

    opennoc_rni_pkg::ax_ch_s             awlink_awbus_s1_w;
    wire                                 stall_flag_s1_w;
    wire [`AXI4_AWLEN_WIDTH-1:0]         awlink_len_s1_w;
    wire                                 awlink_valid_s1_w;
    wire [`AXI4_AWADDR_WIDTH-1:0]        awlink_addr_s1_w;
    wire                                 awlink_done_s1_w;
    wire [`RNI_BCVEC_WIDTH-1:0]          awlink_bc_vec_s2_w;
    wire [`RNI_DMASK_WIDTH-1:0]          awlink_dmask_s2_w;
    chie_pkg::size_e                     awlink_size_s2_w;
    wire                                 awlink_lock_s2_w;
    logic                                aw_excl_r;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_alloc_ptr_s1_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_rdy_s1_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_v_ns_w;
    wire                                 awctrl_entry_dealloc_v_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_dealloc_vec_w;
    wire [3:0]                           txdat_pkts_s2_w;
    wire                                 aw_txreq_expcompack_w;
    logic [`AXI4_AWCACHE_WIDTH-1:0]      aw_axcache_r;
    wire                                 aw_device_w;
    wire                                 aw_cacheable_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_ordered_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_device_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_ordered_pending_ns_w;
    wire                                 awctrl_ordered_pending_any_w;
    wire                                 awctrl_new_entry_req_dep_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_is_req_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_req_dep_chain_young_ns_w;
    wire                                 awctrl_new_entry_compack_dep_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_is_compack_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_compack_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_compack_dep_chain_young_ns_w;
    wire                                 awctrl_new_entry_bresp_dep_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_is_bresp_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_bresp_dep_v_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_bresp_dep_chain_young_ns_w;
    wire                                 awctrl_req_hi_retry_found_w;
    wire                                 awctrl_req_lo_retry_found_w;
    wire                                 awctrl_req_hi_new_found_w;
    wire                                 awctrl_req_lo_new_found_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_hi_retry_dec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_lo_retry_dec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_hi_new_dec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_lo_new_dec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_ptr_ns_w;
    wire                                 awctrl_entry_req_select_success_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_req_retry_ready_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_hi_retry_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_lo_retry_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_req_new_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_hi_new_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_lo_new_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_entry_req_select_vec_ns_w;
    wire [CHIE_NID_WIDTH_PARAM-1:0]      aw_tx_send_nid_w;
    wire [chie_pkg::NID_WIDTH-1:0]       awctrl_entry_rxrsp_tgtid_w;
    wire [chie_pkg::NID_WIDTH-1:0]       awctrl_entry_rxrsp_srcid_w;
    wire                                 awctrl_entry_rxrsp_tracetag_w;
    wire [11:0]                          awctrl_entry_rxrsp_txnid_w;
    chie_pkg::rsp_opcode_e               awctrl_entry_rxrsp_opcode_w;
    wire [11:0]                          awctrl_entry_rxrsp_dbid_w;
    wire [3:0]                           awctrl_entry_rxrsp_pcrdtype_w;
    wire                                 aw_rxrsp_correct_w;
    wire                                 rxrsp_dbid_recv_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_dbid_recv_vec_w;
    wire                                 rxrsp_comp_recv_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_comp_recv_vec_w;
    wire                                 rxrsp_retryack_recv_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_retryack_recv_vec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_retryack_recv_vec_ns_w;
    wire                                 rxrsp_pcrdgrant_recv_flag_w;
    wire                                 rxrsp_pcrdtype_hi_select_w;
    wire                                 rxrsp_pcrdtype_lo_select_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_hi_upd_ptr_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_lo_upd_ptr_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_recv_vec_ns_w;
    wire                                 rxrsp_pcrdtype_hi_match_d2_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_hi_recv_vec_d2_w;
    wire                                 rxrsp_pcrdtype_lo_match_d2_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_lo_recv_vec_d2_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_dbid_recv_vec_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  rxrsp_comp_recv_vec_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txdat_select_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  wdata_recv_done_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  aw_line_sized_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  aw_full_pending_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  aw_entry_full_write_w;
    logic                                aw_full_write_r;
    wire                                 txdat_select_more_w;
    wire                                 txdat_select_new_entry_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txdat_select_vec_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txdat_send_vec_ns_w;
    wire                                 txdat_select_success_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txdat_select_vec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txrsp_select_rdy_w;
    wire                                 txrsp_select_success_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txrsp_select_vec_ns_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txrsp_compack_send_vec_ns_w;
    wire                                 awctrl_compack_chain_clean_flag_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  awctrl_compack_chain_clean_vec_w;
    wire                                 txrsp_select_success_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  txrsp_select_vec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  bresp_select_rdy_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  bresp_select_vec_ns_w;
    wire                                 bresp_select_success_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  bresp_select_vec_w;
    wire [RNI_AW_ENTRIES_NUM_PARAM-1:0]  bresp_send_ptr_w;
    wire                                 bresp_credit_full_w;
    wire                                 bresp_credit_avail_w;

    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_v_q;
    opennoc_rni_pkg::ax_ch_s             awctrl_entry_info_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic                                awctrl_entry_full_r;
    logic [`AXI4_AWLEN_WIDTH-1:0]        awctrl_entry_len_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [`AXI4_AWADDR_WIDTH-1:0]       awctrl_entry_addr_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [`AXI4_AWSIZE_WIDTH-1:0]       awctrl_entry_size_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_excl_q;
    logic [`RNI_DMASK_CT_WIDTH-1:0]      awctrl_entry_ctmask_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [`RNI_DMASK_PD_WIDTH-1:0]      awctrl_entry_pdmask_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_expcompack_q;
    // CHI E.b Table 9-6 (SS9.4.3 p.9-340) gives a write's Comp and CompDBIDResp
    // both DERR and NDERR, and SS9.1 (p.9-334) makes the Home pass that error
    // back to the Requester. Latched per entry off the completion, so the AXI
    // BRESP can report it.
    chie_pkg::resp_err_e                 awctrl_entry_resperr_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    chie_pkg::resp_err_e                 awctrl_entry_rxrsp_resperr_w;
    chie_pkg::resp_err_e                 brsp_resperr_d2_ns_r;
    chie_pkg::resp_err_e                 brsp_resperr_d2_q;
    logic                                awctrl_entry_segburst_last_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_qos_hi_q;
    logic                                awlink_valid_s2_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_alloc_ptr_s2_q;
    logic [`AXI4_AWID_WIDTH-1:0]         awctrl_awid_s2_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_req_select_rdy_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_req_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_sameid_req_chain_vec_d2_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_req_dep_num_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_req_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_req_dep_num_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_req_dep_chain_young_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_compack_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_sameid_compack_chain_vec_d2_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_compack_dep_num_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_compack_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_compack_dep_num_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_compack_dep_chain_young_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_bresp_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_sameid_bresp_chain_vec_d2_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_bresp_dep_num_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_bresp_dep_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_is_bresp_dep_num_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_bresp_dep_chain_young_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_ordered_pending_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_req_ptr_q;
    logic                                awctrl_entry_req_select_success_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_req_select_vec_q;
    logic                                awctrl_entry_req_select_retry_flag_q;
    logic [11:0]                         aw_txreq_txnid_r;
    chie_pkg::req_flit_s                 aw_txreqflit_info_r;
    logic                                aw_txreqflitv_s5_q;
    chie_pkg::req_flit_s                 aw_txreqflit_s5_q;
    logic                                aw_txreqflit_sent_s5_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_rxrsp_ptr_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_rdy_vec_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_rdy_vec_r;
    logic                                rxrsp_pcrdtype_hi_match_d3_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_recv_vec_d3_q;
    logic                                rxrsp_pcrdtype_lo_match_d3_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_recv_vec_d3_q;
    logic [chie_pkg::NID_WIDTH-1:0]      rxrsp_dbidresp_srcid_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_tracetag_q;
    logic [11:0]                         rxrsp_dbidresp_dbid_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [3:0]                          rxrsp_retryack_pcrdtype_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_retryack_recv_vec_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_upd_ptr_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_upd_ptr_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_recv_vec_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_dbid_recv_vec_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_comp_recv_vec_q;
    logic [`RNI_DMASK_CT_WIDTH-1:0]      txdat_ctmask_d1_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] wdata_recv_done_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_select_ptr_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_select_vec_q;
    // The chunks of the data packets each entry still owes the Completer.
    logic [3:0]                          txdat_pend_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [3:0]                          txdat_pend_sel_r;
    logic                                txdat_rdy_v_d2_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_rdy_entry_d2_q;
    logic [`RNI_DMASK_CT_WIDTH-1:0]      txdat_ctmask_d2_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_rdy_entry_d3_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_select_vec_d3_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txdat_send_vec_q;
    logic [11:0]                         aw_txrsp_txnid_r;
    chie_pkg::rsp_flit_s                 aw_txrspflit_info_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txrsp_select_ptr_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txrsp_select_vec_q;
    logic                                aw_txrspflitv_d0_q;
    logic                                aw_txrspflit_sent_d0_q;
    chie_pkg::rsp_flit_s                 aw_txrspflit_d0_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] txrsp_compack_send_vec_q;
    logic                                txrsp_select_success_flag_q;
    logic                                brsp_last_v_d2_ns_r;
    logic [`AXI4_BID_WIDTH-1:0]          brsp_axid_d2_ns_r;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] bresp_select_ptr_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] bresp_select_vec_q;
    logic                                brsp_rdy_v_d2_q;
    logic                                brsp_last_v_d2_q;
    logic [`AXI4_BID_WIDTH-1:0]          brsp_axid_d2_q;
    logic [`AXI4_BUSER_WIDTH-1:0]        brsp_buser_d2_ns_r;
    logic [`AXI4_BUSER_WIDTH-1:0]        brsp_buser_d2_q;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_tagmatch_req_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_tagmatch_owed_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_tagmatch_hit_w;
    wire                                 rxrsp_tagmatch_recv_w;
    wire  [7:0]                          rxrsp_tagmatch_group_w;
    wire                                 rxrsp_tagmatch_pass_w;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_tagmatch_recv_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_tagmatch_pass_q;
    // Per-entry request class from AWOP/AWCMO (rni_defines.svh)
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_stashw_w;      // WriteUnique*Stash
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_zero_w;        // Write*Zero
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_so_w;          // StashOnce*
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_sosep_w;       // StashOnceSep*
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_cmo_w;         // standalone CMO
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_pft_w;         // PrefetchTgt
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_comb_w;        // WriteNoSnp + CMO
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_lerr_w;        // refused, completed locally
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_dl_w;          // sends no write data
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_unordered_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_persist_owed_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_compcmo_owed_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_stashdone_owed_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_chain_rel_vec_w;
    wire                                 awctrl_chain_rel_flag_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_synth_comp_vec_w;
    wire                                 awctrl_synth_comp_flag_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_data_done_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_compcmo_recv_vec_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_persist_hit_w;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxrsp_stashdone_hit_w;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_compcmo_recv_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_persist_recv_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_stashdone_recv_q;
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_atom_w;        // AtomicStore/Load/Swap/Compare
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_entry_atom_rd_w;     // ... that returns data
    wire  [RNI_AW_ENTRIES_NUM_PARAM-1:0] rxdat_atom_vec_w;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_atom_rdata_v_q;
    logic [RNI_AW_ENTRIES_NUM_PARAM-1:0] awctrl_atom_r_sent_q;
    logic [opennoc_rni_pkg::DATA_WIDTH-1:0] awctrl_atom_rdata_q [RNI_AW_ENTRIES_NUM_PARAM-1:0];
    logic [1:0]                          awctrl_atom_rresp_q  [RNI_AW_ENTRIES_NUM_PARAM-1:0];

    genvar                               entry;

    /////////////////////////////////////////////////////////////
    // txreq s1
    /////////////////////////////////////////////////////////////
    rni_awlink rni_awlink_u0
               (
                   .clk_i                        (clk_i                  )
                   ,.rst_i                        (rst_i                  )
                   ,.AWVALID                      (AWVALID0               )
                   ,.AWBUS                        (AW_CH_S0               )
                   ,.stall_flag_s1_i              (stall_flag_s1_w        )
                   ,.AWREADY                      (AWREADY0               )
                   ,.awlink_awvalid_s1_o          ()
                   ,.awlink_awbus_s1_o            (awlink_awbus_s1_w      )
                   ,.awlink_len_s1_o              (awlink_len_s1_w        )
                   ,.awlink_valid_s1_o            (awlink_valid_s1_w      )
                   ,.awlink_addr_s1_o             (awlink_addr_s1_w       )
                   ,.awlink_done_s1_o             (awlink_done_s1_w       )
                   ,.awlink_bc_vec_s2_o           (awlink_bc_vec_s2_w     )
                   ,.awlink_dmask_s2_o            (awlink_dmask_s2_w      )
                   ,.awlink_size_s2_o             (awlink_size_s2_w       )
                   ,.awlink_lock_s2_o             (awlink_lock_s2_w       )
               );


    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        awctrl_entry_alloc(
            .entry_vec(awctrl_entry_rdy_s1_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry({RNI_AW_ENTRIES_NUM_PARAM{1'b0}})
            ,.entry_ptr_sel(awctrl_alloc_ptr_s1_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found()
        );

    always_comb begin
        awctrl_entry_full_r = 1'b1;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            awctrl_entry_full_r = awctrl_entry_full_r & awctrl_entry_v_q[i];
    end
    //wdata is written at s2, so it is pfull
    assign stall_flag_s1_w = wb_req_fifo_pfull_d1_i | awctrl_entry_full_r;
    assign awctrl_entry_rdy_s1_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ~awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & {RNI_AW_ENTRIES_NUM_PARAM{awlink_valid_s1_w}};
    assign awctrl_entry_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_alloc_ptr_s1_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin: txn_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_info_q[entry] <= '0;
                end
                else begin
                    if(awctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        awctrl_entry_info_q[entry] <= awlink_awbus_s1_w;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_len_q[entry][`AXI4_AWLEN_WIDTH-1:0] <= '0;
                end
                else begin
                    if(awctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        awctrl_entry_len_q[entry][`AXI4_AWLEN_WIDTH-1:0] <= awlink_len_s1_w[`AXI4_AWLEN_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_addr_q[entry][`AXI4_AWADDR_WIDTH-1:0] <= '0;
                end
                else begin
                    if(awctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        awctrl_entry_addr_q[entry][`AXI4_AWADDR_WIDTH-1:0] <= awlink_addr_s1_w[`AXI4_AWADDR_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_segburst_last_q[entry] <= 1'b0;
                end
                else begin
                    if(awctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        awctrl_entry_segburst_last_q[entry] <= awlink_done_s1_w;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_qos_hi_q[entry] <= 1'b0;
                end
                else begin
                    if(awctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        awctrl_entry_qos_hi_q[entry] <= (awlink_awbus_s1_w.qos == 4'b1111);
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s1_w | awctrl_entry_dealloc_v_w)begin
                awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awlink_valid_s2_q <= 1'b0;
        end
        else begin
            awlink_valid_s2_q <= awlink_valid_s1_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_alloc_ptr_s1_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    /////////////////////////////////////////////////////////////
    // txreq s2
    /////////////////////////////////////////////////////////////
    assign awctrl_alloc_valid_s2_o = awlink_valid_s2_q;
    assign awctrl_alloc_entry_s2_o[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_ctmask_s2_o[`RNI_DMASK_CT_WIDTH-1:0] = awlink_dmask_s2_w[`RNI_DMASK_CT_WIDTH-1:0];
    assign awctrl_pdmask_s2_o[`RNI_DMASK_PD_WIDTH-1:0] = awlink_dmask_s2_w[`RNI_DMASK_PD_RANGE];
    assign awctrl_bc_vec_s2_o[`RNI_BCVEC_WIDTH-1:0] = awlink_bc_vec_s2_w[`RNI_BCVEC_WIDTH-1:0];
    // SS2.10.4 (p.2-136): a write's data is every packet of its Size-aligned container.
    assign txdat_pkts_s2_w = opennoc_rni_pkg::size_pkts(awlink_size_s2_w,
                                                        {awctrl_ctmask_s2_o[3] | awctrl_ctmask_s2_o[2],
                                                         awctrl_ctmask_s2_o[3] | awctrl_ctmask_s2_o[1]});
    // CHI E.b Table 2-9 fn a (SS2.8 p.2-119) makes Ordered Write Observation the
    // Order=0b10/ExpCompAck=1 pair alone, and Table 2-11 (SS2.9.4 p.2-129) gives
    // every Device row Order=EndpointOrder -- under which SS2.8.5 (p.2-119) names
    // the DBIDResp, not a CompAck, as what orders the next request. So a Device
    // write orders on its own Order field and never joins the CompAck chain.
    // Tables 4-7 (p.4-172) and 4-13 (p.4-178): no Dataless request and no Write Zero takes
    // ExpCompAck, so those never join the CompAck chain either.
    assign aw_txreq_expcompack_w = awctrl_new_entry_compack_dep_w &
           ~|(awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_device_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           ~|(awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_dl_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           // Table 4-21 (p.4-188): an Atomic takes no ExpCompAck.
           ~|(awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_atom_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]);

    always_comb begin
        awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] = awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] | ({`AXI4_AWID_WIDTH{awctrl_alloc_ptr_s2_q[i]}} & awctrl_entry_info_q[i].id);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_select_rdy_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            awctrl_entry_req_select_rdy_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin: txn_size_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_size_q[entry][`AXI4_AWSIZE_WIDTH-1:0] <= '0;
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_size_q[entry][`AXI4_AWSIZE_WIDTH-1:0] <= awlink_size_s2_w[`AXI4_AWSIZE_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_excl_q[entry] <= 1'b0;
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_excl_q[entry] <= awlink_lock_s2_w;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_ctmask_q[entry][`RNI_DMASK_CT_WIDTH-1:0] <={`RNI_DMASK_CT_WIDTH{1'b0}};
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_ctmask_q[entry][`RNI_DMASK_CT_WIDTH-1:0] <= awctrl_ctmask_s2_o[`RNI_DMASK_CT_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_pdmask_q[entry][`RNI_DMASK_PD_WIDTH-1:0] <={`RNI_DMASK_PD_WIDTH{1'b0}};
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_pdmask_q[entry][`RNI_DMASK_PD_WIDTH-1:0] <= awctrl_pdmask_s2_o[`RNI_DMASK_PD_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_expcompack_q[entry] <=1'b0;
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_expcompack_q[entry] <= aw_txreq_expcompack_w;
                    end
                end
            end

            // The completion carries the status; allocation clears it so a reused
            // entry does not inherit the previous write's error.
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_resperr_q[entry][2-1:0] <= '0;
                end
                else begin
                    if(awctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        awctrl_entry_resperr_q[entry][2-1:0] <= awctrl_entry_lerr_w[entry] ? chie_pkg::RESP_ERR_DATA : chie_pkg::RESP_ERR_NORM_OK;
                    end
                    else if(rxrsp_comp_recv_vec_w[entry] == 1'b1)begin
                        awctrl_entry_resperr_q[entry][2-1:0] <= awctrl_entry_rxrsp_resperr_w[2-1:0];
                    end
                    else if(rxdat_atom_vec_w[entry] == 1'b1)begin
                        awctrl_entry_resperr_q[entry][2-1:0] <= awctrl_rxdatflit_d1_i.resperr;
                    end
                    // SS9.3: the CMO half of a Combined Write reports its own error on CompCMO.
                    else if(rxrsp_compcmo_recv_vec_w[entry] & awctrl_entry_rxrsp_resperr_w[1])begin
                        awctrl_entry_resperr_q[entry][2-1:0] <= awctrl_entry_rxrsp_resperr_w[2-1:0];
                    end
                end
            end
        end
    endgenerate

    //request chain
    assign awctrl_new_entry_req_dep_w = |awctrl_sameid_req_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_is_req_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_is_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_sameid_req_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_chain_rel_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{(awctrl_new_entry_req_dep_w)}} & awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_is_req_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_req_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ((awctrl_req_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_sameid_req_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_chain_rel_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:axid_req_same
            always_comb begin
                if((awctrl_alloc_ptr_s2_q[entry] == 1'b0) && (awctrl_entry_v_q[entry] == 1'b1) && (awctrl_chain_rel_vec_w[entry] == 1'b0))begin
                    awctrl_sameid_req_chain_vec_d2_r[entry] = (awlink_valid_s2_q && awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] == awctrl_entry_info_q[entry].id) && awctrl_req_dep_chain_young_q[entry];
                end
                else begin
                    awctrl_sameid_req_chain_vec_d2_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        awctrl_entry_is_req_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            awctrl_entry_is_req_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_is_req_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_chain_rel_vec_w[i]}} & awctrl_entry_is_req_dep_num_q[i][RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_is_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_chain_rel_flag_w)begin
                awctrl_entry_is_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_is_req_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((awlink_valid_s2_q && awctrl_new_entry_req_dep_w) | awctrl_chain_rel_flag_w)begin
                awctrl_entry_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_req_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:req_dep_num
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_is_req_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                end
                else begin
                    if(awctrl_chain_rel_vec_w[entry])begin
                        awctrl_entry_is_req_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                    end
                    else if((awlink_valid_s2_q && awctrl_sameid_req_chain_vec_d2_r[entry]))begin
                        awctrl_entry_is_req_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_req_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_chain_rel_flag_w)begin
                awctrl_req_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_req_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    //compack chain
    assign awctrl_new_entry_compack_dep_w = |awctrl_sameid_compack_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_is_compack_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_is_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_sameid_compack_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_compack_chain_clean_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_compack_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{(awctrl_new_entry_compack_dep_w)}} & awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])) &
           ~awctrl_entry_is_compack_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_compack_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ((awctrl_compack_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_sameid_compack_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           ~awctrl_compack_chain_clean_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];


    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:axid_compack_same
            always_comb begin
                if((awctrl_alloc_ptr_s2_q[entry] == 1'b0) && (awctrl_entry_v_q[entry] == 1'b1) && (awctrl_compack_chain_clean_vec_w[entry] == 1'b0))begin
                    awctrl_sameid_compack_chain_vec_d2_r[entry] = (awlink_valid_s2_q && awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] == awctrl_entry_info_q[entry].id) && awctrl_compack_dep_chain_young_q[entry];
                end
                else begin
                    awctrl_sameid_compack_chain_vec_d2_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        awctrl_entry_is_compack_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            awctrl_entry_is_compack_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_is_compack_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_compack_chain_clean_vec_w[i]}} & awctrl_entry_is_compack_dep_num_q[i][RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_is_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_compack_chain_clean_flag_w)begin
                awctrl_entry_is_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_is_compack_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((awlink_valid_s2_q & awctrl_new_entry_compack_dep_w) | awctrl_compack_chain_clean_flag_w)begin
                awctrl_entry_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_compack_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:compack_dep_num
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_is_compack_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                end
                else begin
                    if(awctrl_compack_chain_clean_vec_w[entry])begin
                        awctrl_entry_is_compack_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                    end
                    else if((awlink_valid_s2_q && awctrl_sameid_compack_chain_vec_d2_r[entry]))begin
                        awctrl_entry_is_compack_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_compack_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_compack_chain_clean_flag_w)begin
                awctrl_compack_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_compack_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    //bresp chain
    assign awctrl_new_entry_bresp_dep_w = |awctrl_sameid_bresp_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_is_bresp_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_is_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_sameid_bresp_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_bresp_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{(awctrl_new_entry_bresp_dep_w)}} & awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_is_bresp_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_bresp_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ((awctrl_bresp_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_sameid_bresp_chain_vec_d2_r[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:axid_bresp_same
            always_comb begin
                if((awctrl_alloc_ptr_s2_q[entry] == 1'b0) && (awctrl_entry_v_q[entry] == 1'b1) && (awctrl_entry_dealloc_vec_w[entry] == 1'b0))begin
                    awctrl_sameid_bresp_chain_vec_d2_r[entry] = (awlink_valid_s2_q && awctrl_awid_s2_r[`AXI4_AWID_WIDTH-1:0] == awctrl_entry_info_q[entry].id) && awctrl_bresp_dep_chain_young_q[entry];
                end
                else begin
                    awctrl_sameid_bresp_chain_vec_d2_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        awctrl_entry_is_bresp_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            awctrl_entry_is_bresp_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_is_bresp_dep_num_r[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_entry_dealloc_vec_w[i]}} & awctrl_entry_is_bresp_dep_num_q[i][RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_is_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_brsp_fifo_pop_d3_i)begin
                awctrl_entry_is_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_is_bresp_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((awlink_valid_s2_q & awctrl_new_entry_bresp_dep_w) | awctrl_brsp_fifo_pop_d3_i)begin
                awctrl_entry_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_bresp_dep_v_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:bresp_dep_num
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    awctrl_entry_is_bresp_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                end
                else begin
                    if(awctrl_entry_dealloc_vec_w[entry])begin
                        awctrl_entry_is_bresp_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
                    end
                    else if((awlink_valid_s2_q && awctrl_sameid_bresp_chain_vec_d2_r[entry]))begin
                        awctrl_entry_is_bresp_dep_num_q[entry][RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_bresp_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awlink_valid_s2_q | awctrl_brsp_fifo_pop_d3_i)begin
                awctrl_bresp_dep_chain_young_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_bresp_dep_chain_young_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // txreq select
    /////////////////////////////////////////////////////////////
    assign awctrl_req_retry_ready_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_req_select_rdy_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & rxrsp_pcrdgrant_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_req_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_hi_retry_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_req_retry_ready_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_qos_hi_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_lo_retry_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_req_retry_ready_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_qos_hi_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // Sec 2.8.5 (p.2-119, MUST): "The Requester requires a DBIDResp or DBIDRespOrd
    // to determine when it can send the next ordered request", and the Streaming
    // Ordered Write form (p.2-122, MUST) says the same. The dependency chain above
    // keys on AWID alone, which leaves two ordered writes under different AWIDs
    // free to go out back to back. Gated per Requester rather than per address:
    // Sec 2.8.2's Note (p.2-115) leaves the endpoint address range IMPLEMENTATION
    // DEFINED, so the scope cannot be narrowed below what this bridge can prove --
    // the same choice the AR path makes.
    // Table 4-13 (SS4.2.3 p.4-178) gives WriteNoSnpFull / WriteUniqueFull Size=64
    // where the Ptl forms take <=64, so only a whole-line segment can be a Full
    // write at all.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin: aw_line_sized
            // awctrl_entry_size_q lands a cycle after allocation; the request class, which
            // the allocation cycle already reads, takes the size from the pipe until then.
            assign aw_line_sized_w[entry] = ((awctrl_alloc_ptr_s2_q[entry] ? awlink_size_s2_w[`AXI4_AWSIZE_WIDTH-1:0]
                                                                           : awctrl_entry_size_q[entry][`AXI4_AWSIZE_WIDTH-1:0])
                                             == chie_pkg::SIZE_64B);
        end
    endgenerate

    // SS2.10.3 (p.2-135, MUST) requires all byte enables asserted on a Full write,
    // and those live on the W channel -- so a whole-line entry holds its request
    // until its last beat has landed and the opcode is decidable. The cost is the
    // REQ/DBID round trip no longer overlapping the write data, which is bounded by
    // one line of AXI beats; the data itself could not have been sent any earlier,
    // since TXDAT already waits on the same wdata_recv_done_q.
    // This is also what keeps SS2.11 (p.2-145, MUST)'s "must have the same field
    // values as the original request" true of a reissue: the strobes are complete
    // before the first attempt, so the retried request re-derives the same opcode.
    assign aw_full_pending_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = aw_line_sized_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    assign awctrl_req_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_req_select_rdy_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_req_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~rxrsp_retryack_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_req_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~aw_full_pending_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]
             & ~({RNI_AW_ENTRIES_NUM_PARAM{awctrl_ordered_pending_any_w}} & awctrl_entry_ordered_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
             & ~({RNI_AW_ENTRIES_NUM_PARAM{arctrl_device_ordered_pending_i}} & awctrl_entry_device_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
             & ~awctrl_entry_lerr_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_hi_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_req_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_qos_hi_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_lo_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_req_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_qos_hi_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    //deassert select_vec when receiving retryack
    assign awctrl_entry_req_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_entry_req_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_entry_req_select_success_flag_w}} & awctrl_entry_req_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~rxrsp_retryack_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        req_retry_hi(
            .entry_vec(awctrl_entry_req_hi_retry_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(awctrl_entry_req_hi_retry_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(awctrl_req_hi_retry_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        req_retry_lo(
            .entry_vec(awctrl_entry_req_lo_retry_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(awctrl_entry_req_lo_retry_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(awctrl_req_lo_retry_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        req_new_hi(
            .entry_vec(awctrl_entry_req_hi_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(awctrl_entry_req_hi_new_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(awctrl_req_hi_new_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        req_new_lo(
            .entry_vec(awctrl_entry_req_lo_new_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(awctrl_entry_req_lo_new_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(awctrl_req_lo_new_found_w)
        );

    assign awctrl_entry_req_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_req_hi_retry_found_w ? awctrl_entry_req_hi_retry_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]:
           awctrl_req_hi_new_found_w ? awctrl_entry_req_hi_new_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]:
           awctrl_req_lo_retry_found_w ? awctrl_entry_req_lo_retry_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]:
           awctrl_entry_req_lo_new_dec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_entry_req_select_success_flag_w = (awctrl_req_hi_retry_found_w | awctrl_req_hi_new_found_w | awctrl_req_lo_retry_found_w | awctrl_req_lo_new_found_w) & (awctrl_txreqflit_sent_s4_i | ~awctrl_txreqflitv_s4_o);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awctrl_entry_req_select_success_flag_w)begin
                awctrl_entry_req_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_req_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_select_success_q <= 1'b0;
        end
        else begin
            awctrl_entry_req_select_success_q <= awctrl_entry_req_select_success_flag_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awctrl_entry_req_select_success_flag_w | rxrsp_retryack_recv_flag_w | awctrl_entry_dealloc_v_w)begin
                awctrl_entry_req_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_entry_req_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_entry_req_select_retry_flag_q <= 1'b0;
        end
        else begin
            if(awctrl_entry_req_select_success_flag_w)begin
                awctrl_entry_req_select_retry_flag_q <= awctrl_req_hi_retry_found_w | awctrl_req_lo_retry_found_w;
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // txreq send
    /////////////////////////////////////////////////////////////
    //expcompack considers that when sending a flit, if the comp it depends on has not been received, it will choose owo, otherwise it will be rqo
    assign aw_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0] = HNF_NID_PARAM;

    always_comb begin
        aw_txreq_txnid_r[11:0] = '0;
        aw_txreq_txnid_r[12-1] = 1'b1;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_txreq_txnid_r[`RNI_AW_ENTRIES_WIDTH-1:0] = aw_txreq_txnid_r[`RNI_AW_ENTRIES_WIDTH-1:0] | ({`RNI_AW_ENTRIES_WIDTH{awctrl_entry_req_ptr_q[i]}} & i[`RNI_AW_ENTRIES_WIDTH-1:0]);
    end


    // AMBA AXI4 (IHI 0022) Table A4-5 -> CHI E.b Table 2-11 (SS2.9.4 p.2-129);
    // see rni_arctrl.v for the derivation. Table 2-13 (p.2-132) admits
    // WriteUnique* only on the Snoopable row, so a Device or Non-cacheable write
    // is a WriteNoSnp (CHI-OpenNoC#20).
    logic [`AXI4_TAGOP_WIDTH-1:0]      aw_axtagop_r;
    wire                               aw_lpid_alias_w;
    logic                              aw_lpid_alias_r;
    logic [`AXI4_TAGGROUPID_WIDTH-1:0] aw_axtggid_r;
    wire  [`AXI4_TAGOP_WIDTH-1:0]      aw_tagop_w;
    wire                               aw_tagop_match_w;

    always_comb begin: aw_axcache_sel_t
        aw_axcache_r[`AXI4_AWCACHE_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_axcache_r[`AXI4_AWCACHE_WIDTH-1:0] = aw_axcache_r[`AXI4_AWCACHE_WIDTH-1:0] |
                ({`AXI4_AWCACHE_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].cache);
    end

    // Table 12-2 (Sec 12.12 p.12-388) gives every write this bridge elects the
    // Invalid, Update and Match columns; Transfer belongs to WriteNoSnpFull alone,
    // which is not known until the data has arrived, so an AWUSER Transfer is
    // presented as Invalid. Table 13-32 (Sec 13.10.37 p.13-435) encodes Update 0b10
    // and Match 0b11.
    always_comb begin: aw_axtagop_sel_t
        aw_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] = '0;
        aw_axtggid_r[`AXI4_TAGGROUPID_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)begin
            aw_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] = aw_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] |
                ({`AXI4_TAGOP_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].user[`AXI4_USER_TAGOP_RANGE]);
            aw_axtggid_r[`AXI4_TAGGROUPID_WIDTH-1:0] = aw_axtggid_r[`AXI4_TAGGROUPID_WIDTH-1:0] |
                ({`AXI4_TAGGROUPID_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].user[`AXI4_USER_TGGID_RANGE]);
        end
    end

    always_comb begin: aw_lpid_alias_sel_t
        aw_lpid_alias_r = 1'b0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_lpid_alias_r = aw_lpid_alias_r |
                (awctrl_entry_req_ptr_q[i] & (|awctrl_entry_info_q[i].id[`AXI4_AWID_WIDTH-1:8]));
    end
    assign aw_lpid_alias_w = aw_lpid_alias_r;

    // Sec 12.1 (p.12-372): only a Normal WriteBack (Cacheable) write carries a TagOp.
    assign aw_tagop_w = (aw_cacheable_w & aw_axtagop_r[1]) ? aw_axtagop_r : 2'b00;

    // The same narrowing per entry, so the write data can be built from AWUSER that
    // was latched at the AW handshake rather than from whichever entry is selected.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:aw_entry_tagop
            assign awctrl_entry_tagop_o[entry] =
                (opennoc_rni_pkg::axi_cacheable(awctrl_entry_info_q[entry].cache) &
                 awctrl_entry_info_q[entry].user[`AXI4_USER_TAGOP_LSB+1]) ?
                awctrl_entry_info_q[entry].user[`AXI4_USER_TAGOP_RANGE] : 2'b00;
        end
    endgenerate
    // Sec 13.10.40 (p.13-435): "TagGroupID is applicable in requests where TagOp is
    // set to Match", and there "the same bits in the packet are used for LPID".
    assign aw_tagop_match_w = (aw_tagop_w == 2'b11);

    assign aw_device_w    = ~aw_axcache_r[1];
    assign aw_cacheable_w = opennoc_rni_pkg::axi_cacheable(aw_axcache_r);
    // "This entry's request is ordered", per entry so the gate narrows if the
    // Order election below ever does. It gives a Device row EndpointOrder and
    // every other row RequestOrder/OWO (Table 2-11, Sec 2.9.4 p.2-129), so every
    // write this bridge sends carries a non-zero Order today.
    assign awctrl_entry_ordered_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ~awctrl_entry_unordered_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    // The same AxCACHE[1] decode as aw_device_w above, held per entry: AXI4
    // (IHI 0022) Table A4-5's two Device rows are the ones Table 2-11 (p.2-129)
    // gives Order=0b11, which is Sec 2.9.4's Device nRnE and nRE.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:aw_entry_device
            assign awctrl_entry_device_w[entry] = ~awctrl_entry_info_q[entry].cache[1];
        end
    endgenerate

    // AWOP and AWCMO (rni_defines.svh) name the CHI request beyond AWCACHE's, per entry.
    // Table B-1 (p.B-492/493) lists what an RN-I may send; a combination it or the
    // attribute tables refuse is completed locally with an error and sends nothing:
    // a StashOnce off Normal WriteBack (Table 4-7 p.4-172), a PrefetchTgt to Device
    // (SS2.9.6 p.2-133), a CMO combined with a WriteUnique (Table B-1: RN-F only), and a
    // Write Zero narrower than a line (Table 4-13 p.4-178: Size 64).
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:aw_entry_class
            wire [3:0] op_w  = awctrl_entry_info_q[entry].op;
            wire [1:0] cmo_w = awctrl_entry_info_q[entry].cmo;
            wire       wb_w  = opennoc_rni_pkg::axi_cacheable(awctrl_entry_info_q[entry].cache);
            // AXI5 AWATOP[5:4]: 01 AtomicStore, 10 AtomicLoad, 11 AtomicSwap (0000) or
            // AtomicCompare (0001); 00 is not atomic.
            assign awctrl_entry_atom_w[entry]    = |awctrl_entry_info_q[entry].atop[5:4];
            assign awctrl_entry_atom_rd_w[entry] = awctrl_entry_info_q[entry].atop[5];
            assign awctrl_entry_stashw_w[entry] = (op_w == `RNI_AWOP_WRITE_STASH) & wb_w & ~awctrl_entry_atom_w[entry];
            assign awctrl_entry_zero_w[entry]   = (op_w == `RNI_AWOP_WRITE_ZERO);
            assign awctrl_entry_sosep_w[entry]  = (op_w == `RNI_AWOP_STASH_ONCE_SEP_SHARED) | (op_w == `RNI_AWOP_STASH_ONCE_SEP_UNIQUE);
            assign awctrl_entry_so_w[entry]     = (op_w == `RNI_AWOP_STASH_ONCE_SHARED) | (op_w == `RNI_AWOP_STASH_ONCE_UNIQUE) |
                                                  awctrl_entry_sosep_w[entry];
            assign awctrl_entry_cmo_w[entry]    = (op_w >= `RNI_AWOP_CLEAN_SHARED) & (op_w <= `RNI_AWOP_MAKE_INVALID);
            assign awctrl_entry_pft_w[entry]    = (op_w == `RNI_AWOP_PREFETCH_TGT);
            assign awctrl_entry_comb_w[entry]   = ~(|op_w) & (cmo_w != `RNI_AWCMO_NONE) & ~wb_w;
            assign awctrl_entry_lerr_w[entry]   = (awctrl_entry_so_w[entry] & ~wb_w) |
                                                  (awctrl_entry_pft_w[entry] & awctrl_entry_device_w[entry]) |
                                                  (~(|op_w) & (cmo_w != `RNI_AWCMO_NONE) & wb_w) |
                                                  (awctrl_entry_zero_w[entry] & ~aw_line_sized_w[entry]);
            assign awctrl_entry_dl_w[entry]     = awctrl_entry_zero_w[entry] | awctrl_entry_so_w[entry] |
                                                  awctrl_entry_cmo_w[entry] | awctrl_entry_pft_w[entry] |
                                                  awctrl_entry_lerr_w[entry];
            assign awctrl_entry_unordered_w[entry] = awctrl_entry_so_w[entry] | awctrl_entry_cmo_w[entry] |
                                                     awctrl_entry_pft_w[entry] | awctrl_entry_lerr_w[entry];
            // SS2.3.3/SS4.2.4 (p.4-182): a CleanSharedPersistSep, alone or combined with a
            // write, owes a Persist besides its completion; a Combined Write owes CompCMO; a
            // StashOnceSep owes StashDone (SS2.3.4 p.2-72).
            assign awctrl_entry_persist_owed_w[entry]   = ~awctrl_entry_lerr_w[entry] &
                   ((op_w == `RNI_AWOP_CLEAN_SHARED_PERSIST_SEP) |
                    (awctrl_entry_comb_w[entry] & (cmo_w == `RNI_AWCMO_CLEAN_SH_PERSIST_SEP)));
            assign awctrl_entry_compcmo_owed_w[entry]   = awctrl_entry_comb_w[entry];
            assign awctrl_entry_stashdone_owed_w[entry] = awctrl_entry_sosep_w[entry] & ~awctrl_entry_lerr_w[entry];
        end
    endgenerate

    // The class of the entry being sent
    logic aw_sel_stashw_r, aw_sel_zero_r, aw_sel_so_r, aw_sel_sosep_r, aw_sel_cmo_r, aw_sel_pft_r, aw_sel_comb_r;
    logic [3:0] aw_sel_op_r;
    logic [1:0] aw_sel_cmoop_r;
    logic       aw_sel_stashniden_r;
    logic       aw_sel_atom_r;
    logic [5:0] aw_sel_atop_r;
    logic [2:0] aw_sel_asize_r;
    logic [CHIE_NID_WIDTH_PARAM-1:0] aw_sel_stashnid_r;
    logic [7:0] aw_sel_grpid_r;
    always_comb begin: aw_class_sel_t
        aw_sel_stashw_r = 1'b0; aw_sel_zero_r = 1'b0; aw_sel_so_r = 1'b0; aw_sel_sosep_r = 1'b0;
        aw_sel_cmo_r = 1'b0; aw_sel_pft_r = 1'b0; aw_sel_comb_r = 1'b0;
        aw_sel_op_r = '0; aw_sel_cmoop_r = '0; aw_sel_stashniden_r = 1'b0; aw_sel_stashnid_r = '0; aw_sel_grpid_r = '0;
        aw_sel_atom_r = 1'b0; aw_sel_atop_r = '0; aw_sel_asize_r = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            aw_sel_stashw_r     = aw_sel_stashw_r | (awctrl_entry_req_ptr_q[i] & awctrl_entry_stashw_w[i]);
            aw_sel_zero_r       = aw_sel_zero_r   | (awctrl_entry_req_ptr_q[i] & awctrl_entry_zero_w[i]);
            aw_sel_so_r         = aw_sel_so_r     | (awctrl_entry_req_ptr_q[i] & awctrl_entry_so_w[i]);
            aw_sel_sosep_r      = aw_sel_sosep_r  | (awctrl_entry_req_ptr_q[i] & awctrl_entry_sosep_w[i]);
            aw_sel_cmo_r        = aw_sel_cmo_r    | (awctrl_entry_req_ptr_q[i] & awctrl_entry_cmo_w[i]);
            aw_sel_pft_r        = aw_sel_pft_r    | (awctrl_entry_req_ptr_q[i] & awctrl_entry_pft_w[i]);
            aw_sel_comb_r       = aw_sel_comb_r   | (awctrl_entry_req_ptr_q[i] & awctrl_entry_comb_w[i]);
            aw_sel_atom_r       = aw_sel_atom_r   | (awctrl_entry_req_ptr_q[i] & awctrl_entry_atom_w[i]);
            aw_sel_atop_r       = aw_sel_atop_r   | ({6{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].atop);
            aw_sel_asize_r      = aw_sel_asize_r  | ({3{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].size);
            aw_sel_op_r         = aw_sel_op_r     | ({4{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].op);
            aw_sel_cmoop_r      = aw_sel_cmoop_r  | ({2{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].cmo);
            aw_sel_stashniden_r = aw_sel_stashniden_r | (awctrl_entry_req_ptr_q[i] & awctrl_entry_info_q[i].stashniden);
            aw_sel_stashnid_r   = aw_sel_stashnid_r | ({CHIE_NID_WIDTH_PARAM{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].stashnid);
            // A StashOnceSep's StashGroupID and a persistent CMO's PGroupID: the entry
            // itself, which no other outstanding request of this RN-I holds.
            aw_sel_grpid_r      = aw_sel_grpid_r  | ({8{awctrl_entry_req_ptr_q[i]}} & 8'(i));
        end
    end

    always_comb begin
        aw_excl_r = 1'b0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_excl_r = aw_excl_r | (awctrl_entry_req_ptr_q[i] & awctrl_entry_excl_q[i]);
    end

    // SS12.5.2 (p.12-379, MUST): a Full write with TagOp=Update must assert every TU
    // bit, where the Ptl forms admit "any combination of TU and BE bits". TU names
    // which Allocation Tags to update (SS13.10.39 p.13-435), so an Update the manager
    // marked for only some tags cannot be widened to all of them -- it is issued as
    // the Ptl form, which SS2.10.3 (p.2-135) lets assert every byte enable anyway.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin: aw_entry_full_write
            assign aw_entry_full_write_w[entry] = aw_line_sized_w[entry] & wdata_recv_done_q[entry] &
                   wb_entry_all_be_i[entry] &
                   ((awctrl_entry_tagop_o[entry] != chie_pkg::TAGOP_UPDATE) | wb_entry_all_tu_i[entry]);
        end
    endgenerate

    always_comb begin: aw_full_write_sel
        aw_full_write_r = 1'b0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_full_write_r = aw_full_write_r | (awctrl_entry_req_ptr_q[i] & aw_entry_full_write_w[i]);
    end

    always_comb begin
        aw_txreqflit_info_r = '0;
        aw_txreqflit_info_r.tgtid = aw_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0];
        aw_txreqflit_info_r.srcid = RNI_NID_PARAM;
        aw_txreqflit_info_r.txnid = aw_txreq_txnid_r[11:0];
        // Table 4-13 (p.4-178) gives the Non-snoopable and Snoopable writes both a
        // Full and a Partial form. SS2.10.3 (p.2-135) lets a *Ptl write assert any
        // combination "including asserting all", so the Partial form is always
        // legal -- but a Full write is a different transaction at the Completer
        // (Table 4-24 p.4-195 answers WriteUniqueFull with SnpMakeInvalid, which
        // returns no data, where the Ptl form's snoop feeds a read-modify-write),
        // so a whole-line write is issued as one.
        aw_txreqflit_info_r.opcode = aw_cacheable_w
            ? (aw_full_write_r ? chie_pkg::REQ_WRITEUNIQUEFULL : chie_pkg::REQ_WRITEUNIQUEPTL)
            : (aw_full_write_r ? chie_pkg::REQ_WRITENOSNPFULL  : chie_pkg::REQ_WRITENOSNPPTL);
        aw_txreqflit_info_r.allowretry = ~awctrl_entry_req_select_retry_flag_q;
        aw_txreqflit_info_r.tagop = aw_tagop_w[`AXI4_TAGOP_WIDTH-1:0];
        // Table 2-11's Device rows carry Order=EndpointOrder; on a Normal row
        // this Requester keeps its Ordered-Write-Observation stream, which
        // Table 2-11 footnote (a) permits for both WriteUnique and WriteNoSnp.
        aw_txreqflit_info_r.order = aw_device_w ? chie_pkg::ORDER_END_POINT : chie_pkg::ORDER_REQ_WR_OBS;
        // Sec 2.9.2 (p.2-126, MUST): EWA "must be asserted in any Write transaction
        // that is not a WriteNoSnp transaction", and Table 2-11 (p.2-129) gives
        // every Cacheable row EWA=1 -- AWCACHE Write-Through (bit[0]=0 with
        // bits[3:2] set) would otherwise emit a combination the table calls
        // Not valid.
        aw_txreqflit_info_r.memattr.early_wr_ack = aw_cacheable_w | aw_axcache_r[0];
        aw_txreqflit_info_r.memattr.device = aw_device_w;
        aw_txreqflit_info_r.memattr.cacheable = aw_cacheable_w;
        aw_txreqflit_info_r.snpattr = aw_cacheable_w;
        // SS2.7 (p.2-113, MUST): see rni_arctrl.sv for the derivation.
        // SS13.10.27 (p.13-432, MUST) gives WriteNoSnp the Excl bit and
        // WriteUnique none; see rni_arctrl.sv for the Cacheable case.
        // The write half of the same declaration; see rni_arctrl.sv.
        aw_txreqflit_info_r.excl.excl = aw_excl_r & ~aw_cacheable_w & ~aw_lpid_alias_w & ~(|aw_sel_op_r) & (aw_sel_cmoop_r == `RNI_AWCMO_NONE);
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)begin
            aw_txreqflit_info_r.qos = aw_txreqflit_info_r.qos | ({`AXI4_AWQOS_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].qos);
            aw_txreqflit_info_r.lpid = aw_txreqflit_info_r.lpid |
                ({8{awctrl_entry_req_ptr_q[i] & ~aw_cacheable_w & ~aw_tagop_match_w}} & awctrl_entry_info_q[i].id[7:0]) |
                ({8{awctrl_entry_req_ptr_q[i] & aw_tagop_match_w}} & aw_axtggid_r[`AXI4_TAGGROUPID_WIDTH-1:0]);
            aw_txreqflit_info_r.size = chie_pkg::size_e'(aw_txreqflit_info_r.size | ({`AXI4_AWSIZE_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_size_q[i][`AXI4_AWSIZE_WIDTH-1:0]));
            aw_txreqflit_info_r.addr = aw_txreqflit_info_r.addr | ({`AXI4_AWADDR_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_addr_q[i][`AXI4_AWADDR_WIDTH-1:0]);
            aw_txreqflit_info_r.pcrdtype = ~awctrl_entry_req_select_retry_flag_q ? '0 :
                               aw_txreqflit_info_r.pcrdtype | ({4{awctrl_entry_req_ptr_q[i]}} & rxrsp_retryack_pcrdtype_q[i][3:0]);
            // Table 2-11 gives no non-cacheable row an Allocate value.
            aw_txreqflit_info_r.memattr.allocate = aw_txreqflit_info_r.memattr.allocate | (aw_cacheable_w & awctrl_entry_req_ptr_q[i] & awctrl_entry_info_q[i].cache[3]);
            aw_txreqflit_info_r.expcompack = aw_txreqflit_info_r.expcompack | (awctrl_entry_req_ptr_q[i] & awctrl_entry_expcompack_q[i]);
`ifdef CHIE_MPAM_PRESENT
            // Sec 11.3 (p.11-365, MUST): see rni_arctrl.sv -- AWUSER carries the label.
            aw_txreqflit_info_r.mpam = chie_pkg::mpam_s'(aw_txreqflit_info_r.mpam |
                ({chie_pkg::MPAM_WIDTH{awctrl_entry_req_ptr_q[i]}} & awctrl_entry_info_q[i].user[`AXI4_USER_MPAM_RANGE]));
`endif
        end
        // ---- the requests AWOP/AWCMO select (rni_defines.svh)
        if (aw_sel_stashw_r) begin
            // Table 4-13 (p.4-178): the Stash forms take WriteUnique's rows. SS13.10.8/9
            // (p.13-419): the stash target, with no StashLPID.
            aw_txreqflit_info_r.opcode = aw_full_write_r ? chie_pkg::REQ_WRITEUNIQUEFULLSTASH : chie_pkg::REQ_WRITEUNIQUEPTLSTASH;
            aw_txreqflit_info_r.stashnidvalid.stashnidvalid = aw_sel_stashniden_r;
            aw_txreqflit_info_r.returnnid = aw_sel_stashniden_r ? aw_sel_stashnid_r : '0;
        end
        if (aw_sel_zero_r) begin
            // Table 4-13: Size 64, Excl 0, ExpCompAck 0; Device nE Order 11, Normal 00/10
            // (Request Order here, as this bridge orders its other Normal writes), and
            // Table 12-2 (p.12-389) no tags.
            aw_txreqflit_info_r.opcode     = aw_cacheable_w ? chie_pkg::REQ_WRITEUNIQUEZERO : chie_pkg::REQ_WRITENOSNPZERO;
            aw_txreqflit_info_r.size       = chie_pkg::SIZE_64B;
            aw_txreqflit_info_r.tagop      = 2'b00;
            aw_txreqflit_info_r.expcompack = 1'b0;
        end
        if (aw_sel_so_r) begin
            // Table 4-7 (p.4-172): Size 64, Excl 0, SnpAttr 1, MemAttr 0101/1101, Order 00,
            // ExpCompAck 0; Table 12-2 (p.12-388): TagOp Invalid is permitted.
            aw_txreqflit_info_r.opcode     = (aw_sel_op_r == `RNI_AWOP_STASH_ONCE_SHARED)     ? chie_pkg::REQ_STASHONCESHARED :
                                             (aw_sel_op_r == `RNI_AWOP_STASH_ONCE_UNIQUE)     ? chie_pkg::REQ_STASHONCEUNIQUE :
                                             (aw_sel_op_r == `RNI_AWOP_STASH_ONCE_SEP_SHARED) ? chie_pkg::REQ_STASHONCESEPSHARED :
                                                                                                chie_pkg::REQ_STASHONCESEPUNIQUE;
            aw_txreqflit_info_r.stashnidvalid.stashnidvalid = aw_sel_stashniden_r;
            aw_txreqflit_info_r.returnnid  = aw_sel_stashniden_r ? aw_sel_stashnid_r : '0;
            // SS13.10.7 (p.13-418): a StashOnceSep's StashGroupID occupies the LPID bits.
            aw_txreqflit_info_r.lpid       = aw_sel_sosep_r ? aw_sel_grpid_r : 8'h00;
        end
        if (aw_sel_cmo_r) begin
            // Table 4-7: Size 64, Excl 0, Order 00, ExpCompAck 0, SnpAttr with the memory
            // type; Table 12-2: TagOp Invalid.
            aw_txreqflit_info_r.opcode     = (aw_sel_op_r == `RNI_AWOP_CLEAN_SHARED)             ? chie_pkg::REQ_CLEANSHARED :
                                             (aw_sel_op_r == `RNI_AWOP_CLEAN_SHARED_PERSIST)     ? chie_pkg::REQ_CLEANSHAREDPERSIST :
                                             (aw_sel_op_r == `RNI_AWOP_CLEAN_SHARED_PERSIST_SEP) ? chie_pkg::REQ_CLEANSHAREDPERSISTSEP :
                                             (aw_sel_op_r == `RNI_AWOP_CLEAN_INVALID)            ? chie_pkg::REQ_CLEANINVALID :
                                                                                                   chie_pkg::REQ_MAKEINVALID;
            // SS13.10.7: a CleanSharedPersistSep's PGroupID occupies the LPID bits.
            aw_txreqflit_info_r.lpid       = (aw_sel_op_r == `RNI_AWOP_CLEAN_SHARED_PERSIST_SEP) ? aw_sel_grpid_r : 8'h00;
        end
        if (aw_sel_so_r | aw_sel_cmo_r | aw_sel_pft_r) begin
            aw_txreqflit_info_r.size       = chie_pkg::SIZE_64B;
            aw_txreqflit_info_r.tagop      = 2'b00;
            aw_txreqflit_info_r.order      = chie_pkg::ORDER_NONE;
            aw_txreqflit_info_r.expcompack = 1'b0;
            aw_txreqflit_info_r.excl.excl  = 1'b0;
        end
        if (aw_sel_pft_r) begin
            // SS3.3.1: "PrefetchTgt always targets a Subordinate Node"; SS2.11 (p.2-145)
            // gives it no Retry sequence.
            aw_txreqflit_info_r.opcode     = chie_pkg::REQ_PREFETCHTGT;
            aw_txreqflit_info_r.tgtid      = CHIE_NID_WIDTH_PARAM'(SNF_NID_PARAM);
            aw_txreqflit_info_r.allowretry = 1'b0;
            aw_txreqflit_info_r.lpid       = 8'h00;
        end
        if (aw_sel_comb_r) begin
            // Table 4-17 (p.4-182): a WriteNoSnp combines with CleanShared, CleanInvalid or
            // a persistent CMO, which SS4.2.4 makes a CleanSharedPersistSep; Excl and a
            // TagOp Match are not permitted on a Combined Write.
            aw_txreqflit_info_r.opcode     = aw_full_write_r ?
                ((aw_sel_cmoop_r == `RNI_AWCMO_CLEAN_SHARED)  ? chie_pkg::REQ_WRITENOSNPFULLCLEANSH :
                 (aw_sel_cmoop_r == `RNI_AWCMO_CLEAN_INVALID) ? chie_pkg::REQ_WRITENOSNPFULLCLEANINV :
                                                                chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP) :
                ((aw_sel_cmoop_r == `RNI_AWCMO_CLEAN_SHARED)  ? chie_pkg::REQ_WRITENOSNPPTLCLEANSH :
                 (aw_sel_cmoop_r == `RNI_AWCMO_CLEAN_INVALID) ? chie_pkg::REQ_WRITENOSNPPTLCLEANINV :
                                                                chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP);
            aw_txreqflit_info_r.excl.excl  = 1'b0;
            aw_txreqflit_info_r.lpid       = (aw_sel_cmoop_r == `RNI_AWCMO_CLEAN_SH_PERSIST_SEP) ? aw_sel_grpid_r : 8'h00;
        end
        if (aw_sel_atom_r) begin
            // AXI5 AWATOP[2:0] orders ADD, CLR, EOR, SET, SMAX, SMIN, UMAX, UMIN as CHI's
            // AtomicStore/AtomicLoad encodings do (Tables 4-19/4-20). Table 4-21 (p.4-188):
            // ExpCompAck 0, SnoopMe 0 here, Order 11 on Device and Request Order on Normal;
            // SS13.10.28 (p.13-432): AWATOP[3] is the Endian of a Store or Load.
            aw_txreqflit_info_r.opcode     = (aw_sel_atop_r[5:4] == 2'b01) ? chie_pkg::req_opcode_e'(7'h28 | 7'(aw_sel_atop_r[2:0])) :
                                             (aw_sel_atop_r[5:4] == 2'b10) ? chie_pkg::req_opcode_e'(7'h30 | 7'(aw_sel_atop_r[2:0])) :
                                             aw_sel_atop_r[0]              ? chie_pkg::REQ_ATOMICCOMPARE : chie_pkg::REQ_ATOMICSWAP;
            aw_txreqflit_info_r.stashnidvalid.endian = (aw_sel_atop_r[5:4] != 2'b11) & aw_sel_atop_r[3];
            // Table 4-21: Size is the operand size, AWSIZE, not the write's 16-byte container.
            aw_txreqflit_info_r.size       = chie_pkg::size_e'(aw_sel_asize_r);
            aw_txreqflit_info_r.excl.snoopme = 1'b0;
            aw_txreqflit_info_r.expcompack = 1'b0;
            aw_txreqflit_info_r.tagop      = 2'b00;
            aw_txreqflit_info_r.order      = aw_device_w ? chie_pkg::ORDER_END_POINT : chie_pkg::ORDER_REQ_WR_OBS;
        end
    end

    assign awctrl_txreqflitv_s4_o = awctrl_entry_req_select_success_q | (~aw_txreqflit_sent_s5_q & aw_txreqflitv_s5_q);
    assign awctrl_txreqflit_s4_o = (~aw_txreqflit_sent_s5_q & aw_txreqflitv_s5_q) ? aw_txreqflit_s5_q : aw_txreqflit_info_r;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txreqflitv_s5_q <= 1'b0;
        end
        else begin
            aw_txreqflitv_s5_q <= awctrl_txreqflitv_s4_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txreqflit_s5_q <= '0;
        end
        else begin
            aw_txreqflit_s5_q<= awctrl_txreqflit_s4_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txreqflit_sent_s5_q <= 1'b0;
        end
        else begin
            aw_txreqflit_sent_s5_q<= awctrl_txreqflit_sent_s4_i;
        end
    end

    /////////////////////////////////////////////////////////////
    // rxrsp
    /////////////////////////////////////////////////////////////
    assign awctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] = awctrl_rxrspflit_d1_i.tgtid;
    assign awctrl_entry_rxrsp_srcid_w[chie_pkg::NID_WIDTH-1:0] = awctrl_rxrspflit_d1_i.srcid;
    assign awctrl_entry_rxrsp_tracetag_w = awctrl_rxrspflit_d1_i.tracetag;
    assign awctrl_entry_rxrsp_txnid_w[11:0] = awctrl_rxrspflit_d1_i.txnid;
    assign awctrl_entry_rxrsp_opcode_w[5-1:0] = awctrl_rxrspflit_d1_i.opcode;
    assign awctrl_entry_rxrsp_dbid_w[11:0] = awctrl_rxrspflit_d1_i.dbid;
    assign awctrl_entry_rxrsp_pcrdtype_w[3:0] = awctrl_rxrspflit_d1_i.pcrdtype;
    assign awctrl_entry_rxrsp_resperr_w[2-1:0] = awctrl_rxrspflit_d1_i.resperr;

    assign aw_rxrsp_correct_w = awctrl_rxrspflitv_d1_i & awctrl_entry_rxrsp_txnid_w[12-1] & (awctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] == RNI_NID_PARAM);
    // Table B-3 (p.B-495) lists DBIDRespOrd among the responses an RN-I
    // receives, and SS2.8.5 (p.2-120) lets the Completer send it in place of
    // DBIDResp for an ordered write; without this the buffer grant is missed and
    // the write never sends its data.
    assign rxrsp_dbid_recv_flag_w = aw_rxrsp_correct_w & ((awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPDBIDRESP) | (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_DBIDRESP) | (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_DBIDRESPORD));
    assign rxrsp_dbid_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{rxrsp_dbid_recv_flag_w}} & awctrl_rxrsp_ptr_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // Table 4-38 (p.4-218): a StashOnceSep may complete with CompStashDone, and a
    // CleanSharedPersistSep with CompPersist (SS2.3.3), each also its other half.
    assign rxrsp_comp_recv_flag_w = aw_rxrsp_correct_w & ((awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPDBIDRESP) | (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMP) |
                                                          (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPSTASHDONE) | (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPPERSIST));
    assign rxrsp_comp_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{rxrsp_comp_recv_flag_w}} & awctrl_rxrsp_ptr_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_retryack_recv_flag_w = aw_rxrsp_correct_w & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_RETRYACK);

    // A request that sends no write data is ordered by its Comp, as a write is by its DBID.
    assign awctrl_chain_rel_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = rxrsp_dbid_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] |
           ((rxrsp_comp_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_synth_comp_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & awctrl_entry_dl_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    assign awctrl_chain_rel_flag_w = |awctrl_chain_rel_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // PrefetchTgt has no response (SS2.3.5): its completion is its sending. A refused
    // request completes at allocation, with an error.
    assign awctrl_synth_comp_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] =
           rxdat_atom_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] |
           ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_entry_req_select_success_flag_w}} & awctrl_entry_req_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_pft_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) |
           (awctrl_alloc_ptr_s2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_lerr_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    assign awctrl_synth_comp_flag_w = |awctrl_synth_comp_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    // An Atomic that returns data completes with CompData (Table 2-7 SS2.3.3), on DAT
    // under its write-side TxnID; it carries the original value.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:atom_rdata
            assign rxdat_atom_vec_w[entry] = awctrl_rxdatflitv_d1_i & awctrl_rxdatflit_d1_i.txnid[11] &
                   (awctrl_rxdatflit_d1_i.opcode == chie_pkg::DAT_COMPDATA) &
                   (awctrl_rxdatflit_d1_i.tgtid == RNI_NID_PARAM) &
                   (awctrl_rxdatflit_d1_i.txnid[`RNI_AW_ENTRIES_WIDTH-1:0] == `RNI_AW_ENTRIES_WIDTH'(entry)) &
                   awctrl_entry_v_q[entry] & awctrl_entry_atom_rd_w[entry];
            // The AXI beat is the 16-byte lane holding the address: SS2.10.4's DataID names
            // where the CHI packet starts, in 16-byte units.
            logic [1:0] lane_w;
            assign lane_w = awctrl_entry_addr_q[entry][5:4] - awctrl_rxdatflit_d1_i.dataid;
            // The window: Size bytes from an aligned address, or for an AtomicCompare whose
            // address names its second operand, the Size bytes centred on it.
            logic [6:0] nbytes_w, lo_w;
            assign nbytes_w = 7'd1 << awctrl_entry_info_q[entry].size;
            assign lo_w     = ((awctrl_entry_addr_q[entry][5:0] & 6'(nbytes_w - 7'd1)) == 6'd0) ?
                              {1'b0, awctrl_entry_addr_q[entry][5:0]} :
                              ({1'b0, awctrl_entry_addr_q[entry][5:0]} - (nbytes_w >> 1));
            assign awctrl_entry_atom_o[entry]    = awctrl_entry_atom_w[entry];
            assign awctrl_entry_atom_be_o[entry] = (((`WR_BUFFER_DATA_BANK_NUM*`AXI4_WSTRB_WIDTH)'(1) << nbytes_w) - 1'b1) << lo_w;
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                    awctrl_atom_rdata_v_q[entry] <= 1'b0;
                    awctrl_atom_rdata_q[entry]   <= '0;
                    awctrl_atom_rresp_q[entry]   <= '0;
                end
                else if (awctrl_entry_dealloc_vec_w[entry]) begin
                    awctrl_atom_rdata_v_q[entry] <= 1'b0;
                end
                else if (rxdat_atom_vec_w[entry]) begin
                    awctrl_atom_rdata_v_q[entry] <= 1'b1;
                    awctrl_atom_rdata_q[entry]   <= awctrl_rxdatflit_d1_i.data[lane_w*opennoc_rni_pkg::DATA_WIDTH +: opennoc_rni_pkg::DATA_WIDTH];
                    awctrl_atom_rresp_q[entry]   <= awctrl_rxdatflit_d1_i.resperr;
                end
            end
        end
    endgenerate

    assign rxrsp_compcmo_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] =
           {RNI_AW_ENTRIES_NUM_PARAM{aw_rxrsp_correct_w & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPCMO)}} & awctrl_rxrsp_ptr_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // Persist and StashDone carry TxnID 0 and the group in the DBID bits (Table A-8,
    // p.A-488), like TagMatch below; CompPersist and CompStashDone are TxnID-matched.
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:group_rsp_track
            assign rxrsp_persist_hit_w[entry] =
                   (awctrl_rxrspflitv_d1_i & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_PERSIST) &
                    (awctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] == RNI_NID_PARAM) &
                    awctrl_entry_v_q[entry] & awctrl_entry_persist_owed_w[entry] &
                    (awctrl_rxrspflit_d1_i.dbid[7:0] == 8'(entry))) |
                   (aw_rxrsp_correct_w & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPPERSIST) & awctrl_rxrsp_ptr_r[entry]);
            assign rxrsp_stashdone_hit_w[entry] =
                   (awctrl_rxrspflitv_d1_i & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_STASHDONE) &
                    (awctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] == RNI_NID_PARAM) &
                    awctrl_entry_v_q[entry] & awctrl_entry_stashdone_owed_w[entry] &
                    (awctrl_rxrspflit_d1_i.dbid[7:0] == 8'(entry))) |
                   (aw_rxrsp_correct_w & (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_COMPSTASHDONE) & awctrl_rxrsp_ptr_r[entry]);
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                    awctrl_compcmo_recv_q[entry]   <= 1'b0;
                    awctrl_persist_recv_q[entry]   <= 1'b0;
                    awctrl_stashdone_recv_q[entry] <= 1'b0;
                end
                else if (awctrl_entry_dealloc_vec_w[entry]) begin
                    awctrl_compcmo_recv_q[entry]   <= 1'b0;
                    awctrl_persist_recv_q[entry]   <= 1'b0;
                    awctrl_stashdone_recv_q[entry] <= 1'b0;
                end
                else begin
                    if (rxrsp_compcmo_recv_vec_w[entry]) awctrl_compcmo_recv_q[entry]   <= 1'b1;
                    if (rxrsp_persist_hit_w[entry])      awctrl_persist_recv_q[entry]   <= 1'b1;
                    if (rxrsp_stashdone_hit_w[entry])    awctrl_stashdone_recv_q[entry] <= 1'b1;
                end
            end
        end
    endgenerate

    // Table A-8 (p.A-488) gives TagMatch TxnID = 0, so it is not admitted by the
    // TxnID[11] convention the other write responses use: Sec 13.10.40 (p.13-435)
    // keys it by the TagGroupID the DBID bits carry. Table 13-35 (p.13-437) makes
    // Resp[0] the verdict, 1 Pass and 0 Fail.
    assign rxrsp_tagmatch_recv_w = awctrl_rxrspflitv_d1_i &
           (awctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_TAGMATCH) &
           (awctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] == RNI_NID_PARAM);
    assign rxrsp_tagmatch_group_w[7:0] = awctrl_rxrspflit_d1_i.dbid[7:0];
    assign rxrsp_tagmatch_pass_w       = awctrl_rxrspflit_d1_i.resp[0];

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:tagmatch_track
            // Sec 13.10.40: a Requester groups its Match requests and processes the
            // TagMatch responses per group, so one response answers every entry of
            // that group that is still owed one.
            assign awctrl_tagmatch_req_w[entry] = (awctrl_entry_tagop_o[entry] == 2'b11);
            assign rxrsp_tagmatch_hit_w[entry]  = rxrsp_tagmatch_recv_w &
                   awctrl_entry_v_q[entry] & awctrl_tagmatch_req_w[entry] &
                   (awctrl_entry_info_q[entry].user[`AXI4_USER_TGGID_RANGE] == rxrsp_tagmatch_group_w[7:0]);
            assign awctrl_tagmatch_owed_w[entry] = awctrl_tagmatch_req_w[entry] &
                   ~(awctrl_tagmatch_recv_q[entry] | rxrsp_tagmatch_hit_w[entry]);

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                    awctrl_tagmatch_recv_q[entry] <= 1'b0;
                    awctrl_tagmatch_pass_q[entry] <= 1'b0;
                end
                else if (awctrl_entry_dealloc_vec_w[entry]) begin
                    awctrl_tagmatch_recv_q[entry] <= 1'b0;
                    awctrl_tagmatch_pass_q[entry] <= 1'b0;
                end
                else if (rxrsp_tagmatch_hit_w[entry]) begin
                    awctrl_tagmatch_recv_q[entry] <= 1'b1;
                    awctrl_tagmatch_pass_q[entry] <= rxrsp_tagmatch_pass_w;
                end
            end
        end
    endgenerate
    assign rxrsp_retryack_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{rxrsp_retryack_recv_flag_w}} & awctrl_rxrsp_ptr_r[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    assign rxrsp_retryack_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (rxrsp_retryack_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | rxrsp_retryack_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_dbid_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (rxrsp_dbid_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | rxrsp_dbid_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // Set when the ordered write is actually sent, cleared only by its own
    // DBIDResp/DBIDRespOrd/CompDBIDResp or by dealloc -- so a RetryAck'd ordered
    // write keeps blocking the next one, which is Figure 2-34 step 5 (p.2-121).
    assign awctrl_ordered_pending_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (awctrl_ordered_pending_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_entry_req_select_success_flag_w}} & awctrl_entry_req_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_ordered_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_chain_rel_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_ordered_pending_any_w = |awctrl_ordered_pending_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // Sec 2.9.4 (p.2-130, MUST): the Device nRnE and Device nRE required behaviour
    // is that "All Read and Write transactions from the same source to the same
    // endpoint must remain ordered" -- across the two kinds, not within each. The
    // per-channel gates below are Sec 2.8.5's, one transaction family apiece, so
    // this pair is what orders a read against a write. Device-qualified on both
    // sides: Table 2-11 (p.2-129) gives Device RE Order[0]=0 and p.2-130 drops the
    // endpoint clause for it, and a Normal write owes a read nothing at all.
    // The NEXT-state term, not the flopped one, so a Device write selected THIS
    // cycle already blocks the read channel. Both channels select independently
    // and only then arbitrate for the one TXREQ port, so the flop's one-cycle
    // latency -- which is exact within a channel, where the poll picks one entry
    // per cycle -- lets a read and a write be selected together. The asymmetry
    // with the read channel's flopped term below is what breaks the combinational
    // loop the two gates would otherwise form; which side wins a same-cycle tie is
    // arbitrary, and Sec 2.9.4 (p.2-130) constrains only that one of them backs off.
    assign awctrl_device_ordered_pending_o = |(awctrl_ordered_pending_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_entry_device_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    assign rxrsp_comp_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (rxrsp_comp_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | rxrsp_comp_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] | awctrl_synth_comp_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    assign rxrsp_pcrdgrant_recv_flag_w = pcrdgnt_pkt_v_d2_i;
    // SS2.11 (p.2-145, MUST): a credit may arrive before the RetryAck it belongs
    // to, so rni_misc must keep it while any request of this channel can still be
    // retried. An allocated entry is exactly that.
    assign awctrl_entry_any_v_o = |awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    assign awctrl_pcrdgnt_h_present_d3_o = rxrsp_pcrdtype_hi_match_d3_q;
    assign awctrl_pcrdgnt_l_present_d3_o = rxrsp_pcrdtype_lo_match_d3_q;
    assign rxrsp_pcrdtype_hi_select_w = awctrl_pcrdgnt_h_win_d3_i & rxrsp_pcrdtype_hi_match_d3_q;
    assign rxrsp_pcrdtype_lo_select_w = awctrl_pcrdgnt_l_win_d3_i & rxrsp_pcrdtype_lo_match_d3_q;
    assign rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_hi_select_w}} & rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_lo_select_w}} & rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_pcrdgrant_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (rxrsp_pcrdgrant_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] |
            (({RNI_AW_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_hi_select_w}} & rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) |
             ({RNI_AW_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_lo_select_w}} & rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]))) &
           ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:rxrsp_ptr
            always_comb begin
                if(entry == awctrl_entry_rxrsp_txnid_w[`RNI_AW_ENTRIES_WIDTH-1:0])begin
                    awctrl_rxrsp_ptr_r[entry] = 1'b1;
                end
                else begin
                    awctrl_rxrsp_ptr_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:pcrdtype_match
            always_comb begin
                if(rxrsp_pcrdgrant_recv_flag_w & rxrsp_retryack_recv_vec_q[entry] & ~(rxrsp_pcrdgrant_recv_vec_q[entry] | rxrsp_pcrdgrant_recv_vec_ns_w[entry]))begin
                    rxrsp_pcrdgrant_hi_rdy_vec_r[entry] = (pcrdgnt_pkt_d2_i.pcrdtype == rxrsp_retryack_pcrdtype_q[entry][3:0]) &&
                                                (pcrdgnt_pkt_d2_i.srcid == aw_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0]) &&
                                                (pcrdgnt_pkt_d2_i.tgtid == RNI_NID_PARAM) && awctrl_entry_qos_hi_q[entry];
                end
                else begin
                    rxrsp_pcrdgrant_hi_rdy_vec_r[entry] = 1'b0;
                end
            end

            always_comb begin
                if(rxrsp_pcrdgrant_recv_flag_w & rxrsp_retryack_recv_vec_q[entry] & ~(rxrsp_pcrdgrant_recv_vec_q[entry] | rxrsp_pcrdgrant_recv_vec_ns_w[entry]))begin
                    rxrsp_pcrdgrant_lo_rdy_vec_r[entry] = (pcrdgnt_pkt_d2_i.pcrdtype == rxrsp_retryack_pcrdtype_q[entry][3:0]) &&
                                                (pcrdgnt_pkt_d2_i.srcid == aw_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0]) &&
                                                (pcrdgnt_pkt_d2_i.tgtid == RNI_NID_PARAM) && ~awctrl_entry_qos_hi_q[entry];
                end
                else begin
                    rxrsp_pcrdgrant_lo_rdy_vec_r[entry] = 1'b0;
                end
            end
        end
    endgenerate
    //s2 selects entry, s3 knows whether it is successful, and s4 updates rxrsp_pcrdgrant_hi_upd_ptr_q/rxrsp_pcrdgrant_recv_vec_q,
    // it is necessary to consider the situation of two consecutive beats.
    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        pcrdtype_hi_select(
            .entry_vec(rxrsp_pcrdgrant_hi_rdy_vec_r[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(rxrsp_pcrdtype_hi_select_w ? rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] : rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(rxrsp_pcrdgrant_hi_recv_vec_d2_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(rxrsp_pcrdtype_hi_match_d2_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        pcrdtype_lo_select(
            .entry_vec(rxrsp_pcrdgrant_lo_rdy_vec_r[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(rxrsp_pcrdtype_lo_select_w ? rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] : rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(rxrsp_pcrdgrant_lo_recv_vec_d2_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(rxrsp_pcrdtype_lo_match_d2_w)
        );

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdtype_hi_match_d3_q <= 1'b0;
        end
        else begin
            rxrsp_pcrdtype_hi_match_d3_q <= rxrsp_pcrdtype_hi_match_d2_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_hi_recv_vec_d2_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdtype_lo_match_d3_q <= 1'b0;
        end
        else begin
            rxrsp_pcrdtype_lo_match_d3_q <= rxrsp_pcrdtype_lo_match_d2_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_lo_recv_vec_d2_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:rxrsp_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    rxrsp_dbidresp_srcid_q[entry][chie_pkg::NID_WIDTH-1:0] <= '0;
                end
                else begin
                    if(rxrsp_dbid_recv_vec_w[entry])begin
                        rxrsp_dbidresp_srcid_q[entry][chie_pkg::NID_WIDTH-1:0] <= awctrl_entry_rxrsp_srcid_w[chie_pkg::NID_WIDTH-1:0];
                    end
                    else if(awctrl_entry_dealloc_vec_w[entry])begin
                        rxrsp_dbidresp_srcid_q[entry][chie_pkg::NID_WIDTH-1:0] <= '0;
                    end
                end
            end
            // SS11.5.1 (p.11-368, MUST): the NCBWrDataCompAck TraceTag "must be set
            // if either one of Comp or DBIDResp that caused the WriteData response
            // have the TraceTag bit set", so this is the OR over both, held until
            // the entry that owes the reflection is done with it.
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    rxrsp_tracetag_q[entry] <= 1'b0;
                end
                else begin
                    if((rxrsp_dbid_recv_vec_w[entry] | rxrsp_comp_recv_vec_w[entry]) & awctrl_entry_rxrsp_tracetag_w)begin
                        rxrsp_tracetag_q[entry] <= 1'b1;
                    end
                    else if(awctrl_entry_dealloc_vec_w[entry])begin
                        rxrsp_tracetag_q[entry] <= 1'b0;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    rxrsp_dbidresp_dbid_q[entry][11:0] <= '0;
                end
                else begin
                    if(rxrsp_dbid_recv_vec_w[entry])begin
                        rxrsp_dbidresp_dbid_q[entry][11:0] <= awctrl_entry_rxrsp_dbid_w[11:0];
                    end
                    else if(awctrl_entry_dealloc_vec_w[entry])begin
                        rxrsp_dbidresp_dbid_q[entry][11:0] <= '0;
                    end
                end
            end
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    rxrsp_retryack_pcrdtype_q[entry][3:0] <= '0;
                end
                else begin
                    if(rxrsp_retryack_recv_vec_w[entry])begin
                        rxrsp_retryack_pcrdtype_q[entry][3:0] <= awctrl_entry_rxrsp_pcrdtype_w[3:0];
                    end
                    else if(awctrl_entry_dealloc_vec_w[entry])begin
                        rxrsp_retryack_pcrdtype_q[entry][3:0] <= '0;
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_retryack_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_retryack_recv_flag_w | awctrl_entry_dealloc_v_w)begin
                rxrsp_retryack_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_retryack_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            awctrl_ordered_pending_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            awctrl_ordered_pending_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= awctrl_ordered_pending_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_hi_select_w)begin
                rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_lo_select_w)begin
                rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_hi_select_w | rxrsp_pcrdtype_lo_select_w | awctrl_entry_dealloc_v_w)begin
                rxrsp_pcrdgrant_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_dbid_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_dbid_recv_flag_w | awctrl_entry_dealloc_v_w)begin
                rxrsp_dbid_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_dbid_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_comp_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_comp_recv_flag_w | awctrl_synth_comp_flag_w | awctrl_entry_dealloc_v_w)begin
                rxrsp_comp_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= rxrsp_comp_recv_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // txdat
    /////////////////////////////////////////////////////////////
    //req is sent in two beats and txdat is sent in three beats
    assign txdat_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = rxrsp_dbid_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~txdat_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] &
           ~awctrl_entry_dl_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // A request with no CHI write data is done with its data once the AXI beat it was
    // given has been drained, so B still follows every W beat (AXI4 A3.3.1).
    assign awctrl_data_done_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = txdat_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] |
           (awctrl_entry_dl_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]);
    assign wdata_recv_done_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{wb_req_done_d3_i}} & wb_req_entry_d3_i[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    // An entry with packets left after this one stays selectable, so it is sent again next.
    assign txdat_select_more_w = wb_not_busy_d1_i & txdat_select_success_w & (|(txdat_pend_sel_r & ~txdat_ctmask_d1_r));
    assign txdat_select_new_entry_w = wb_not_busy_d1_i & txdat_select_success_w & ~txdat_select_more_w;
    assign txdat_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (txdat_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{txdat_select_new_entry_w}} & txdat_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign txdat_send_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (txdat_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_txdat_not_busy_d2_i}} & txdat_rdy_entry_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & txdat_select_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];//txdat_select_vec_d3_q prevents a second packet
    assign awctrl_txdat_compack_d2_o = 1'b0;
    assign awctrl_txdat_rdy_v_d2_o = txdat_rdy_v_d2_q;
    assign awctrl_txdat_rdy_entry_d2_o[RNI_AW_ENTRIES_NUM_PARAM-1:0] = txdat_rdy_entry_d2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_txdat_ctmask_d2_o[`RNI_DMASK_CT_WIDTH-1:0] = txdat_ctmask_d2_q[`RNI_DMASK_CT_WIDTH-1:0];
    //If an entry needs to send more packets, entry_vec and upd are the same as the last selection.
    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        txdat_select(
            .entry_vec(txdat_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(txdat_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(txdat_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(txdat_select_success_w)
        );

    always_comb begin
        txdat_ctmask_d1_r[`RNI_DMASK_CT_WIDTH-1:0] = {`RNI_DMASK_CT_WIDTH{1'b0}};
        txdat_pend_sel_r = 4'b0000;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_select_vec_w[i]) begin
                txdat_pend_sel_r = txdat_pend_q[i];
                txdat_ctmask_d1_r[`RNI_DMASK_CT_WIDTH-1:0] = opennoc_rni_pkg::next_pkt(txdat_pend_q[i], awctrl_entry_addr_q[i][5:4]);
            end
        end
    end

    generate
        for (genvar e = 0; e < RNI_AW_ENTRIES_NUM_PARAM; e = e + 1) begin: txdat_pend
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1 || awctrl_entry_dealloc_vec_w[e])
                    txdat_pend_q[e] <= 4'b0000;
                else if (awlink_valid_s2_q && awctrl_alloc_ptr_s2_q[e])
                    txdat_pend_q[e] <= txdat_pkts_s2_w;
                else if (wb_not_busy_d1_i && txdat_select_success_w && txdat_select_vec_w[e])
                    txdat_pend_q[e] <= txdat_pend_q[e] & ~txdat_ctmask_d1_r;
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(wb_req_done_d3_i | awctrl_entry_dealloc_v_w)begin
                wdata_recv_done_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= wdata_recv_done_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(txdat_select_new_entry_w)begin
                txdat_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txdat_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(txdat_select_new_entry_w | awctrl_entry_dealloc_v_w)begin
                txdat_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txdat_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_rdy_v_d2_q <= 1'b0;
        end
        else begin
            if(wb_not_busy_d1_i)begin
                txdat_rdy_v_d2_q <=txdat_select_success_w;
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_rdy_entry_d2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(wb_not_busy_d1_i)begin
                txdat_rdy_entry_d2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <=txdat_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_comb begin
        awctrl_txdat_qos_d2_o = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_rdy_v_d2_q && txdat_rdy_entry_d2_q[i])
                awctrl_txdat_qos_d2_o[3:0] = awctrl_entry_info_q[i].qos;
        end
    end

    always_comb begin
        awctrl_txdat_dbid_d2_o = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_rdy_v_d2_q && txdat_rdy_entry_d2_q[i])
                awctrl_txdat_dbid_d2_o[11:0] = rxrsp_dbidresp_dbid_q[i][11:0];
        end
    end

    // SS2.10.6 (p.2-139, MUST): CCID matches Addr[5:4] of the request the data belongs to.
    always_comb begin
        awctrl_txdat_ccid_d2_o = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_rdy_v_d2_q && txdat_rdy_entry_d2_q[i])
                awctrl_txdat_ccid_d2_o = awctrl_entry_addr_q[i][5:4];
        end
    end

    always_comb begin
        awctrl_txdat_tracetag_d2_o = 1'b0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_rdy_v_d2_q && txdat_rdy_entry_d2_q[i])
                awctrl_txdat_tracetag_d2_o = rxrsp_tracetag_q[i];
        end
    end

    always_comb begin
        awctrl_txdat_tgtid_d2_o[chie_pkg::NID_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1) begin
            if(txdat_rdy_v_d2_q && txdat_rdy_entry_d2_q[i])
                awctrl_txdat_tgtid_d2_o[chie_pkg::NID_WIDTH-1:0] = rxrsp_dbidresp_srcid_q[i][chie_pkg::NID_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_ctmask_d2_q[`RNI_DMASK_CT_WIDTH-1:0] <= {4{1'b0}};
        end
        else begin
            if(wb_not_busy_d1_i)begin
                txdat_ctmask_d2_q[`RNI_DMASK_CT_WIDTH-1:0] <=txdat_ctmask_d1_r[`RNI_DMASK_CT_WIDTH-1:0];
            end
        end
    end

    // Shadow the write buffer's d3 flit register; share its enable
    // (rni_wr_buffer.v txdat_info_flop_en_d2_w) so the two stay aligned.
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_rdy_entry_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else if(awctrl_txdat_not_busy_d2_i)begin
            txdat_rdy_entry_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <=txdat_rdy_entry_d2_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_select_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else if(awctrl_txdat_not_busy_d2_i)begin
            txdat_select_vec_d3_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txdat_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txdat_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(awctrl_txdat_not_busy_d2_i | awctrl_entry_dealloc_v_w)begin
                txdat_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <=txdat_send_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end
    /////////////////////////////////////////////////////////////
    // txrsp
    /////////////////////////////////////////////////////////////
    assign txrsp_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = txdat_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & rxrsp_comp_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_compack_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] &
           awctrl_entry_expcompack_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~txrsp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign txrsp_select_success_flag_w = txrsp_select_success_w & (~awctrl_txrspflitv_d0_o | awctrl_txrspflit_sent_d0_i);
    assign txrsp_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (txrsp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{txrsp_select_success_flag_w}} & txrsp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_txrspflitv_d0_o = txrsp_select_success_flag_q | (aw_txrspflitv_d0_q & ~aw_txrspflit_sent_d0_q);
    assign awctrl_txrspflit_d0_o = (aw_txrspflitv_d0_q & ~aw_txrspflit_sent_d0_q) ? aw_txrspflit_d0_q : aw_txrspflit_info_r;
    assign txrsp_compack_send_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (txrsp_compack_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | (txrsp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & {RNI_AW_ENTRIES_NUM_PARAM{(awctrl_txrspflitv_d0_o & awctrl_txrspflit_sent_d0_i)}})) &
           ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_compack_chain_clean_flag_w = (awctrl_txrspflitv_d0_o & awctrl_txrspflit_sent_d0_i) | rxrsp_comp_recv_flag_w;
    assign awctrl_compack_chain_clean_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = ({RNI_AW_ENTRIES_NUM_PARAM{awctrl_txrspflitv_d0_o & awctrl_txrspflit_sent_d0_i}} & txrsp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) |
           (rxrsp_comp_recv_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~awctrl_entry_expcompack_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]);

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        txrsp_select(
            .entry_vec(txrsp_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(txrsp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(txrsp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(txrsp_select_success_w)
        );

    always_comb begin
        aw_txrsp_txnid_r[11:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            aw_txrsp_txnid_r[11:0] = aw_txrsp_txnid_r[11:0] | ({12{txrsp_select_ptr_q[i]}} & rxrsp_dbidresp_dbid_q[i][11:0]);
    end

    // Table 3-1 (SS3.3.2 p.3-153, MUST) derives a CompAck's TgtID from "Comp.SrcID
    // or DBIDResp.SrcID or CompDBIDResp.SrcID", not from a build parameter: SS3.3.1
    // (p.3-152, MUST) has a Requester "expect the interconnect to remap the target
    // ID of a request", so the Home that answers need not be the one addressed.
    always_comb begin
        aw_txrspflit_info_r = '0;
        aw_txrspflit_info_r.srcid = RNI_NID_PARAM;
        aw_txrspflit_info_r.txnid = aw_txrsp_txnid_r[11:0];
        aw_txrspflit_info_r.opcode = chie_pkg::RSP_COMPACK;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)begin
            aw_txrspflit_info_r.qos = aw_txrspflit_info_r.qos | ({`AXI4_AWQOS_WIDTH{txrsp_select_ptr_q[i]}} & awctrl_entry_info_q[i].qos);
            aw_txrspflit_info_r.tgtid = aw_txrspflit_info_r.tgtid |
                ({chie_pkg::NID_WIDTH{txrsp_select_ptr_q[i]}} & rxrsp_dbidresp_srcid_q[i][chie_pkg::NID_WIDTH-1:0]);
            aw_txrspflit_info_r.tracetag = aw_txrspflit_info_r.tracetag | (txrsp_select_ptr_q[i] & rxrsp_tracetag_q[i]);
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txrsp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(txrsp_select_success_flag_w)begin
                txrsp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txrsp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txrsp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(txrsp_select_success_flag_w | awctrl_entry_dealloc_v_w)begin
                txrsp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txrsp_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txrspflitv_d0_q <= 1'b0;
        end
        else begin
            aw_txrspflitv_d0_q <= awctrl_txrspflitv_d0_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txrspflit_sent_d0_q <= 1'b0;
        end
        else begin
            aw_txrspflit_sent_d0_q <= awctrl_txrspflit_sent_d0_i;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            aw_txrspflit_d0_q <= '0;
        end
        else begin
            aw_txrspflit_d0_q <= awctrl_txrspflit_d0_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txrsp_compack_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((awctrl_txrspflitv_d0_o & awctrl_txrspflit_sent_d0_i) | awctrl_entry_dealloc_v_w)begin
                txrsp_compack_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= txrsp_compack_send_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            txrsp_select_success_flag_q <= 1'b0;
        end
        else begin
            txrsp_select_success_flag_q <= txrsp_select_success_flag_w;
        end
    end

    /////////////////////////////////////////////////////////////
    // bresp
    /////////////////////////////////////////////////////////////
    assign bresp_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & rxrsp_comp_recv_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & awctrl_data_done_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] &
           // The other halves a request may owe: CompCMO, Persist, StashDone.
           (awctrl_compcmo_recv_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ~awctrl_entry_compcmo_owed_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           (awctrl_persist_recv_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ~awctrl_entry_persist_owed_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           (awctrl_stashdone_recv_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ~awctrl_entry_stashdone_owed_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           // An Atomic's R beat leaves before its entry, which holds the data, is freed.
           (awctrl_atom_r_sent_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ~awctrl_entry_atom_rd_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           (txrsp_compack_send_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ~awctrl_entry_expcompack_q[RNI_AW_ENTRIES_NUM_PARAM-1:0]) &
           ~awctrl_entry_bresp_dep_v_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] & ~bresp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] &
           // Sec 12.11.1 (p.12-386, MUST) owes a TagMatch to every Match write, and
           // Sec 12.1 (p.12-372) requires the failure reach the Requester -- which on
           // this port is BUSER, so B waits for the verdict.
           ~awctrl_tagmatch_owed_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign bresp_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = (bresp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] | ({RNI_AW_ENTRIES_NUM_PARAM{bresp_select_success_w & bresp_credit_avail_w}} & bresp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])) & ~awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_brsp_rdy_v_d2_o = brsp_rdy_v_d2_q;
    assign awctrl_brsp_last_v_d2_o = brsp_last_v_d2_q;
    assign awctrl_brsp_axid_d2_o[`AXI4_BID_WIDTH-1:0] = brsp_axid_d2_q[`AXI4_BID_WIDTH-1:0];
    assign awctrl_brsp_resperr_d2_o[2-1:0] = brsp_resperr_d2_q[2-1:0];
    assign awctrl_brsp_buser_d2_o[`AXI4_BUSER_WIDTH-1:0] = brsp_buser_d2_q[`AXI4_BUSER_WIDTH-1:0];
    assign bresp_credit_avail_w = !bresp_credit_full_w;

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AW_ENTRIES_NUM_PARAM)
        )
        bresp_select(
            .entry_vec(bresp_select_rdy_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(bresp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(bresp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0])
            ,.found(bresp_select_success_w)
        );

    sync_fifo #(
                  .FIFO_ENTRIES_WIDTH (RNI_AW_ENTRIES_NUM_PARAM)
                  ,.FIFO_ENTRIES_DEPTH (`BRSP_FIFO_ENTRIES_DEPTH)
                  ,.FIFO_BYP_ENABLE    (1'b0)
              )
              bresp_credit(
                  .clk            (clk_i                                              )
                  ,.rst            (rst_i                                              )
                  ,.push           (bresp_select_success_w & bresp_credit_avail_w      )
                  ,.pop            (awctrl_brsp_fifo_pop_d3_i                          )
                  ,.data_in        (bresp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]   )
                  ,.data_out       (bresp_send_ptr_w[RNI_AW_ENTRIES_NUM_PARAM-1:0]     )
                  ,.empty          (                                                   )
                  ,.full           (bresp_credit_full_w                                )
                  ,.count          (                                                   )
              );

    always_comb begin
        brsp_last_v_d2_ns_r = 1'b0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            brsp_last_v_d2_ns_r = brsp_last_v_d2_ns_r | (bresp_select_vec_w[i] & awctrl_entry_segburst_last_q[i]);
    end

    always_comb begin
        brsp_axid_d2_ns_r[`AXI4_BID_WIDTH-1:0] = '0;
        brsp_buser_d2_ns_r[`AXI4_BUSER_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)begin
            brsp_axid_d2_ns_r[`AXI4_BID_WIDTH-1:0] = brsp_axid_d2_ns_r[`AXI4_BID_WIDTH-1:0] | ({`AXI4_BID_WIDTH{bresp_select_vec_w[i]}} & awctrl_entry_info_q[i].id);
            // The hit is folded in combinationally as well: the response may be
            // selected in the same cycle the TagMatch clears its hold, and the
            // registered record does not exist yet then.
            brsp_buser_d2_ns_r[0] = brsp_buser_d2_ns_r[0] | (bresp_select_vec_w[i] & awctrl_tagmatch_req_w[i] &
                                    (awctrl_tagmatch_recv_q[i] | rxrsp_tagmatch_hit_w[i]));
            brsp_buser_d2_ns_r[1] = brsp_buser_d2_ns_r[1] | (bresp_select_vec_w[i] & awctrl_tagmatch_req_w[i] &
                                    (rxrsp_tagmatch_hit_w[i] ? rxrsp_tagmatch_pass_w : awctrl_tagmatch_pass_q[i]));
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)
            brsp_buser_d2_q[`AXI4_BUSER_WIDTH-1:0] <= '0;
        else
            brsp_buser_d2_q[`AXI4_BUSER_WIDTH-1:0] <= brsp_buser_d2_ns_r[`AXI4_BUSER_WIDTH-1:0];
    end

    always_comb begin
        brsp_resperr_d2_ns_r[2-1:0] = '0;
        for (int i =0; i < RNI_AW_ENTRIES_NUM_PARAM; i=i+1)
            brsp_resperr_d2_ns_r[2-1:0] = brsp_resperr_d2_ns_r[2-1:0] | ({2{bresp_select_vec_w[i]}} & awctrl_entry_resperr_q[i][2-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            bresp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(bresp_select_success_w & bresp_credit_avail_w)begin
                bresp_select_ptr_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= bresp_select_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            bresp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= {RNI_AW_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((bresp_select_success_w & bresp_credit_avail_w) | awctrl_entry_dealloc_v_w)begin
                bresp_select_vec_q[RNI_AW_ENTRIES_NUM_PARAM-1:0] <= bresp_select_vec_ns_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            brsp_rdy_v_d2_q <= 1'b0;
        end
        else begin
            brsp_rdy_v_d2_q <= bresp_select_success_w && bresp_credit_avail_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            brsp_last_v_d2_q <= 1'b0;
        end
        else begin
            brsp_last_v_d2_q <= brsp_last_v_d2_ns_r;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            brsp_axid_d2_q[`AXI4_BID_WIDTH-1:0] <= '0;
        end
        else begin
            brsp_axid_d2_q[`AXI4_BID_WIDTH-1:0] <= brsp_axid_d2_ns_r[`AXI4_BID_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            brsp_resperr_d2_q[2-1:0] <= '0;
        end
        else begin
            brsp_resperr_d2_q[2-1:0] <= brsp_resperr_d2_ns_r[2-1:0];
        end
    end

    /////////////////////////////////////////////////////////////
    // dealloc
    /////////////////////////////////////////////////////////////
    assign awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0] = {RNI_AW_ENTRIES_NUM_PARAM{awctrl_brsp_fifo_pop_d3_i}} & bresp_send_ptr_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];

    /////////////////////////////////////////////////////////////
    // Atomic R beat: one at a time, lowest entry first, held until accepted
    /////////////////////////////////////////////////////////////
    logic                                atr_v_q;
    logic [`RNI_AW_ENTRIES_WIDTH-1:0]    atr_idx_q;
    logic                                atr_pick_v_r;
    logic [`RNI_AW_ENTRIES_WIDTH-1:0]    atr_pick_idx_r;
    always_comb begin: atr_pick_t
        atr_pick_v_r = 1'b0; atr_pick_idx_r = '0;
        for (int i = RNI_AW_ENTRIES_NUM_PARAM-1; i >= 0; i--)
            if (awctrl_atom_rdata_v_q[i] & ~awctrl_atom_r_sent_q[i] & ~(atr_v_q & (atr_idx_q == `RNI_AW_ENTRIES_WIDTH'(i)))) begin
                atr_pick_v_r = 1'b1; atr_pick_idx_r = `RNI_AW_ENTRIES_WIDTH'(i);
            end
    end
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            atr_v_q   <= 1'b0;
            atr_idx_q <= '0;
        end
        else if (atr_v_q & awctrl_atr_ready_i) begin
            atr_v_q   <= 1'b0;
        end
        else if (~atr_v_q & atr_pick_v_r) begin
            atr_v_q   <= 1'b1;
            atr_idx_q <= atr_pick_idx_r;
        end
    end
    generate
        for (entry=0; entry < RNI_AW_ENTRIES_NUM_PARAM; entry=entry+1) begin:atom_r_sent
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i)                                   awctrl_atom_r_sent_q[entry] <= 1'b0;
                else if (awctrl_entry_dealloc_vec_w[entry])  awctrl_atom_r_sent_q[entry] <= 1'b0;
                else if (atr_v_q & awctrl_atr_ready_i & (atr_idx_q == `RNI_AW_ENTRIES_WIDTH'(entry)))
                                                             awctrl_atom_r_sent_q[entry] <= 1'b1;
            end
        end
    endgenerate
    assign awctrl_atr_valid_o   = atr_v_q;
    assign awctrl_atr_o.id      = awctrl_entry_info_q[atr_idx_q].id;
    assign awctrl_atr_o.data    = awctrl_atom_rdata_q[atr_idx_q];
    assign awctrl_atr_o.resp    = awctrl_atom_rresp_q[atr_idx_q];
    assign awctrl_atr_o.user    = '0;
    assign awctrl_atr_o.last    = 1'b1;
    assign awctrl_entry_dealloc_v_w = |awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
    assign awctrl_dealloc_entry_o[RNI_AW_ENTRIES_NUM_PARAM-1:0] = awctrl_entry_dealloc_vec_w[RNI_AW_ENTRIES_NUM_PARAM-1:0];
endmodule
