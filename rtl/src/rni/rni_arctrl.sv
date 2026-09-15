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

`include "axi4_defines.svh"
`include "rni_defines.svh"
`include "rni_param.svh"

module rni_arctrl
    `RNI_PARAM
    (
    input  wire                             clk_i,
    input  wire                             rst_i,

    input  opennoc_rni_pkg::ax_ch_s         AR_CH_S0,
    input  wire                             ARVALID0,
    output wire                             ARREADY0,

    output wire                             arctrl_txreqflitv_s4_o,
    output chie_pkg::req_flit_s             arctrl_txreqflit_s4_o,
    input  wire                             arctrl_txreqflit_sent_s4_i,

    input  wire                             rxdatflitv_d1_i,
    input  wire [11:0]                      rxdatflit_txnid_d1_i,
    input  wire [1:0]                       rxdatflit_dataid_d1_i,
    input  wire [3:0]                       rxdatflit_opcode_d1_i,

    input  wire                             rxrspflitv_d1_i,
    input  chie_pkg::rsp_flit_s             rxrspflit_d1_i,

    input  wire                             rp_fifo_acpt_d4_i,
    output wire                             arctrl_rb_valid_d4_o,
    output wire [`RNI_DMASK_CT_WIDTH-1:0]   arctrl_rb_ctmask_d4_o,
    output wire                             arctrl_rb_rlast_d4_o,
    output wire [`AXI4_ARID_WIDTH-1:0]      arctrl_rb_rid_d4_o,
    output wire [`RNI_AR_ENTRIES_WIDTH-1:0] arctrl_rb_idx_d4_o,
    output wire [`RNI_BC_WIDTH-1:0]         arctrl_rb_bc_d4_o,

    input  wire                             pcrdgnt_pkt_v_d2_i,
    input  opennoc_rni_pkg::pcrdgrant_pkt_s pcrdgnt_pkt_d2_i,
    output wire                             arctrl_pcrdgnt_h_present_d3_o,
    output wire                             arctrl_pcrdgnt_l_present_d3_o,
    input  wire                             ar_pcrdgnt_h_win_d3_i,
    output wire                             arctrl_entry_any_v_o,
    input  wire                             ar_pcrdgnt_l_win_d3_i,

    // rni_aw_ctl Interface -- Sec 2.9.4's (p.2-130) cross-kind Device ordering
    output wire                             arctrl_device_ordered_pending_o,
    input  wire                             awctrl_device_ordered_pending_i
    );

    wire                                 alloc_busy_s1_w;
    opennoc_rni_pkg::ax_ch_s             arlink_arbus_s1_w;
    wire                                 arlink_valid_s1_w;
    wire [`AXI4_ARADDR_WIDTH-1:0]        arlink_addr_s1_w;
    wire [`RNI_BCVEC_WIDTH-1:0]          arlink_bc_vec_s2_w;
    wire [`RNI_DMASK_WIDTH-1:0]          arlink_dmask_s2_w;
    wire [`AXI4_ARSIZE_WIDTH-1:0]        arlink_size_s2_w;
    wire                                 arlink_lock_s2_w;
    logic                                ar_excl_r;
    logic [`AXI4_ARCACHE_WIDTH-1:0]      ar_axcache_r;
    wire                                 ar_device_w;
    wire                                 ar_cacheable_w;
    logic [`AXI4_ARSIZE_WIDTH-1:0]       ar_size_r;
    logic [`AXI4_TAGOP_WIDTH-1:0]        ar_axtagop_r;
    wire                                 ar_lpid_alias_w;
    logic                                ar_lpid_alias_r;
    wire  [`AXI4_TAGOP_WIDTH-1:0]        ar_tagop_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_alloc_ptr_s1_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_rdy_s1_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_v_ns_w;
    wire                                 arctrl_new_entry_req_dep_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_is_req_dep_v_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_dep_v_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_req_dep_chain_young_ns_w;
    wire                                 arctrl_new_entry_rdata_dep_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_is_rdata_dep_v_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_rdata_dep_v_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_rdata_dep_chain_young_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_req_retry_ready_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_hi_retry_rdy_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_lo_retry_rdy_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_req_new_rdy_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_hi_new_rdy_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_lo_new_rdy_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_select_vec_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_hi_retry_dec_w;
    wire                                 arctrl_req_hi_retry_found_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_lo_retry_dec_w;
    wire                                 arctrl_req_lo_retry_found_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_hi_new_dec_w;
    wire                                 arctrl_req_hi_new_found_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_lo_new_dec_w;
    wire                                 arctrl_req_lo_new_found_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_req_ptr_ns_w;
    wire                                 arctrl_entry_req_select_success_flag_w;
    wire [CHIE_NID_WIDTH_PARAM-1:0]      ar_tx_send_nid_w;
    wire [chie_pkg::NID_WIDTH-1:0]       arctrl_entry_rxrsp_tgtid_w;
    wire [chie_pkg::NID_WIDTH-1:0]       arctrl_entry_rxrsp_srcid_w;
    wire [11:0]                          arctrl_entry_rxrsp_txnid_w;
    chie_pkg::rsp_opcode_e               arctrl_entry_rxrsp_opcode_w;
    wire [3:0]                           arctrl_entry_rxrsp_pcrdtype_w;
    wire                                 ar_rxrsp_correct_w;
    wire                                 rxrsp_retryack_recv_flag_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_retryack_recv_vec_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_retryack_recv_vec_ns_w;
    wire                                 rxrsp_ordrsp_recv_flag_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_ordrsp_recv_vec_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_ordered_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_ordered_pending_ns_w;
    wire                                 arctrl_ordered_pending_any_w;
    wire                                 rxrsp_pcrdgrant_recv_flag_w;
    wire                                 rxrsp_pcrdtype_hi_select_w;
    wire                                 rxrsp_pcrdtype_lo_select_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_hi_upd_ptr_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_lo_upd_ptr_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_recv_vec_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_hi_recv_vec_d2_w;
    wire                                 rxrsp_pcrdtype_hi_match_d2_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_pcrdgrant_lo_recv_vec_d2_w;
    wire                                 rxrsp_pcrdtype_lo_match_d2_w;
    wire [`RNI_DMASK_PD_WIDTH-1:0]       arctrl_rdat_pdmask_ns_w;
    wire                                 rxdat_recv_done_flag_w;
    wire                                 rdata_select_adv_w;
    wire [`RNI_DMASK_CT_WIDTH-1:0]       arctrl_rdat_ctmask_ns_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_rdata_select_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_entry_dealloc_vec_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_rdata_retire_w;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rdata_retired_q;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxrsp_respsep_recv_vec_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  rxdat_sepform_vec_w;
    wire [RNI_AR_ENTRIES_NUM_PARAM-1:0]  arctrl_respsep_owed_w;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_sepform_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_respsep_recv_q;
    wire                                 arctrl_entry_dealloc_v_w;

    logic                                arctrl_entry_full_r;
    logic [`AXI4_ARID_WIDTH-1:0]         arctrl_arid_s2_r;
    logic [`AXI4_ARADDR_WIDTH-1:0]       arctrl_araddr_s2_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_same_req_chain_vec_d2_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_req_dep_num_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_sameid_rdata_chain_vec_d2_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_rdata_dep_num_r;
    logic [11:0]                         ar_txreq_txnid_r;
    chie_pkg::req_flit_s                 ar_txreqflit_info_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rxrsp_ptr_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_rdy_vec_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_rdy_vec_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rxdat_ptr_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rdata_rdy_r;
    logic [`RNI_BCVEC_WIDTH-1:0]         arctrl_rdata_bc_r;
    logic                                arctrl_rdata_bc_break_r;
    logic [`RNI_AR_ENTRIES_WIDTH-1:0]    arctrl_rdata_entry_idx_r;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxdat_recv_done_vec_r;
    logic [`RNI_DMASK_CT_WIDTH-1:0]      arctrl_rdat_ctmask_r;
    logic [`RNI_DMASK_PD_WIDTH-1:0]      arctrl_rdat_pdmask_r;
    logic [`RNI_DMASK_LS_WIDTH-1:0]      arctrl_rdat_lsmask_r;
    logic [`AXI4_ARID_WIDTH-1:0]         arctrl_rdat_axid_r;
    logic [`RNI_BCVEC_WIDTH-1:0]         arctrl_rdat_bcvec_r;

    opennoc_rni_pkg::ax_ch_s             arctrl_entry_info_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [`AXI4_ARADDR_WIDTH-1:0]       arctrl_entry_addr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_qos_hi_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_v_q;
    logic                                arlink_valid_s2_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_alloc_ptr_s2_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_req_select_rdy_q;
    logic [`AXI4_ARSIZE_WIDTH-1:0]       arctrl_entry_size_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_excl_q;
    logic [`RNI_DMASK_LS_WIDTH-1:0]      arctrl_entry_lsmask_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [`RNI_BCVEC_WIDTH-1:0]         arctrl_entry_bcvec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_req_dep_v_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_req_dep_v_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_req_dep_num_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_req_dep_chain_young_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_rdata_dep_v_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_rdata_dep_v_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_is_rdata_dep_num_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rdata_dep_chain_young_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_req_ptr_q;
    logic                                arctrl_entry_req_select_success_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_entry_req_select_vec_q;
    logic                                arctrl_entry_req_select_retry_flag_q;
    logic                                ar_txreqflitv_s5_q;
    chie_pkg::req_flit_s                 ar_txreqflit_s5_q;
    logic                                ar_txreqflit_sent_s5_q;
    logic                                rxrsp_pcrdtype_hi_match_d3_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_recv_vec_d3_q;
    logic                                rxrsp_pcrdtype_lo_match_d3_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_recv_vec_d3_q;
    logic [3:0]                          rxrsp_retryack_pcrdtype_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_retryack_recv_vec_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_ordered_pending_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_hi_upd_ptr_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_lo_upd_ptr_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] rxrsp_pcrdgrant_recv_vec_q;
    logic                                rxdat_flitv_q;
    logic [11:0]                         rxdat_txnid_q;
    logic [3:0]                          rxdat_opcode_q;
    logic [1:0]                          rxdat_dataid_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rdata_start_ptr_q;
    logic [RNI_AR_ENTRIES_NUM_PARAM-1:0] arctrl_rdata_send_q;
    logic [`RNI_DMASK_RV_WIDTH-1:0]      arctrl_entry_rvmask_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [`RNI_DMASK_CT_WIDTH-1:0]      arctrl_entry_ctmask_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    logic [`RNI_DMASK_PD_WIDTH-1:0]      arctrl_entry_pdmask_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    genvar                               entry;
    /////////////////////////////////////////////////////////////
    // txreq s1
    /////////////////////////////////////////////////////////////
    rni_arlink rni_arlink_u0
               (
                   .clk_i                          (clk_i                  )
                   ,.rst_i                         (rst_i                  )
                   ,.ARVALID                       (ARVALID0               )
                   ,.AR_CH_S0                      (AR_CH_S0               )
                   ,.ARREADY                       (ARREADY0               )
                   ,.alloc_busy_s1_i               (alloc_busy_s1_w        )
                   ,.arlink_arbus_s1_o             (arlink_arbus_s1_w      )
                   ,.arlink_valid_s1_o             (arlink_valid_s1_w      )
                   ,.arlink_addr_s1_o              (arlink_addr_s1_w       )
                   ,.arlink_bc_vec_s2_o            (arlink_bc_vec_s2_w     )
                   ,.arlink_dmask_s2_o             (arlink_dmask_s2_w      )
                   ,.arlink_size_s2_o              (arlink_size_s2_w       )
                   ,.arlink_lock_s2_o              (arlink_lock_s2_w       )
               );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        arctrl_entry_alloc(
            .entry_vec(arctrl_entry_rdy_s1_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry({RNI_AR_ENTRIES_NUM_PARAM{1'b0}})
            ,.entry_ptr_sel(arctrl_alloc_ptr_s1_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found()
        );

    always_comb begin
        arctrl_entry_full_r = 1'b1;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            arctrl_entry_full_r = arctrl_entry_full_r & arctrl_entry_v_q[i];
    end

    assign alloc_busy_s1_w = arctrl_entry_full_r;
    assign arctrl_entry_rdy_s1_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = ~arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & {RNI_AR_ENTRIES_NUM_PARAM{arlink_valid_s1_w}};
    assign arctrl_entry_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_alloc_ptr_s1_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin: txn_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_info_q[entry] <= '0;
                end
                else begin
                    if(arctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        arctrl_entry_info_q[entry] <= arlink_arbus_s1_w;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_addr_q[entry][`AXI4_ARADDR_WIDTH-1:0] <= '0;
                end
                else begin
                    if(arctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        arctrl_entry_addr_q[entry][`AXI4_ARADDR_WIDTH-1:0] <= arlink_addr_s1_w[`AXI4_ARADDR_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_qos_hi_q[entry] <= 1'b0;
                end
                else begin
                    if(arctrl_alloc_ptr_s1_w[entry] == 1'b1)begin
                        arctrl_entry_qos_hi_q[entry] <= (arlink_arbus_s1_w.qos == 4'b1111);
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arlink_valid_s1_w | arctrl_entry_dealloc_v_w)begin
                arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arlink_valid_s2_q <= 1'b0;
        end
        else begin
            arlink_valid_s2_q <= arlink_valid_s1_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_alloc_ptr_s1_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end
    /////////////////////////////////////////////////////////////
    // txreq s2
    /////////////////////////////////////////////////////////////
    always_comb begin
        arctrl_arid_s2_r[`AXI4_ARID_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            arctrl_arid_s2_r[`AXI4_ARID_WIDTH-1:0] = arctrl_arid_s2_r[`AXI4_ARID_WIDTH-1:0] | ({`AXI4_ARID_WIDTH{arctrl_alloc_ptr_s2_q[i]}} & arctrl_entry_info_q[i].id);
    end

    always_comb begin
        arctrl_araddr_s2_r[`AXI4_ARADDR_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            arctrl_araddr_s2_r[`AXI4_ARADDR_WIDTH-1:0] = arctrl_araddr_s2_r[`AXI4_ARADDR_WIDTH-1:0] | ({`AXI4_ARADDR_WIDTH{arctrl_alloc_ptr_s2_q[i]}} & arctrl_entry_addr_q[i][`AXI4_ARADDR_WIDTH-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_select_rdy_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            arctrl_entry_req_select_rdy_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin: txn_size_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_size_q[entry][`AXI4_ARSIZE_WIDTH-1:0] <= '0;
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_size_q[entry][`AXI4_ARSIZE_WIDTH-1:0] <= arlink_size_s2_w[`AXI4_ARSIZE_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_excl_q[entry] <= 1'b0;
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_excl_q[entry] <= arlink_lock_s2_w;
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_lsmask_q[entry][`RNI_DMASK_LS_WIDTH-1:0] <={`RNI_DMASK_LS_WIDTH{1'b0}};
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_lsmask_q[entry][`RNI_DMASK_LS_WIDTH-1:0] <= arlink_dmask_s2_w[`RNI_DMASK_LS_RANGE];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_bcvec_q[entry][`RNI_BCVEC_WIDTH-1:0] <= {`RNI_BCVEC_WIDTH{1'b0}};
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_bcvec_q[entry][`RNI_BCVEC_WIDTH-1:0] <= arlink_bc_vec_s2_w[`RNI_BCVEC_WIDTH-1:0];
                    end
                end
            end
        end
    endgenerate

    //request chain
    assign arctrl_new_entry_req_dep_w = |arctrl_same_req_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_is_req_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_is_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_same_req_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~rxdat_recv_done_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_req_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{(arctrl_new_entry_req_dep_w)}} & arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])) & ~arctrl_entry_is_req_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_req_dep_chain_young_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = ((arctrl_req_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_same_req_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~rxdat_recv_done_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:axid_req_same
            always_comb begin
                if((arctrl_alloc_ptr_s2_q[entry] == 1'b0) && (arctrl_entry_v_q[entry] == 1'b1) && (rxdat_recv_done_vec_r[entry] == 1'b0))begin
                    arctrl_same_req_chain_vec_d2_r[entry] = arlink_valid_s2_q && (arctrl_arid_s2_r[`AXI4_ARID_WIDTH-1:0] == arctrl_entry_info_q[entry].id) &&
                                                  (arctrl_araddr_s2_r[`AXI4_ARADDR_WIDTH-1:`L3_CACHELINE_OFFSET] == arctrl_entry_addr_q[entry][`AXI4_ARADDR_WIDTH-1:`L3_CACHELINE_OFFSET]) && arctrl_req_dep_chain_young_q[entry];
                end
                else begin
                    arctrl_same_req_chain_vec_d2_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        arctrl_entry_is_req_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            arctrl_entry_is_req_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_entry_is_req_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{rxdat_recv_done_vec_r[i]}} & arctrl_entry_is_req_dep_num_q[i][RNI_AR_ENTRIES_NUM_PARAM-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_is_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arlink_valid_s2_q | rxdat_recv_done_flag_w)begin
                arctrl_entry_is_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_is_req_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((arlink_valid_s2_q && arctrl_new_entry_req_dep_w) | rxdat_recv_done_flag_w)begin
                arctrl_entry_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_req_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:req_dep_num
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_is_req_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
                end
                else begin
                    if(rxdat_recv_done_vec_r[entry])begin
                        arctrl_entry_is_req_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
                    end
                    else if((arlink_valid_s2_q && arctrl_same_req_chain_vec_d2_r[entry]))begin
                        arctrl_entry_is_req_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_req_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arlink_valid_s2_q | rxdat_recv_done_flag_w)begin
                arctrl_req_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_req_dep_chain_young_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    //rdata chain
    assign arctrl_new_entry_rdata_dep_w = |arctrl_sameid_rdata_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_is_rdata_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_is_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_sameid_rdata_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_rdata_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{(arctrl_new_entry_rdata_dep_w)}} & arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])) & ~arctrl_entry_is_rdata_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_rdata_dep_chain_young_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = ((arctrl_rdata_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_sameid_rdata_chain_vec_d2_r[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:axid_rdata_same
            always_comb begin
                if((arctrl_alloc_ptr_s2_q[entry] == 1'b0) && (arctrl_entry_v_q[entry] == 1'b1) && (arctrl_entry_dealloc_vec_w[entry] == 1'b0))begin
                    arctrl_sameid_rdata_chain_vec_d2_r[entry] = (arlink_valid_s2_q && arctrl_arid_s2_r[`AXI4_ARID_WIDTH-1:0] == arctrl_entry_info_q[entry].id) && arctrl_rdata_dep_chain_young_q[entry];
                end
                else begin
                    arctrl_sameid_rdata_chain_vec_d2_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        arctrl_entry_is_rdata_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            arctrl_entry_is_rdata_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_entry_is_rdata_dep_num_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{arctrl_entry_dealloc_vec_w[i]}} & arctrl_entry_is_rdata_dep_num_q[i][RNI_AR_ENTRIES_NUM_PARAM-1:0]);
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_is_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arlink_valid_s2_q | arctrl_entry_dealloc_v_w)begin
                arctrl_entry_is_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_is_rdata_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if((arlink_valid_s2_q & arctrl_new_entry_rdata_dep_w) | arctrl_entry_dealloc_v_w)begin
                arctrl_entry_rdata_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_rdata_dep_v_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:rdata_dep_num
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_is_rdata_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
                end
                else begin
                    if(arctrl_entry_dealloc_vec_w[entry])begin
                        arctrl_entry_is_rdata_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
                    end
                    else if((arlink_valid_s2_q && arctrl_sameid_rdata_chain_vec_d2_r[entry]))begin
                        arctrl_entry_is_rdata_dep_num_q[entry][RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_alloc_ptr_s2_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_rdata_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arlink_valid_s2_q | arctrl_entry_dealloc_v_w)begin
                arctrl_rdata_dep_chain_young_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_rdata_dep_chain_young_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // txreq select
    /////////////////////////////////////////////////////////////
    assign arctrl_req_retry_ready_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_req_select_rdy_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & rxrsp_pcrdgrant_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_req_select_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_req_hi_retry_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_req_retry_ready_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_qos_hi_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_req_lo_retry_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_req_retry_ready_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_qos_hi_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    // Sec 2.8 (p.2-119, MUST): "The Requester requires a ReadReceipt to determine
    // when it can send the next ordered request", and a Completer sending
    // separate responses "can send RespSepData response instead of ReadReceipt".
    // Gated per Requester rather than per stream: Sec 2.8's Note (p.2-122)
    // permits the narrower per-ARID form, which this does not attempt.
    assign arctrl_req_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_req_select_rdy_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_req_dep_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~rxrsp_retryack_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_req_select_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]
             & ~({RNI_AR_ENTRIES_NUM_PARAM{arctrl_ordered_pending_any_w}} & arctrl_entry_ordered_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
             & ~({RNI_AR_ENTRIES_NUM_PARAM{awctrl_device_ordered_pending_i}} & arctrl_entry_ordered_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]);
    assign arctrl_entry_req_hi_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_req_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_qos_hi_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_req_lo_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_req_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_qos_hi_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    //deassert select_vec when receiving retryack
    assign arctrl_entry_req_select_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_entry_req_select_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{arctrl_entry_req_select_success_flag_w}} & arctrl_entry_req_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])) & ~rxrsp_retryack_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        req_retry_hi(
            .entry_vec(arctrl_entry_req_hi_retry_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(arctrl_entry_req_hi_retry_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found(arctrl_req_hi_retry_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        req_retry_lo(
            .entry_vec(arctrl_entry_req_lo_retry_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(arctrl_entry_req_lo_retry_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found(arctrl_req_lo_retry_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        req_new_hi(
            .entry_vec(arctrl_entry_req_hi_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(arctrl_entry_req_hi_new_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found(arctrl_req_hi_new_found_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        req_new_lo(
            .entry_vec(arctrl_entry_req_lo_new_rdy_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(arctrl_entry_req_lo_new_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found(arctrl_req_lo_new_found_w)
        );

    assign arctrl_entry_req_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = arctrl_req_hi_retry_found_w ? arctrl_entry_req_hi_retry_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]:
           arctrl_req_hi_new_found_w ? arctrl_entry_req_hi_new_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]:
           arctrl_req_lo_retry_found_w ? arctrl_entry_req_lo_retry_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]:
           arctrl_entry_req_lo_new_dec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_req_select_success_flag_w = (arctrl_req_hi_retry_found_w | arctrl_req_hi_new_found_w | arctrl_req_lo_retry_found_w | arctrl_req_lo_new_found_w) & (arctrl_txreqflit_sent_s4_i | ~arctrl_txreqflitv_s4_o);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arctrl_entry_req_select_success_flag_w)begin
                arctrl_entry_req_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_req_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_select_success_q <= 1'b0;
        end
        else begin
            arctrl_entry_req_select_success_q <= arctrl_entry_req_select_success_flag_w;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_select_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(arctrl_entry_req_select_success_flag_w | rxrsp_retryack_recv_flag_w | arctrl_entry_dealloc_v_w)begin
                arctrl_entry_req_select_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_entry_req_select_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_entry_req_select_retry_flag_q <= 1'b0;
        end
        else begin
            if(arctrl_entry_req_select_success_flag_w)begin
                arctrl_entry_req_select_retry_flag_q <= arctrl_req_hi_retry_found_w | arctrl_req_lo_retry_found_w;
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // txreq send
    /////////////////////////////////////////////////////////////
    assign ar_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0] = HNF_NID_PARAM;

    always_comb begin
        ar_txreq_txnid_r[11:0] = '0;
        ar_txreq_txnid_r[12-1] = 1'b0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            ar_txreq_txnid_r[`RNI_AR_ENTRIES_WIDTH-1:0] = ar_txreq_txnid_r[`RNI_AR_ENTRIES_WIDTH-1:0] | ({`RNI_AR_ENTRIES_WIDTH{arctrl_entry_req_ptr_q[i]}} & i[`RNI_AR_ENTRIES_WIDTH-1:0]);
    end


    // AMBA AXI4 (IHI 0022) Table A4-5 names the memory type from AxCACHE:
    // ARCACHE[1] (Modifiable) low is Device, and with it high ARCACHE[3:2] split
    // Normal into Non-cacheable (both low) and cacheable. CHI E.b Table 2-11
    // (SS2.9.4 p.2-129) then gives each of those types exactly one legal
    // MemAttr/SnpAttr/Order row, and SS2.9.6's Table 2-13 (p.2-132) admits
    // ReadOnce only on the Snoopable one -- so opcode and attributes are derived
    // from the access rather than fixed (CHI-OpenNoC#21).
    always_comb begin: ar_axcache_sel_t
        ar_axcache_r[`AXI4_ARCACHE_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            ar_axcache_r[`AXI4_ARCACHE_WIDTH-1:0] = ar_axcache_r[`AXI4_ARCACHE_WIDTH-1:0] |
                ({`AXI4_ARCACHE_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_info_q[i].cache);
    end

    assign ar_device_w    = ~ar_axcache_r[1];
    assign ar_cacheable_w = ar_axcache_r[1] & (|ar_axcache_r[3:2]);

    // The selected entry's AxLOCK, already reduced by rni_segburst to the bursts
    // one Exclusive ReadNoSnp can carry.
    always_comb begin
        ar_excl_r = 1'b0;
        ar_size_r[`AXI4_ARSIZE_WIDTH-1:0] = {`AXI4_ARSIZE_WIDTH{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)begin
            ar_excl_r = ar_excl_r | (arctrl_entry_req_ptr_q[i] & arctrl_entry_excl_q[i]);
            ar_size_r[`AXI4_ARSIZE_WIDTH-1:0] = ar_size_r[`AXI4_ARSIZE_WIDTH-1:0] |
                ({`AXI4_ARSIZE_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_size_q[i][`AXI4_ARSIZE_WIDTH-1:0]);
        end
    end

    // Table 12-2 (Sec 12.12 p.12-388) gives ReadOnce {Invalid, Transfer} and
    // ReadNoSnp {Invalid, Transfer, Fetch}, and Table 13-32 (Sec 13.10.37 p.13-435)
    // encodes Transfer 0b01 and Fetch 0b11 -- Update is no read's row. An ARUSER
    // TagOp the elected opcode does not admit is presented as Invalid, which the
    // table permits everywhere.
    always_comb begin: ar_axtagop_sel_t
        ar_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] = '0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            ar_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] = ar_axtagop_r[`AXI4_TAGOP_WIDTH-1:0] |
                ({`AXI4_TAGOP_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_info_q[i].user[`AXI4_USER_TAGOP_RANGE]);
    end

    always_comb begin: ar_lpid_alias_sel_t
        ar_lpid_alias_r = 1'b0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)
            ar_lpid_alias_r = ar_lpid_alias_r |
                (arctrl_entry_req_ptr_q[i] & (|arctrl_entry_info_q[i].id[`AXI4_ARID_WIDTH-1:8]));
    end
    assign ar_lpid_alias_w = ar_lpid_alias_r;

    assign ar_tagop_w = (ar_axtagop_r == 2'b01)                    ? 2'b01 :
                        ((ar_axtagop_r == 2'b11) & ~ar_cacheable_w) ? 2'b11 : 2'b00;

    // The same Device decode, held per entry rather than for the one currently
    // selected: Table 2-11 (Sec 2.9.4 p.2-129) gives every Device row
    // Order=EndpointOrder, so this is "this entry's request is ordered".
    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:entry_ordered
            assign arctrl_entry_ordered_w[entry] = ~arctrl_entry_info_q[entry].cache[1];
        end
    endgenerate

    always_comb begin
        ar_txreqflit_info_r = '0;
        ar_txreqflit_info_r.tgtid = ar_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0];
        ar_txreqflit_info_r.srcid = RNI_NID_PARAM;
        ar_txreqflit_info_r.txnid = ar_txreq_txnid_r[11:0];
        ar_txreqflit_info_r.opcode = ar_cacheable_w ? chie_pkg::REQ_READONCE : chie_pkg::REQ_READNOSNP;
        ar_txreqflit_info_r.tagop = ar_tagop_w[`AXI4_TAGOP_WIDTH-1:0];
        ar_txreqflit_info_r.allowretry = ~arctrl_entry_req_select_retry_flag_q;
        // Table 2-11's Device rows carry Order=EndpointOrder; every Normal row
        // carries Order[0]=0, and this Requester elects no ordering of its own.
        ar_txreqflit_info_r.order = ar_device_w ? chie_pkg::ORDER_END_POINT : chie_pkg::ORDER_NONE;
        // Sec 2.9.2 (p.2-126, MUST): EWA "must be asserted in any Read ... that is
        // not a ReadNoSnp, ReadNoSnpSep, or CMO transaction", which is every
        // ReadOnce this bridge emits; Table 2-11 (p.2-129) gives every Cacheable
        // row EWA=1.
        ar_txreqflit_info_r.memattr.early_wr_ack = ar_cacheable_w | ar_axcache_r[0];
        ar_txreqflit_info_r.memattr.device = ar_device_w;
        ar_txreqflit_info_r.memattr.cacheable = ar_cacheable_w;
        ar_txreqflit_info_r.snpattr = ar_cacheable_w;
        // CHI E.b SS2.7 (p.2-113, MUST): "The LPID must be set to the correct value
        // for ... any Non-snoopable Non-cacheable or Device access: ReadNoSnp,
        // WriteNoSnp" and "for Exclusive accesses". AMBA AXI4 (IHI 0022) A7.2
        // makes the AXI exclusive monitor per-ID, so an AxID is the logical
        // processor SS2.7 names. Zero on the cacheable path, which SS2.7 does not
        // list.
        // SS13.10.27 (p.13-432, MUST) gives ReadNoSnp the Excl bit and ReadOnce
        // none, so a Cacheable exclusive access is bridged as a plain read; the
        // Normal OK it then earns is AXI4 A7.2.3's OKAY from a target that does
        // not support the exclusive access.
        // Sec 6.3.3 (p.6-291, MUST) binds the one-outstanding and the pairing rules
        // to the LP, which Sec 13.10.20 (p.13-427) makes eight bits -- narrower than
        // this port's AxID, so IDs differing only above bit 7 would present as one
        // LP and their sequences would interleave. Sec 6.3 (p.6-287) leaves it
        // IMPLEMENTATION DEFINED whether a target supports Exclusive accesses, and
        // AXI4 (IHI 0022) A7.2.3 makes OKAY the answer from one that does not -- so
        // an AxID that does not fit is declined rather than aliased.
        ar_txreqflit_info_r.excl.excl = ar_excl_r & ~ar_cacheable_w & ~ar_lpid_alias_w;
        // SS2.9.3 (p.2-127): a Device read "must not read more data than
        // requested", and SS2.10.2 (p.2-134) makes Size decide that window, so a
        // ReadNoSnp takes the segmenter's own per-request size. Table 4-2
        // (SS4.2.1 p.4-166) leaves it the only size-flexible read, so the
        // cacheable ReadOnce stays a whole line.
        ar_txreqflit_info_r.size = ar_cacheable_w ? chie_pkg::SIZE_64B
                                                  : chie_pkg::size_e'(ar_size_r[`AXI4_ARSIZE_WIDTH-1:0]);
        ar_txreqflit_info_r.expcompack = 1'b0;
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)begin
            ar_txreqflit_info_r.qos = ar_txreqflit_info_r.qos | ({`AXI4_ARQOS_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_info_q[i].qos);
            ar_txreqflit_info_r.lpid = ar_txreqflit_info_r.lpid |
                ({8{arctrl_entry_req_ptr_q[i] & ~ar_cacheable_w}} & arctrl_entry_info_q[i].id[7:0]);
            ar_txreqflit_info_r.addr = ar_txreqflit_info_r.addr | ({`AXI4_ARADDR_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_addr_q[i][`AXI4_ARADDR_WIDTH-1:0]);
            ar_txreqflit_info_r.pcrdtype = ~arctrl_entry_req_select_retry_flag_q ? '0 :
                               ar_txreqflit_info_r.pcrdtype | ({4{arctrl_entry_req_ptr_q[i]}} & rxrsp_retryack_pcrdtype_q[i][3:0]);
            // Table 2-11 gives no non-cacheable row an Allocate value.
            ar_txreqflit_info_r.memattr.allocate = ar_txreqflit_info_r.memattr.allocate | (ar_cacheable_w & arctrl_entry_req_ptr_q[i] & arctrl_entry_info_q[i].cache[2]);
`ifdef CHIE_MPAM_PRESENT
            // Sec 11.3 (p.11-365, MUST): the whole MPAM label is the sender's, so it
            // crosses verbatim from ARUSER -- see axi4_defines.svh for the layout.
            ar_txreqflit_info_r.mpam = chie_pkg::mpam_s'(ar_txreqflit_info_r.mpam |
                ({chie_pkg::MPAM_WIDTH{arctrl_entry_req_ptr_q[i]}} & arctrl_entry_info_q[i].user[`AXI4_USER_MPAM_RANGE]));
`endif
        end
    end

    assign arctrl_txreqflitv_s4_o = arctrl_entry_req_select_success_q | (~ar_txreqflit_sent_s5_q & ar_txreqflitv_s5_q);
    assign arctrl_txreqflit_s4_o = (~ar_txreqflit_sent_s5_q & ar_txreqflitv_s5_q) ? ar_txreqflit_s5_q : ar_txreqflit_info_r;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            ar_txreqflitv_s5_q <= 1'b0;
        end
        else begin
            ar_txreqflitv_s5_q <= arctrl_txreqflitv_s4_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            ar_txreqflit_s5_q <= '0;
        end
        else begin
            ar_txreqflit_s5_q<= arctrl_txreqflit_s4_o;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            ar_txreqflit_sent_s5_q <= 1'b0;
        end
        else begin
            ar_txreqflit_sent_s5_q<= arctrl_txreqflit_sent_s4_i;
        end
    end

    /////////////////////////////////////////////////////////////
    // rxrsp
    /////////////////////////////////////////////////////////////
    assign arctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] = rxrspflit_d1_i.tgtid;
    assign arctrl_entry_rxrsp_srcid_w[chie_pkg::NID_WIDTH-1:0] = rxrspflit_d1_i.srcid;
    assign arctrl_entry_rxrsp_txnid_w[11:0] = rxrspflit_d1_i.txnid;
    assign arctrl_entry_rxrsp_opcode_w[5-1:0] = rxrspflit_d1_i.opcode;
    assign arctrl_entry_rxrsp_pcrdtype_w[3:0] = rxrspflit_d1_i.pcrdtype;

    assign ar_rxrsp_correct_w = rxrspflitv_d1_i & ~arctrl_entry_rxrsp_txnid_w[12-1] & (arctrl_entry_rxrsp_tgtid_w[chie_pkg::NID_WIDTH-1:0] == RNI_NID_PARAM);
    assign rxrsp_retryack_recv_flag_w = ar_rxrsp_correct_w & (arctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_RETRYACK);
    assign rxrsp_retryack_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{rxrsp_retryack_recv_flag_w}} & arctrl_rxrsp_ptr_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    assign rxrsp_retryack_recv_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (rxrsp_retryack_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | rxrsp_retryack_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    // Sec 2.8 (p.2-119) makes ReadReceipt and RespSepData interchangeable as the
    // ordering response, so either discharges the gate. Pending is set when the
    // ordered request is actually sent and cleared only by that response or by
    // dealloc -- so a RetryAck'd ordered request keeps blocking the next one,
    // which is Figure 2-34 step 5 (p.2-121).
    assign rxrsp_ordrsp_recv_flag_w = ar_rxrsp_correct_w & ((arctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_READRECEIPT) | (arctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_RESPSEPDATA));

    // CHI E.b SS2.5.2 (p.2-87): a TxnID may be reused only once "all responses
    // associated with a previous transaction that have used the same value" have
    // arrived. SS2.3.1 Alternative 2's separate form owes two -- RespSepData on
    // RSP and DataSepResp on DAT -- so the data half alone does not free the ID.
    // Which form the Home elected is not known until the data arrives, hence a
    // per-entry record rather than a property of the request.
    assign rxrsp_respsep_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] =
        {RNI_AR_ENTRIES_NUM_PARAM{ar_rxrsp_correct_w &
            (arctrl_entry_rxrsp_opcode_w[5-1:0] == chie_pkg::RSP_RESPSEPDATA)}} &
        arctrl_rxrsp_ptr_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign rxdat_sepform_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] =
        {RNI_AR_ENTRIES_NUM_PARAM{rxdat_opcode_q[3:0] == chie_pkg::DAT_DATASEPRESP}} &
        arctrl_rxdat_ptr_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    // Owed once the data says the form was separate, until the RSP half lands.
    // Both halves are folded in combinationally as well, so an arrival in the
    // same cycle as a dealloc is judged on this cycle's state, not last cycle's.
    assign arctrl_respsep_owed_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] =
        (arctrl_sepform_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] |
         rxdat_sepform_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]) &
        ~(arctrl_respsep_recv_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] |
          rxrsp_respsep_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]);

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:respsep_track
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                    arctrl_sepform_q[entry]     <= 1'b0;
                    arctrl_respsep_recv_q[entry] <= 1'b0;
                end
                else if (arctrl_entry_dealloc_vec_w[entry]) begin
                    arctrl_sepform_q[entry]     <= 1'b0;
                    arctrl_respsep_recv_q[entry] <= 1'b0;
                end
                else begin
                    if (rxdat_sepform_vec_w[entry])       arctrl_sepform_q[entry]      <= 1'b1;
                    if (rxrsp_respsep_recv_vec_w[entry])  arctrl_respsep_recv_q[entry] <= 1'b1;
                end
            end
        end
    endgenerate
    assign rxrsp_ordrsp_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{rxrsp_ordrsp_recv_flag_w}} & arctrl_rxrsp_ptr_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_ordered_pending_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_ordered_pending_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] | ({RNI_AR_ENTRIES_NUM_PARAM{arctrl_entry_req_select_success_flag_w}} & arctrl_entry_req_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_ordered_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])) & ~rxrsp_ordrsp_recv_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] & ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_ordered_pending_any_w = |arctrl_ordered_pending_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    // Sec 2.9.4 (p.2-130, MUST): the Device nRnE and Device nRE required behaviour
    // is that "All Read and Write transactions from the same source to the same
    // endpoint must remain ordered" -- across the two kinds, not within each. The
    // per-channel gates below are Sec 2.8.5's, one transaction family apiece, so
    // this pair is what orders a read against a write. Device-qualified on both
    // sides: Table 2-11 (p.2-129) gives Device RE Order[0]=0 and p.2-130 drops the
    // endpoint clause for it, and a Normal write owes a read nothing at all.
    // The flopped term: the write channel's gate must not depend on this channel's
    // own gate, or the two close a combinational loop. See rni_awctrl's next-state
    // twin, which is the half that resolves a same-cycle selection.
    assign arctrl_device_ordered_pending_o = |(arctrl_ordered_pending_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] & arctrl_entry_ordered_w[RNI_AR_ENTRIES_NUM_PARAM-1:0]);

    assign rxrsp_pcrdgrant_recv_flag_w = pcrdgnt_pkt_v_d2_i;
    // SS2.11 (p.2-145, MUST): a credit may arrive before the RetryAck it belongs
    // to, so rni_misc must keep it while any request of this channel can still be
    // retried. An allocated entry is exactly that.
    assign arctrl_entry_any_v_o = |arctrl_entry_v_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    assign arctrl_pcrdgnt_h_present_d3_o = rxrsp_pcrdtype_hi_match_d3_q;
    assign arctrl_pcrdgnt_l_present_d3_o = rxrsp_pcrdtype_lo_match_d3_q;
    assign rxrsp_pcrdtype_hi_select_w = ar_pcrdgnt_h_win_d3_i & rxrsp_pcrdtype_hi_match_d3_q;
    assign rxrsp_pcrdtype_lo_select_w = ar_pcrdgnt_l_win_d3_i & rxrsp_pcrdtype_lo_match_d3_q;
    assign rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_hi_select_w}} & rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_lo_select_w}} & rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign rxrsp_pcrdgrant_recv_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (rxrsp_pcrdgrant_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] |
            (({RNI_AR_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_hi_select_w}} & rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]) |
             ({RNI_AR_ENTRIES_NUM_PARAM{rxrsp_pcrdtype_lo_select_w}} & rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]))) &
           ~arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:rxrsp_ptr
            always_comb begin
                if(entry == arctrl_entry_rxrsp_txnid_w[`RNI_AR_ENTRIES_WIDTH-1:0])begin
                    arctrl_rxrsp_ptr_r[entry] = 1'b1;
                end
                else begin
                    arctrl_rxrsp_ptr_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:pcrdtype_match
            always_comb begin
                if(rxrsp_pcrdgrant_recv_flag_w & rxrsp_retryack_recv_vec_q[entry] & ~(rxrsp_pcrdgrant_recv_vec_q[entry] | rxrsp_pcrdgrant_recv_vec_ns_w[entry]))begin
                    rxrsp_pcrdgrant_hi_rdy_vec_r[entry] = (pcrdgnt_pkt_d2_i.pcrdtype == rxrsp_retryack_pcrdtype_q[entry][3:0]) &&
                                                (pcrdgnt_pkt_d2_i.srcid == ar_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0]) &&
                                                (pcrdgnt_pkt_d2_i.tgtid == RNI_NID_PARAM) && arctrl_entry_qos_hi_q[entry];
                end
                else begin
                    rxrsp_pcrdgrant_hi_rdy_vec_r[entry] = 1'b0;
                end
            end

            always_comb begin
                if(rxrsp_pcrdgrant_recv_flag_w & rxrsp_retryack_recv_vec_q[entry] & ~(rxrsp_pcrdgrant_recv_vec_q[entry] | rxrsp_pcrdgrant_recv_vec_ns_w[entry]))begin
                    rxrsp_pcrdgrant_lo_rdy_vec_r[entry] = (pcrdgnt_pkt_d2_i.pcrdtype == rxrsp_retryack_pcrdtype_q[entry][3:0]) &&
                                                (pcrdgnt_pkt_d2_i.srcid == ar_tx_send_nid_w[CHIE_NID_WIDTH_PARAM-1:0]) &&
                                                (pcrdgnt_pkt_d2_i.tgtid == RNI_NID_PARAM) && ~arctrl_entry_qos_hi_q[entry];
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
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        pcrdtype_hi_select(
            .entry_vec(rxrsp_pcrdgrant_hi_rdy_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(rxrsp_pcrdtype_hi_select_w ? rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] : rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(rxrsp_pcrdgrant_hi_recv_vec_d2_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found(rxrsp_pcrdtype_hi_match_d2_w)
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        pcrdtype_lo_select(
            .entry_vec(rxrsp_pcrdgrant_lo_rdy_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(rxrsp_pcrdtype_lo_select_w ? rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] : rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(rxrsp_pcrdgrant_lo_recv_vec_d2_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
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
            rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            rxrsp_pcrdgrant_hi_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_hi_recv_vec_d2_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
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
            rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            rxrsp_pcrdgrant_lo_recv_vec_d3_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_lo_recv_vec_d2_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:rxrsp_info
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    rxrsp_retryack_pcrdtype_q[entry][3:0] <= '0;
                end
                else begin
                    if(rxrsp_retryack_recv_vec_w[entry])begin
                        rxrsp_retryack_pcrdtype_q[entry][3:0] <= arctrl_entry_rxrsp_pcrdtype_w[3:0];
                    end
                    else if(arctrl_entry_dealloc_vec_w[entry])begin
                        rxrsp_retryack_pcrdtype_q[entry][3:0] <= '0;
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_retryack_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_retryack_recv_flag_w | arctrl_entry_dealloc_v_w)begin
                rxrsp_retryack_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_retryack_recv_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_ordered_pending_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            arctrl_ordered_pending_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_ordered_pending_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_hi_select_w)begin
                rxrsp_pcrdgrant_hi_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_hi_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_lo_select_w)begin
                rxrsp_pcrdgrant_lo_upd_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_lo_upd_ptr_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxrsp_pcrdgrant_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else begin
            if(rxrsp_pcrdtype_hi_select_w | rxrsp_pcrdtype_lo_select_w | arctrl_entry_dealloc_v_w)begin
                rxrsp_pcrdgrant_recv_vec_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= rxrsp_pcrdgrant_recv_vec_ns_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
            end
        end
    end

    /////////////////////////////////////////////////////////////
    // rdata
    /////////////////////////////////////////////////////////////
    assign arctrl_rdat_pdmask_ns_w[`RNI_DMASK_PD_WIDTH-1:0] = arctrl_rdat_pdmask_r[`RNI_DMASK_PD_WIDTH-1:0] & (~arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0]);
    assign rxdat_recv_done_flag_w = |rxdat_recv_done_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign rdata_select_adv_w = rp_fifo_acpt_d4_i | (!arctrl_rb_valid_d4_o);
    assign arctrl_rb_valid_d4_o = |arctrl_rdata_send_q[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_rb_ctmask_d4_o[`RNI_DMASK_CT_WIDTH-1:0] = arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0];
    assign arctrl_rb_rlast_d4_o = |(arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0] & arctrl_rdat_lsmask_r[`RNI_DMASK_LS_WIDTH-1:0]);
    assign arctrl_rb_rid_d4_o[`AXI4_ARID_WIDTH-1:0] = arctrl_rdat_axid_r[`AXI4_ARID_WIDTH-1:0];
    assign arctrl_rb_idx_d4_o[`RNI_AR_ENTRIES_WIDTH-1:0] = arctrl_rdata_entry_idx_r[`RNI_AR_ENTRIES_WIDTH-1:0];
    assign arctrl_rb_bc_d4_o[`RNI_BC_WIDTH-1:0] = arctrl_rdata_bc_r[`RNI_BC_WIDTH-1:0];

    poll_with_start_entry
        #(
            .ENTRIES_NUM(`RNI_DMASK_CT_WIDTH)
        )
        arctrl_ctmask_ns(
            .entry_vec(arctrl_rdat_pdmask_r[`RNI_DMASK_PD_WIDTH-1:0] & (~arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0]))
            ,.start_entry({`RNI_DMASK_CT_WIDTH{1'b0}})
            ,.entry_ptr_sel(arctrl_rdat_ctmask_ns_w[`RNI_DMASK_CT_WIDTH-1:0])
            ,.found()
        );

    poll_with_start_entry
        #(
            .ENTRIES_NUM(RNI_AR_ENTRIES_NUM_PARAM)
        )
        arctrl_rdata_entry(
            .entry_vec(arctrl_rdata_rdy_r[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.start_entry(arctrl_rdata_start_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.entry_ptr_sel(arctrl_rdata_select_w[RNI_AR_ENTRIES_NUM_PARAM-1:0])
            ,.found()
        );

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:rxdat_ptr
            always_comb begin
                if((entry == rxdat_txnid_q[`RNI_AR_ENTRIES_WIDTH-1:0]) && rxdat_flitv_q)begin
                    arctrl_rxdat_ptr_r[entry] = 1'b1;
                end
                else begin
                    arctrl_rxdat_ptr_r[entry] = 1'b0;
                end
            end

            always_comb begin
                if(|(arctrl_entry_rvmask_q[entry] & ((arctrl_rdat_ctmask_ns_w[`RNI_DMASK_CT_WIDTH-1:0] & {`RNI_DMASK_CT_WIDTH{rp_fifo_acpt_d4_i & arctrl_rdata_send_q[entry]}}) |
                                                     (arctrl_entry_ctmask_q[entry] & {`RNI_DMASK_CT_WIDTH{~rp_fifo_acpt_d4_i}}))) && (~arctrl_entry_rdata_dep_v_q[entry]))begin
                    arctrl_rdata_rdy_r[entry] = 1'b1;
                end
                else begin
                    arctrl_rdata_rdy_r[entry] = 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin
        arctrl_rdata_bc_r[`RNI_BCVEC_WIDTH-1:0] = arctrl_rdat_bcvec_r[`RNI_BCVEC_WIDTH-1:0];
        arctrl_rdata_bc_break_r = 1'b0;
        for (int i =0; i < `RNI_DMASK_CT_WIDTH; i=i+1)begin
            if((!arctrl_rdat_ctmask_r[i]) && (!arctrl_rdata_bc_break_r))begin
                arctrl_rdata_bc_r[`RNI_BCVEC_WIDTH-1:0] = arctrl_rdata_bc_r[`RNI_BCVEC_WIDTH-1:0] >> `RNI_BC_WIDTH;
                arctrl_rdata_bc_break_r = 1'b0;
            end
            else begin
                arctrl_rdata_bc_r[`RNI_BCVEC_WIDTH-1:0] =  arctrl_rdata_bc_r[`RNI_BCVEC_WIDTH-1:0];
                arctrl_rdata_bc_break_r = 1'b1;
            end
        end
    end

    always_comb begin
        arctrl_rdata_entry_idx_r[`RNI_AR_ENTRIES_WIDTH-1:0] = {`RNI_AR_ENTRIES_WIDTH{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)begin
            if(arctrl_rdata_send_q[i])begin
                arctrl_rdata_entry_idx_r[`RNI_AR_ENTRIES_WIDTH-1:0] = i[`RNI_AR_ENTRIES_WIDTH-1:0];
            end
        end
    end

    always_comb begin
        rxdat_recv_done_vec_r[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)begin
            if(arctrl_rxdat_ptr_r[i])begin
                rxdat_recv_done_vec_r[i] = (((arctrl_entry_rvmask_q[i][`RNI_DMASK_RV_WIDTH-1:0] | {{2{rxdat_dataid_q[1]}},{2{~rxdat_dataid_q[1]}}}) &
                                             arctrl_entry_pdmask_q[i][`RNI_DMASK_PD_WIDTH-1:0]) == arctrl_entry_pdmask_q[i][`RNI_DMASK_PD_WIDTH-1:0]);
            end
        end
    end

    always_comb begin
        arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0] = {`RNI_DMASK_CT_WIDTH{1'b0}};
        arctrl_rdat_pdmask_r[`RNI_DMASK_PD_WIDTH-1:0] = {`RNI_DMASK_PD_WIDTH{1'b0}};
        arctrl_rdat_lsmask_r[`RNI_DMASK_LS_WIDTH-1:0] = {`RNI_DMASK_LS_WIDTH{1'b0}};
        arctrl_rdat_axid_r[`AXI4_ARID_WIDTH-1:0] = '0;
        arctrl_rdat_bcvec_r[`RNI_BCVEC_WIDTH-1:0] = {`RNI_BCVEC_WIDTH{1'b0}};
        for (int i =0; i < RNI_AR_ENTRIES_NUM_PARAM; i=i+1)begin
            arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0] = arctrl_rdat_ctmask_r[`RNI_DMASK_CT_WIDTH-1:0] | ({`RNI_DMASK_CT_WIDTH{arctrl_rdata_send_q[i]}} & arctrl_entry_ctmask_q[i][`RNI_DMASK_CT_WIDTH-1:0]);
            arctrl_rdat_pdmask_r[`RNI_DMASK_PD_WIDTH-1:0] = arctrl_rdat_pdmask_r[`RNI_DMASK_PD_WIDTH-1:0] | ({`RNI_DMASK_PD_WIDTH{arctrl_rdata_send_q[i]}} & arctrl_entry_pdmask_q[i][`RNI_DMASK_PD_WIDTH-1:0]);
            arctrl_rdat_lsmask_r[`RNI_DMASK_LS_WIDTH-1:0] = arctrl_rdat_lsmask_r[`RNI_DMASK_LS_WIDTH-1:0] | ({`RNI_DMASK_LS_WIDTH{arctrl_rdata_send_q[i]}} & arctrl_entry_lsmask_q[i][`RNI_DMASK_LS_WIDTH-1:0]);
            arctrl_rdat_axid_r[`AXI4_ARID_WIDTH-1:0] = arctrl_rdat_axid_r[`AXI4_ARID_WIDTH-1:0] | ({`AXI4_ARID_WIDTH{arctrl_rdata_send_q[i]}} & arctrl_entry_info_q[i].id);
            arctrl_rdat_bcvec_r[`RNI_BCVEC_WIDTH-1:0] = arctrl_rdat_bcvec_r[`RNI_BCVEC_WIDTH-1:0] | ({`RNI_BCVEC_WIDTH{arctrl_rdata_send_q[i]}} & arctrl_entry_bcvec_q[i][`RNI_BCVEC_WIDTH-1:0]);
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxdat_flitv_q <= 1'b0;
        end
        else begin
            rxdat_flitv_q <= rxdatflitv_d1_i;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxdat_txnid_q[11:0] <= '0;
        end
        else begin
            rxdat_txnid_q[11:0] <= rxdatflit_txnid_d1_i[11:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxdat_opcode_q[3:0] <= '0;
        end
        else begin
            rxdat_opcode_q[3:0] <= rxdatflit_opcode_d1_i[3:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            rxdat_dataid_q[1:0] <= '0;
        end
        else begin
            rxdat_dataid_q[1:0] <= rxdatflit_dataid_d1_i[1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_rdata_start_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else if(rdata_select_adv_w)begin
            arctrl_rdata_start_ptr_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_rdata_select_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1)begin
            arctrl_rdata_send_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= {RNI_AR_ENTRIES_NUM_PARAM{1'b0}};
        end
        else if(rdata_select_adv_w)begin
            arctrl_rdata_send_q[RNI_AR_ENTRIES_NUM_PARAM-1:0] <= arctrl_rdata_select_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
        end
    end

    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:arctrl_mask
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_rvmask_q[entry][`RNI_DMASK_RV_WIDTH-1:0] <={`RNI_DMASK_RV_WIDTH{1'b0}};
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_rvmask_q[entry][`RNI_DMASK_RV_WIDTH-1:0] <= arlink_dmask_s2_w[`RNI_DMASK_RV_RANGE];
                    end
                    else if(arctrl_rxdat_ptr_r[entry])begin
                        arctrl_entry_rvmask_q[entry][`RNI_DMASK_RV_WIDTH-1:0] <= arctrl_entry_rvmask_q[entry][`RNI_DMASK_RV_WIDTH-1:0] | {{2{rxdat_dataid_q[1]}},{2{~rxdat_dataid_q[1]}}};
                    end

                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_ctmask_q[entry][`RNI_DMASK_CT_WIDTH-1:0] <={`RNI_DMASK_CT_WIDTH{1'b0}};
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_ctmask_q[entry][`RNI_DMASK_CT_WIDTH-1:0] <= arlink_dmask_s2_w[`RNI_DMASK_CT_WIDTH-1:0];
                    end
                    else if(arctrl_rdata_send_q[entry] && rp_fifo_acpt_d4_i)begin
                        arctrl_entry_ctmask_q[entry][`RNI_DMASK_CT_WIDTH-1:0] <= arctrl_rdat_ctmask_ns_w[`RNI_DMASK_CT_WIDTH-1:0];
                    end
                end
            end

            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i == 1'b1)begin
                    arctrl_entry_pdmask_q[entry][`RNI_DMASK_PD_WIDTH-1:0] <={`RNI_DMASK_PD_WIDTH{1'b0}};
                end
                else begin
                    if(arctrl_alloc_ptr_s2_q[entry] == 1'b1)begin
                        arctrl_entry_pdmask_q[entry][`RNI_DMASK_PD_WIDTH-1:0] <= arlink_dmask_s2_w[`RNI_DMASK_PD_RANGE];
                    end
                    else if(arctrl_rdata_send_q[entry] && rp_fifo_acpt_d4_i)begin
                        arctrl_entry_pdmask_q[entry][`RNI_DMASK_PD_WIDTH-1:0] <= arctrl_rdat_pdmask_ns_w[`RNI_DMASK_PD_WIDTH-1:0];
                    end
                end
            end
        end
    endgenerate

    /////////////////////////////////////////////////////////////
    // dealloc
    /////////////////////////////////////////////////////////////
    assign arctrl_rdata_retire_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = {RNI_AR_ENTRIES_NUM_PARAM{rp_fifo_acpt_d4_i && !(|arctrl_rdat_pdmask_ns_w[`RNI_DMASK_PD_WIDTH-1:0])}} & arctrl_rdata_send_q;

    // The retire is a single cycle and the entry is not re-selected for read data
    // once its mask is empty, so it is held rather than dropped while SS2.5.2's
    // remaining response is owed.
    generate
        for (entry=0; entry < RNI_AR_ENTRIES_NUM_PARAM; entry=entry+1) begin:rdata_retired
            always_ff @(posedge clk_i or posedge rst_i) begin
                if (rst_i) begin
                    arctrl_rdata_retired_q[entry] <= 1'b0;
                end
                else if (arctrl_entry_dealloc_vec_w[entry]) begin
                    arctrl_rdata_retired_q[entry] <= 1'b0;
                end
                else if (arctrl_rdata_retire_w[entry]) begin
                    arctrl_rdata_retired_q[entry] <= 1'b1;
                end
            end
        end
    endgenerate

    assign arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] = (arctrl_rdata_retire_w[RNI_AR_ENTRIES_NUM_PARAM-1:0] | arctrl_rdata_retired_q[RNI_AR_ENTRIES_NUM_PARAM-1:0]) & ~arctrl_respsep_owed_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
    assign arctrl_entry_dealloc_v_w = |arctrl_entry_dealloc_vec_w[RNI_AR_ENTRIES_NUM_PARAM-1:0];
endmodule
