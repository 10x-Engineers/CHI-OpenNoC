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

`include "axi4_defines.svh"
`include "snf_defines.svh"
`include "snf_param.svh"

module snf_qos `SNF_PARAM
    (
        input  wire                               clk,
        input  wire                               rst,

    //inputs from RXREQ
        input  wire                               rxreq_valid_s0,
        input  chie_pkg::req_flit_s               rxreqflit_s0,

    //inputs from TXRSP
        input  wire                               txrsp_retryack_won_s1,
        input  wire                               txrsp_pcrdgnt_won_s2,

    //inputs from snf_mshr
        input  wire                               mshr_retired_valid_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_retired_idx_sx,

    //outputs to TXRSP
        output wire                               qos_txrsp_retryack_valid_s1,
        output chie_pkg::retry_ackq_s             qos_txrsp_retryack_fifo_s1,

        output wire                               qos_txrsp_pcrdgnt_valid_s2,
        output chie_pkg::pcrdgrantq_s             qos_txrsp_pcrdgnt_fifo_s2,

    //outputs to RXREQ
        output wire                               rxreq_retry_enable_s0,

    //outputs to mshr
        output wire                               rxreq_alloc_en_s0,
        output chie_pkg::req_flit_s               rxreq_alloc_flit_s0,
        output wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s0,

    //outputs to the link handshake
        output wire                               qos_active_sx
    );
    //internal wire signals
    logic [11:0]                     rxreq_txnid_s0;
    logic [3:0]                      rxreq_qos_s0;
    logic                            rxreq_allowretry_s0;
    logic [chie_pkg::NID_WIDTH-1:0]  rxreq_srcid_s0;
    logic                            rxreq_tracetag_s0;
    logic [3:0]                      rxreq_pcrdtype_s0;
    wire                             qpc_high_s0;
    wire                             qpc_low_s0;
    wire                             req_qos_can_alloc_s0;
    wire                             req_dyn_s0;
    wire                             req_static_s0;
    wire                             qos_h_can_alloc_s0;
    wire                             qos_l_can_alloc_s0;
    wire                             req_dyn_alloc_s0;
    wire                             req_static_alloc_s0;
    wire                             req_dyn_alloc_fail_s0;
    wire                             mshr_dyn_avail_s0;
    wire                             mshr_static_avail_s0;
    wire                             use_static_pool_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_dyn_entry_idx_avail_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_static_entry_idx_avail_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_alloc_entry_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_alloc_set_v_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_entry_valid_flop_en_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_static_set_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_alloc_entry_s1;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0] mshr_static_en_s0;
    wire                             pool_free_sx;
    wire                             grant_window_sx;
    wire                             pool_free_grant_sx;
    wire                             qos_high_pool_avail_s0;
    wire                             qos_low_pool_avail_s0;
    wire                             qos_pool_high_full_s0;
    wire                             qos_pool_low_full_s0;
    wire                             high_cnt_update_s0;
    wire                             low_cnt_update_s0;
    localparam [31:0]                    HIGH_POOL_NUM      = `SNF_QOS_HIGH_POOL_NUM;
    localparam [31:0]                    LOW_POOL_NUM       = `SNF_QOS_LOW_POOL_NUM;
    localparam [`SNF_QOS_CNT_WIDTH-1:0]  QOS_HIGH_POOL_FULL = HIGH_POOL_NUM[`SNF_QOS_CNT_WIDTH-1:0];
    localparam [`SNF_QOS_CNT_WIDTH-1:0]  QOS_LOW_POOL_FULL  = LOW_POOL_NUM[`SNF_QOS_CNT_WIDTH-1:0];
    localparam [`SNF_RET_BANK_CNT_WIDTH-1:0] RET_CNT_ONE    = {{(`SNF_RET_BANK_CNT_WIDTH-1){1'b0}}, 1'b1};

    wire [`SNF_QOS_CNT_WIDTH-1:0]           qos_pool_high_cnt_ns;
    wire [`SNF_QOS_CNT_WIDTH-1:0]           qos_pool_low_cnt_ns;
    wire                                    qos_pool_high_cnt_inc_s0;
    wire                                    qos_pool_high_cnt_dec_s0;
    wire                                    qos_pool_low_cnt_inc_s0;
    wire                                    qos_pool_low_cnt_dec_s0;
    wire                                    qos_low_pool_alloc_s0;
    wire                                    qos_high_pool_alloc_s0;
    wire [`SNF_QOS_CLASS_WIDTH-1:0]         qos_pool_retire_class_sx;
    wire                                    h_retire_can_convert_static_sx;
    wire                                    l_retire_can_convert_static_sx;
    wire [`SNF_QOS_CLASS_WIDTH-1:0]         qos_class_pool_s0;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]        qos_class_pool_flop_en_s0;
    wire                                    mark_mshr_static_sx;
    chie_pkg::retry_ackq_s                  retry_ackq_datain_s0;
    chie_pkg::pcrdgrantq_s                  pcrdgrant_fifo_datain_s1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_bank_srcid_match_vec_s0;
    wire                                    ret_bank_alloc_en_s0;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_bank_entry_v_s0;
    wire                                    ret_is_h_s0;
    wire                                    ret_is_l_s0;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_inc_ptr_s0;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_inc_s0;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_inc_s0;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_dec_s1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_dec_s1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_en_s1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_en_s1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_zero;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_one;
    wire                                    retry_h_num_one;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_zero;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_one;
    wire                                    retry_l_num_one;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    h_retry_req_entry;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    l_retry_req_entry;
    wire                                    high_present;
    wire                                    low_present;
    wire                                    l_present_win;
    wire                                    h_present_win_sx;
    wire                                    l_present_win_sx;
    wire                                    l_wait_lost;
    wire                                    l_wait_cnt_inc;
    wire                                    l_wait_cnt_rst;
    wire                                    l_to_h_disbale;
    wire                                    l_wait_upd_en;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_h_dec_ptr_sx1;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    ret_cnt_l_dec_ptr_sx1;
    wire                                    pcrdgnt_req_enable_s1;
    logic [chie_pkg::NID_WIDTH-1:0]         pcrdgnt_srcid_s1;
    logic [3:0]                             pcrdgnt_qos_s1;
    logic [3:0]                             retry_ackq_pcrdtype_s0;
    chie_pkg::retry_ackq_s                  retry_ack_fifo_dataout_s1;
    wire                                    retry_ack_fifo_empty;
    wire                                    retry_ack_fifo_full;
    wire                                    retry_ack_fifo_push;
    wire                                    retry_ack_fifo_pop;
    chie_pkg::pcrdgrantq_s                  pcrdgrant_fifo_dataout_s2;
    wire                                    pcrdgrant_fifo_empty;
    wire                                    pcrdgrant_fifo_full;
    wire                                    pcrdgrant_fifo_push;
    wire                                    pcrdgrant_fifo_pop;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    h_retry_entry;
    wire [`SNF_RET_BANK_ENTRIES_NUM-1:0]    l_retry_entry;

    //internal reg signals
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_static_entry_valid_s1_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]     mshr_dyn_idx_alloc_s0;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]     mshr_static_idx_alloc_s0;
    logic                                   rxreq_alloc_en_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_alloc_entry_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_entry_valid_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_retire_entry_s0;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_dyn_entry_idx_ptr_s0;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_dyn_entry_idx_vector;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_static_entry_idx_ptr_s0;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]       mshr_static_entry_idx_vector;
    logic                                   qos_high_pool_full_s1_q;
    logic                                   qos_low_pool_full_s1_q;
    logic [`SNF_QOS_CNT_WIDTH-1:0]          qos_pool_high_cnt_q;
    logic [`SNF_QOS_CNT_WIDTH-1:0]          qos_pool_low_cnt_q;
    logic [`SNF_QOS_CLASS_WIDTH-1:0]        qos_class_pool_s1_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [3:0]                             pcrdgnt_pcrdtype_s1;
    logic [chie_pkg::NID_WIDTH-1:0]         ret_bank_srcid_s1_q[0:SNF_MSHR_HNF_NUM_PARAM-1];
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   ret_bank_entry_v_s1_q;
    logic [`SNF_RET_BANK_ENTRIES_WIDTH-1:0] ret_bank_entry_idx_s1_q;
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   ret_bank_entry_ptr_s0;
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   ret_cnt_h_inc_s1_q;
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   ret_cnt_l_inc_s1_q;
    logic [`SNF_RET_BANK_CNT_WIDTH-1:0]     ret_cnt_h_entry_s2_q[0:SNF_MSHR_HNF_NUM_PARAM-1];
    logic [`SNF_RET_BANK_CNT_WIDTH-1:0]     ret_cnt_l_entry_s2_q[0:SNF_MSHR_HNF_NUM_PARAM-1];
    logic [`SNF_RET_BANK_CNT_WIDTH-1:0]     ret_cnt_h_entry_ns_s1[0:SNF_MSHR_HNF_NUM_PARAM-1];
    logic [`SNF_RET_BANK_CNT_WIDTH-1:0]     ret_cnt_l_entry_ns_s1[0:SNF_MSHR_HNF_NUM_PARAM-1];
    logic                                   h_present_win_sx1_q;
    logic                                   l_present_win_sx1_q;
    logic [`SNF_MAX_WAIT_CNT_WIDTH-1:0]     l_wait_cnt_q;
    logic [`SNF_MAX_WAIT_CNT_WIDTH-1:0]     l_wait_cnt_ns;
    logic [chie_pkg::NID_WIDTH-1:0]         h_pcrdgrant_srcid_sx1;
    logic [chie_pkg::NID_WIDTH-1:0]         l_pcrdgrant_srcid_sx1;
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   h_retry_req_entry_q;
    logic [`SNF_RET_BANK_ENTRIES_NUM-1:0]   l_retry_req_entry_q;

    //Rxreq decode
    assign rxreq_txnid_s0       = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.txnid      : '0;
    assign rxreq_qos_s0         = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.qos        : '0;
    assign rxreq_allowretry_s0  = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.allowretry : 1'b0;
    assign rxreq_srcid_s0       = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.srcid      : '0;
    assign rxreq_tracetag_s0    = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.tracetag   : 1'b0;
    assign rxreq_pcrdtype_s0    = (rxreq_valid_s0 == 1'b1) ? rxreqflit_s0.pcrdtype   : '0;

    //QoS Priority Class:high
    assign qpc_high_s0 = (rxreq_qos_s0 >= `SNF_QOS_HIGH_MIN)?1'b1:1'b0;

    //QoS Priority Class:low
    assign qpc_low_s0 = (rxreq_qos_s0 <= `SNF_QOS_LOW_MAX)?1'b1:1'b0;

    //Dynamic/static
    assign req_dyn_s0            = rxreq_valid_s0 & rxreq_allowretry_s0;
    assign req_static_s0         = rxreq_valid_s0 & ~rxreq_allowretry_s0;

    //high can allocate if high and low pool is available
    assign qos_h_can_alloc_s0 = qos_high_pool_avail_s0 | qos_low_pool_avail_s0;

    //low can allocate if low pool is available
    assign qos_l_can_alloc_s0 = qos_low_pool_avail_s0;

    assign req_qos_can_alloc_s0 = (qpc_high_s0 & qos_h_can_alloc_s0 ) | (qpc_low_s0 & qos_l_can_alloc_s0 ) ;

    //an allocation is only legal onto an entry the corresponding pool actually offers
    assign mshr_dyn_avail_s0    = |mshr_dyn_entry_idx_avail_s0;
    assign mshr_static_avail_s0 = |mshr_static_entry_idx_avail_s0;

    //qos allocate logic
    assign req_dyn_alloc_s0      = req_dyn_s0 &  req_qos_can_alloc_s0 &  mshr_dyn_avail_s0;
    assign req_dyn_alloc_fail_s0 = req_dyn_s0 & (~req_qos_can_alloc_s0 | ~mshr_dyn_avail_s0);

    // Sec 2.11 (p.2-145): "except for PrefetchTgt, the AllowRetry field must be
    // asserted the first time a transaction is sent", so an AllowRetry=0 request is
    // either a retried one -- which holds a reserved static entry -- or a PrefetchTgt,
    // which holds none and must fall back to a free dynamic entry.
    assign use_static_pool_s0    = req_static_s0 & mshr_static_avail_s0;
    assign req_static_alloc_s0   = req_static_s0 & (mshr_static_avail_s0 | mshr_dyn_avail_s0);

    //qos allocate enable
    assign rxreq_alloc_en_s0         = req_dyn_alloc_s0 | req_static_alloc_s0;

    // Sec 2.11 (p.2-145, MUST): "When required resources become available, at a
    // later point in time, the Completer must then send a P-Credit to the
    // Requester, using a PCrdGrant response." A retirement is the moment a
    // resource is RELEASED, not the only moment one is AVAILABLE: once the tracker
    // drains, entries stay free and no further retirement occurs, so a retry
    // banked at or after the last one would never be granted -- and Sec 2.11
    // (p.2-146) makes the Requester's wait unconditional, so that is a permanent
    // stall, not a slow path. Held off a cycle in which an entry is retiring or
    // allocating, so the two grant paths never reserve at once and the free-entry
    // pointer is stable.
    assign pool_free_sx    = mshr_dyn_avail_s0 & ~rxreq_alloc_en_s0 & ~mshr_retired_valid_sx;
    assign grant_window_sx = mshr_retired_valid_sx | pool_free_sx;

    assign rxreq_alloc_flit_s0       = (rxreq_alloc_en_s0 == 1'b1) ? rxreqflit_s0 : '0;

    always_ff @(posedge clk or posedge rst) begin: update_mshr_alloc_en_timing_logic
        if (rst == 1'b1)
            rxreq_alloc_en_s1_q <= 1'b0;
        else
            rxreq_alloc_en_s1_q <= rxreq_alloc_en_s0;
    end

    //encode the dynamic allocation pointer
    assign mshr_dyn_entry_idx_avail_s0 = ~mshr_static_entry_valid_s1_q & ~mshr_entry_valid_s1_q;

    //find 1 from available dynamic allocations
    always_comb begin: mshr_dyn_entry_idx_ptr_comb_logic
        mshr_dyn_entry_idx_vector = {`SNF_MSHR_ENTRIES_NUM{1'b0}};
        mshr_dyn_entry_idx_ptr_s0 = {`SNF_MSHR_ENTRIES_NUM{1'b0}};

        for (int i=1; i<`SNF_MSHR_ENTRIES_NUM; i=i+1)begin
            mshr_dyn_entry_idx_vector[i] = mshr_dyn_entry_idx_vector[i-1] | mshr_dyn_entry_idx_avail_s0[i-1];
        end

        for(int i=0; i<`SNF_MSHR_ENTRIES_NUM; i=i+1)begin
            mshr_dyn_entry_idx_ptr_s0[i] = ~mshr_dyn_entry_idx_vector[i] & mshr_dyn_entry_idx_avail_s0[i];
        end
    end

    //encode the dynamic allocation index
    always_comb begin: enc_dyn_ptr_alloc_idx_comb_logic
        mshr_dyn_idx_alloc_s0 = {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};

        for(int i=0; i<`SNF_MSHR_ENTRIES_NUM; i = i+1)begin
            if (mshr_dyn_entry_idx_ptr_s0[i])
                mshr_dyn_idx_alloc_s0 = i[`SNF_MSHR_ENTRIES_WIDTH-1:0];
            else
                mshr_dyn_idx_alloc_s0 = mshr_dyn_idx_alloc_s0;
        end
    end

    //encode the static allocation pointer
    assign mshr_static_entry_idx_avail_s0 = mshr_static_entry_valid_s1_q & ~mshr_entry_valid_s1_q;

    //find 1 from available static allocations
    always_comb begin: mshr_static_entry_idx_ptr_comb_logic
        mshr_static_entry_idx_vector = {`SNF_MSHR_ENTRIES_NUM{1'b0}};
        mshr_static_entry_idx_ptr_s0 = {`SNF_MSHR_ENTRIES_NUM{1'b0}};

        for (int i=1; i<`SNF_MSHR_ENTRIES_NUM; i=i+1)begin
            mshr_static_entry_idx_vector[i] = mshr_static_entry_idx_vector[i-1] | mshr_static_entry_idx_avail_s0[i-1];
        end

        for(int i=0; i<`SNF_MSHR_ENTRIES_NUM; i=i+1)begin
            mshr_static_entry_idx_ptr_s0[i] = ~mshr_static_entry_idx_vector[i] & mshr_static_entry_idx_avail_s0[i];
        end
    end

    //encode the static allocation index
    always_comb begin: enc_static_ptr_alloc_idx_comb_logic
        mshr_static_idx_alloc_s0 = {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        for(int i=0; i<`SNF_MSHR_ENTRIES_NUM; i = i+1)begin
            if (mshr_static_entry_idx_ptr_s0[i])
                mshr_static_idx_alloc_s0 = i[`SNF_MSHR_ENTRIES_WIDTH-1:0];
            else
                mshr_static_idx_alloc_s0 = mshr_static_idx_alloc_s0;
        end
    end

    //qos allocate index logic
    assign mshr_entry_idx_alloc_s0 = use_static_pool_s0? mshr_static_idx_alloc_s0 : mshr_dyn_idx_alloc_s0;

    //qos alloccate location
    assign mshr_alloc_entry_s0 = use_static_pool_s0? mshr_static_entry_idx_ptr_s0 : mshr_dyn_entry_idx_ptr_s0;

    always_ff @(posedge clk or posedge rst) begin: mshr_entry_location_timing_logic
        if (rst == 1'b1)
            mshr_alloc_entry_s1_q <= {`SNF_MSHR_ENTRIES_NUM{1'b0}};
        else if (rxreq_alloc_en_s0 == 1'b1)
            mshr_alloc_entry_s1_q <= mshr_alloc_entry_s0;
    end

    //qos enqueue entry location valid.
    //  qos entry valid is set on alloc and cleared on retire.
    assign mshr_alloc_set_v_s0 = {`SNF_MSHR_ENTRIES_NUM{rxreq_alloc_en_s0}} & mshr_alloc_entry_s0;

    always_comb begin: retired_entry_idx_location_comb_logic
        mshr_retire_entry_s0 = {`SNF_MSHR_ENTRIES_NUM{1'b0}};
        if(mshr_retired_valid_sx == 1'b1)
            mshr_retire_entry_s0[mshr_retired_idx_sx] = 1'b1;
        else
            mshr_retire_entry_s0 = {`SNF_MSHR_ENTRIES_NUM{1'b0}};
    end

    assign mshr_entry_valid_flop_en_s0 = mshr_alloc_set_v_s0 | mshr_retire_entry_s0;

    genvar entry;
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1)begin
            always_ff @(posedge clk or posedge rst) begin: update_mshr_entry_valid_timing_logic
                if (rst == 1'b1)
                    mshr_entry_valid_s1_q[entry] <= 1'b0;
                else if (mshr_entry_valid_flop_en_s0[entry] == 1'b1)
                    mshr_entry_valid_s1_q[entry] <= mshr_alloc_set_v_s0[entry];
                else
                    ;
            end
        end
    endgenerate

    //mshr static entry valid logic
    assign h_retire_can_convert_static_sx  = (qos_pool_retire_class_sx == `SNF_QOS_CLASS_HIGH) &
           high_present;

    assign l_retire_can_convert_static_sx  = (qos_pool_retire_class_sx == `SNF_QOS_CLASS_LOW) &
           (high_present | low_present);

    assign mark_mshr_static_sx = mshr_retired_valid_sx &
           (h_retire_can_convert_static_sx | l_retire_can_convert_static_sx);

    assign mshr_alloc_entry_s1  = {`SNF_MSHR_ENTRIES_NUM{rxreq_alloc_en_s1_q}} & mshr_alloc_entry_s1_q;

    // A grant off the free-entry path reserves one of those free entries, so the
    // AllowRetry=0 reissue Sec 2.11 (p.2-145) guarantees acceptance for still finds
    // a static entry -- the same reservation the retirement path makes of the entry
    // it frees. Taken off the win decision itself, so the two cannot diverge.
    assign pool_free_grant_sx   = pool_free_sx & (h_present_win_sx | l_present_win_sx);

    assign mshr_static_set_s0   = ({`SNF_MSHR_ENTRIES_NUM{mark_mshr_static_sx}} & mshr_retire_entry_s0)
                                | ({`SNF_MSHR_ENTRIES_NUM{pool_free_grant_sx}}  & mshr_dyn_entry_idx_ptr_s0);

    //static entry is set on mshr retired.
    //  static entry is cleared on mshr allocate (previously retried).
    assign mshr_static_en_s0 = mshr_static_set_s0 | mshr_alloc_entry_s1;

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1)begin
            always_ff @(posedge clk or posedge rst) begin: update_mshr_static_entry_valid_timing_logic
                if (rst == 1'b1)
                    mshr_static_entry_valid_s1_q[entry] <= 1'b0;
                else if (mshr_static_en_s0[entry] == 1'b1)
                    mshr_static_entry_valid_s1_q[entry] <= mshr_static_set_s0[entry];
            end
        end
    endgenerate

    //mshr qos class pool decode logic
    assign qos_class_pool_s0 = ({`SNF_QOS_CLASS_WIDTH{qos_low_pool_alloc_s0}} & `SNF_QOS_CLASS_LOW  ) |
           ({`SNF_QOS_CLASS_WIDTH{qos_high_pool_alloc_s0}} & `SNF_QOS_CLASS_HIGH );

    assign qos_class_pool_flop_en_s0 = {`SNF_MSHR_ENTRIES_NUM{req_dyn_alloc_s0}} & mshr_alloc_entry_s0;

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1)begin
            always_ff @(posedge clk or posedge rst) begin: update_mshr_pool_timing_logic
                if (rst == 1'b1)
                qos_class_pool_s1_q[entry] <= {`SNF_QOS_CLASS_WIDTH{1'b0}};
                else if (qos_class_pool_flop_en_s0[entry] == 1'b1)
                    qos_class_pool_s1_q[entry] <= qos_class_pool_s0;
                else
                    ;
            end
        end
    endgenerate

    assign qos_pool_retire_class_sx = qos_class_pool_s1_q[mshr_retired_idx_sx];

    //high pool count logic
    assign qos_high_pool_alloc_s0 = qos_high_pool_avail_s0 & qpc_high_s0;

    assign qos_pool_high_cnt_inc_s0 = req_dyn_alloc_s0 & qos_high_pool_alloc_s0;//static req don't need to update qos_pool_x_cnt
    assign qos_pool_high_cnt_dec_s0 = mshr_retired_valid_sx &
           ~(high_present) &
           (qos_pool_retire_class_sx == `SNF_QOS_CLASS_HIGH);

    assign high_cnt_update_s0 = (qos_pool_high_cnt_inc_s0 | qos_pool_high_cnt_dec_s0) &
           ~(qos_pool_high_cnt_inc_s0 & qos_pool_high_cnt_dec_s0);

    assign qos_pool_high_cnt_ns = qos_pool_high_cnt_inc_s0? (qos_pool_high_cnt_q + 1'b1):
           (qos_pool_high_cnt_q - 1'b1);

    assign qos_pool_high_full_s0 = (qos_pool_high_cnt_ns == QOS_HIGH_POOL_FULL);

    always_ff @(posedge clk or posedge rst) begin: update_high_pool_count_timing_logic
        if (rst == 1'b1)
            qos_pool_high_cnt_q <= {`SNF_QOS_CNT_WIDTH{1'b0}};
        else if (high_cnt_update_s0 == 1'b1)
            qos_pool_high_cnt_q <= qos_pool_high_cnt_ns;
        else
            qos_pool_high_cnt_q <= qos_pool_high_cnt_q;
    end

    always_ff @(posedge clk or posedge rst) begin: update_high_pool_full_timing_logic
        if (rst == 1'b1)
            qos_high_pool_full_s1_q <= 1'b0;
        else if (high_cnt_update_s0 == 1'b1)
            qos_high_pool_full_s1_q <= qos_pool_high_full_s0;
        else
            qos_high_pool_full_s1_q <= qos_high_pool_full_s1_q;
    end

    assign qos_high_pool_avail_s0 = ~qos_high_pool_full_s1_q;

    //low pool count logic
    assign qos_low_pool_alloc_s0 = qos_low_pool_avail_s0 &
           (qpc_high_s0 | qpc_low_s0) &
           ~(qos_high_pool_alloc_s0);

    assign qos_pool_low_cnt_inc_s0 = req_dyn_alloc_s0 & qos_low_pool_alloc_s0;
    assign qos_pool_low_cnt_dec_s0 = mshr_retired_valid_sx &
           ~(high_present | low_present) &
           (qos_pool_retire_class_sx == `SNF_QOS_CLASS_LOW);

    assign low_cnt_update_s0 = (qos_pool_low_cnt_inc_s0 | qos_pool_low_cnt_dec_s0) &
           ~(qos_pool_low_cnt_inc_s0 & qos_pool_low_cnt_dec_s0);

    assign qos_pool_low_cnt_ns = qos_pool_low_cnt_inc_s0? (qos_pool_low_cnt_q + 1'b1):
           (qos_pool_low_cnt_q - 1'b1);

    assign qos_pool_low_full_s0 = (qos_pool_low_cnt_ns == QOS_LOW_POOL_FULL);

    always_ff @(posedge clk or posedge rst) begin: update_low_pool_count_timing_logic
        if (rst == 1'b1)
            qos_pool_low_cnt_q <= {`SNF_QOS_CNT_WIDTH{1'b0}};
        else if (low_cnt_update_s0 == 1'b1)
            qos_pool_low_cnt_q <= qos_pool_low_cnt_ns;
        else
            qos_pool_low_cnt_q <= qos_pool_low_cnt_q;
    end

    always_ff @(posedge clk or posedge rst) begin: update_low_pool_full_timing_logic
        if (rst == 1'b1)
            qos_low_pool_full_s1_q <= 1'b0;
        else if (low_cnt_update_s0 == 1'b1)
            qos_low_pool_full_s1_q <= qos_pool_low_full_s0;
        else
            qos_low_pool_full_s1_q <= qos_low_pool_full_s1_q;
    end

    assign qos_low_pool_avail_s0 = ~qos_low_pool_full_s1_q;

    //rxreq retry enable logic
    assign rxreq_retry_enable_s0 = req_dyn_alloc_fail_s0;

    // Sec 14.7.2 (p.14-463, MUST): a Subordinate asserts TXSACTIVE "while it is
    // processing a transaction that is in progress", and Sec 14.7.1 (p.14-460)
    // counts a RetryAck'd one as in progress "until the associated credit has been
    // supplied and used or returned" -- the retry bank and the reserved static
    // entries are that credit's lifetime.
    assign qos_active_sx = (|mshr_entry_valid_s1_q)
                         | (|mshr_static_entry_valid_s1_q)
                         | (|ret_bank_entry_v_s1_q)
                         | (~retry_ack_fifo_empty)
                         | (~pcrdgrant_fifo_empty);

    //retry pcrdtype field encode logic

    assign retry_ackq_pcrdtype_s0 = { 2'b0, qpc_high_s0, qpc_low_s0};

    //retry_ack_fifo flit assamble
    assign retry_ackq_datain_s0.srcid    = rxreq_srcid_s0;
    assign retry_ackq_datain_s0.txnid    = rxreq_txnid_s0;
    assign retry_ackq_datain_s0.qos      = rxreq_qos_s0;
    assign retry_ackq_datain_s0.trace    = rxreq_tracetag_s0;
    assign retry_ackq_datain_s0.pcrdtype = retry_ackq_pcrdtype_s0;

    assign retry_ack_fifo_push = rxreq_retry_enable_s0 & (~retry_ack_fifo_full | (retry_ack_fifo_full & txrsp_retryack_won_s1));
    assign retry_ack_fifo_pop  = txrsp_retryack_won_s1 & ~retry_ack_fifo_empty;

    sync_fifo #(
                       .FIFO_ENTRIES_WIDTH ($bits(chie_pkg::retry_ackq_s)    ),
                       .FIFO_ENTRIES_DEPTH (`SNF_RETRY_ACKQ_DATA_DEPTH    ),
                       .FIFO_BYP_ENABLE(1'b0)
                   )retry_ack_fifo_nobyp(
                       .clk        (clk                       ),
                       .rst        (rst                       ),
                       .push       (retry_ack_fifo_push       ),
                       .data_in    (retry_ackq_datain_s0      ),
                       .pop        (retry_ack_fifo_pop        ),
                       .data_out   (retry_ack_fifo_dataout_s1 ),
                       .empty      (retry_ack_fifo_empty      ),
                       .full       (retry_ack_fifo_full       ),
                       .count      (                          )
                   );

    //retry_ack_fifo
    assign qos_txrsp_retryack_valid_s1    = ~retry_ack_fifo_empty;
    assign qos_txrsp_retryack_fifo_s1     = retry_ack_fifo_dataout_s1;

    //retry bank logic
    //retry bank srcid match logic
    genvar ret_entry;
    generate
        for(ret_entry=0; ret_entry<`SNF_RET_BANK_ENTRIES_NUM;ret_entry=ret_entry+1)begin
            assign ret_bank_srcid_match_vec_s0[ret_entry] = (rxreq_srcid_s0 == ret_bank_srcid_s1_q[ret_entry]) & ret_bank_entry_v_s1_q[ret_entry];
        end
    endgenerate

    //qualify retry bank allocation
    assign ret_bank_alloc_en_s0  = req_dyn_alloc_fail_s0 & ~(|ret_bank_srcid_match_vec_s0);//rxreq_valid_s0

    //update next retry bank entry index
    always_ff @(posedge clk or posedge rst) begin: update_next_ret_bank_idx_timing_logic
        if (rst == 1'b1)
            ret_bank_entry_idx_s1_q <= {`SNF_RET_BANK_ENTRIES_WIDTH{1'b0}};
        else if (ret_bank_alloc_en_s0 == 1'b1)
            ret_bank_entry_idx_s1_q <= ret_bank_entry_idx_s1_q + 1'b1;
        else
            ret_bank_entry_idx_s1_q <= ret_bank_entry_idx_s1_q;
    end

    always_comb begin:pass_ret_bank_alloc_idx_to_ptr
        ret_bank_entry_ptr_s0 = {`SNF_RET_BANK_ENTRIES_NUM{1'b0}};
        for (int i=0; i<`SNF_RET_BANK_ENTRIES_NUM; i=i+1)
            ret_bank_entry_ptr_s0[i] = (ret_bank_entry_idx_s1_q == i[`SNF_RET_BANK_ENTRIES_WIDTH-1:0]);
    end

    //update retry bank entry valid
    assign ret_bank_entry_v_s0 = {`SNF_RET_BANK_ENTRIES_NUM{ret_bank_alloc_en_s0}} & ret_bank_entry_ptr_s0;

    generate
        for(ret_entry=0; ret_entry<`SNF_RET_BANK_ENTRIES_NUM;ret_entry=ret_entry+1)begin
            always_ff @(posedge clk or posedge rst) begin: update_ret_bank_entry_valid_timing_logic
                if (rst == 1'b1)
                    ret_bank_entry_v_s1_q[ret_entry] <= 1'b0;
                else if (ret_bank_entry_v_s0[ret_entry] == 1'b1)
                    ret_bank_entry_v_s1_q[ret_entry] <= ret_bank_entry_v_s0[ret_entry];
            end
        end
    endgenerate

    //update retry bank srcid entry
    generate
        for(ret_entry=0;ret_entry< `SNF_RET_BANK_ENTRIES_NUM;ret_entry=ret_entry+1) begin: update_retry_bank_srcid_pool_timing_logic
            always_ff @(posedge clk)begin
                if (ret_bank_entry_v_s0[ret_entry] == 1'b1)
                    ret_bank_srcid_s1_q[ret_entry] <= rxreq_srcid_s0;
                else
                    ;
            end
        end
    endgenerate

    //update retry bank count pointer
    assign ret_cnt_inc_ptr_s0 = ret_bank_alloc_en_s0? ret_bank_entry_ptr_s0 : ret_bank_srcid_match_vec_s0;

    //retry bank qos class cnt logic
    assign ret_is_h_s0 = rxreq_retry_enable_s0 & qpc_high_s0;

    assign ret_is_l_s0 = rxreq_retry_enable_s0 & qpc_low_s0;

    generate
        for(ret_entry=0;ret_entry<`SNF_RET_BANK_ENTRIES_NUM;ret_entry=ret_entry+1)begin
            //retry bank high count
            assign ret_cnt_h_inc_s0[ret_entry] = ret_is_h_s0 & ret_cnt_inc_ptr_s0[ret_entry];
            assign ret_cnt_h_dec_s1[ret_entry] = (h_present_win_sx1_q & pcrdgrant_fifo_push & ~ret_cnt_h_zero[ret_entry] & ret_cnt_h_dec_ptr_sx1[ret_entry]);
            assign ret_cnt_h_en_s1[ret_entry] = ret_cnt_h_inc_s0[ret_entry] | ret_cnt_h_dec_s1[ret_entry];

            always_comb begin: determine_h_entry_cnt_update_comb_logic
                unique case({ret_cnt_h_inc_s0[ret_entry], ret_cnt_h_dec_s1[ret_entry]})
                    2'b10:
                        ret_cnt_h_entry_ns_s1[ret_entry] = ret_cnt_h_entry_s2_q[ret_entry]+1'b1;
                    2'b01:
                        ret_cnt_h_entry_ns_s1[ret_entry] = ret_cnt_h_entry_s2_q[ret_entry]-1'b1;
                    2'b11:
                        ret_cnt_h_entry_ns_s1[ret_entry] = ret_cnt_h_entry_s2_q[ret_entry];
                    default:
                        ret_cnt_h_entry_ns_s1[ret_entry] = ret_cnt_h_entry_s2_q[ret_entry];
                endcase
            end

            always_ff @(posedge clk or posedge rst) begin: update_h_entry_cnt_timing_logic
                if (rst == 1'b1)
                    ret_cnt_h_entry_s2_q[ret_entry]<= {`SNF_RET_BANK_CNT_WIDTH{1'b0}};
                else if (ret_cnt_h_en_s1[ret_entry] == 1'b1)
                    ret_cnt_h_entry_s2_q[ret_entry] <= ret_cnt_h_entry_ns_s1[ret_entry];
            end

            assign ret_cnt_h_zero[ret_entry]  = ret_cnt_h_entry_s2_q[ret_entry] == {`SNF_RET_BANK_CNT_WIDTH{1'b0}};

            assign ret_cnt_h_one[ret_entry]  = (ret_cnt_h_entry_s2_q[ret_entry] == RET_CNT_ONE) & (~(ret_cnt_h_inc_s0[ret_entry] == 1'b1));
            assign retry_h_num_one = |ret_cnt_h_one;

            //retry bank low count
            assign ret_cnt_l_inc_s0[ret_entry] = ret_is_l_s0 & ret_cnt_inc_ptr_s0[ret_entry];
            assign ret_cnt_l_dec_s1[ret_entry] = (l_present_win_sx1_q & pcrdgrant_fifo_push & ~ret_cnt_l_zero[ret_entry] & ret_cnt_l_dec_ptr_sx1[ret_entry]);
            assign ret_cnt_l_en_s1[ret_entry] = ret_cnt_l_inc_s0[ret_entry] | ret_cnt_l_dec_s1[ret_entry];

            always_comb begin: determine_l_entry_cnt_update_comb_logic
                unique case({ret_cnt_l_inc_s0[ret_entry], ret_cnt_l_dec_s1[ret_entry]})
                    2'b10:
                        ret_cnt_l_entry_ns_s1[ret_entry] = ret_cnt_l_entry_s2_q[ret_entry]+1'b1;
                    2'b01:
                        ret_cnt_l_entry_ns_s1[ret_entry] = ret_cnt_l_entry_s2_q[ret_entry]-1'b1;
                    2'b11:
                        ret_cnt_l_entry_ns_s1[ret_entry] = ret_cnt_l_entry_s2_q[ret_entry];
                    default:
                        ret_cnt_l_entry_ns_s1[ret_entry] = ret_cnt_l_entry_s2_q[ret_entry];
                endcase
            end

            always_ff @(posedge clk or posedge rst) begin: update_l_entry_cnt_timing_logic
                if (rst == 1'b1)
                    ret_cnt_l_entry_s2_q[ret_entry]<= {`SNF_RET_BANK_CNT_WIDTH{1'b0}};
                else if (ret_cnt_l_en_s1[ret_entry] == 1'b1)
                    ret_cnt_l_entry_s2_q[ret_entry] <= ret_cnt_l_entry_ns_s1[ret_entry];
            end

            assign ret_cnt_l_zero[ret_entry]  = ret_cnt_l_entry_s2_q[ret_entry] == {`SNF_RET_BANK_CNT_WIDTH{1'b0}};

            assign ret_cnt_l_one[ret_entry]  = (ret_cnt_l_entry_s2_q[ret_entry] == RET_CNT_ONE) & (~(ret_cnt_l_inc_s0[ret_entry] == 1'b1));
            assign retry_l_num_one = |ret_cnt_l_one;

        end
    endgenerate

    assign h_retry_req_entry = (ret_bank_entry_v_s1_q & ~ret_cnt_h_zero) | ret_cnt_h_inc_s0;

    assign l_retry_req_entry = (ret_bank_entry_v_s1_q & ~ret_cnt_l_zero) | ret_cnt_l_inc_s0;

    assign high_present = retry_h_num_one ? (|(h_retry_req_entry & ~ret_cnt_h_dec_s1)) : (|h_retry_req_entry);

    assign low_present = retry_l_num_one ? (|(l_retry_req_entry & ~ret_cnt_l_dec_s1)) : (|l_retry_req_entry);

    //pcrdgrant and starvation logic
    //disable logic
    assign l_to_h_disbale  = (l_wait_cnt_q  >= `SNF_LOW2HIGH_MAX_CNT);

    //high present win logic
    //  High takes the resource outright only when a HIGH-class entry retired into
    //  it; on a LOW-class retirement, and on the free-entry path where the
    //  resource belongs to no class, the starvation guard still applies -- without
    //  it a non-empty high bank would win every idle cycle and low would never be
    //  granted at all.
    assign h_present_win_sx = high_present & grant_window_sx
           & ((mshr_retired_valid_sx & (qos_pool_retire_class_sx == `SNF_QOS_CLASS_HIGH)) ? 1'b1
                                                                                         : (~l_to_h_disbale));

    always_ff @(posedge clk or posedge rst) begin: update_h_present_win_timing_logic
        if (rst == 1'b1)
            h_present_win_sx1_q <= 1'b0;
        else
            h_present_win_sx1_q <= h_present_win_sx;
    end

    //low present win logic
    assign l_present_win = low_present & grant_window_sx
           & (pool_free_sx | (qos_pool_retire_class_sx == `SNF_QOS_CLASS_LOW));
    assign l_present_win_sx = ~h_present_win_sx & l_present_win;

    always_ff @(posedge clk or posedge rst) begin: update_l_present_win_timing_logic
        if (rst == 1'b1)
            l_present_win_sx1_q <= 1'b0;
        else
            l_present_win_sx1_q <= l_present_win_sx;
    end

    //ltoh count logic
    assign l_wait_lost = l_present_win & ~l_present_win_sx;
    assign l_wait_cnt_inc = l_wait_lost & ~(l_wait_cnt_q == `SNF_LOW2HIGH_MAX_CNT);
    assign l_wait_cnt_rst = l_present_win_sx;

    always_comb begin: determine_low_wait_cnt_update_comb_logic
        unique casez({l_wait_cnt_rst, l_wait_cnt_inc})
            2'b00:
                l_wait_cnt_ns = l_wait_cnt_q;
            2'b01:
                l_wait_cnt_ns = l_wait_cnt_q + 1'b1;
            2'b1?:
                l_wait_cnt_ns = {`SNF_MAX_WAIT_CNT_WIDTH{1'b0}};
            default:
                l_wait_cnt_ns = {`SNF_MAX_WAIT_CNT_WIDTH{1'b0}};
        endcase
    end

    assign l_wait_upd_en = l_wait_cnt_inc | l_wait_cnt_rst;

    always_ff @(posedge clk or posedge rst) begin: update_low_to_hhigh_timing_logic
        if (rst == 1'b1)
            l_wait_cnt_q <= {`SNF_MAX_WAIT_CNT_WIDTH{1'b0}};
        else if (l_wait_upd_en == 1'b1)
            l_wait_cnt_q <= l_wait_cnt_ns;
        else
            l_wait_cnt_q <= l_wait_cnt_q;
    end

    //pcrdgrant enable logic
    assign pcrdgnt_req_enable_s1 = h_present_win_sx1_q | l_present_win_sx1_q;

    //h pcrdgrant srcid logic
    always_ff @(posedge clk or posedge rst)begin: h_retry_entry_delay
        if (rst)begin
            h_retry_req_entry_q <= {`SNF_RET_BANK_ENTRIES_NUM{1'b0}};
        end
        else begin
            h_retry_req_entry_q <= h_retry_req_entry;
        end
    end

    assign h_retry_entry = h_retry_req_entry_q;

    //h pcrdgrant srcid logic
    poll_function #(.POLL_ENTRIES_NUM(SNF_MSHR_HNF_NUM_PARAM))
                    h_snf_find_entry(
                        .clk               (clk                 ),
                        .rst               (rst                 ),
                        .entry_vec         (h_retry_entry   ),
                        .upd               (h_present_win_sx    ),
                        .found             (),
                        .sel_entry         (ret_cnt_h_dec_ptr_sx1),
                        .sel_index         ()
                    );

    always_comb begin: high_pcrdgrant_srcid_comb_logic
        h_pcrdgrant_srcid_sx1 = {chie_pkg::NID_WIDTH{1'b0}};
        for (int i=0; i<`SNF_RET_BANK_ENTRIES_NUM; i=i+1)
            h_pcrdgrant_srcid_sx1 = h_pcrdgrant_srcid_sx1 | ({chie_pkg::NID_WIDTH{ret_cnt_h_dec_ptr_sx1[i]}} & ret_bank_srcid_s1_q[i]);
    end

    //l pcrdgrant srcid logic
    always_ff @(posedge clk or posedge rst)begin: l_retry_entry_delay
        if (rst)begin
            l_retry_req_entry_q <= {`SNF_RET_BANK_ENTRIES_NUM{1'b0}};
        end
        else begin
            l_retry_req_entry_q <= l_retry_req_entry;
        end
    end

    assign l_retry_entry = l_retry_req_entry_q;

    //l pcrdgrant srcid logic
    poll_function #(.POLL_ENTRIES_NUM(SNF_MSHR_HNF_NUM_PARAM))
                    l_snf_find_entry(
                        .clk               (clk                 ),
                        .rst               (rst                 ),
                        .entry_vec         (l_retry_entry       ),
                        .upd               (l_present_win_sx    ),
                        .found             (),
                        .sel_entry         (ret_cnt_l_dec_ptr_sx1),
                        .sel_index         ()
                    );

    always_comb begin: low_pcrdgrant_srcid_comb_logic
        l_pcrdgrant_srcid_sx1 = {chie_pkg::NID_WIDTH{1'b0}};
        for (int i=0; i<`SNF_RET_BANK_ENTRIES_NUM; i=i+1)
            l_pcrdgrant_srcid_sx1 = l_pcrdgrant_srcid_sx1 | ({chie_pkg::NID_WIDTH{ret_cnt_l_dec_ptr_sx1[i]}} & ret_bank_srcid_s1_q[i]);
    end

    //arbitrate pcrdgrant srcid
    assign pcrdgnt_srcid_s1 = ({chie_pkg::NID_WIDTH{h_present_win_sx1_q}}  & h_pcrdgrant_srcid_sx1)  |
           ({chie_pkg::NID_WIDTH{l_present_win_sx1_q}}  & l_pcrdgrant_srcid_sx1)  ;

    //arbitrate pcrdgrant qos
    assign pcrdgnt_qos_s1 = ({4{h_present_win_sx1_q}}  & 4'hf) |
           ({4{l_present_win_sx1_q}}  & 4'h0) ;

    //generate pcrdgrant pcrdtype
    always_comb begin
        pcrdgnt_pcrdtype_s1    = {4{1'b0}};
        pcrdgnt_pcrdtype_s1[0] = l_present_win_sx1_q;
        pcrdgnt_pcrdtype_s1[1] = h_present_win_sx1_q;
    end

    //encode pcrdgrant part fields to fifo
    assign pcrdgrant_fifo_datain_s1.srcid    = pcrdgnt_srcid_s1;
    assign pcrdgrant_fifo_datain_s1.qos      = pcrdgnt_qos_s1;
    assign pcrdgrant_fifo_datain_s1.pcrdtype = pcrdgnt_pcrdtype_s1;

    assign pcrdgrant_fifo_push = pcrdgnt_req_enable_s1 & (~pcrdgrant_fifo_full | (pcrdgrant_fifo_full & txrsp_pcrdgnt_won_s2));
    assign pcrdgrant_fifo_pop  = txrsp_pcrdgnt_won_s2 & ~pcrdgrant_fifo_empty;

    sync_fifo #(
                       .FIFO_ENTRIES_WIDTH ($bits(chie_pkg::pcrdgrantq_s)    ),
                       .FIFO_ENTRIES_DEPTH (`SNF_PCRDGRANTQ_DATA_DEPTH    ),
                       .FIFO_BYP_ENABLE(1'b0)
                   )pcrdgrant_fifo_nobyp(
                       .clk        (clk                       ),
                       .rst        (rst                       ),
                       .push       (pcrdgrant_fifo_push       ),
                       .data_in    (pcrdgrant_fifo_datain_s1  ),
                       .pop        (pcrdgrant_fifo_pop        ),
                       .data_out   (pcrdgrant_fifo_dataout_s2 ),
                       .empty      (pcrdgrant_fifo_empty      ),
                       .full       (pcrdgrant_fifo_full       ),
                       .count      (                          )
                   );

    //decode pcrdgrant part fields from fifo
    assign qos_txrsp_pcrdgnt_valid_s2    = ~pcrdgrant_fifo_empty;
    assign qos_txrsp_pcrdgnt_fifo_s2     = pcrdgrant_fifo_dataout_s2;


endmodule
