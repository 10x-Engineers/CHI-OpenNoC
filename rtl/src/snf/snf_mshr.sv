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

module snf_mshr `SNF_PARAM
    (
        input  wire                               clk,
        input  wire                               rst,
        input  wire                               rxreq_alloc_en_s0,
        input  chie_pkg::req_flit_s               rxreq_alloc_flit_s0,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_entry_idx_alloc_s0,

        output  wire                               txrsp_valid_sx,
        output  logic [3:0]                        txrsp_qos_sx,
        output  logic [chie_pkg::NID_WIDTH-1:0]    txrsp_tgtid_sx,
        output  logic [11:0]                       txrsp_txnid_sx,
        output  chie_pkg::rsp_opcode_e             txrsp_opcode_sx,
        output  chie_pkg::resp_err_e               txrsp_resperr_sx,
        output  chie_pkg::resp_state_e             txrsp_resp_sx,
        output  logic [11:0]                       txrsp_dbid_sx,
        output  logic [chie_pkg::NID_WIDTH-1:0]    txrsp_srcid_sx,
        output  logic                              txrsp_tracetag_sx,

        input  wire                               txrsp_won_sx,
        output  wire                               rxreq_dbf_en_s1,
        output  logic [chie_pkg::REQ_ADDR_WIDTH-1:0] rxreq_dbf_addr_s1,
        output  wire                               rxreq_dbf_wr_s1,
        output  wire                               rxreq_dbf_wrzero_s1,
        output  chie_pkg::size_e                   rxreq_dbf_size_s1,
        output  wire [`AXI4_ARLEN_WIDTH-1:0]       rxreq_dbf_axlen_s1,
        output  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] rxreq_dbf_entry_idx_s1,
        input  wire                               dbf_mshr_rdata_en_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] dbf_mshr_rdata_idx_sx,
        input  wire [`SNF_MASK_CD_WIDTH-1:0]      dbf_mshr_rdata_cdmask_sx,
        input  wire                               dbf_mshr_rxdat_ok_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] dbf_mshr_rxdat_ok_idx_sx,
        input  wire                               dbf_mshr_rxdat_cancel_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] dbf_mshr_rxdat_cancel_idx_sx,
        output  wire                               mshr_txdat_en_sx,
        output  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_txdat_entry_idx_sx,
        output  logic [1:0]                        mshr_txdat_dataid_sx,
        output  logic [11:0]                       mshr_txdat_txnid_sx,
        output  chie_pkg::dat_opcode_e             mshr_txdat_opcode_sx,
        output  chie_pkg::resp_state_e             mshr_txdat_resp_sx,
        output  chie_pkg::resp_err_e               mshr_txdat_resperr_sx,
        output  logic [11:0]                       mshr_txdat_dbid_sx,
        output  logic [chie_pkg::NID_WIDTH-1:0]    mshr_txdat_tgtid_sx,
        output  logic [chie_pkg::NID_WIDTH-1:0]    mshr_txdat_srcid_sx,
        output  logic [chie_pkg::NID_WIDTH-1:0]    mshr_txdat_homenid_sx,
        output  logic                              mshr_txdat_tracetag_sx,
        input  wire                               mshr_txdat_won_sx,
        output  wire                               mshr_wdat_en_sx,
        output  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_wdat_entry_idx_sx,
        output  wire                               mshr_retired_valid_sx,
        output  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0] mshr_retired_idx_sx,
        output  wire [`AXI4_ARID_WIDTH-1:0]        arid_sx,
        output  wire [`AXI4_ARADDR_WIDTH-1:0]      araddr_sx,
        output  wire [`AXI4_ARLEN_WIDTH-1:0]       arlen_sx,
        output  wire [`AXI4_ARSIZE_WIDTH-1:0]      arsize_sx,
        output  wire [`AXI4_ARBURST_WIDTH-1:0]     arburst_sx,
        output  wire [`AXI4_ARLOCK_WIDTH-1:0]      arlock_sx,
        output  wire [`AXI4_ARCACHE_WIDTH-1:0]     arcache_sx,
        output  wire [`AXI4_ARPROT_WIDTH-1:0]      arprot_sx,
        output  wire [`AXI4_ARQOS_WIDTH-1:0]       arqos_sx,
        output  wire [`AXI4_ARREGION_WIDTH-1:0]    arregion_sx,
        output  logic                              arvalid_sx,
        input  wire                               arready_sx,
        output  wire [`AXI4_AWID_WIDTH-1:0]        awid_sx,
        output  wire [`AXI4_AWADDR_WIDTH-1:0]      awaddr_sx,
        output  wire [`AXI4_AWLEN_WIDTH-1:0]       awlen_sx,
        output  wire [`AXI4_AWSIZE_WIDTH-1:0]      awsize_sx,
        output  wire [`AXI4_AWBURST_WIDTH-1:0]     awburst_sx,
        output  wire [`AXI4_AWLOCK_WIDTH-1:0]      awlock_sx,
        output  wire [`AXI4_AWCACHE_WIDTH-1:0]     awcache_sx,
        output  wire [`AXI4_AWPROT_WIDTH-1:0]      awprot_sx,
        output  wire [`AXI4_AWQOS_WIDTH-1:0]       awqos_sx,
        output  wire [`AXI4_AWREGION_WIDTH-1:0]    awregion_sx,
        output  logic                              awvalid_sx,
        input  wire                               awready_sx,
        input  wire [`AXI4_BID_WIDTH-1:0]         bid_sx,
        input  wire [`AXI4_BRESP_WIDTH-1:0]       bresp_sx,
        input  wire                               bvalid_sx,
        output  wire                               bready_sx
    );
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   mshr_entry_idx_alloc_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     mshr_entry_valid_sx_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     sleep_s2_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   hazard_idx_s2_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     hazard_sx_q;
    logic                                                 rxreq_alloc_en_s1_q;
    chie_pkg::req_opcode_e               rxreq_opcode_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [3:0]                  rxreq_qos_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::memattr_s              rxreq_memattr_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::NID_WIDTH-1:0]                rxreq_srcid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [11:0]                rxreq_txnid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::size_e                 rxreq_size_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]                 rxreq_addr_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic                   rxreq_ns_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    chie_pkg::order_e                rxreq_order_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [11:0]          rxreq_returntxnid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic             rxreq_tracetag_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [chie_pkg::NID_WIDTH-1:0]            rxreq_returnnid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [1:0]                 rxreq_ccid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_AXID_WIDTH-1:0]                          rxreq_axid_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_ARLEN_WIDTH-1:0]                         rxreq_axlen_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_ARSIZE_WIDTH-1:0]                        rxreq_axsize_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`AXI4_AXADDR_WIDTH-1:0]                        rxreq_axaddr_s1_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_wr_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_wrzero_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_rd_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_dodmt_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_dodwt_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxreq_ewa_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     txrsp_comp_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     txrsp_comp_sent_sx_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     txrsp_rdreceipt_valid_sx_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     txrsp_rdy_sx_q;
    chie_pkg::rsp_opcode_e               txrsp_opcode_rdy_sx_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   txrsp_entry_idx_sx;
    logic [1:0]                                           txdat_rdy_sx_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   txdat_entry_idx_sx;
    logic                                                 txdat_en_sx_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   txdat_entry_idx_sx_q;
    logic [1:0]                                           txdat_sent_sx_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     arvalid_fifo_s1_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   arvalid_fifo_idx_sx_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   arvalid_fifo_set_vec;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   arvalid_fifo_vec;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   arvalid_entry_idx_s1_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rdat_valid_s1_q;
    logic [3:0]                                           rdat_pdmask_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     awvalid_fifo_valid_s2_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   awvalid_fifo_idx_s2_q[`SNF_MSHR_ENTRIES_NUM-1:0];
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   awvalid_fifo_cnt_sx_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   awvalid_fifo_vec_sx;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   awvalid_entry_idx_s2_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     bresp_ok_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     bresp_err_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     retired_entry_sx1_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0]                   retired_entry_idx_sx1_q;
    logic                                                 mshr_wdat_en_rst;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]                     rxdat_cancel_s1_q;

    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    mshr_entry_alloc_sx;
    logic [3:0]                                        rxreq_qos_s0;
    logic [chie_pkg::NID_WIDTH-1:0]                    rxreq_srcid_s0;
    logic [11:0]                                       rxreq_txnid_s0;
    chie_pkg::req_opcode_e                             rxreq_opcode_s0;
    chie_pkg::size_e                                   rxreq_size_s0;
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0]               rxreq_addr_s0;
    logic [chie_pkg::NID_WIDTH-1:0]                    rxreq_returnnid_s0;
    logic [11:0]                                       rxreq_returntxnid_s0;
    wire                                                rxreq_dodmt_s0;
    wire                                                rxreq_dodwt_s0;
    logic                                              rxreq_ns_s0;
    chie_pkg::order_e                                  rxreq_order_s0;
    logic [3:0]                                        rxreq_pcrdtype_s0;
    chie_pkg::memattr_s                                rxreq_memattr_s0;
    logic                                              rxreq_tracetag_s0;
    wire                                                rxreq_ewa_s0;
    wire                                                rxreq_rd_s0;
    wire                                                rxreq_wr_s0;
    wire                                                rxreq_rdsep_s0;
    wire                                                rxreq_cmo_s0;
    wire                                                rxreq_cmopersist_s0;
    wire                                                rxreq_cw_s0;
    wire                                                rxreq_cwpersist_s0;
    wire                                                rxreq_atomic_s0;
    wire                                                rxreq_atomicdat_s0;
    wire                                                rxreq_wrzero_s0;
    wire                                                rxreq_drop_s0;
    wire                                                rxreq_errwr_s0;
    wire                                                rxreq_errdat_s0;
    wire                                                rxreq_errrsp_s0;
    wire                                                rxreq_err_s0;
    wire                                                rxreq_rsponly_s0;
    chie_pkg::rsp_opcode_e              rxreq_rsponly_opcode_s0;
    wire                                                rxreq_errgrant_s0;
    wire                                                txrsp_rsponly_en_s1;
    wire                                                txrsp_errgrant_en_s1;
    wire                                                txrsp_rsponly_en_sx;
    wire                                                txrsp_errgrant_en_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txdat_errdat_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    all_rsp_sent_sx;
    wire                                                txrsp_sent_sx;
    wire                                                txrsp_en_s1;
    wire                                                txrsp_en_sx;
    wire                                                txrsp_readreceipt_en_s1;
    wire                                                txrsp_compdbidresp_en_s1;
    wire                                                txrsp_dbidresp_en_s1;
    chie_pkg::rsp_opcode_e              txrsp_opcode_en_s1;
    wire                                                txrsp_compdbidresp_en_sx;
    wire                                                txrsp_dbidresp_en_sx;
    wire                                                txrsp_ewa_dwt_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]                  txrsp_ewa_dwt_rdy_entry_sx;
    wire                                                txrsp_noewa_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]                  txrsp_noewa_rdy_entry_sx;
    chie_pkg::rsp_opcode_e              txrsp_opcode_en_sx;
    wire                                                txrsp_update_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_valid_idx_sx;
    wire                                                txrsp_comp_wrdatcancel_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]                  txrsp_comp_wrcancel_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txdat1_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txdat2_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    rdat_allrcvd_sx;
    wire                                                arvalid_en_s1;
    wire                                                arvalid_en2_s1;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    bresp_ok_sx;
    wire                                                wakeup_valid;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]                  wakeup_idx_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    retired_entry_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txdat_valid_sx;
    wire                                                mshr_txdat_update;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    mshr_txdat_idx_vec;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    hazard_sx;
    wire                                                sel_idx_valid;

    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_rdsep_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_errwr_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_errdat_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_err_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_rsponly_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_errgrant_s1_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    errwr_data_done_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    rxreq_drop_s1_q;
    chie_pkg::rsp_opcode_e              rxreq_rsponly_opcode_s1_q [`SNF_MSHR_ENTRIES_NUM-1:0];
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_q2_valid_q;
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_cmo_owed_q;
    chie_pkg::rsp_opcode_e              txrsp_cmo_opcode_q [`SNF_MSHR_ENTRIES_NUM-1:0];
    logic  [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_any_sent_q;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_comp_rdy_sx;
    wire [`SNF_MSHR_ENTRIES_NUM-1:0]                    txrsp_comp_queued_sx;

    genvar entry;

    localparam [31:0]                          ENTRIES_M1 = `SNF_MSHR_ENTRIES_NUM-1;
    localparam [31:0]                          ENTRIES_M2 = `SNF_MSHR_ENTRIES_NUM-2;
    localparam [`SNF_MSHR_ENTRIES_WIDTH-1:0]   IDX_ONE    = {{(`SNF_MSHR_ENTRIES_WIDTH-1){1'b0}}, 1'b1};
    localparam [`SNF_MSHR_ENTRIES_WIDTH-1:0]   IDX_TWO    = {{(`SNF_MSHR_ENTRIES_WIDTH-2){1'b0}}, 2'd2};
    localparam [`SNF_MSHR_ENTRIES_WIDTH-1:0]   IDX_LAST   = ENTRIES_M1[`SNF_MSHR_ENTRIES_WIDTH-1:0];
    localparam [`SNF_MSHR_ENTRIES_WIDTH-1:0]   IDX_LAST_M1= ENTRIES_M2[`SNF_MSHR_ENTRIES_WIDTH-1:0];

    //************************************************************************//
    //                     request fields decode logic                        //
    //************************************************************************//

    assign rxreq_qos_s0         = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.qos          : '0;
    assign rxreq_srcid_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.srcid        : '0;
    assign rxreq_txnid_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.txnid        : '0;
    assign rxreq_opcode_s0      = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.opcode       : chie_pkg::REQ_REQLCRDRETURN;
    assign rxreq_size_s0        = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.size         : chie_pkg::SIZE_1B;
    assign rxreq_addr_s0        = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.addr         : '0;
    assign rxreq_ns_s0          = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.ns           : '0;
    assign rxreq_order_s0       = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.order        : chie_pkg::ORDER_NONE;
    assign rxreq_pcrdtype_s0    = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.pcrdtype     : '0;
    assign rxreq_memattr_s0     = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.memattr      : '0;
    assign rxreq_tracetag_s0    = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.tracetag     : '0;
    assign rxreq_returnnid_s0   = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.returnnid    : '0;
    assign rxreq_returntxnid_s0 = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.returntxnid  : '0;
    assign rxreq_dodmt_s0       = (rxreq_alloc_en_s0 == 1'b1)? (rxreq_rd_s0 == 1'b1) && (rxreq_alloc_flit_s0.srcid != rxreq_alloc_flit_s0.returnnid) :1'b0;
    // Sec 4.2.1 (p.4-176): "DWT flow between a Request Node and a Subordinate Node
    // in WriteNoSnpZero and WriteUniqueZero is never permitted."
    assign rxreq_dodwt_s0       = (rxreq_alloc_en_s0 == 1'b1)? (rxreq_wr_s0 == 1'b1) && (~rxreq_wrzero_s0) && (rxreq_alloc_flit_s0.snpattr.dodwt)      :1'b0;
    // CHI E.b Sec 4.5.1 (p.4-197, MUST): "A completion response is required for all
    // transactions except PCrdReturn and PrefetchTgt." Every inbound request is
    // therefore classified here, and every class below owns a response programme.
    assign rxreq_rdsep_s0       = (rxreq_opcode_s0 == chie_pkg::REQ_READNOSNPSEP);
    assign rxreq_rd_s0          = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_READNOSNP) | rxreq_rdsep_s0) :1'b0;
    // A Combined Write carries a real write leg: Sec 2.3.9 (p.2-80) has the
    // Subordinate grant a DBID, take NCBWrData and complete it exactly as a plain
    // WriteNoSnp*, with the CMO leg's CompCMO/CompPersist owed on top.
    assign rxreq_wr_s0          = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULL)|(rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTL)|rxreq_cw_s0|rxreq_wrzero_s0):1'b0;
    assign rxreq_cmopersist_s0  = (rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHAREDPERSISTSEP);
    // A CMO at a Subordinate holding no cached copy is a no-op that owes only its
    // completion (Sec 2.3.9 p.2-81); Sec 2.3.5 (p.2-74) lets the *PersistSep one
    // fold its Persist into CompPersist.
    assign rxreq_cmo_s0         = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHARED)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_CLEANINVALID)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_MAKEINVALID)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_CLEANSHAREDPERSIST)
                                                              | rxreq_cmopersist_s0) :1'b0;
    assign rxreq_cwpersist_s0   = (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP)
                                | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP);
    assign rxreq_cw_s0          = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANSH)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPFULLCLEANINV)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANSH)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPPTLCLEANINV)
                                                              | rxreq_cwpersist_s0) :1'b0;
    assign rxreq_atomic_s0      = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 >= chie_pkg::REQ_ATOMICSTORE_ADD)
                                                             && (rxreq_opcode_s0 <= chie_pkg::REQ_ATOMICCOMPARE)) :1'b0;
    assign rxreq_atomicdat_s0   = rxreq_atomic_s0 && (rxreq_opcode_s0 >= chie_pkg::REQ_ATOMICLOAD_ADD);
    assign rxreq_wrzero_s0      = (rxreq_alloc_en_s0 == 1'b1)? (rxreq_opcode_s0 == chie_pkg::REQ_WRITENOSNPZERO) :1'b0;
    // Sec 2.3.6 (p.2-74), Sec 4.5.4 (p.4-207): given no response, so no entry.
    assign rxreq_drop_s0        = (rxreq_alloc_en_s0 == 1'b1)? ((rxreq_opcode_s0 == chie_pkg::REQ_PREFETCHTGT)
                                                              | (rxreq_opcode_s0 == chie_pkg::REQ_PCRDRETURN)) :1'b0;
    // Sec 9.1 (p.9-334): NDERR is what a Completer reports for "an attempt to use a
    // transaction type that is not supported", and Sec 16.3.3 (p.16-479, MUST) makes
    // it mandatory for an Atomic. Sec 9.4.4 (p.9-342, MUST) then keeps the whole
    // transaction structure -- grant, write data, read data -- so the class carries
    // its shape as well as its error.
    assign rxreq_err_s0         = rxreq_alloc_en_s0 && ~(rxreq_rd_s0 | rxreq_wr_s0 | rxreq_cmo_s0 | rxreq_drop_s0);
    assign rxreq_errwr_s0       = rxreq_err_s0 && (rxreq_cw_s0 | rxreq_atomic_s0);
    assign rxreq_errdat_s0      = rxreq_err_s0 && rxreq_atomicdat_s0;
    assign rxreq_errrsp_s0      = rxreq_err_s0 && ~rxreq_errwr_s0 && ~rxreq_wrzero_s0;
    assign rxreq_rsponly_s0     = rxreq_cmo_s0 | rxreq_errrsp_s0;
    assign rxreq_rsponly_opcode_s0 = rxreq_cmopersist_s0 ? chie_pkg::RSP_COMPPERSIST : chie_pkg::RSP_COMP;
    assign rxreq_errgrant_s0    = rxreq_errwr_s0;
    assign rxreq_ewa_s0         = (rxreq_alloc_en_s0 == 1'b1)? rxreq_alloc_flit_s0.memattr.early_wr_ack  : 1'b0;

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign mshr_entry_alloc_sx[entry] = (rxreq_alloc_en_s0 == 1'b1) && (mshr_entry_idx_alloc_s0 == entry);
        end
    endgenerate

    //************************************************************************//
    //                             FIELD REG                                  //
    //************************************************************************//

    always_ff @(posedge clk)begin : mshr_rxreq_alloc_s1_q_timing_logic
            if(rst)begin
                rxreq_alloc_en_s1_q         <= 1'b0;
                mshr_entry_idx_alloc_s1_q   <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
            end
            else begin
                rxreq_alloc_en_s1_q         <= rxreq_alloc_en_s0;
                mshr_entry_idx_alloc_s1_q   <= mshr_entry_idx_alloc_s0;
            end
        end

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk)begin : mshr_entry_valid_s1_q_timing_logic
                if(rst == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    mshr_entry_valid_sx_q[entry] <= 1'b1;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_wr_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_wr_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_wr_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1 && rxreq_wr_s0)
                    rxreq_wr_s1_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_wrzero_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_wrzero_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_wrzero_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_wrzero_s1_q[entry] <= rxreq_wrzero_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_rd_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_rd_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_rd_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1 && rxreq_rd_s0)
                    rxreq_rd_s1_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_class_s1_q_timing_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)begin
                    rxreq_rdsep_s1_q[entry]    <= 1'b0;
                    rxreq_errwr_s1_q[entry]    <= 1'b0;
                    rxreq_errdat_s1_q[entry]   <= 1'b0;
                    rxreq_errgrant_s1_q[entry] <= 1'b0;
                    rxreq_err_s1_q[entry]      <= 1'b0;
                    rxreq_rsponly_s1_q[entry]  <= 1'b0;
                    rxreq_drop_s1_q[entry]     <= 1'b0;
                    rxreq_rsponly_opcode_s1_q[entry] <= chie_pkg::RSP_RSPLCRDRETURN;
                end
                else if(mshr_entry_alloc_sx[entry] == 1'b1)begin
                    rxreq_rdsep_s1_q[entry]    <= rxreq_rd_s0 & rxreq_rdsep_s0;
                    rxreq_errwr_s1_q[entry]    <= rxreq_errwr_s0;
                    rxreq_errdat_s1_q[entry]   <= rxreq_errdat_s0;
                    rxreq_errgrant_s1_q[entry] <= rxreq_errgrant_s0;
                    rxreq_err_s1_q[entry]      <= rxreq_err_s0;
                    rxreq_rsponly_s1_q[entry]  <= rxreq_rsponly_s0;
                    rxreq_drop_s1_q[entry]     <= rxreq_drop_s0;
                    rxreq_rsponly_opcode_s1_q[entry] <= rxreq_rsponly_opcode_s0;
                end
            end

            // The RSP the entry sends after the one currently armed, and the CMO
            // leg a Combined Write owes on top of its write completion
            // (Sec 2.3.9 p.2-80, Sec 9.4.3 p.9-341).
            always_ff @(posedge clk or posedge rst)begin : txrsp_queue_alloc_timing_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)begin
                    txrsp_q2_valid_q[entry]   <= 1'b0;
                    txrsp_cmo_owed_q[entry]   <= 1'b0;
                    txrsp_cmo_opcode_q[entry] <= chie_pkg::RSP_RSPLCRDRETURN;
                end
                else if(mshr_entry_alloc_sx[entry] == 1'b1)begin
                    txrsp_q2_valid_q[entry]   <= rxreq_errgrant_s0 & ~rxreq_errdat_s0 & ~rxreq_ewa_s0;
                    txrsp_cmo_owed_q[entry]   <= rxreq_cw_s0;
                    txrsp_cmo_opcode_q[entry] <= rxreq_cwpersist_s0 ? chie_pkg::RSP_COMPPERSIST : chie_pkg::RSP_COMPCMO;
                end
                else if(txrsp_sent_sx && (entry == txrsp_entry_idx_sx))begin
                    if (txrsp_comp_queued_sx[entry])
                        txrsp_q2_valid_q[entry]   <= 1'b0;
                    else
                        txrsp_cmo_owed_q[entry]   <= 1'b0;
                end
                else if(txrsp_comp_rdy_sx[entry] && txrsp_rdy_sx_q[entry])
                    txrsp_q2_valid_q[entry]   <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst)begin : txrsp_any_sent_timing_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    txrsp_any_sent_q[entry] <= 1'b0;
                else if(txrsp_sent_sx && (entry == txrsp_entry_idx_sx))
                    txrsp_any_sent_q[entry] <= 1'b1;
            end

            // Sec 9.4.4 (p.9-342, MUST): an errored request still transfers its
            // write data, so the entry is only freed once that data has landed.
            always_ff @(posedge clk or posedge rst)begin : errwr_data_done_timing_logic
                if(rst == 1'b1 || retired_entry_sx[entry] == 1'b1)
                    errwr_data_done_q[entry] <= 1'b0;
                else if(dbf_mshr_rxdat_ok_sx && (entry == dbf_mshr_rxdat_ok_idx_sx))
                    errwr_data_done_q[entry] <= 1'b1;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_dodmt_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_dodmt_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_dodmt_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_dodmt_s1_q[entry] <= rxreq_dodmt_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_dodwt_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_dodwt_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_dodwt_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_dodwt_s1_q[entry] <= rxreq_dodwt_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : rxreq_ewa_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_ewa_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_ewa_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_ewa_s1_q[entry] <= rxreq_ewa_s0;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_qos_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_qos_s1_q[entry] <= {4{1'b0}};
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_qos_s1_q[entry] <= {4{1'b0}};
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_qos_s1_q[entry] <= rxreq_qos_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_srcid_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_srcid_s1_q[entry] <= {chie_pkg::NID_WIDTH{1'b0}};
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_srcid_s1_q[entry] <= {chie_pkg::NID_WIDTH{1'b0}};
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_srcid_s1_q[entry] <= rxreq_srcid_s0;
                else
                    ;
            end


            always_ff @(posedge clk or posedge rst)begin : mshr_txnid_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_txnid_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_txnid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_txnid_s1_q[entry] <= rxreq_txnid_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_opcode_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_opcode_s1_q[entry] <= chie_pkg::REQ_REQLCRDRETURN;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_opcode_s1_q[entry] <= chie_pkg::REQ_REQLCRDRETURN;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_opcode_s1_q[entry] <= rxreq_opcode_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_size_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_size_s1_q[entry] <= chie_pkg::SIZE_1B;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_size_s1_q[entry] <= chie_pkg::SIZE_1B;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_size_s1_q[entry] <= rxreq_size_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_addr_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_addr_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_addr_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_addr_s1_q[entry] <= rxreq_addr_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_ns_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_ns_s1_q[entry] <= 1'b0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_ns_s1_q[entry] <= 1'b0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_ns_s1_q[entry] <= rxreq_ns_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_order_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_order_s1_q[entry] <= chie_pkg::ORDER_NONE;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_order_s1_q[entry] <= chie_pkg::ORDER_NONE;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_order_s1_q[entry] <= rxreq_order_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_memattr_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_memattr_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_memattr_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_memattr_s1_q[entry] <= rxreq_memattr_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_tracetag_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_tracetag_s1_q[entry] <= rxreq_tracetag_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_returnnid_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_returnnid_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_returnnid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_returnnid_s1_q[entry] <= rxreq_returnnid_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_returntxnid_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_returntxnid_s1_q[entry] <= '0;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_returntxnid_s1_q[entry] <= '0;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_returntxnid_s1_q[entry] <= rxreq_returntxnid_s0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_ccid_s1_q_timing_logic
                if(rst == 1'b1)
                    rxreq_ccid_s1_q[entry] <= 2'b00;
                else if(retired_entry_sx[entry] == 1'b1)
                    rxreq_ccid_s1_q[entry] <= 2'b00;
                else if(mshr_entry_alloc_sx[entry] == 1'b1)
                    rxreq_ccid_s1_q[entry] <= rxreq_addr_s0[5:4];
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//
    //                            AXI SIGNAL                                  //
    //************************************************************************//

    // The AXI mapping of a request depends only on that request, so it is
    // decoded once here rather than rebuilt inside each of the N entry slots.
    // unique: Table 2-16 (SS2.10.5 p.2-137) gives Size seven encodings and they
    // are mutually exclusive, so the arms are a parallel mux, not a chain.
    logic [`AXI4_AXADDR_WIDTH-1:0] rxreq_axaddr_s0;
    logic [`AXI4_ARLEN_WIDTH-1:0]  rxreq_axlen_s0;
    logic [`AXI4_AWSIZE_WIDTH-1:0] rxreq_axsize_s0;

    always_comb begin : rxreq_axi_map_t
        unique case (rxreq_size_s0)
            chie_pkg::SIZE_1B  : rxreq_axaddr_s0 =  rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:0];
            chie_pkg::SIZE_2B  : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],rxreq_addr_s0[5:1],1'b0};
            chie_pkg::SIZE_4B  : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],rxreq_addr_s0[5:2],2'b0};
            chie_pkg::SIZE_8B  : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],rxreq_addr_s0[5:3],3'b0};
            chie_pkg::SIZE_16B : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],rxreq_addr_s0[5:4],4'b0};
            chie_pkg::SIZE_32B : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],rxreq_addr_s0[5:5],5'b0};
            chie_pkg::SIZE_64B : rxreq_axaddr_s0 = {rxreq_addr_s0[`AXI4_AXADDR_WIDTH-1:6],6'b0};
            default            : rxreq_axaddr_s0 = '0;
        endcase

        unique case (rxreq_size_s0)
            chie_pkg::SIZE_1B, chie_pkg::SIZE_2B, chie_pkg::SIZE_4B,
            chie_pkg::SIZE_8B, chie_pkg::SIZE_16B : begin
                rxreq_axlen_s0  = '0;
                rxreq_axsize_s0 = rxreq_size_s0;
            end
            chie_pkg::SIZE_32B : begin
                rxreq_axlen_s0  = (`AXI4_AXDATA_WIDTH == 128) ? 8'd1 : 8'd0;
                rxreq_axsize_s0 = (`AXI4_AXDATA_WIDTH == 128) ? 3'b100 : 3'b101;
            end
            chie_pkg::SIZE_64B : begin
                rxreq_axlen_s0  = (`AXI4_AXDATA_WIDTH == 128) ? 8'd3 : 8'd1; //4len,2len
                rxreq_axsize_s0 = (`AXI4_AXDATA_WIDTH == 128) ? 3'b100 : 3'b101; //16B,32B
            end
            default : begin
                rxreq_axlen_s0  = '0;
                rxreq_axsize_s0 = '0;
            end
        endcase
    end

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                        rxreq_axaddr_s1_q[entry] <= {`AXI4_AXADDR_WIDTH{1'b0}};
                end
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                        rxreq_axaddr_s1_q[entry] <= {`AXI4_AXADDR_WIDTH{1'b0}};
                end
                else if (rxreq_alloc_en_s0 && (entry == mshr_entry_idx_alloc_s0))begin
                    rxreq_axaddr_s1_q[entry] <= rxreq_axaddr_s0;
                end
                else begin
                        rxreq_axaddr_s1_q[entry] <= rxreq_axaddr_s1_q[entry];
                end
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_axid_timing_logic
                if(rst == 1'b1)
                    rxreq_axid_s1_q[entry] <= 0;
                else if (retired_entry_sx[entry] == 1'b1)
                    rxreq_axid_s1_q[entry] <= {`AXI4_AXID_WIDTH{1'b0}};
                else if (rxreq_alloc_en_s0 && (entry == mshr_entry_idx_alloc_s0))
                    rxreq_axid_s1_q[entry] <= {{(`AXI4_AXID_WIDTH-`SNF_MSHR_ENTRIES_WIDTH){1'b0}}, mshr_entry_idx_alloc_s0};
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    rxreq_axlen_s1_q[entry]  <= {`AXI4_ARLEN_WIDTH{1'b0}};
                    rxreq_axsize_s1_q[entry] <= {`AXI4_AWSIZE_WIDTH{1'b0}};
                end
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                    rxreq_axlen_s1_q[entry]  <= {`AXI4_ARLEN_WIDTH{1'b0}};
                    rxreq_axsize_s1_q[entry] <= {`AXI4_AWSIZE_WIDTH{1'b0}};
                end
                else if (rxreq_alloc_en_s0 && (entry == mshr_entry_idx_alloc_s0))begin
                    rxreq_axlen_s1_q[entry]  <= rxreq_axlen_s0;
                    rxreq_axsize_s1_q[entry] <= rxreq_axsize_s0;
                end
            end
        end
    endgenerate

    // to databuffer
    assign rxreq_dbf_en_s1         = rxreq_alloc_en_s1_q;
    assign rxreq_dbf_addr_s1       = rxreq_addr_s1_q[mshr_entry_idx_alloc_s1_q];
    assign rxreq_dbf_wr_s1         = rxreq_wr_s1_q[mshr_entry_idx_alloc_s1_q] | rxreq_errwr_s1_q[mshr_entry_idx_alloc_s1_q];
    assign rxreq_dbf_wrzero_s1     = rxreq_wrzero_s1_q[mshr_entry_idx_alloc_s1_q];
    assign rxreq_dbf_size_s1       = rxreq_size_s1_q[mshr_entry_idx_alloc_s1_q];
    assign rxreq_dbf_axlen_s1      = rxreq_axlen_s1_q[mshr_entry_idx_alloc_s1_q];
    assign rxreq_dbf_entry_idx_s1  = mshr_entry_idx_alloc_s1_q;

    //************************************************************************//
    //                      mshr txrspflit wrap logic                         //
    //************************************************************************//
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : txrsp_comp_timing_logic
                if (rst == 1'b1)
                    txrsp_comp_s1_q[entry] <= 1'b0;
                else if ((mshr_entry_valid_sx_q[entry]) && txrsp_dbidresp_en_s1 && (entry == mshr_entry_idx_alloc_s1_q))
                    txrsp_comp_s1_q[entry] <= 1'b1;
                else if ((mshr_entry_valid_sx_q[entry]) && txrsp_dbidresp_en_sx && (entry == wakeup_idx_sx))
                    txrsp_comp_s1_q[entry] <= 1'b1;
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))
                    txrsp_comp_s1_q[entry] <= 1'b0;
                else
                    ;
            end
        end
    endgenerate
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_txrsp_comp_timing_logic
                if(rst == 1'b1)
                    txrsp_comp_sent_sx_q[entry] <= 1'b0;
                else if(txrsp_won_sx && txrsp_valid_sx && (txrsp_opcode_sx == chie_pkg::RSP_COMP) & (entry == txrsp_entry_idx_sx))
                    txrsp_comp_sent_sx_q[entry] <= 1'b1;
                else if(mshr_retired_valid_sx & entry == mshr_retired_idx_sx)
                    txrsp_comp_sent_sx_q[entry] <= 1'b0;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : txrsp_comp_timing_logic
                if (rst == 1'b1)
                    txrsp_rdreceipt_valid_sx_q[entry] <= 1'b0;
                else if (txrsp_readreceipt_en_s1 && (entry == mshr_entry_idx_alloc_s1_q))
                    txrsp_rdreceipt_valid_sx_q[entry] <= 1'b1;
                else if (txrsp_won_sx && txrsp_valid_sx && (txrsp_opcode_sx == chie_pkg::RSP_READRECEIPT) && (entry == txrsp_entry_idx_sx))
                    txrsp_rdreceipt_valid_sx_q[entry] <= 1'b0;
                else
                    ;
            end
        end
    endgenerate

    //*****************************************************************************************//
    //  1. ewa = 1  && dwt  : return DBIDRESP to RNF;rxdat finish ,return comp to HN
    //  2. ewa = 1  && ！dwt： compdbidresp to HN
    //  3. !ewa && dwt      : return DBIDRESP to RNF;bresp receive ,return comp to HN
    //  4. !ewa && ！dwt    :  bresp receive ,return comp to HN
    //*****************************************************************************************//
    assign txrsp_en_s1                 = txrsp_dbidresp_en_s1 | txrsp_readreceipt_en_s1 | txrsp_compdbidresp_en_s1
                                       | txrsp_rsponly_en_s1 | txrsp_errgrant_en_s1;
    // Sec 2.8.5 (p.2-120): the ReadReceipt is owed whenever Order is non-zero,
    // whether or not the read data goes back direct to the Requester.
    assign txrsp_readreceipt_en_s1     = rxreq_alloc_en_s1_q && rxreq_rd_s1_q[mshr_entry_idx_alloc_s1_q] && (rxreq_order_s1_q[mshr_entry_idx_alloc_s1_q] != 2'b00);
    assign txrsp_rsponly_en_s1         = rxreq_alloc_en_s1_q && rxreq_rsponly_s1_q[mshr_entry_idx_alloc_s1_q] && (~sleep_s2_q[mshr_entry_idx_alloc_s1_q]);
    // Table 9-6 (p.9-340) keeps DBIDResp at OK, so an errored write still grants
    // normally and carries its NDERR on the completion that follows. Table 9-9
    // (p.9-342) gives AtomicLoad/Swap/Compare no CompDBIDResp, so those always
    // take the split grant.
    assign txrsp_errgrant_en_s1        = rxreq_alloc_en_s1_q && rxreq_errgrant_s1_q[mshr_entry_idx_alloc_s1_q] && (~sleep_s2_q[mshr_entry_idx_alloc_s1_q]);
    assign txrsp_compdbidresp_en_s1    = (rxreq_alloc_en_s1_q && (~sleep_s2_q[mshr_entry_idx_alloc_s1_q])) ? (rxreq_wr_s1_q[mshr_entry_idx_alloc_s1_q] && ((~rxreq_dodwt_s1_q[mshr_entry_idx_alloc_s1_q]) && rxreq_ewa_s1_q[mshr_entry_idx_alloc_s1_q])) : 1'b0;
    assign txrsp_dbidresp_en_s1        = (rxreq_alloc_en_s1_q && (~sleep_s2_q[mshr_entry_idx_alloc_s1_q])) ? (rxreq_wr_s1_q[mshr_entry_idx_alloc_s1_q] && (rxreq_dodwt_s1_q[mshr_entry_idx_alloc_s1_q] | (~rxreq_ewa_s1_q[mshr_entry_idx_alloc_s1_q]))) : 1'b0;
    assign txrsp_opcode_en_s1          = txrsp_dbidresp_en_s1 ? chie_pkg::RSP_DBIDRESP
                                       : txrsp_readreceipt_en_s1 ? chie_pkg::RSP_READRECEIPT
                                       : txrsp_compdbidresp_en_s1 ? chie_pkg::RSP_COMPDBIDRESP
                                       : txrsp_rsponly_en_s1 ? rxreq_rsponly_opcode_s1_q[mshr_entry_idx_alloc_s1_q]
                                       : txrsp_errgrant_en_s1 ? ((rxreq_ewa_s1_q[mshr_entry_idx_alloc_s1_q] && (~rxreq_errdat_s1_q[mshr_entry_idx_alloc_s1_q])) ? chie_pkg::RSP_COMPDBIDRESP : chie_pkg::RSP_DBIDRESP)
                                       : chie_pkg::RSP_RSPLCRDRETURN;

    // A request that hit a same-address hazard was put to sleep before its RSP was
    // armed, so the wakeup path has to arm every class the S1 path does.
    assign txrsp_en_sx                 = txrsp_dbidresp_en_sx | txrsp_compdbidresp_en_sx
                                       | txrsp_rsponly_en_sx | txrsp_errgrant_en_sx;
    assign txrsp_dbidresp_en_sx        = wakeup_valid ? (rxreq_wr_s1_q[wakeup_idx_sx]&& (rxreq_dodwt_s1_q[wakeup_idx_sx] | (~rxreq_ewa_s1_q[wakeup_idx_sx]))) : 1'b0;
    assign txrsp_compdbidresp_en_sx    = wakeup_valid ? (rxreq_wr_s1_q[wakeup_idx_sx] && ((~rxreq_dodwt_s1_q[wakeup_idx_sx]) && rxreq_ewa_s1_q[wakeup_idx_sx])) : 1'b0; //ewa&~dwt
    assign txrsp_rsponly_en_sx         = wakeup_valid ? rxreq_rsponly_s1_q[wakeup_idx_sx]  : 1'b0;
    assign txrsp_errgrant_en_sx        = wakeup_valid ? rxreq_errgrant_s1_q[wakeup_idx_sx] : 1'b0;
    assign txrsp_opcode_en_sx          = txrsp_dbidresp_en_sx ? chie_pkg::RSP_DBIDRESP
                                       : txrsp_compdbidresp_en_sx ? chie_pkg::RSP_COMPDBIDRESP
                                       : txrsp_rsponly_en_sx ? rxreq_rsponly_opcode_s1_q[wakeup_idx_sx]
                                       : txrsp_errgrant_en_sx ? ((rxreq_ewa_s1_q[wakeup_idx_sx] && (~rxreq_errdat_s1_q[wakeup_idx_sx])) ? chie_pkg::RSP_COMPDBIDRESP : chie_pkg::RSP_DBIDRESP)
                                       : chie_pkg::RSP_RSPLCRDRETURN;

    assign txrsp_ewa_dwt_rdy_sx         = dbf_mshr_rxdat_ok_sx && txrsp_comp_s1_q[dbf_mshr_rxdat_ok_idx_sx] && rxreq_ewa_s1_q[dbf_mshr_rxdat_ok_idx_sx] && rxreq_dodwt_s1_q[dbf_mshr_rxdat_ok_idx_sx];
    assign txrsp_ewa_dwt_rdy_entry_sx   = dbf_mshr_rxdat_ok_idx_sx ;
    assign txrsp_noewa_rdy_sx           = (bvalid_sx & bready_sx) ? (~rxreq_ewa_s1_q[bid_sx[`SNF_MSHR_ENTRIES_WIDTH-1:0]]  & txrsp_comp_s1_q[bid_sx[`SNF_MSHR_ENTRIES_WIDTH-1:0]]) : 1'b0;
    assign txrsp_noewa_rdy_entry_sx     = (bvalid_sx & bready_sx) ? bid_sx[`SNF_MSHR_ENTRIES_WIDTH-1:0] : {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
    assign txrsp_comp_wrdatcancel_sx    =  dbf_mshr_rxdat_cancel_sx && txrsp_comp_s1_q[dbf_mshr_rxdat_cancel_idx_sx];
    assign txrsp_comp_wrcancel_sx       =  dbf_mshr_rxdat_cancel_idx_sx;

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin
                if (rst)begin
                    txrsp_rdy_sx_q[entry] <= 1'b0;
                    txrsp_opcode_rdy_sx_q[entry] <= chie_pkg::RSP_RSPLCRDRETURN;
                end
                else if (txrsp_sent_sx && (entry == txrsp_entry_idx_sx))begin
                    txrsp_rdy_sx_q[entry] <= txrsp_comp_queued_sx[entry] | txrsp_cmo_owed_q[entry];
                    txrsp_opcode_rdy_sx_q[entry] <= txrsp_comp_queued_sx[entry] ? chie_pkg::RSP_COMP
                                                  : txrsp_cmo_owed_q[entry] ? txrsp_cmo_opcode_q[entry]
                                                  : chie_pkg::RSP_RSPLCRDRETURN;
                end
                else if (txrsp_en_s1 && (entry == mshr_entry_idx_alloc_s1_q))begin
                    txrsp_rdy_sx_q[entry] <= 1'b1;
                    txrsp_opcode_rdy_sx_q[entry] <= txrsp_opcode_en_s1;
                end
                else if (txrsp_en_sx && (entry == wakeup_idx_sx))begin
                    txrsp_rdy_sx_q[entry] <= 1'b1;
                    txrsp_opcode_rdy_sx_q[entry] <= txrsp_opcode_en_sx;
                end
                // Only when the slot is free. A Comp arriving while the entry's
                // grant is still queued is banked instead -- Sec 2.3.9 (p.2-79,
                // MUST) gives a Home-to-Subordinate write DBIDResp + Comp or
                // CompDBIDResp, and overwriting the grant leaves it neither.
                else if (txrsp_comp_rdy_sx[entry] && (~txrsp_rdy_sx_q[entry])) begin
                    txrsp_rdy_sx_q[entry] <= 1'b1;
                    txrsp_opcode_rdy_sx_q[entry] <= chie_pkg::RSP_COMP;
                end
            end
        end
    endgenerate

    // The three points a write's Comp becomes ready, per entry, and what the entry
    // owes as a Comp once the currently armed response is sent.
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign txrsp_comp_rdy_sx[entry] = (txrsp_ewa_dwt_rdy_sx      && (entry == txrsp_ewa_dwt_rdy_entry_sx))
                                            | (txrsp_noewa_rdy_sx        && (entry == txrsp_noewa_rdy_entry_sx))
                                            | (txrsp_comp_wrdatcancel_sx && (entry == txrsp_comp_wrcancel_sx));
            assign txrsp_comp_queued_sx[entry] = txrsp_q2_valid_q[entry] | txrsp_comp_rdy_sx[entry];
        end
    endgenerate

    poll_function #(.POLL_ENTRIES_NUM(`SNF_MSHR_ENTRIES_NUM)) 
                    txrsp_entry_sel(
                        .clk               (clk                 ),
                        .rst               (rst                 ),
                        .entry_vec         (txrsp_rdy_sx_q      ),
                        .upd               (txrsp_update_sx     ),
                        .found             (),
                        .sel_entry         (txrsp_valid_idx_sx  ),
                        .sel_index         (txrsp_entry_idx_sx  ) 
                    );

    assign txrsp_sent_sx                = txrsp_valid_sx & txrsp_won_sx;
    assign txrsp_update_sx              = (|txrsp_rdy_sx_q) & (~txrsp_valid_sx);
    assign txrsp_valid_sx               = (|txrsp_valid_idx_sx) & txrsp_rdy_sx_q[txrsp_entry_idx_sx];
    assign txrsp_qos_sx                 = (rxreq_qos_s1_q[txrsp_entry_idx_sx]);
    assign txrsp_tgtid_sx               = ((rxreq_dodwt_s1_q[txrsp_entry_idx_sx] && (txrsp_opcode_sx == chie_pkg::RSP_DBIDRESP)) == 1'b1) ? rxreq_returnnid_s1_q[txrsp_entry_idx_sx] : rxreq_srcid_s1_q[txrsp_entry_idx_sx];
    assign txrsp_txnid_sx               = ((rxreq_dodwt_s1_q[txrsp_entry_idx_sx] && (txrsp_opcode_sx == chie_pkg::RSP_DBIDRESP)) == 1'b1) ? rxreq_returntxnid_s1_q[txrsp_entry_idx_sx] : rxreq_txnid_s1_q[txrsp_entry_idx_sx];
    assign txrsp_opcode_sx              = txrsp_opcode_rdy_sx_q[txrsp_entry_idx_sx];
    // Sec 9.1 (p.9-334): NDERR reports "an attempt to use a transaction type that
    // is not supported". Table 9-6 (p.9-340) pins DBIDResp to OK and Sec 4.5.4
    // (p.4-207) pins the ReadReceipt's Resp/RespErr to zero, so only the
    // completion carries it.
    assign txrsp_resperr_sx             = ((rxreq_err_s1_q[txrsp_entry_idx_sx] | bresp_err_q[txrsp_entry_idx_sx])
                                        && (txrsp_opcode_sx != chie_pkg::RSP_DBIDRESP)
                                        && (txrsp_opcode_sx != chie_pkg::RSP_READRECEIPT)) ? chie_pkg::RESP_ERR_NON_DATA
                                                                                   : chie_pkg::RESP_ERR_NORM_OK;
    assign txrsp_resp_sx                = chie_pkg::RESP_I;
    assign txrsp_dbid_sx                = {{(12-`SNF_MSHR_ENTRIES_WIDTH){1'b0}}, txrsp_entry_idx_sx};
    assign txrsp_tracetag_sx            = rxreq_tracetag_s1_q[txrsp_entry_idx_sx];
    // Sec 2.6.1 (p.2-94, MUST): "the SrcID is a fixed value for the Subordinate.
    // This also matches the TgtID received." Echoing the request's TgtID instead
    // leaves the Subordinate answering under whatever identity it was addressed by.
    assign txrsp_srcid_sx               = SNF_NID_PARAM;

    //************************************************************************//
    //                       mshr AR channel logic                            //
    //************************************************************************//
    assign arvalid_en_s1 = rxreq_alloc_en_s1_q ? ((~sleep_s2_q[mshr_entry_idx_alloc_s1_q]) && rxreq_rd_s1_q[mshr_entry_idx_alloc_s1_q]) : 1'b0;
    assign arvalid_en2_s1 = wakeup_valid ? rxreq_rd_s1_q[wakeup_idx_sx] : 1'b0;

    always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_set_comb_logic
        if(rst == 1'b1)
            arvalid_fifo_set_vec <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        else if(arvalid_en_s1 && arvalid_en2_s1)
            arvalid_fifo_set_vec <= (arvalid_fifo_set_vec == IDX_LAST_M1) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (arvalid_fifo_set_vec == IDX_LAST) ? IDX_ONE : (arvalid_fifo_set_vec + IDX_TWO);
        else if ((arvalid_en_s1 && (~arvalid_en2_s1)) | ((~arvalid_en_s1) && arvalid_en2_s1))
            arvalid_fifo_set_vec <= (arvalid_fifo_set_vec == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (arvalid_fifo_set_vec + 1'b1);
    end

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_set_comb_logic
                if(rst == 1'b1)
                    arvalid_fifo_s1_q[entry]        <= 1'b0;
                else if ((arvalid_sx == 1'b1) && (arready_sx == 1'b1) && (arvalid_fifo_vec == entry))
                    arvalid_fifo_s1_q[entry]        <= 1'b0;
                else if (arvalid_en_s1 && arvalid_en2_s1 && (arvalid_fifo_set_vec == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= wakeup_idx_sx;
                end
                else if (arvalid_en_s1 && arvalid_en2_s1 && (((arvalid_fifo_set_vec == IDX_LAST) & (entry == 0)) | ((arvalid_fifo_set_vec +1) == entry))) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                end
                else if (arvalid_en_s1 && (arvalid_fifo_set_vec == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= mshr_entry_idx_alloc_s1_q;
                end
                else if (arvalid_en2_s1 && (arvalid_fifo_set_vec == entry)) begin
                    arvalid_fifo_s1_q[entry]        <= 1'b1;
                    arvalid_fifo_idx_sx_q[entry]    <= wakeup_idx_sx;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_cnt_comb_logic
        if(rst == 1'b1)
            arvalid_fifo_vec     <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        else if((arvalid_sx == 1'b1) && (arready_sx == 1'b1))
            arvalid_fifo_vec     <= (arvalid_fifo_vec == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (arvalid_fifo_vec + 1'b1);
    end

    always_ff @(posedge clk or posedge rst)begin : mshr_arvalid_timing_logic
        if(rst == 1'b1) begin
            arvalid_sx                <= 1'b0;
            arvalid_entry_idx_s1_q    <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if((arvalid_sx == 1'b1) && (arready_sx == 1'b1))begin
            arvalid_sx                <= 1'b0;
            arvalid_entry_idx_s1_q    <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(arvalid_fifo_s1_q[arvalid_fifo_vec])begin
            arvalid_sx                <= 1'b1;
            arvalid_entry_idx_s1_q    <= arvalid_fifo_idx_sx_q[arvalid_fifo_vec];
        end
    end

    assign arid_sx          = rxreq_axid_s1_q[arvalid_entry_idx_s1_q];
    assign araddr_sx        = rxreq_axaddr_s1_q[arvalid_entry_idx_s1_q];
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
    //                                TXDAT                                   //
    //************************************************************************//

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: rdat_valid_s1_q_logic
                if(rst == 1'b1)
                    rdat_valid_s1_q[entry] <= 1'b0;
                else if (dbf_mshr_rdata_en_sx && (dbf_mshr_rdata_idx_sx == entry))
                    rdat_valid_s1_q[entry] <= 1'b1;
                else if (mshr_retired_valid_sx && (mshr_retired_idx_sx == entry))
                    rdat_valid_s1_q[entry] <= 1'b0;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: arvalid_fifo_set_comb_logic
                if(rst == 1'b1)
                    rdat_pdmask_q[entry] <= 4'b0000;
                else if ((dbf_mshr_rdata_en_sx && (entry == dbf_mshr_rdata_idx_sx)) && (mshr_txdat_en_sx && (entry == mshr_txdat_entry_idx_sx)) && (mshr_txdat_dataid_sx == 2'b00))
                    rdat_pdmask_q[entry] <= (dbf_mshr_rdata_cdmask_sx | rdat_pdmask_q[entry]) & 4'b1100;
                else if ((dbf_mshr_rdata_en_sx && (entry == dbf_mshr_rdata_idx_sx)) && (mshr_txdat_en_sx && (entry == mshr_txdat_entry_idx_sx)) && (mshr_txdat_dataid_sx == 2'b10))
                    rdat_pdmask_q[entry] <= (dbf_mshr_rdata_cdmask_sx | rdat_pdmask_q[entry]) & 4'b0011;
                else if ((dbf_mshr_rdata_en_sx && (entry == dbf_mshr_rdata_idx_sx))&& (~(mshr_txdat_en_sx && (entry == mshr_txdat_entry_idx_sx))))
                    rdat_pdmask_q[entry] <= dbf_mshr_rdata_cdmask_sx | rdat_pdmask_q[entry];
                else if(~(dbf_mshr_rdata_en_sx && (entry == dbf_mshr_rdata_idx_sx)) && (mshr_txdat_en_sx && (entry == mshr_txdat_entry_idx_sx)) && (mshr_txdat_dataid_sx == 2'b00))
                    rdat_pdmask_q[entry] <= rdat_pdmask_q[entry] & 4'b1100;
                else if(~(dbf_mshr_rdata_en_sx && (entry == dbf_mshr_rdata_idx_sx)) && (mshr_txdat_en_sx && (entry == mshr_txdat_entry_idx_sx)) && (mshr_txdat_dataid_sx == 2'b10))
                    rdat_pdmask_q[entry] <= rdat_pdmask_q[entry] & 4'b0011;
                else if (mshr_retired_valid_sx && entry == mshr_retired_idx_sx)
                    rdat_pdmask_q[entry] <= 4'b0000;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            // Sec 9.4.1 (p.9-337, MUST): a Read's data response carries a Non-data
            // Error "either in none or in all data response packets", and the AXI
            // error is not final until the last beat is in. A two-packet transfer
            // therefore holds its first packet until the whole burst has arrived;
            // a single-packet one has nothing to hold.
            assign rdat_allrcvd_sx[entry] = (rxreq_size_s1_q[entry] == chie_pkg::SIZE_64B) ?
                                (rdat_pdmask_q[entry] == 4'b1111) : 1'b1;

            assign txdat1_rdy_sx[entry] = (rdat_valid_s1_q[entry] && (~txdat_rdy_sx_q[entry][0]) && rdat_allrcvd_sx[entry]) ?
                                (((rxreq_ccid_s1_q[entry][1] == 1'b0) && (rdat_pdmask_q[entry][1:0] == 2'b11))
                                | ((rxreq_ccid_s1_q[entry][1] == 1'b1) && (rdat_pdmask_q[entry][3:2] == 2'b11))
                                | (rxreq_size_s1_q[entry] < chie_pkg::SIZE_32B) && (|(rdat_pdmask_q[entry])))
                                : 1'b0; // packet 1

            assign txdat2_rdy_sx[entry] = (rdat_valid_s1_q[entry] && (txdat_rdy_sx_q[entry][0]) && (~txdat_rdy_sx_q[entry][1]))? //packet 2
                                 (((rxreq_ccid_s1_q[entry][1] == 1'b0) && (rdat_pdmask_q[entry][3:2] == 2'b11)) | ((rxreq_ccid_s1_q[entry][1] == 1'b1) && (rdat_pdmask_q[entry][1:0] == 2'b11))) : 1'b0;
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin
                if(rst == 1'b1)
                    txdat_rdy_sx_q[entry]   <= 2'b00;
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))
                    txdat_rdy_sx_q[entry]   <= 2'b00;
                else if (txdat_errdat_rdy_sx[entry])
                    txdat_rdy_sx_q[entry]   <= txdat_rdy_sx_q[entry] | 2'b01;
                else if (txdat1_rdy_sx[entry] && (~txdat2_rdy_sx[entry]))
                    txdat_rdy_sx_q[entry]   <= txdat_rdy_sx_q[entry] | 2'b01;
                else if ((~txdat1_rdy_sx[entry]) && txdat2_rdy_sx[entry])
                    txdat_rdy_sx_q[entry]   <= txdat_rdy_sx_q[entry] | 2'b10;
                else if (txdat1_rdy_sx[entry] && txdat2_rdy_sx[entry])
                    txdat_rdy_sx_q[entry]   <= txdat_rdy_sx_q[entry] | 2'b11;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin: txdat_sent_logic
                if (rst)
                    txdat_sent_sx_q[entry]      <= 2'b00;
                else if (mshr_txdat_won_sx && (mshr_txdat_entry_idx_sx == entry) && (((mshr_txdat_dataid_sx == 2'b00) && (rxreq_ccid_s1_q[entry][1] == 1'b0)) | ((mshr_txdat_dataid_sx == 2'b10) && (rxreq_ccid_s1_q[entry][1] == 1'b1))))
                    txdat_sent_sx_q[entry]      <= txdat_sent_sx_q[entry] | 2'b01;
                else if (mshr_txdat_won_sx && (mshr_txdat_entry_idx_sx == entry) && (((mshr_txdat_dataid_sx == 2'b10) && (rxreq_ccid_s1_q[entry][1] == 1'b0)) | ((mshr_txdat_dataid_sx == 2'b00) && (rxreq_ccid_s1_q[entry][1] == 1'b1))) && (txdat_sent_sx_q[entry][0] == 1'b1))
                    txdat_sent_sx_q[entry]      <= txdat_sent_sx_q[entry] | 2'b10;
                else if (mshr_retired_valid_sx && entry == mshr_retired_idx_sx)
                    txdat_sent_sx_q[entry]      <= 2'b00;
            end
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            // Sec 9.4.4 (p.9-342, MUST): AtomicLoad, AtomicSwap and AtomicCompare
            // carry their Non-data Error on CompData, so the errored entry still
            // returns one data packet once it has taken the operand.
            assign txdat_errdat_rdy_sx[entry] = dbf_mshr_rxdat_ok_sx && rxreq_errdat_s1_q[entry]
                                             && (entry == dbf_mshr_rxdat_ok_idx_sx)
                                             && (txdat_rdy_sx_q[entry] == 2'b00);
            assign txdat_valid_sx[entry]  = (txdat_sent_sx_q[entry] != txdat_rdy_sx_q[entry]);
        end
    endgenerate
    
    poll_function #(.POLL_ENTRIES_NUM(`SNF_MSHR_ENTRIES_NUM))
                    txdat_entry_sel(
                        .clk               (clk                 ),
                        .rst               (rst                 ),
                        .entry_vec         (txdat_valid_sx      ),
                        .upd               (mshr_txdat_update   ),
                        .found             (sel_idx_valid       ),
                        .sel_entry         (),
                        .sel_index         (txdat_entry_idx_sx  ) 
                    );

    assign mshr_txdat_update        = (~mshr_txdat_en_sx) & (~txdat_valid_sx[txdat_entry_idx_sx]);
    assign mshr_txdat_entry_idx_sx  = txdat_entry_idx_sx;
    assign mshr_txdat_en_sx         = sel_idx_valid;
    assign mshr_txdat_dataid_sx     = ((((rxreq_ccid_s1_q[mshr_txdat_entry_idx_sx][1] == 1'b0) && (txdat_rdy_sx_q[mshr_txdat_entry_idx_sx][0] == 1'b1) && (txdat_sent_sx_q[mshr_txdat_entry_idx_sx][0] == 1'b0))
                                        | ((rxreq_ccid_s1_q[mshr_txdat_entry_idx_sx][1] == 1'b1) && (txdat_rdy_sx_q[mshr_txdat_entry_idx_sx][1] == 1'b1) && (txdat_sent_sx_q[mshr_txdat_entry_idx_sx][1] == 1'b1))) ? 2'b00 //ccid[1]=0,packet1;ccid[1]=1,packet2
                                    : (((rxreq_ccid_s1_q[mshr_txdat_entry_idx_sx][1] == 1'b0) && (txdat_rdy_sx_q[mshr_txdat_entry_idx_sx][1] == 1'b1) && (txdat_sent_sx_q[mshr_txdat_entry_idx_sx] == 2'b01))
                                        | ((rxreq_ccid_s1_q[mshr_txdat_entry_idx_sx][1] == 1'b1) && (txdat_rdy_sx_q[mshr_txdat_entry_idx_sx][0] == 1'b1) && (txdat_sent_sx_q[mshr_txdat_entry_idx_sx][0] == 1'b0)) ? 2'b10 // ccid[1]=0,packet2;ccid[1]=1,packet1
                                            : 2'b00));
    assign mshr_txdat_txnid_sx      = (rxreq_dodmt_s1_q[mshr_txdat_entry_idx_sx] == 1'b1) ? rxreq_returntxnid_s1_q[mshr_txdat_entry_idx_sx] : rxreq_txnid_s1_q[mshr_txdat_entry_idx_sx];
    // Sec 4.5.1 (p.4-197, MUST): "A Subordinate Node can send DataSepResp only in
    // response to ReadNoSnpSep, and only CompData in response to ReadNoSnp."
    assign mshr_txdat_opcode_sx     = rxreq_rdsep_s1_q[mshr_txdat_entry_idx_sx] ? chie_pkg::DAT_DATASEPRESP : chie_pkg::DAT_COMPDATA;
    assign mshr_txdat_resp_sx       = chie_pkg::RESP_UC_UD;
    assign mshr_txdat_resperr_sx    = rxreq_err_s1_q[mshr_txdat_entry_idx_sx] ? chie_pkg::RESP_ERR_NON_DATA
                                                                             : chie_pkg::RESP_ERR_NORM_OK;
    assign mshr_txdat_dbid_sx       = rxreq_txnid_s1_q[mshr_txdat_entry_idx_sx];
    assign mshr_txdat_tgtid_sx      = (rxreq_dodmt_s1_q[mshr_txdat_entry_idx_sx] == 1'b1) ? rxreq_returnnid_s1_q[mshr_txdat_entry_idx_sx] : rxreq_srcid_s1_q[mshr_txdat_entry_idx_sx];
    assign mshr_txdat_srcid_sx      = SNF_NID_PARAM; // Sec 2.6.1 (p.2-94, MUST), as txrsp_srcid_sx
    assign mshr_txdat_homenid_sx    = rxreq_srcid_s1_q[mshr_txdat_entry_idx_sx];
    assign mshr_txdat_tracetag_sx   = rxreq_tracetag_s1_q[mshr_txdat_entry_idx_sx];

    //************************************************************************//
    //                       mshr AW channel logic                            //
    //************************************************************************//
    always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_in_comb_logic
        if(rst == 1'b1)
            awvalid_fifo_cnt_sx_q   <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        else if(dbf_mshr_rxdat_ok_sx && !dbf_mshr_rxdat_cancel_sx && !rxreq_errwr_s1_q[dbf_mshr_rxdat_ok_idx_sx])
            awvalid_fifo_cnt_sx_q   <= (awvalid_fifo_cnt_sx_q == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (awvalid_fifo_cnt_sx_q + 1'b1);
    end

    always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_out_comb_logic
        if(rst == 1'b1)
            awvalid_fifo_vec_sx        <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        else if((awvalid_sx == 1'b1) && (awready_sx == 1'b1))
            awvalid_fifo_vec_sx        <= (awvalid_fifo_vec_sx == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (awvalid_fifo_vec_sx + 1'b1);
    end

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin: awvalid_fifo_set_comb_logic
                if(rst == 1'b1)begin
                    awvalid_fifo_valid_s2_q[entry]      <= 1'b0;
                    awvalid_fifo_idx_s2_q[entry]        <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else if (dbf_mshr_rxdat_ok_sx && !dbf_mshr_rxdat_cancel_sx && !rxreq_errwr_s1_q[dbf_mshr_rxdat_ok_idx_sx] && (awvalid_fifo_cnt_sx_q == entry)) begin
                    awvalid_fifo_valid_s2_q[entry]      <= 1'b1;
                    awvalid_fifo_idx_s2_q[entry]        <= dbf_mshr_rxdat_ok_idx_sx;
                end
                else if ((awvalid_sx == 1'b1) && (awready_sx == 1'b1) && (awvalid_fifo_vec_sx == entry))begin
                    awvalid_fifo_valid_s2_q[entry]      <= 1'b0;
                    awvalid_fifo_idx_s2_q[entry]        <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else begin
                    ;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst)begin : mshr_aw_timing_logic
        if(rst == 1'b1) begin
            awvalid_sx              <= 1'b0;
            awvalid_entry_idx_s2_q  <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if((awvalid_sx == 1'b1) && (awready_sx == 1'b1))begin
            awvalid_sx              <= 1'b0;
            awvalid_entry_idx_s2_q  <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if(awvalid_fifo_valid_s2_q[awvalid_fifo_vec_sx])begin
            awvalid_sx              <= 1'b1;
            awvalid_entry_idx_s2_q  <= awvalid_fifo_idx_s2_q[awvalid_fifo_vec_sx];
        end
    end

    assign awid_sx                = rxreq_axid_s1_q[awvalid_entry_idx_s2_q];
    assign awaddr_sx              = rxreq_axaddr_s1_q[awvalid_entry_idx_s2_q];
    assign awcache_sx[0]          = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][0];
    assign awcache_sx[1]          = ~rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][1];
    assign awcache_sx[2]          = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][2];
    assign awcache_sx[3]          = rxreq_memattr_s1_q[awvalid_entry_idx_s2_q][3];
    assign awqos_sx               = rxreq_qos_s1_q[awvalid_entry_idx_s2_q];
    assign awprot_sx              = {1'b0,rxreq_ns_s1_q[awvalid_entry_idx_s2_q],1'b0};
    assign awlen_sx               = rxreq_axlen_s1_q[awvalid_entry_idx_s2_q];
    assign awsize_sx              = rxreq_axsize_s1_q[awvalid_entry_idx_s2_q];
    assign awburst_sx             = 2'b01;
    assign awlock_sx              = 1'b0;
    assign awregion_sx            = {`AXI4_AWREGION_WIDTH{1'b0}};

    always_ff @(posedge clk or posedge rst)begin
        if (rst)
            mshr_wdat_en_rst   <= 1'b0;
        else
            mshr_wdat_en_rst   <= awvalid_sx;
    end

    assign mshr_wdat_en_sx        = awvalid_sx & (~mshr_wdat_en_rst);
    assign mshr_wdat_entry_idx_sx = awvalid_entry_idx_s2_q;

    //************************************************************************//
    //                      mshr B channel logic                              //
    //************************************************************************//

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign bresp_ok_sx[entry] = bvalid_sx && bready_sx & (bid_sx == entry);
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin  //bresp received
            always_ff @(posedge clk or posedge rst)begin : mshr_bresp_complete_flag_timing_logic
                if (rst)
                    bresp_ok_q[entry] <= 1'b0;
                else if (retired_entry_sx[entry])
                    bresp_ok_q[entry] <= 1'b0;
                else if (bresp_ok_sx[entry])
                    bresp_ok_q[entry] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    // AMBA AXI4 (IHI 0022) Table A3-4 gives BRESP two error encodings, SLVERR and
    // DECERR, which share bit 1. Sec 9.1 (p.9-334) names the access that failed a
    // Non-data Error, and Sec 9.2 (p.9-335) requires the Completer report it.
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_bresp_err_flag_timing_logic
                if (rst)
                    bresp_err_q[entry] <= 1'b0;
                else if (retired_entry_sx[entry])
                    bresp_err_q[entry] <= 1'b0;
                else if (bresp_ok_sx[entry] && bresp_sx[1])
                    bresp_err_q[entry] <= 1'b1;
                else
                    ;
            end
        end
    endgenerate

    assign bready_sx    = ~rst;

    //************************************************************************//
    //                      mshr check hazard ownership logic                 //
    //************************************************************************//
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign hazard_sx[entry] = rxreq_alloc_en_s0 & (~hazard_sx_q[entry]) & mshr_entry_valid_sx_q[entry] & (rxreq_addr_s1_q[entry][chie_pkg::REQ_ADDR_WIDTH-1:6] == rxreq_addr_s0[chie_pkg::REQ_ADDR_WIDTH-1:6]);
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : mshr_wakeup_logic
                if (rst == 1'b1) begin
                    hazard_sx_q[entry]     <= 1'b0;
                    hazard_idx_s2_q[entry] <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else if (mshr_retired_valid_sx && (mshr_retired_idx_sx == entry)) begin
                    hazard_sx_q[entry]     <= 1'b0;
                    hazard_idx_s2_q[entry] <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else if (hazard_sx[entry]) begin
                    hazard_sx_q[entry]     <= 1'b1;
                    hazard_idx_s2_q[entry] <= mshr_entry_idx_alloc_s0;
                end
            end

            always_ff @(posedge clk or posedge rst)begin : mshr_sleep_logic
                if (rst == 1'b1)
                    sleep_s2_q[entry]               <= 1'b0;
                else if (wakeup_valid & (wakeup_idx_sx == entry))
                    sleep_s2_q[entry]               <= 1'b0;
                else if (rxreq_alloc_en_s0 & (|hazard_sx) & (mshr_entry_idx_alloc_s0 == entry))
                    sleep_s2_q[entry]               <= 1'b1;
            end
        end
    endgenerate

    assign wakeup_valid         = mshr_retired_valid_sx ? hazard_sx_q[mshr_retired_idx_sx] : 1'b0;
    assign wakeup_idx_sx        = mshr_retired_valid_sx ? hazard_idx_s2_q[mshr_retired_idx_sx] : {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};

    //************************************************************************//
    //                  rxdat logic : rxdat_cancel save                       //
    //************************************************************************//

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : rxdat_cancel_s1_q_timing_logic
                if(rst == 1'b1)
                    rxdat_cancel_s1_q[entry]          <= 1'b0;
                else if(dbf_mshr_rxdat_ok_sx && dbf_mshr_rxdat_cancel_sx && (entry == dbf_mshr_rxdat_ok_idx_sx))
                    rxdat_cancel_s1_q[entry]          <= 1'b1;
                else if(mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))
                    rxdat_cancel_s1_q[entry]          <= 1'b0;
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//
    //                         mshr retire logic                              //
    //************************************************************************//
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign all_rsp_sent_sx[entry] = txrsp_any_sent_q[entry] && (~txrsp_rdy_sx_q[entry])
                                         && (~txrsp_comp_queued_sx[entry]) && (~txrsp_cmo_owed_q[entry]);
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            assign retired_entry_sx[entry]  = (mshr_entry_valid_sx_q[entry] && (~sleep_s2_q[entry]))
                                                && (((rxreq_wr_s1_q[entry]) && all_rsp_sent_sx[entry] && (((~rxdat_cancel_s1_q[entry]) && bresp_ok_q[entry] && (~txrsp_comp_s1_q[entry])) | ((~rxdat_cancel_s1_q[entry]) && bresp_ok_q[entry] && txrsp_comp_s1_q[entry] && txrsp_comp_sent_sx_q[entry]) | ((rxdat_cancel_s1_q[entry]) && txrsp_comp_s1_q[entry] && txrsp_comp_sent_sx_q[entry]) | ((rxdat_cancel_s1_q[entry]) && (~txrsp_comp_s1_q[entry]))))
                                                    |((rxreq_rd_s1_q[entry]) && (~txrsp_rdreceipt_valid_sx_q[entry]) && (((rxreq_size_s1_q[entry] == 3'b110) && (txdat_sent_sx_q[entry] == 2'b11)) | ((rxreq_size_s1_q[entry] != 3'b110) && ((txdat_sent_sx_q[entry] == 2'b01) | (txdat_sent_sx_q[entry] == 2'b10)))))
                                                    // Sec 2.3.6 (p.2-74): PrefetchTgt and PCrdReturn owe nothing, so the
                                                    // entry is freed at once rather than leaked.
                                                    |(rxreq_drop_s1_q[entry])
                                                    |((rxreq_rsponly_s1_q[entry] | rxreq_errgrant_s1_q[entry]) && all_rsp_sent_sx[entry]
                                                        && ((~rxreq_errwr_s1_q[entry])  | errwr_data_done_q[entry])
                                                        && ((~rxreq_errdat_s1_q[entry]) | (txdat_sent_sx_q[entry] != 2'b00))));
        end
    endgenerate

    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin
                if(rst == 1'b1)
                    retired_entry_sx1_q[entry]  <=1'b0;
                else if (retired_entry_sx[entry])
                    retired_entry_sx1_q[entry]  <= 1'b1;
                else if (mshr_retired_valid_sx && (mshr_retired_idx_sx == entry))
                    retired_entry_sx1_q[entry]  <= 1'b0;
            end
        end
    endgenerate

    always_comb begin
        integer k;
        retired_entry_idx_sx1_q = {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        for (k=0; k < `SNF_MSHR_ENTRIES_NUM; k=k+1) begin
            if(retired_entry_sx1_q[k])
                retired_entry_idx_sx1_q = k[`SNF_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    assign mshr_retired_valid_sx    = |retired_entry_sx1_q;
    assign mshr_retired_idx_sx      = retired_entry_idx_sx1_q;

endmodule

