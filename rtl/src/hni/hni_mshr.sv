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
*    Li Zhao <lizhao@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*    Xiaotian Cao <caoxiaotian@bosc.ac.cn>
*/

`include "axi4_defines.svh"
`include "hni_defines.svh"
`include "hni_param.svh"

module hni_mshr `HNI_PARAM
    (
    //inputs
    input wire clk,
    input wire rst,

    //inputs from hni_qos
    input wire rxreq_alloc_en_s0,
    input chie_pkg::req_flit_s rxreq_alloc_flit_s0,
    input wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s0,

    //inouts with hni_global_monitor
    input wire excl_pass_s1,
    input wire excl_fail_s1,

    //inouts with hni_rxrsp
    input wire rxrsp_valid_s0,
    input chie_pkg::rsp_flit_s rxrspflit_s0,

    //inouts with hni_txrsp
    output wire mshr_entry_sleep_s1,
    output logic txrsp_valid_sx_q,
    output wire [3:0] txrsp_qos_sx,
    output wire [chie_pkg::NID_WIDTH-1:0] txrsp_tgtid_sx,
    output wire [11:0] txrsp_txnid_sx,
    output chie_pkg::rsp_opcode_e txrsp_opcode_sx,
    output chie_pkg::resp_err_e txrsp_resperr_sx,
    output chie_pkg::resp_state_e txrsp_resp_sx,
    output wire [11:0] txrsp_dbid_sx,
    output wire txrsp_tracetag_sx,

    input wire txrsp_won_sx,
    input wire txrsp_fp_won_s1,

    //inouts with hni_data_buffer
    output wire rxreq_dbf_en_s0,
    output wire [`HNI_AXI4_AXID_WIDTH-1:0] rxreq_dbf_axid_s0,
    output wire [chie_pkg::REQ_ADDR_WIDTH-1:0] rxreq_dbf_addr_s0,
    output wire rxreq_dbf_device_s0,
    output wire rxreq_dbf_wr_s0,  //write txn
    output wire rxreq_dbf_wrzero_s0,
    output chie_pkg::size_e rxreq_dbf_size_s0,
    output wire [`AXI4_AWLEN_WIDTH-1:0] rxreq_dbf_axlen_s0,

    output wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] rxreq_dbf_entry_idx_s0,

    output wire mshr_rdat_en_sx,  //mshr allow dbf receive data from slave
    output wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] mshr_rdat_entry_idx_sx,

    input wire dbf_rvalid_sx,  //dbf receive rdata
    input wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] dbf_rvalid_entry_idx_sx,
    input wire [3:0] dbf_cdmask_sx,

    output wire mshr_txdat_en_sx,  //mshr allow dbf send data to chi xp
    output wire [1:0] mshr_txdat_dataid_sx,
    output wire [11:0] mshr_txdat_txnid_sx,
    output chie_pkg::dat_opcode_e mshr_txdat_opcode_sx,
    output chie_pkg::resp_state_e mshr_txdat_resp_sx,
    output chie_pkg::resp_err_e mshr_txdat_resperr_sx,
    output wire mshr_txdat_be_ovr_en_sx,
    output logic  [chie_pkg::BE_WIDTH-1:0] mshr_txdat_be_ovr_sx,
    output wire [11:0] mshr_txdat_dbid_sx,
    output wire [chie_pkg::NID_WIDTH-1:0] mshr_txdat_tgtid_sx,
    output wire mshr_txdat_tracetag_sx,
    input wire mshr_txdat_won_sx,

    input wire dbf_rxdat_valid_s0,
    input wire [11:0] dbf_rxdat_txnid_s0,
    input chie_pkg::dat_opcode_e dbf_rxdat_opcode_s0,
    input wire [1:0] dbf_rxdat_dataid_s0,

    output wire mshr_wdat_en_sx,  //send data to axi slave enable
    output wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] mshr_wdat_entry_idx_sx,
    input wire dbf_wdat_last,

    //outputs to hni_qos, hni_data_buffer
    output wire mshr_retired_valid_sx,
    output wire [`HNI_MSHR_ENTRIES_WIDTH-1:0] mshr_retired_idx_sx,

    //inout with axi slaves
    output wire [`AXI4_ARID_WIDTH-1:0] arid_sx,
    output wire [`AXI4_ARADDR_WIDTH-1:0] araddr_sx,
    output wire [`AXI4_ARLEN_WIDTH-1:0] arlen_sx,
    output wire [`AXI4_ARSIZE_WIDTH-1:0] arsize_sx,
    output wire [`AXI4_ARBURST_WIDTH-1:0] arburst_sx,
    output wire [`AXI4_ARLOCK_WIDTH-1:0] arlock_sx,
    output wire [`AXI4_ARCACHE_WIDTH-1:0] arcache_sx,
    output wire [`AXI4_ARPROT_WIDTH-1:0] arprot_sx,
    output wire [`AXI4_ARQOS_WIDTH-1:0] arqos_sx,
    output wire [`AXI4_ARREGION_WIDTH-1:0] arregion_sx,
    output logic arvalid_sx,
    input wire arready_sx,

    output wire [`AXI4_AWID_WIDTH-1:0] awid_sx,
    output wire [`AXI4_AWADDR_WIDTH-1:0] awaddr_sx,
    output wire [`AXI4_AWLEN_WIDTH-1:0] awlen_sx,
    output wire [`AXI4_AWSIZE_WIDTH-1:0] awsize_sx,
    output wire [`AXI4_AWBURST_WIDTH-1:0] awburst_sx,
    output wire [`AXI4_AWLOCK_WIDTH-1:0] awlock_sx,
    output wire [`AXI4_AWCACHE_WIDTH-1:0] awcache_sx,
    output wire [`AXI4_AWPROT_WIDTH-1:0] awprot_sx,
    output wire [`AXI4_AWQOS_WIDTH-1:0] awqos_sx,
    output wire [`AXI4_AWREGION_WIDTH-1:0] awregion_sx,
    output logic awvalid_sx,
    input wire awready_sx,

    input wire [`AXI4_BID_WIDTH-1:0] bid_sx,
    input wire [`AXI4_BRESP_WIDTH-1:0] bresp_sx,
    input wire bvalid_sx,
    output wire bready_sx
    );

    //internal reg
    logic                                         rxreq_alloc_en_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           mshr_entry_idx_alloc_s1_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             mshr_entry_valid_sx_q;

    chie_pkg::req_opcode_e       rxreq_opcode_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [3:0]          rxreq_qos_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::memattr_s      rxreq_memattr_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic                                         rxreq_device_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::NID_WIDTH-1:0]        rxreq_srcid_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [11:0]        rxreq_txnid_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_excl_s1_q;
    chie_pkg::size_e         rxreq_size_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]         rxreq_addr_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic           rxreq_ns_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::order_e        rxreq_order_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_expcompack_s1_q;
    logic     rxreq_tracetag_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [7:0]         rxreq_lpid_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_excl_pass_s2_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_excl_fail_s2_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_rd_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_wrf_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_wrp_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_err_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_errrd_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_errwr_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_errdat_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_drop_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_cw_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_cwpersist_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxreq_rsp1_owed_s1_q;
    chie_pkg::rsp_opcode_e       rxreq_rsp1_opcode_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             wrzero_pending_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             errdat_pending_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           wrzero_inject_idx_sx;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           errdat_inject_idx_sx;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txdat_en_idx_sx;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txrsp_second_idx_sx;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             txrsp_second_pend_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             txrsp_second_sent_q;
    logic [1:0]         rxreq_ccid_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]         rxreq_alignaddr_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_AXI4_AXID_WIDTH-1:0]              rxreq_axid_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_AWLEN_WIDTH-1:0]                 rxreq_axlen_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_AWSIZE_WIDTH-1:0]                rxreq_axsize_s1_q[`HNI_MSHR_ENTRIES_NUM-1:0];

    logic [`HNI_AXI4_AXID_WIDTH-1:0]              rxreq_axid_s0;    
    logic [1:0]                                   addr_region_id;
    logic [2:0]                                   addr_range_compare;
    logic [chie_pkg::REQ_ADDR_WIDTH-1-12:0]      addr_order_region_aligned;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxrsp_compack_s1_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxdat_data1_valid_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxdat_data2_valid_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             dbf_rxdat_ok_s2_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rxdat_compack_s1_q;

    logic [2*`HNI_MSHR_ENTRIES_NUM-1:0]           txrsp_fifo_valid_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txrsp_fifo_entry_idx_sx_q[2*`HNI_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::rsp_opcode_e       txrsp_fifo_opcode_s1_q[2*`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_WIDTH:0]             txrsp_fifo_set_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH:0]             txrsp_fifo_cnt_sx_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txrsp_entry_idx_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             txrsp_sent_q;

    logic [1:0]                                   txdat_fifo_rdy_sx_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [2*`HNI_MSHR_ENTRIES_NUM-1:0]           txdat_fifo_valid_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txdat_fifo_entry_idx_sx_q[2*`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [1:0]       txdat_fifo_dataid_s1_q[2*`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_WIDTH:0]             txdat_fifo_set_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH:0]             txdat_fifo_cnt_sx_q;
    logic                                         txdat_en_sx_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           txdat_entry_idx_sx_q;
    logic [1:0]                                   txdat_sent_sx_q[`HNI_MSHR_ENTRIES_NUM-1:0];

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             arvalid_fifo_s1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           arvalid_fifo_idx_sx_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           arvalid_fifo_set_sx_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           arvalid_fifo_cnt_sx_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           arvalid_entry_idx_s1_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             rdat_valid_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           rdat_entry_idx_s1_q;
    logic [3:0]                                   rdat_pdmask_q[`HNI_MSHR_ENTRIES_NUM-1:0];

    logic                                         dbf_rxdat_valid_s1_q;
    localparam [31:0]                        HNI_ENTRIES_M1 = `HNI_MSHR_ENTRIES_NUM-1;
    localparam [`HNI_MSHR_ENTRIES_WIDTH-1:0] IDX_LAST       = HNI_ENTRIES_M1[`HNI_MSHR_ENTRIES_WIDTH-1:0];

    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           dbf_rxdat_txnid_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             awvalid_fifo_s2_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           awvalid_fifo_idx_s2_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           awvalid_fifo_set_s2_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           awvalid_fifo_cnt_sx_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           awvalid_entry_idx_s2_q;
    logic                                         awvalid_sx1_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             bresp_ok_q;
    logic                                         wdat_wait_sx_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             mshr_entry_sleep_s1_q;
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             need_to_wakeup_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           need_to_wakeup_idx_q[`HNI_MSHR_ENTRIES_NUM-1:0];
    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             sleep_sx_q;

    logic [`HNI_MSHR_ENTRIES_NUM-1:0]             retired_entry_sx1_q;
    logic [`HNI_MSHR_ENTRIES_WIDTH-1:0]           retired_entry_idx_sx1_q;

    //wire 
    wire [3:0]         rxreq_qos_s0;
    wire [chie_pkg::NID_WIDTH-1:0]       rxreq_srcid_s0;
    wire [11:0]       rxreq_txnid_s0;
    chie_pkg::req_opcode_e      rxreq_opcode_s0;
    chie_pkg::size_e        rxreq_size_s0;
    wire [chie_pkg::REQ_ADDR_WIDTH-1:0]        rxreq_addr_s0;
    wire          rxreq_ns_s0;
    wire                                        rxreq_allowretry_s0;
    chie_pkg::order_e       rxreq_order_s0;
    wire [3:0]    rxreq_pcrdtype_s0;
    chie_pkg::memattr_s     rxreq_memattr_s0;
    wire                                        rxreq_device_s0;
    wire [7:0]        rxreq_lpid_s0;
    wire                                        rxreq_excl_s0;
    wire                                        rxreq_expcompack_s0;
    wire    rxreq_tracetag_s0;
    wire                                        rxreq_rd_s0;
    wire                                        rxreq_wrf_s0;
    wire                                        rxreq_wrp_s0;
    wire                                        rxreq_wrzero_s0;
    wire                                        rxreq_cwf_s0;
    wire                                        rxreq_cwp_s0;
    wire                                        rxreq_errcw_s0;
    wire                                        rxreq_cw_s0;
    wire                                        rxreq_cwpersist_s0;
    wire                                        rxreq_cmo_s0;
    wire                                        rxreq_cmopersist_s0;
    wire                                        rxreq_drop_s0;
    wire                                        rxreq_atomic_s0;
    wire                                        rxreq_atomicdat_s0;
    wire                                        rxreq_err_s0;
    wire                                        rxreq_errrd_s0;
    wire                                        rxreq_errwrdat_s0;
    wire                                        rxreq_errwr_s0;
    wire                                        rxreq_errdat_s0;
    wire                                        rxreq_errgrant_s0;
    wire                                        rxreq_errstash_s0;
    wire                                        rxreq_rdshape_s0;
    wire                                        rxreq_rsp1_owed_s0;
    chie_pkg::rsp_opcode_e      rxreq_rsp1_opcode_s0;
    wire [`AXI4_AWSIZE_WIDTH-1:0]               rxreq_axsize_s0;
    wire [`AXI4_AWLEN_WIDTH-1:0]                rxreq_axlen_s0;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            mshr_entry_alloc_sx;
    wire [chie_pkg::REQ_ADDR_WIDTH-1-12:0]     sam_addrregion_idx[2:0];
    wire [5:0]                                  sam_addrregion_size[2:0];
    wire [5:0]                                  sam_order_region_size[2:0];
    wire [11:0]       rxrsp_entry_idx_s0;
    chie_pkg::rsp_opcode_e      rxrsp_opcode_s0;
    wire                                        rxdat_valid_s0;
    wire [11:0]       rxdat_entry_idx_s0;
    chie_pkg::dat_opcode_e      rxdat_opcode_s0;
    wire [1:0]      rxdat_dataid_s0;
    wire                                        rxdat_data1_valid_s0;
    wire                                        rxdat_data2_valid_s0;
    wire                                        rxdat_ok_real_s1;
    wire                                        dbf_rxdat_ok_s1;
    wire [`HNI_MSHR_ENTRIES_WIDTH-1:0]          rxdat_ok_idx_s1;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            wrzero_ready_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            errdat_ready_sx;
    wire                                        wrzero_inject_sx;
    wire                                        errdat_inject_sx;
    wire                                        rdat_valid_sx;
    wire [`HNI_MSHR_ENTRIES_WIDTH-1:0]          rdat_idx_sx;
    wire [3:0]                                  rdat_cdmask_sx;
    wire                                        txrsp_en_s1;
    wire                                        txrsp_en2_s1;
    wire                                        txrsp_en3_sx;
    chie_pkg::rsp_opcode_e      txrsp_opcode3_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            txrsp_all_sent_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            txdat_done_sx;
    chie_pkg::size_e        atomic_ret_size_sx;
    wire [chie_pkg::BE_WIDTH:0]            atomic_ret_bytes_sx;
    wire [4:0]                                  atomic_ret_off_sx;
    wire                                        txdat_en_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            txdat1_en_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            txdat2_en_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            rdat_allrcvd_sx;
    wire                                        arvalid_en_s1;
    wire                                        arvalid_en2_s1;
    wire                                        awvalid_en_s1;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            need_to_sleep_s0;
    wire                                        wakeup_valid;
    wire [`HNI_MSHR_ENTRIES_WIDTH-1:0]          wakeup_idx_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1: 0]           compack_ok_sx;
    wire [`HNI_MSHR_ENTRIES_NUM-1:0]            retired_entry_sx;

//main function
    genvar entry, i, j;

    //************************************************************************//

    //          mshr allocate s0 stage request fields decode logic

    //************************************************************************//

    //rxreq_alloc_flit_s0 decode
    assign rxreq_qos_s0        = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.qos           :'0;
    assign rxreq_srcid_s0      = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.srcid         :'0;
    assign rxreq_txnid_s0      = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.txnid         :'0;
    assign rxreq_opcode_s0     = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.opcode        :chie_pkg::REQ_REQLCRDRETURN;
    assign rxreq_size_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.size          :chie_pkg::SIZE_1B;
    assign rxreq_addr_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.addr          :'0;
    assign rxreq_ns_s0         = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.ns            :'0;
    assign rxreq_allowretry_s0 = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.allowretry    :'0;
    assign rxreq_order_s0      = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.order         :chie_pkg::ORDER_NONE;
    assign rxreq_pcrdtype_s0   = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.pcrdtype      :'0;
    assign rxreq_memattr_s0    = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.memattr       :'0;
    assign rxreq_device_s0     = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.memattr.device:'0;
    assign rxreq_lpid_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.lpid          :'0;
    assign rxreq_excl_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.excl          :'0;
    assign rxreq_expcompack_s0 = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.expcompack    :'0;
    assign rxreq_tracetag_s0   = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.tracetag      :'0;
    assign rxreq_rd_s0         = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_READNOSNP)|(rxreq_opcode_s0 == chie_pkg::REQ_READONCE)|(rxreq_opcode_s0 == chie_pkg::REQ_READCLEAN)|(rxreq_opcode_s0 == chie_pkg::REQ_READNOTSHAREDDIRTY)|(rxreq_opcode_s0 == chie_pkg::REQ_READUNIQUE)) :1'b0;
    assign rxreq_wrf_s0        = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITEEVICTFULL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULL)|rxreq_cwf_s0|rxreq_wrzero_s0):1'b0;
    assign rxreq_wrp_s0        = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTL)|rxreq_cwp_s0):1'b0;

    // CHI E.b Sec 4.5.1 (p.4-197, MUST): "A completion response is required for all
    // transactions except PCrdReturn and PrefetchTgt", and Sec 4.2 (p.4-162) requires
    // an HN-I to answer "in a protocol-compliant manner" even a transaction it is only
    // a permitted target for. Every inbound request is therefore classified here, and
    // every class below owns a response programme.
    assign rxreq_wrzero_s0     = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPZERO);
    // Table B-1 (p.B-493): the six WriteNoSnp Combined Writes are expected at an HN-I.
    // Their write leg executes as the plain WriteNoSnp* does (Sec 2.3.2 p.2-59) and the
    // CMO leg owes its own completion.
    assign rxreq_cwf_s0        = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANINV)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP);
    assign rxreq_cwp_s0        = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANINV)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP);
    assign rxreq_errcw_s0      = (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANINV)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULLCLEANSH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP);
    assign rxreq_cw_s0         = rxreq_cwf_s0 | rxreq_cwp_s0 | rxreq_errcw_s0;
    // Sec 2.3.2 (p.2-62) permits the combined CompPersist for the CMO leg of the
    // *CleanShPerSep forms, and Table 4-38 (p.4-218) for CleanSharedPersistSep itself.
    assign rxreq_cwpersist_s0  = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP);
    assign rxreq_cmopersist_s0 = (rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHAREDPERSISTSEP);
    // An HN-I holds no cached copy and is no PoC (Sec 1.6 p.1-28), so a CMO is a no-op
    // that owes only its completion (Table 4-38 p.4-218).
    assign rxreq_cmo_s0        = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHARED)
                                                             | (rxreq_opcode_s0 == chie_pkg::REQ_CLEANINVALID)
                                                             | (rxreq_opcode_s0 == chie_pkg::REQ_MAKEINVALID)
                                                             | (rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHAREDPERSIST)
                                                             | rxreq_cmopersist_s0) :1'b0;
    // Sec 4.5.1's two exceptions, plus the Link-layer credit return of Table 13-12
    // (p.13-421), which is not a transaction at all: given no response, so no tracker
    // entry is held.
    assign rxreq_drop_s0       = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_PREFETCHTGT)
                                                             | (rxreq_opcode_s0 == chie_pkg::REQ_PCRDRETURN)
                                                             | (rxreq_opcode_s0 == chie_pkg::REQ_REQLCRDRETURN)) :1'b0;
    assign rxreq_atomic_s0     = (rxreq_opcode_s0 >= chie_pkg::REQ_ATOMICSTORE_ADD) && (rxreq_opcode_s0 <= chie_pkg::REQ_ATOMICCOMPARE);
    assign rxreq_atomicdat_s0  = rxreq_atomic_s0 && (rxreq_opcode_s0 >= chie_pkg::REQ_ATOMICLOAD_ADD);
    // Everything not in a serviced class above. Sec 9.1 (p.9-334) gives NDERR for "an
    // attempt to use a transaction type that is not supported"; for the Atomics that is
    // Sec 16.1's (p.16-470) undeclared Atomic_Transactions property -- "if a property is
    // not declared, it is considered False" -- which Sec 16.3.2 (p.16-479) scopes to an
    // interconnect and Sec 16.3.3 (p.16-479, MUST) answers with an Error response.
    // Sec 9.4.4 (p.9-342, MUST) then keeps the transaction structure intact, so the
    // class carries its shape -- grant, write data, read data -- as well as its error.
    assign rxreq_err_s0        = rxreq_alloc_en_s0 && ~(rxreq_rd_s0 | rxreq_wrf_s0 | rxreq_wrp_s0 | rxreq_cmo_s0 | rxreq_drop_s0);
    assign rxreq_errrd_s0      = rxreq_err_s0 && ((rxreq_opcode_s0 == chie_pkg::REQ_READSHARED)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_READNOSNPSEP)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_READONCECLEANINVALID)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_READONCEMAKEINVALID)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_READPREFERUNIQUE)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_MAKEREADUNIQUE));
    assign rxreq_errwrdat_s0   = (rxreq_opcode_s0 == chie_pkg::REQ_WRITEBACKPTL)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEFULLSTASH)
                               | (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEPTLSTASH);
    assign rxreq_errwr_s0      = rxreq_err_s0 && (rxreq_atomic_s0 | rxreq_errcw_s0 | rxreq_errwrdat_s0);
    assign rxreq_errdat_s0     = rxreq_err_s0 && rxreq_atomicdat_s0;
    // Table 4-39 (p.4-219) gives a Write Zero no WriteData response but still a DBID,
    // so it joins the errored writes in owing a CompDBIDResp without owing data.
    assign rxreq_errgrant_s0   = rxreq_errwr_s0 | (rxreq_err_s0 && (rxreq_opcode_s0 == chie_pkg::REQ_WRITEUNIQUEZERO));
    // Table 4-38 (p.4-218): StashOnceSep* is completed by CompStashDone.
    assign rxreq_errstash_s0   = rxreq_err_s0 && ((rxreq_opcode_s0 == chie_pkg::REQ_STASHONCESEPSHARED)
                                                | (rxreq_opcode_s0 == chie_pkg::REQ_STASHONCESEPUNIQUE));
    // Sec 2.8.5 (p.2-120): a read owes a ReadReceipt when it is ordered, and its
    // completion rides on the data. Everything else owes an RSP up front.
    assign rxreq_rdshape_s0    = rxreq_rd_s0 | rxreq_errrd_s0;
    assign rxreq_rsp1_owed_s0  = rxreq_alloc_en_s0 && (~rxreq_drop_s0)
                              && (rxreq_rdshape_s0 ? (rxreq_order_s0 != 2'b00) : 1'b1);
    // Table 9-9 (p.9-342) gives AtomicLoad/Swap/Compare no CompDBIDResp, so those take
    // the split grant and carry their error on CompData.
    assign rxreq_rsp1_opcode_s0 = rxreq_rdshape_s0 ? chie_pkg::RSP_READRECEIPT
                                : rxreq_errdat_s0  ? chie_pkg::RSP_DBIDRESP
                                : (rxreq_wrf_s0 | rxreq_wrp_s0 | rxreq_errgrant_s0) ? chie_pkg::RSP_COMPDBIDRESP
                                : (rxreq_cmo_s0 & rxreq_cmopersist_s0) ? chie_pkg::RSP_COMPPERSIST
                                : rxreq_errstash_s0 ? chie_pkg::RSP_COMPSTASHDONE
                                : chie_pkg::RSP_COMP;

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign mshr_entry_alloc_sx[entry] = (rxreq_alloc_en_s0 == 1'b1) && (mshr_entry_idx_alloc_s0 == entry);
        end
    endgenerate

    //ax channel signal
    assign rxreq_axsize_s0  = ((rxreq_size_s0 == 3'b110) | (rxreq_size_s0 == 3'b101)) ? 3'b100 : rxreq_size_s0;
    assign rxreq_axlen_s0   = rxreq_device_s0 ? ((rxreq_size_s0 == 3'b110) ? (8'd3-{6'b0,rxreq_addr_s0[5:4]}) : ((rxreq_size_s0 == 3'b101) ? ({7'b0,~rxreq_addr_s0[4]}) : 8'b0)) : ((rxreq_size_s0 == 3'b110) ? 'b11 : ((rxreq_size_s0 == 3'b101) ? 'b1 : 8'b0));

    assign rxreq_dbf_en_s0        = rxreq_alloc_en_s0;
    assign rxreq_dbf_axid_s0      = rxreq_axid_s0;
    assign rxreq_dbf_addr_s0      = rxreq_addr_s0;
    assign rxreq_dbf_device_s0    = rxreq_device_s0;
    // Sec 9.4.4 (p.9-342, MUST): an errored write still transfers its write data, so
    // the buffer is armed for it even though the write never reaches memory.
    assign rxreq_dbf_wr_s0        = rxreq_wrf_s0 | rxreq_wrp_s0 | rxreq_errwr_s0;
    assign rxreq_dbf_wrzero_s0    = rxreq_wrzero_s0;
    assign rxreq_dbf_size_s0      = rxreq_size_s0;
    assign rxreq_dbf_axlen_s0     = rxreq_axlen_s0;
    assign rxreq_dbf_entry_idx_s0 = mshr_entry_idx_alloc_s0;

    //fields reg
    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_entry_valid_s1_q_logic
                if(rst == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_rd_s1_q_logic
                if(rst == 1'b1)
                    rxreq_rd_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_rd_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_rd_s1_q[entry] <= rxreq_rd_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_wrf_s1_q_logic
                if(rst == 1'b1)
                    rxreq_wrf_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_wrf_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_wrf_s1_q[entry] <= rxreq_wrf_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_wrp_s1_q_logic
                if(rst == 1'b1)
                    rxreq_wrp_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_wrp_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_wrp_s1_q[entry] <= rxreq_wrp_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_class_s1_q_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)begin
                    rxreq_err_s1_q[entry]        <= 1'b0;
                    rxreq_errrd_s1_q[entry]      <= 1'b0;
                    rxreq_errwr_s1_q[entry]      <= 1'b0;
                    rxreq_errdat_s1_q[entry]     <= 1'b0;
                    rxreq_drop_s1_q[entry]       <= 1'b0;
                    rxreq_cw_s1_q[entry]         <= 1'b0;
                    rxreq_cwpersist_s1_q[entry]  <= 1'b0;
                    rxreq_rsp1_owed_s1_q[entry]  <= 1'b0;
                    rxreq_rsp1_opcode_s1_q[entry] <= chie_pkg::RSP_RSPLCRDRETURN;
                end
                else if(mshr_entry_alloc_sx[entry] == 1'b1)begin
                    rxreq_err_s1_q[entry]        <= rxreq_err_s0;
                    rxreq_errrd_s1_q[entry]      <= rxreq_errrd_s0;
                    rxreq_errwr_s1_q[entry]      <= rxreq_errwr_s0;
                    rxreq_errdat_s1_q[entry]     <= rxreq_errdat_s0;
                    rxreq_drop_s1_q[entry]       <= rxreq_drop_s0;
                    rxreq_cw_s1_q[entry]         <= rxreq_cw_s0;
                    rxreq_cwpersist_s1_q[entry]  <= rxreq_cwpersist_s0;
                    rxreq_rsp1_owed_s1_q[entry]  <= rxreq_rsp1_owed_s0;
                    rxreq_rsp1_opcode_s1_q[entry] <= rxreq_rsp1_opcode_s0;
                end
            end

            // Table 4-39 (p.4-219): a Write Zero has no WriteData response, so its
            // write-data-complete handshake is sourced here on a cycle no real write
            // data is using it.
            always_ff @(posedge clk or posedge rst)begin : wrzero_pending_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    wrzero_pending_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    wrzero_pending_q[entry] <= rxreq_wrzero_s0;
                else if(wrzero_inject_sx && (entry == wrzero_inject_idx_sx))
                    wrzero_pending_q[entry] <= 1'b0;
            end

            // Sec 9.3 (p.9-336): "the source of the data packets is required to send
            // the correct number of packets, but the data values are not required to be
            // valid", so an errored read is driven onto the existing read-data path.
            // Sec 9.4.4 (p.9-342, MUST) makes the Atomic's own read data owed only once
            // its write data transfer has taken place.
            always_ff @(posedge clk or posedge rst)begin : errdat_pending_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    errdat_pending_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    errdat_pending_q[entry] <= rxreq_errrd_s0;
                else if(dbf_rxdat_ok_s1 && rxreq_errdat_s1_q[entry] && (entry == rxdat_ok_idx_s1))
                    errdat_pending_q[entry] <= 1'b1;
                else if(errdat_inject_sx && (entry == errdat_inject_idx_sx))
                    errdat_pending_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_qos_s1_q_logic
                if(rst == 1'b1)
                    rxreq_qos_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_qos_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_qos_s1_q[entry] <= rxreq_qos_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_srcid_s1_q_logic
                if(rst == 1'b1)
                    rxreq_srcid_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_srcid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_srcid_s1_q[entry] <= rxreq_srcid_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_txnid_s1_q_logic
                if(rst == 1'b1)
                    rxreq_txnid_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_txnid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_txnid_s1_q[entry] <= rxreq_txnid_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_opcode_s1_q_logic
                if(rst == 1'b1)
                    rxreq_opcode_s1_q[entry] <= chie_pkg::REQ_REQLCRDRETURN;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_opcode_s1_q[entry] <= chie_pkg::REQ_REQLCRDRETURN;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_opcode_s1_q[entry] <= rxreq_opcode_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_size_s1_q_logic
                if(rst == 1'b1)
                    rxreq_size_s1_q[entry] <= chie_pkg::SIZE_1B;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_size_s1_q[entry] <= chie_pkg::SIZE_1B;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_size_s1_q[entry] <= rxreq_size_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_addr_s1_q_logic
                if(rst == 1'b1)
                    rxreq_addr_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_addr_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_addr_s1_q[entry] <= rxreq_addr_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_alignaddr_s1_q_logic
                if(rst == 1'b1)
                    rxreq_alignaddr_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_alignaddr_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_alignaddr_s1_q[entry] <= ((rxreq_addr_s0 >> rxreq_size_s0) << rxreq_size_s0);
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_ns_s1_q_logic
                if(rst == 1'b1)
                    rxreq_ns_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_ns_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_ns_s1_q[entry] <= rxreq_ns_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_order_s1_q_logic
                if(rst == 1'b1)
                    rxreq_order_s1_q[entry] <= chie_pkg::ORDER_NONE;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_order_s1_q[entry] <= chie_pkg::ORDER_NONE;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_order_s1_q[entry] <= rxreq_order_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_memattr_s1_q_logic
                if(rst == 1'b1)
                    rxreq_memattr_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_memattr_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_memattr_s1_q[entry] <= rxreq_memattr_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_device_s1_q_logic
                if(rst == 1'b1)
                    rxreq_device_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_device_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_device_s1_q[entry] <= rxreq_device_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_excl_s1_q_logic
                if(rst == 1'b1)
                    rxreq_excl_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_excl_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_excl_s1_q[entry] <= rxreq_excl_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_expcompack_s1_q_logic
                if(rst == 1'b1)
                    rxreq_expcompack_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_expcompack_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_expcompack_s1_q[entry] <= rxreq_expcompack_s0;
            end

            // Sec 2.6 step 4 (p.2-102, MUST): "The PGroupID is set to the same value
            // as the PGroupID of the original request", which the request carries in
            // its LPID bits and the response in its DBID bits (Sec 13.10.12 p.13-419).
            always_ff @(posedge clk or posedge rst)begin : mshr_lpid_s1_q_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    rxreq_lpid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_lpid_s1_q[entry] <= rxreq_lpid_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_tracetag_s1_q_logic
                if(rst == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= rxreq_tracetag_s0;
            end

            //ADDR[5:4]:identifies the critical chunk
            always_ff @(posedge clk or posedge rst)begin : axlen_logic
                if(rst == 1'b1)
                    rxreq_axlen_s1_q[entry] <= {`AXI4_AWLEN_WIDTH{1'b0}};
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_axlen_s1_q[entry] <= {`AXI4_AWLEN_WIDTH{1'b0}};
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_axlen_s1_q[entry] <= rxreq_axlen_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : axsize_logic
                if(rst == 1'b1)
                    rxreq_axsize_s1_q[entry] <= {`AXI4_AWSIZE_WIDTH{1'b0}};
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_axsize_s1_q[entry] <= {`AXI4_AWSIZE_WIDTH{1'b0}};
                else if(mshr_entry_alloc_sx[entry] == 1'b1)begin
                    rxreq_axsize_s1_q[entry] <= rxreq_axsize_s0;
                end
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_ccid_s1_q_logic
                if(rst == 1'b1)
                    rxreq_ccid_s1_q[entry] <= 2'b00;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_ccid_s1_q[entry] <= 2'b00;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_ccid_s1_q[entry] <= rxreq_addr_s0[5:4];
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_excl_pass_s_q_logic
                if(rst == 1'b1)begin
                    rxreq_excl_pass_s2_q[entry] <= 1'b0;
                    rxreq_excl_fail_s2_q[entry] <= 1'b0;
                end   
                else if(retired_entry_sx1_q[entry] == 1'b1) begin
                    rxreq_excl_pass_s2_q[entry] <= 1'b0;
                    rxreq_excl_fail_s2_q[entry] <= 1'b0;                    
                end
                else if(rxreq_alloc_en_s1_q && (mshr_entry_idx_alloc_s1_q == entry))begin
                    rxreq_excl_pass_s2_q[entry] <= excl_pass_s1;
                    rxreq_excl_fail_s2_q[entry] <= excl_fail_s1; 
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst)begin : mshr_rxreq_alloc_s1_q_logic
        if(rst)begin
            rxreq_alloc_en_s1_q         <= 1'b0;
            mshr_entry_idx_alloc_s1_q   <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else begin
            rxreq_alloc_en_s1_q         <= rxreq_alloc_en_s0;
            mshr_entry_idx_alloc_s1_q   <= mshr_entry_idx_alloc_s0;
        end
    end

    //************************************************************************//

    //                            mshr sam logic

    //************************************************************************//

    wire [chie_pkg::REQ_ADDR_WIDTH-1:0] rxreq_addralign_s0[HNI_ADDR_REGION_NUM-1:0];
    generate
        for(i=0;i< HNI_ADDR_REGION_NUM;i=i+1) begin:rxreq_addralign_s0_val
            assign rxreq_addralign_s0[i] = (rxreq_addr_s0 >> HNI_ADDR_REGION_SIZE[i]);
        end
    endgenerate
    always_comb begin: rxreq_axid_s0_val
        rxreq_axid_s0 = {`HNI_AXI4_AXID_WIDTH{1'b0}};
        for (int k =0;k< HNI_ADDR_REGION_NUM;k=k+1) begin
            if (rxreq_addralign_s0[k] == (HNI_ADDR_REGION_LSB[k] >> HNI_ADDR_REGION_SIZE[k])) begin
                rxreq_axid_s0 = k[`HNI_AXI4_AXID_WIDTH-1:0] + 1'b1;
            end
        end
    end

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : sam_axid_logic
                if (rst ==1'b1)
                    rxreq_axid_s1_q[entry] <= {`HNI_AXI4_AXID_WIDTH{1'b0}};
                else if (retired_entry_sx[entry] == 1'b1)
                    rxreq_axid_s1_q[entry] <= {`HNI_AXI4_AXID_WIDTH{1'b0}};
                else if (mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_axid_s1_q[entry] <= rxreq_axid_s0;
            end
        end
    endgenerate

    //************************************************************************//

    //                        mshr rxrsp channel decode logic

    //************************************************************************//
    //rsp flit decode
    assign rxrsp_entry_idx_s0 = (rxrsp_valid_s0 == 1'b1)? rxrspflit_s0.txnid  :'0;
    assign rxrsp_opcode_s0    = (rxrsp_valid_s0 == 1'b1)? rxrspflit_s0.opcode :chie_pkg::RSP_RSPLCRDRETURN;

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_rsp_entry_vec_s0_logic
            always_ff @(posedge clk or posedge rst)begin : rxrsp_compack_s1_q_logic
                if(rst == 1'b1)
                    rxrsp_compack_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxrsp_compack_s1_q[entry] <= 1'b0;
                else if((rxrsp_valid_s0 == 1'b1) && (entry == rxrsp_entry_idx_s0))
                    rxrsp_compack_s1_q[entry] <= (rxrsp_opcode_s0 == chie_pkg::RSP_COMPACK);
            end
        end
    endgenerate

    //************************************************************************//

    //                       mshr rxdat channel decode logic

    //************************************************************************//

    assign rxdat_valid_s0           = dbf_rxdat_valid_s0;
    assign rxdat_entry_idx_s0       = dbf_rxdat_txnid_s0;
    assign rxdat_opcode_s0          = dbf_rxdat_opcode_s0;
    assign rxdat_dataid_s0          = dbf_rxdat_dataid_s0;

    assign rxdat_data1_valid_s0     = (rxdat_valid_s0 == 1'b1) ? (rxdat_dataid_s0 == 2'b00) : 1'b0;
    assign rxdat_data2_valid_s0     = (rxdat_valid_s0 == 1'b1) ? (rxdat_dataid_s0 == 2'b10) : 1'b0;

    always_ff @(posedge clk or posedge rst) begin: rxdat_logic
        if(rst == 1'b1) begin
            dbf_rxdat_valid_s1_q <= 1'b0;
            dbf_rxdat_txnid_s1_q <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else begin
            dbf_rxdat_valid_s1_q  <= dbf_rxdat_valid_s0;
            dbf_rxdat_txnid_s1_q  <= dbf_rxdat_txnid_s0[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin : mshr_dat_entry_vec_s0_logic
            always_ff @(posedge clk or posedge rst)begin : rxdat_data1_valid_s1_q_logic
                if(rst == 1'b1)
                    rxdat_data1_valid_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxdat_data1_valid_s1_q[entry] <= 1'b0;
                else if((rxdat_data1_valid_s0 == 1'b1) && (entry == rxdat_entry_idx_s0))
                    rxdat_data1_valid_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : rxdat_data2_valid_s1_q_logic
                if(rst == 1'b1)
                    rxdat_data2_valid_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxdat_data2_valid_s1_q[entry] <= 1'b0;
                else if((rxdat_data2_valid_s0 == 1'b1) && (entry == rxdat_entry_idx_s0))
                    rxdat_data2_valid_s1_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : rxdat_data_ok_logic
                if(rst == 1'b1)
                    dbf_rxdat_ok_s2_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    dbf_rxdat_ok_s2_q[entry] <= 1'b0;
                else if(dbf_rxdat_ok_s1 && (entry == rxdat_ok_idx_s1))
                    dbf_rxdat_ok_s2_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : rxdat_compack_s1_q_logic
                if(rst == 1'b1)
                    rxdat_compack_s1_q[entry] <= 0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxdat_compack_s1_q[entry] <= 1'b0;
                else if((rxdat_valid_s0 == 1'b1) && (entry == rxdat_entry_idx_s0))
                    rxdat_compack_s1_q[entry] <= (rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK);
                else
                    ;
            end
        end
    endgenerate

    assign rxdat_ok_real_s1 = dbf_rxdat_valid_s1_q ? (rxreq_size_s1_q[dbf_rxdat_txnid_s1_q] == 3'b110 ? 
                            (rxdat_data1_valid_s1_q[dbf_rxdat_txnid_s1_q] & rxdat_data2_valid_s1_q[dbf_rxdat_txnid_s1_q]) : 
                            (rxdat_data1_valid_s1_q[dbf_rxdat_txnid_s1_q] | rxdat_data2_valid_s1_q[dbf_rxdat_txnid_s1_q])) : 1'b0;

    // A sleeping entry has not reached the head of its same-address chain, so its
    // write must not be issued yet: the Home withholds the DBID grant until wakeup,
    // which is what stops a real write's data arriving early. A sourced Write Zero
    // payload has no such interlock of its own and takes this one instead.
    assign wrzero_ready_sx = wrzero_pending_q & (~sleep_sx_q);

    always_comb begin: wrzero_inject_idx_comb_logic
        integer m;
        wrzero_inject_idx_sx = {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        for(m=`HNI_MSHR_ENTRIES_NUM-1; m>=0; m=m-1)begin
            if (wrzero_ready_sx[m])
                wrzero_inject_idx_sx = m[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    assign wrzero_inject_sx = (|wrzero_ready_sx) & (~rxdat_ok_real_s1);
    assign dbf_rxdat_ok_s1  = rxdat_ok_real_s1 | wrzero_inject_sx;
    assign rxdat_ok_idx_s1  = wrzero_inject_sx ? wrzero_inject_idx_sx : dbf_rxdat_txnid_s1_q;

    //************************************************************************//

    //                      mshr txrspflit wrap logic

    //************************************************************************//
    // The first response the entry owes, chosen by its class at allocation. A request
    // that hit a same-address hazard was put to sleep before its RSP was armed, so the
    // wakeup path arms the same programme.
    assign txrsp_en_s1  = rxreq_alloc_en_s1_q && (~sleep_sx_q[mshr_entry_idx_alloc_s1_q])
                       && rxreq_rsp1_owed_s1_q[mshr_entry_idx_alloc_s1_q] && (~txrsp_fp_won_s1);
    assign txrsp_en2_s1 = wakeup_valid && rxreq_rsp1_owed_s1_q[wakeup_idx_sx];

    // Sec 2.3.2 (p.2-59): a Combined Write owes a CMO completion on top of its write
    // completion, and Sec 2.3.2 (p.2-62) permits the combined CompPersist for the
    // *CleanShPerSep forms. Queued behind the first response so their order is kept.
    assign txrsp_en3_sx     = (|txrsp_second_pend_q) && (~txrsp_en_s1) && (~txrsp_en2_s1);
    assign txrsp_opcode3_sx = rxreq_cwpersist_s1_q[txrsp_second_idx_sx] ? chie_pkg::RSP_COMPPERSIST : chie_pkg::RSP_COMPCMO;

    always_comb begin: txrsp_second_idx_comb_logic
        integer m;
        txrsp_second_idx_sx = {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        for(m=`HNI_MSHR_ENTRIES_NUM-1; m>=0; m=m-1)begin
            if (txrsp_second_pend_q[m])
                txrsp_second_idx_sx = m[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk or posedge rst) begin: txrsp_fifo_set_logic
        if(rst == 1'b1) begin
            txrsp_fifo_set_s1_q <= {(`HNI_MSHR_ENTRIES_WIDTH+1){1'b0}};
        end
        else if(txrsp_en_s1 && txrsp_en2_s1) begin
            txrsp_fifo_set_s1_q <= txrsp_fifo_set_s1_q + 2;
        end
        else if (txrsp_en_s1 || txrsp_en2_s1 || txrsp_en3_sx) begin
            txrsp_fifo_set_s1_q <= txrsp_fifo_set_s1_q + 1;
        end
    end

    generate
        for(entry=0;entry<(2*`HNI_MSHR_ENTRIES_NUM);entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: txrsp_fifo_set_logic
                if(rst == 1'b1)
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b0;
                else if (txrsp_won_sx && txrsp_valid_sx_q && (txrsp_fifo_cnt_sx_q == entry))
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b0;
                else if (txrsp_en_s1 && txrsp_en2_s1 && (txrsp_fifo_set_s1_q == entry)) begin
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b1;
                    txrsp_fifo_entry_idx_sx_q[entry]    <= wakeup_idx_sx;
                    txrsp_fifo_opcode_s1_q[entry]       <= rxreq_rsp1_opcode_s1_q[wakeup_idx_sx];
                end
                else if (txrsp_en_s1 && txrsp_en2_s1 &&  (((txrsp_fifo_set_s1_q == (2*`HNI_MSHR_ENTRIES_NUM-1)) & (entry == 0)) | ((txrsp_fifo_set_s1_q +1) == entry))) begin
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b1;
                    txrsp_fifo_entry_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                    txrsp_fifo_opcode_s1_q[entry]       <= rxreq_rsp1_opcode_s1_q[mshr_entry_idx_alloc_s1_q];
                end
                else if (txrsp_en_s1 && (txrsp_fifo_set_s1_q == entry)) begin
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b1;
                    txrsp_fifo_entry_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                    txrsp_fifo_opcode_s1_q[entry]       <= rxreq_rsp1_opcode_s1_q[mshr_entry_idx_alloc_s1_q];
                end
                else if (txrsp_en2_s1 && (txrsp_fifo_set_s1_q == entry)) begin
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b1;
                    txrsp_fifo_entry_idx_sx_q[entry]    <= wakeup_idx_sx;
                    txrsp_fifo_opcode_s1_q[entry]       <= rxreq_rsp1_opcode_s1_q[wakeup_idx_sx];
                end
                else if (txrsp_en3_sx && (txrsp_fifo_set_s1_q == entry)) begin
                    txrsp_fifo_valid_s1_q[entry]        <= 1'b1;
                    txrsp_fifo_entry_idx_sx_q[entry]    <= txrsp_second_idx_sx;
                    txrsp_fifo_opcode_s1_q[entry]       <= txrsp_opcode3_sx;
                end
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            // The retire clear takes priority: an entry that owes no response holds this
            // asserted for as long as it is valid, so a lower-priority clear would leave
            // it set for the next request to land on the entry.
            always_ff @(posedge clk or posedge rst) begin: txrsp_sent_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    txrsp_sent_q[entry] <= 1'b0;
                else if (mshr_entry_valid_sx_q[entry] & (~rxreq_rsp1_owed_s1_q[entry]))
                    txrsp_sent_q[entry] <= 1'b1;
                else if (txrsp_won_sx && txrsp_valid_sx_q && (txrsp_entry_idx_s1_q == entry))
                    txrsp_sent_q[entry] <= 1'b1;
                else if (txrsp_fp_won_s1 && (mshr_entry_idx_alloc_s1_q == entry))
                    txrsp_sent_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst) begin: txrsp_second_pend_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    txrsp_second_pend_q[entry] <= 1'b0;
                else if (txrsp_en_s1 && (entry == mshr_entry_idx_alloc_s1_q))
                    txrsp_second_pend_q[entry] <= rxreq_cw_s1_q[entry];
                else if (txrsp_en2_s1 && (entry == wakeup_idx_sx))
                    txrsp_second_pend_q[entry] <= rxreq_cw_s1_q[entry];
                else if (txrsp_en3_sx && (entry == txrsp_second_idx_sx))
                    txrsp_second_pend_q[entry] <= 1'b0;
            end

            always_ff @(posedge clk or posedge rst) begin: txrsp_second_sent_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    txrsp_second_sent_q[entry] <= 1'b0;
                else if (txrsp_won_sx && txrsp_valid_sx_q && (txrsp_entry_idx_s1_q == entry) && txrsp_sent_q[entry])
                    txrsp_second_sent_q[entry] <= 1'b1;
            end
        end
    endgenerate
    
    always_ff @(posedge clk or posedge rst) begin: txrsp_fifo_idx_logic
        if(rst == 1'b1)
            txrsp_fifo_cnt_sx_q     <= {(`HNI_MSHR_ENTRIES_WIDTH+1){1'b0}};
        else if(txrsp_won_sx == 1'b1)
            txrsp_fifo_cnt_sx_q     <= txrsp_fifo_cnt_sx_q + 1;
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_txrsp_logic
        if(rst == 1'b1) begin
            txrsp_valid_sx_q        <= 1'b0;
            txrsp_entry_idx_s1_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(txrsp_won_sx && txrsp_valid_sx_q)begin
            txrsp_valid_sx_q        <= 1'b0;
            txrsp_entry_idx_s1_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(txrsp_fifo_valid_s1_q[txrsp_fifo_cnt_sx_q])begin
            txrsp_valid_sx_q        <= 1'b1;
            txrsp_entry_idx_s1_q    <= txrsp_fifo_entry_idx_sx_q[txrsp_fifo_cnt_sx_q];
        end
    end

    assign txrsp_qos_sx      = (rxreq_qos_s1_q[txrsp_entry_idx_s1_q]);
    assign txrsp_tgtid_sx    = (rxreq_srcid_s1_q[txrsp_entry_idx_s1_q]);
    assign txrsp_txnid_sx    = (rxreq_txnid_s1_q[txrsp_entry_idx_s1_q]);
    assign txrsp_opcode_sx   = txrsp_fifo_opcode_s1_q[txrsp_fifo_cnt_sx_q];
    // Table 9-9 (p.9-342) pins DBIDResp to OK and Sec 4.5.4 (p.4-207) pins the
    // ReadReceipt's Resp/RespErr to zero, so only the completion carries the error.
    assign txrsp_resperr_sx  = (rxreq_err_s1_q[txrsp_entry_idx_s1_q]
                             && (txrsp_opcode_sx != chie_pkg::RSP_DBIDRESP)
                             && (txrsp_opcode_sx != chie_pkg::RSP_READRECEIPT)) ? chie_pkg::RESP_ERR_NON_DATA
                             : ((txrsp_opcode_sx == chie_pkg::RSP_COMPDBIDRESP) & rxreq_excl_s1_q[txrsp_entry_idx_s1_q] & ((rxreq_excl_pass_s2_q[txrsp_entry_idx_s1_q]) | (excl_pass_s1 & (mshr_entry_idx_alloc_s1_q == txrsp_entry_idx_s1_q))))? chie_pkg::RESP_ERR_EX_OK : chie_pkg::RESP_ERR_NORM_OK;
    assign txrsp_resp_sx     = chie_pkg::RESP_I;
    assign txrsp_dbid_sx     = (txrsp_opcode_sx == chie_pkg::RSP_COMPPERSIST)
                             ? {{(12-8){1'b0}}, rxreq_lpid_s1_q[txrsp_entry_idx_s1_q]}
                             : {{(12-`HNI_MSHR_ENTRIES_WIDTH){1'b0}}, txrsp_entry_idx_s1_q};
    assign txrsp_tracetag_sx = rxreq_tracetag_s1_q[txrsp_entry_idx_s1_q];

    //************************************************************************//

    //                      mshr txdatflit wrap logic

    //************************************************************************//
    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            // Sec 9.4.1 (p.9-337, MUST): a Read's data response carries a Non-data
            // Error "either in none or in all data response packets", and the AXI
            // error is not final until the last beat is in. A two-packet transfer
            // therefore holds its first packet until the whole burst has arrived;
            // a single-packet one has nothing to hold.
            assign rdat_allrcvd_sx[entry] = (rxreq_size_s1_q[entry] == 3'b110) ?
                                        (rdat_pdmask_q[entry] == 4'b1111) : 1'b1;

            assign txdat1_en_sx[entry] = (rdat_valid_q[entry] & (~txdat_fifo_rdy_sx_q[entry][0]) & rdat_allrcvd_sx[entry]) ? 
                                        (rxreq_device_s1_q[entry] ? (rxreq_ccid_s1_q[entry]==2'b11 ? (rdat_pdmask_q[entry][3]==1'b1) : 
                                        (rxreq_ccid_s1_q[entry]==2'b10 ? ((rdat_pdmask_q[entry][3:2]==2'b11) | ((rdat_pdmask_q[entry][2]==1'b1) && (rxreq_size_s1_q[entry]<=3'b100))) : 
                                        (rxreq_ccid_s1_q[entry]==2'b01 ? (rdat_pdmask_q[entry][1]==1'b1) :
                                        ((rdat_pdmask_q[entry][1:0]==2'b11) | ((rdat_pdmask_q[entry][0]==1'b1) && (rxreq_size_s1_q[entry]<=3'b100)))))) : 
                                        (rxreq_size_s1_q[entry]<=3'b100) ? rdat_pdmask_q[entry][rxreq_ccid_s1_q[entry]]==1'b1 : 
                                        (rxreq_ccid_s1_q[entry][1]==1'b1 ? rdat_pdmask_q[entry][3:2]==2'b11 :
                                        ((rxreq_ccid_s1_q[entry][1]==1'b0) & (rdat_pdmask_q[entry][1:0]==2'b11)))) : 1'b0;
            assign txdat2_en_sx[entry] = (rdat_valid_q[entry] & (rxreq_size_s1_q[entry]==3'b110) & (txdat_fifo_rdy_sx_q[entry][0]) & (~txdat_fifo_rdy_sx_q[entry][1])) ? 
                                        (rxreq_ccid_s1_q[entry][1] ? (rxreq_device_s1_q[entry] ? 1'b1 : rdat_pdmask_q[entry][1:0]==2'b11) : 
                                        rdat_pdmask_q[entry][3:2]==2'b11) : 1'b0;
        end
    endgenerate
    assign txdat_en_sx = ((|txdat1_en_sx) || (|txdat2_en_sx));

    // One packet is enqueued per cycle, so the enqueue must name the entry that won it
    // rather than whichever entry last took AXI read data.
    always_comb begin: txdat_en_idx_comb_logic
        integer m;
        txdat_en_idx_sx = {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        for(m=`HNI_MSHR_ENTRIES_NUM-1; m>=0; m=m-1)begin
            if (txdat1_en_sx[m] | txdat2_en_sx[m])
                txdat_en_idx_sx = m[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk or posedge rst) begin: txdat_fifo_set_logic
        if(rst == 1'b1)
            txdat_fifo_set_s1_q <= {(`HNI_MSHR_ENTRIES_WIDTH+1){1'b0}};
        else if(txdat_en_sx)
            txdat_fifo_set_s1_q <= txdat_fifo_set_s1_q + 1;
    end

    generate
        for(entry=0;entry<(2*`HNI_MSHR_ENTRIES_NUM);entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: txdat_fifo_set_logic
                if(rst == 1'b1)
                    txdat_fifo_valid_s1_q[entry]        <= 1'b0;
                else if (mshr_txdat_won_sx && txdat_en_sx_q && (txdat_fifo_cnt_sx_q == entry))
                    txdat_fifo_valid_s1_q[entry]        <= 1'b0;
                else if (txdat_en_sx && (txdat_fifo_set_s1_q == entry)) begin
                    txdat_fifo_valid_s1_q[entry]        <= 1'b1;
                    txdat_fifo_entry_idx_sx_q[entry]    <= txdat_en_idx_sx;
                    txdat_fifo_dataid_s1_q[entry]       <= (txdat1_en_sx[txdat_en_idx_sx]) ? ((rxreq_ccid_s1_q[txdat_en_idx_sx][1]) ? 2'b10 : 2'b00) 
                                                            : ((rxreq_ccid_s1_q[txdat_en_idx_sx][1]) ? 2'b00 : 2'b10);
                end
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin: txdat_fifo_rdy_logic
                if (rst)begin
                    txdat_fifo_rdy_sx_q[entry]      <= 2'b00;
                end
                else if (txdat1_en_sx[entry] && (txdat_en_idx_sx == entry))
                    txdat_fifo_rdy_sx_q[entry][0]   <= 1'b1;
                else if (txdat2_en_sx[entry] && (txdat_en_idx_sx == entry))
                    txdat_fifo_rdy_sx_q[entry][1]   <= 1'b1;
                else if (retired_entry_sx[entry])
                    txdat_fifo_rdy_sx_q[entry]      <= 2'b00;
            end

            always_ff @(posedge clk or posedge rst)begin: txdat_sent_logic
                if (rst)begin
                    txdat_sent_sx_q[entry]      <= 2'b00;
                end
                else if (mshr_txdat_won_sx && (txdat_entry_idx_sx_q == entry) && (mshr_txdat_dataid_sx == 2'b00))
                    txdat_sent_sx_q[entry][0]   <= 1'b1;
                else if (mshr_txdat_won_sx && (txdat_entry_idx_sx_q == entry) && (mshr_txdat_dataid_sx == 2'b10))
                    txdat_sent_sx_q[entry][1]   <= 1'b1;
                else if (retired_entry_sx[entry])
                    txdat_sent_sx_q[entry]      <= 2'b00;
            end
        end
    endgenerate
    
    always_ff @(posedge clk or posedge rst) begin: txdat_fifo_idx_logic
        if(rst == 1'b1)
            txdat_fifo_cnt_sx_q     <= {(`HNI_MSHR_ENTRIES_WIDTH+1){1'b0}};
        else if(mshr_txdat_won_sx == 1'b1)
            txdat_fifo_cnt_sx_q     <= txdat_fifo_cnt_sx_q + 1;
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_txdat_logic
        if(rst == 1'b1) begin
            txdat_en_sx_q           <= 1'b0;
            txdat_entry_idx_sx_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(mshr_txdat_won_sx && mshr_txdat_en_sx)begin
            txdat_en_sx_q           <= 1'b0;
            txdat_entry_idx_sx_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(txdat_fifo_valid_s1_q[txdat_fifo_cnt_sx_q])begin
            txdat_en_sx_q           <= 1'b1;
            txdat_entry_idx_sx_q    <= txdat_fifo_entry_idx_sx_q[txdat_fifo_cnt_sx_q];
        end
    end

    assign mshr_txdat_en_sx         = txdat_en_sx_q; 
    assign mshr_txdat_dataid_sx     = txdat_fifo_dataid_s1_q[txdat_fifo_cnt_sx_q];
    assign mshr_txdat_txnid_sx      = rxreq_txnid_s1_q[txdat_entry_idx_sx_q];
    assign mshr_txdat_opcode_sx     = chie_pkg::DAT_COMPDATA;
    assign mshr_txdat_resp_sx       = chie_pkg::RESP_I;
    // Sec 9.4.4 (p.9-342, MUST) / Table 9-10 (p.9-343): the errored read still returns
    // its packets, carrying the Non-data Error.
    assign mshr_txdat_resperr_sx    = rxreq_err_s1_q[txdat_entry_idx_sx_q] ? chie_pkg::RESP_ERR_NON_DATA
                                    : ((rxreq_rd_s1_q[txdat_entry_idx_sx_q] & rxreq_excl_s1_q[txdat_entry_idx_sx_q] & (rxreq_excl_pass_s2_q[txdat_entry_idx_sx_q]))? chie_pkg::RESP_ERR_EX_OK : chie_pkg::RESP_ERR_NORM_OK);
    // Sec 4.2.5 (p.4-187, MUST): an Atomic's "inbound data size must be the same as
    // the outbound data size, except for in AtomicCompare ... half of the outbound",
    // and "Byte enables must be asserted for all valid data". Sec 9.4.4 (p.9-342)
    // keeps that structure on an errored return, so the extent is driven from the
    // request even though Sec 9.3 (p.9-336) leaves the data values invalid.
    assign atomic_ret_size_sx  = ((rxreq_opcode_s1_q[txdat_entry_idx_sx_q] == chie_pkg::REQ_ATOMICCOMPARE)
                               && (rxreq_size_s1_q[txdat_entry_idx_sx_q] != chie_pkg::SIZE_1B))
                               ? chie_pkg::size_e'(rxreq_size_s1_q[txdat_entry_idx_sx_q] - 3'b001)
                               : rxreq_size_s1_q[txdat_entry_idx_sx_q];
    assign atomic_ret_bytes_sx = {{chie_pkg::BE_WIDTH{1'b0}},1'b1} << atomic_ret_size_sx;
    // Sec 2.10.4 (p.2-136): "all bytes are located at their natural byte positions",
    // and Sec 2.10.5 (p.2-137) puts the returned value at the addressed byte.
    assign atomic_ret_off_sx   = rxreq_addr_s1_q[txdat_entry_idx_sx_q][4:0];
    assign mshr_txdat_be_ovr_en_sx = rxreq_errdat_s1_q[txdat_entry_idx_sx_q];

    always_comb begin: mshr_txdat_be_ovr_comb_logic
        integer m, lo, hi;
        lo = {27'b0, atomic_ret_off_sx};
        hi = lo + atomic_ret_bytes_sx[31:0];
        mshr_txdat_be_ovr_sx = '0;
        for(m=0; m<chie_pkg::BE_WIDTH; m=m+1)begin
            if ((m >= lo) && (m < hi))
                mshr_txdat_be_ovr_sx[m] = 1'b1;
        end
    end

    assign mshr_txdat_dbid_sx       = {{(12-`HNI_MSHR_ENTRIES_WIDTH){1'b0}}, txdat_entry_idx_sx_q};
    assign mshr_txdat_tgtid_sx      = rxreq_srcid_s1_q[txdat_entry_idx_sx_q];
    assign mshr_txdat_tracetag_sx   = rxreq_tracetag_s1_q[txdat_entry_idx_sx_q];

    //************************************************************************//

    //                       mshr AR channel logic

    //************************************************************************//
    assign arvalid_en_s1 = rxreq_alloc_en_s1_q ? ((~sleep_sx_q[mshr_entry_idx_alloc_s1_q]) && rxreq_rd_s1_q[mshr_entry_idx_alloc_s1_q]) : 1'b0;
    assign arvalid_en2_s1 = wakeup_valid ? rxreq_rd_s1_q[wakeup_idx_sx] : 1'b0;

    always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_set_logic
        if(rst == 1'b1) begin
            arvalid_fifo_set_sx_q <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(arvalid_en_s1 && arvalid_en2_s1) begin
            arvalid_fifo_set_sx_q <= arvalid_fifo_set_sx_q + 2;
        end
        else if (arvalid_en_s1 || arvalid_en2_s1) begin
            arvalid_fifo_set_sx_q <= arvalid_fifo_set_sx_q + 1;
        end
    end

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_set_logic
                if(rst == 1'b1)
                    arvalid_fifo_s1_q[entry]        <= 1'b0;
                else if ((arvalid_sx == 1'b1) && (arready_sx == 1'b1) && (arvalid_fifo_cnt_sx_q == entry))
                    arvalid_fifo_s1_q[entry]        <= 1'b0;
                else if (arvalid_en_s1 && arvalid_en2_s1 && (arvalid_fifo_set_sx_q == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= wakeup_idx_sx;
                end
                else if (arvalid_en_s1 && arvalid_en2_s1 && (((arvalid_fifo_set_sx_q == IDX_LAST) & (entry == 0)) | ((arvalid_fifo_set_sx_q +1) == entry))) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                end
                else if (arvalid_en_s1 && (arvalid_fifo_set_sx_q == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                end
                else if (arvalid_en2_s1 && (arvalid_fifo_set_sx_q == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= wakeup_idx_sx;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_cnt_logic
        if(rst == 1'b1)
            arvalid_fifo_cnt_sx_q     <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        else if((arvalid_sx == 1'b1) && (arready_sx == 1'b1))
            arvalid_fifo_cnt_sx_q     <= arvalid_fifo_cnt_sx_q + 1;
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_arvalid_logic
        if(rst == 1'b1) begin
            arvalid_sx        <= 1'b0;
            arvalid_entry_idx_s1_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if((arvalid_sx == 1'b1) && (arready_sx == 1'b1))begin
            arvalid_sx        <= 1'b0;
            arvalid_entry_idx_s1_q    <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(arvalid_fifo_s1_q[arvalid_fifo_cnt_sx_q])begin
            arvalid_sx        <= 1'b1;
            arvalid_entry_idx_s1_q    <= arvalid_fifo_idx_sx_q[arvalid_fifo_cnt_sx_q];
        end
    end

    assign arid_sx          = rxreq_axid_s1_q[arvalid_entry_idx_s1_q];
    assign araddr_sx        = rxreq_device_s1_q[arvalid_entry_idx_s1_q] ? rxreq_addr_s1_q[arvalid_entry_idx_s1_q][`AXI4_ARADDR_WIDTH-1:0] : rxreq_alignaddr_s1_q[arvalid_entry_idx_s1_q][`AXI4_ARADDR_WIDTH-1:0];
    assign arcache_sx[0]    = rxreq_memattr_s1_q[arvalid_entry_idx_s1_q][0];
    assign arcache_sx[1]    = ~rxreq_memattr_s1_q[arvalid_entry_idx_s1_q][1];
    assign arcache_sx[2]    = rxreq_memattr_s1_q[arvalid_entry_idx_s1_q][2];
    assign arcache_sx[3]    = rxreq_memattr_s1_q[arvalid_entry_idx_s1_q][3];
    assign arburst_sx       = 2'b01; 
    assign arlock_sx        = 1'b0;
    assign arprot_sx        = {1'b0,rxreq_ns_s1_q[arvalid_entry_idx_s1_q],1'b0};
    assign arqos_sx         = rxreq_qos_s1_q[arvalid_entry_idx_s1_q];
    assign arregion_sx      = {`AXI4_ARREGION_WIDTH{1'b0}};
    assign arlen_sx         = rxreq_axlen_s1_q[arvalid_entry_idx_s1_q];
    assign arsize_sx        = rxreq_axsize_s1_q[arvalid_entry_idx_s1_q];

    //************************************************************************//

    //                       mshr R channel logic

    //************************************************************************//
    assign mshr_rdat_en_sx          = ((arvalid_sx == 1'b1) && (arready_sx == 1'b1));
    assign mshr_rdat_entry_idx_sx   = mshr_rdat_en_sx ? arvalid_entry_idx_s1_q : 0;

    assign errdat_ready_sx = errdat_pending_q & (~sleep_sx_q);

    always_comb begin: errdat_inject_idx_comb_logic
        integer m;
        errdat_inject_idx_sx = {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        for(m=`HNI_MSHR_ENTRIES_NUM-1; m>=0; m=m-1)begin
            if (errdat_ready_sx[m])
                errdat_inject_idx_sx = m[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    // A full pending mask makes the packet count follow Size exactly as a real read
    // does, which is what Sec 9.3 (p.9-336) requires of an errored read. Injected only
    // when the read-data path is otherwise idle.
    assign errdat_inject_sx = (|errdat_ready_sx) & (~dbf_rvalid_sx) & (~txdat_en_sx);
    assign rdat_valid_sx    = dbf_rvalid_sx | errdat_inject_sx;
    assign rdat_idx_sx      = errdat_inject_sx ? errdat_inject_idx_sx : dbf_rvalid_entry_idx_sx;
    assign rdat_cdmask_sx   = errdat_inject_sx ? 4'b1111 : dbf_cdmask_sx;

    always_ff @(posedge clk or posedge rst) begin: rdat_entry_idx_s1_q_logic
        if(rst == 1'b1)
            rdat_entry_idx_s1_q <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        else if(rdat_valid_sx)
            rdat_entry_idx_s1_q <= rdat_idx_sx;
    end

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: rdat_valid_q_logic
                if(rst == 1'b1)
                    rdat_valid_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry])
                    rdat_valid_q[entry] <= 1'b0;
                else if (rdat_valid_sx && (rdat_idx_sx == entry))
                    rdat_valid_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst) begin: rdat_pdmask_q_logic
                if(rst == 1'b1)
                    rdat_pdmask_q[entry] <= 4'b0000;
                else if (rdat_valid_sx && (rdat_idx_sx == entry))
                    rdat_pdmask_q[entry] <= rdat_cdmask_sx | rdat_pdmask_q[entry];
                else if (retired_entry_sx[entry]) begin
                    rdat_pdmask_q[entry] <= 4'b0000;
                end
            end
        end
    endgenerate

    //************************************************************************//

    //                       mshr AW channel logic

    //************************************************************************//
    // Sec 9.4.4 (p.9-342, MUST): the write data transfer still takes place, but the
    // operation the error reports did not, so the write is withheld from memory.
    assign awvalid_en_s1 = dbf_rxdat_ok_s1 && (~rxreq_excl_fail_s2_q[rxdat_ok_idx_s1]) && (~rxreq_errwr_s1_q[rxdat_ok_idx_s1]);

    always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_set_cnt_logic
        if(rst == 1'b1) begin
            awvalid_fifo_set_s2_q   <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(awvalid_en_s1 == 1'b1) begin
            awvalid_fifo_set_s2_q   <= awvalid_fifo_set_s2_q + 1;
        end
    end

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_set_logic
                if(rst == 1'b1)
                    awvalid_fifo_s2_q[entry]        <= 1'b0;
                else if ((awvalid_sx == 1'b1) && (awready_sx == 1'b1) && (awvalid_fifo_cnt_sx_q == entry))
                    awvalid_fifo_s2_q[entry]        <= 1'b0;
                else if (awvalid_en_s1 && (awvalid_fifo_set_s2_q == entry)) begin
                    awvalid_fifo_s2_q[entry]        <= 1'b1;
                    awvalid_fifo_idx_s2_q[entry]    <= rxdat_ok_idx_s1;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_clr_logic
        if(rst == 1'b1)
            awvalid_fifo_cnt_sx_q   <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        else if((awvalid_sx == 1'b1) && (awready_sx == 1'b1))
            awvalid_fifo_cnt_sx_q   <= awvalid_fifo_cnt_sx_q + 1;
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_awvalid_logic
        if(rst == 1'b1) begin
            awvalid_sx              <= 1'b0;
            awvalid_entry_idx_s2_q  <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if((awvalid_sx == 1'b1) && (awready_sx == 1'b1))begin
            awvalid_sx              <= 1'b0;
        end
        else if(~wdat_wait_sx_q && awvalid_fifo_s2_q[awvalid_fifo_cnt_sx_q])begin
            awvalid_sx              <= 1'b1;
            awvalid_entry_idx_s2_q  <= awvalid_fifo_idx_s2_q[awvalid_fifo_cnt_sx_q];
        end
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_awvalid_s1_logic
        if(rst == 1'b1)
            awvalid_sx1_q   <= 1'b0;
        else
            awvalid_sx1_q   <= awvalid_sx;
    end

    //MemAttr propagation on AWCACHE
    // AWCACHE[0] (EWA) => MemAttr[0] (EWA)
    // AWCACHE[1] (Modifiable) => ~MemAttr[1] (Device)
    // AWCACHE[2] (Other Allocate) => MemAttr[2] (Cacheable)
    // AWCACHE[3] (Allocate) => MemAttr[3] (Allocate)
    //--------------------------------------------
    assign awid_sx          = rxreq_axid_s1_q[awvalid_entry_idx_s2_q];
    assign awaddr_sx        = rxreq_device_s1_q[awvalid_entry_idx_s2_q] ? rxreq_addr_s1_q[awvalid_entry_idx_s2_q][`AXI4_AWADDR_WIDTH-1:0] : rxreq_alignaddr_s1_q[awvalid_entry_idx_s2_q][`AXI4_AWADDR_WIDTH-1:0] ;
    assign awcache_sx[0]    = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][0];
    assign awcache_sx[1]    = ~rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][1];
    assign awcache_sx[2]    = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][2];
    assign awcache_sx[3]    = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][3];
    assign awqos_sx         = rxreq_qos_s1_q[awvalid_entry_idx_s2_q];
    assign awprot_sx        = {1'b0,rxreq_ns_s1_q[awvalid_entry_idx_s2_q],1'b0};       
    assign awlen_sx         = rxreq_axlen_s1_q[awvalid_entry_idx_s2_q];
    assign awsize_sx        = rxreq_axsize_s1_q[awvalid_entry_idx_s2_q];
    assign awburst_sx       = 2'b01;
    assign awlock_sx        = 1'b0;        
    assign awregion_sx      = {`AXI4_AWREGION_WIDTH{1'b0}};

    //************************************************************************//

    //                      mshr W channel logic

    //************************************************************************//
    assign mshr_wdat_en_sx          = ~awvalid_sx1_q & awvalid_sx;    //send data to axi slave enable
    assign mshr_wdat_entry_idx_sx   = awvalid_entry_idx_s2_q;

    always_ff @(posedge clk or posedge rst)begin : mshr_wdat_wait_logic
        if(rst == 1'b1)
            wdat_wait_sx_q  <= 1'b0;
        else if(mshr_wdat_en_sx == 1'b1)
            wdat_wait_sx_q  <= 1'b1;
        else if (dbf_wdat_last)
            wdat_wait_sx_q  <= 1'b0;
    end

    //************************************************************************//

    //                      mshr B channel decode logic

    //************************************************************************//  
    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_B_logic
                if (rst)
                    bresp_ok_q[entry] <= 1'b0;
                else if (retired_entry_sx[entry])
                    bresp_ok_q[entry] <= 1'b0;
                else if (bvalid_sx && bready_sx && (~sleep_sx_q[entry]) && (bid_sx == rxreq_axid_s1_q[entry]))
                    bresp_ok_q[entry] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    assign bready_sx    = ~rst;
    //************************************************************************//

    //                      mshr sleep/wakeup logic

    //************************************************************************//
    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign need_to_sleep_s0[entry] = rxreq_alloc_en_s0 && (~need_to_wakeup_q[entry]) && (rxreq_axid_s0 == rxreq_axid_s1_q[entry]);
        end
    endgenerate

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wakeup_logic
                if (rst == 1'b1) begin
                    need_to_wakeup_q[entry]     <= 1'b0;
                    need_to_wakeup_idx_q[entry] <= {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else if (retired_entry_sx1_q[entry] && (retired_entry_idx_sx1_q == entry)) begin
                    need_to_wakeup_q[entry]     <= 1'b0;
                end
                else if (need_to_sleep_s0[entry]) begin
                    need_to_wakeup_q[entry]     <= 1'b1;
                    need_to_wakeup_idx_q[entry] <= mshr_entry_idx_alloc_s0;
                end
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_sleep_logic
                if (rst == 1'b1) begin
                    sleep_sx_q[entry]               <= 1'b0;
                    mshr_entry_sleep_s1_q[entry]    <= 1'b0;
                end
                else if (wakeup_valid & (wakeup_idx_sx == entry)) begin
                    mshr_entry_sleep_s1_q[entry]    <= 1'b0;
                    sleep_sx_q[entry]               <= 1'b0;
                end
                else if (rxreq_alloc_en_s0 & (|need_to_sleep_s0) & (mshr_entry_idx_alloc_s0 == entry)) begin
                    sleep_sx_q[entry]               <= 1'b1;
                    mshr_entry_sleep_s1_q[entry]    <= 1'b1;
                end
                else
                    mshr_entry_sleep_s1_q[entry]    <= 1'b0;
            end
        end
    endgenerate

    assign mshr_entry_sleep_s1  = |mshr_entry_sleep_s1_q;
    assign wakeup_valid         = (|retired_entry_sx1_q) ? need_to_wakeup_q[retired_entry_idx_sx1_q] : 1'b0;
    assign wakeup_idx_sx        = (|retired_entry_sx1_q) ? need_to_wakeup_idx_q[retired_entry_idx_sx1_q] : {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};

    //************************************************************************//

    //                            mshr retire logic

    //************************************************************************//
    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign compack_ok_sx[entry]     = rxrsp_compack_s1_q[entry]|rxdat_compack_s1_q[entry];
            assign txdat_done_sx[entry]     = (txdat_sent_sx_q[entry] == 2'b11) | ((rxreq_size_s1_q[entry] <= 3'b101) & (|txdat_sent_sx_q[entry]));
            assign txrsp_all_sent_sx[entry] = txrsp_sent_q[entry] & (~(rxreq_cw_s1_q[entry] & (~txrsp_second_sent_q[entry])));
            // Sec 4.5.1 (p.4-197): PrefetchTgt and PCrdReturn are owed no response, so
            // the entry is freed at once rather than held.
            assign retired_entry_sx[entry]  = mshr_entry_valid_sx_q[entry] & (~sleep_sx_q[entry])
                                            & ( rxreq_drop_s1_q[entry]
                                              | ( txrsp_all_sent_sx[entry] & (~(rxreq_expcompack_s1_q[entry] & (~compack_ok_sx[entry])))
                                                & ( ((rxreq_wrf_s1_q[entry] | rxreq_wrp_s1_q[entry]) & (bresp_ok_q[entry] | (dbf_rxdat_ok_s2_q[entry] & rxreq_excl_fail_s2_q[entry])))
                                                  | ((rxreq_rd_s1_q[entry] | rxreq_errrd_s1_q[entry]) & txdat_done_sx[entry])
                                                  | (rxreq_errwr_s1_q[entry] & dbf_rxdat_ok_s2_q[entry] & ((~rxreq_errdat_s1_q[entry]) | txdat_done_sx[entry]))
                                                  | (~(rxreq_rd_s1_q[entry] | rxreq_errrd_s1_q[entry] | rxreq_wrf_s1_q[entry] | rxreq_wrp_s1_q[entry] | rxreq_errwr_s1_q[entry]))
                                                  )
                                                )
                                              );
        end
    endgenerate

    generate
        for(entry=0;entry<`HNI_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin
                if(rst == 1'b1) begin
                    retired_entry_sx1_q[entry]  <= 1'b0;
                end
                else if (retired_entry_sx[entry]) begin 
                    retired_entry_sx1_q[entry]  <= 1'b1;
                end 
                else if (mshr_retired_valid_sx & (mshr_retired_idx_sx == entry)) begin
                    retired_entry_sx1_q[entry]  <= 1'b0;
                end
            end
        end
    endgenerate

    always_comb begin:retired_entry_idx_logic
        retired_entry_idx_sx1_q = {`HNI_MSHR_ENTRIES_WIDTH{1'b0}};
        for (int k =0; k < `HNI_MSHR_ENTRIES_NUM; k=k+1) begin
            if(retired_entry_sx1_q[k])
                retired_entry_idx_sx1_q = k[`HNI_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    assign mshr_retired_valid_sx    = |retired_entry_sx1_q;
    assign mshr_retired_idx_sx      = retired_entry_idx_sx1_q;


endmodule

