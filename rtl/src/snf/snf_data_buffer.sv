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

module snf_data_buffer `SNF_PARAM
    (
        input  wire                                 clk,
        input  wire                                 rst,
        input  wire                                 rxdat_valid_s0,
        input  chie_pkg::dat_flit_s                 rxdatflit_s0,
        input  wire                                 rxreq_dbf_en_s1,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   rxreq_dbf_entry_idx_s1,
        input  wire                                 rxreq_dbf_wr_s1,
        input  wire                                 rxreq_dbf_wrzero_s1,
        input  logic [chie_pkg::REQ_ADDR_WIDTH-1:0] rxreq_dbf_addr_s1,
        input  chie_pkg::size_e                     rxreq_dbf_size_s1,
        input  wire [`AXI4_ARLEN_WIDTH-1:0]         rxreq_dbf_axlen_s1,
        input  wire                                 mshr_retired_valid_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   mshr_retired_idx_sx,
        input  wire                                 mshr_wdat_en_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   mshr_wdat_entry_idx_sx,
        input  wire                                 mshr_txdat_en_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   mshr_txdat_entry_idx_sx,
        input  logic [chie_pkg::NID_WIDTH-1:0]      mshr_txdat_tgtid_sx,
        input  logic [11:0]                         mshr_txdat_txnid_sx,
        input  chie_pkg::dat_opcode_e               mshr_txdat_opcode_sx,
        input  chie_pkg::resp_state_e               mshr_txdat_resp_sx,
        input  chie_pkg::resp_err_e                 mshr_txdat_resperr_sx,
        input  logic [11:0]                         mshr_txdat_dbid_sx,
        input  logic [1:0]                          mshr_txdat_dataid_sx,
        // Sec 12.10 (p.12-385) gives a Home-to-Subordinate Read the Transfer and Fetch
        // columns; this says the request asked for one of them.
        input  wire                                 mshr_txdat_tag_return_sx,
        input  logic                                mshr_txdat_tracetag_sx,
        input  logic [chie_pkg::NID_WIDTH-1:0]      mshr_txdat_srcid_sx,
        input  logic [chie_pkg::NID_WIDTH-1:0]      mshr_txdat_homenid_sx,
        output wire                                 mshr_txdat_won_sx,
        input  wire                                 txdat_dbf_rdy_s1,
        input  wire                                 txdat_dbf_won_sx,
        output chie_pkg::dat_flit_s                 txdat_flit,
        output wire [`SNF_MSHR_ENTRIES_NUM-1:0]     dbf_mshr_tagfetch_req_sx,
        input  wire                                 mshr_dbf_tagfetch_ack_sx,
        input  wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   mshr_dbf_tagfetch_idx_sx,
        output wire [`SNF_MSHR_ENTRIES_NUM-1:0]     dbf_mshr_tagmatch_done_sx,
        output wire [`SNF_MSHR_ENTRIES_NUM-1:0]     dbf_mshr_tagmatch_pass_sx,
        output wire                                 dbf_mshr_rxdat_ok_sx,
        output wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   dbf_mshr_rxdat_ok_idx_sx,
        output wire                                 dbf_mshr_rxdat_cancel_sx,
        output wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   dbf_mshr_rxdat_cancel_idx_sx,
        output wire                                 dbf_mshr_rdata_en_sx,
        output wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]   dbf_mshr_rdata_idx_sx,
        output wire [`SNF_MASK_CD_WIDTH-1:0]        dbf_mshr_rdata_cdmask_sx,
        output wire                                 dbf_txdat_valid_sx,
        input  wire [`AXI4_ARID_WIDTH-1:0]          rid,
        input  wire [`AXI4_RDATA_WIDTH-1:0]         rdata,
        input  wire [`AXI4_RUSER_WIDTH-1:0]         ruser,
        input  wire [`AXI4_RRESP_WIDTH-1:0]         rresp,
        input  wire [`AXI4_RLAST_WIDTH-1:0]         rlast,
        input  wire                                 rvalid,
        output wire                                 rready,
        output wire [`AXI4_WDATA_WIDTH-1:0]         wdata,
        output wire [`AXI4_WUSER_WIDTH-1:0]         wuser,
        output wire [`AXI4_WSTRB_WIDTH-1:0]         wstrb,
        output wire [`AXI4_WLAST_WIDTH-1:0]         wlast,
        output wire                                 wvalid,
        input  wire                                 wready
    );
    logic [1:0]                         rxreq_alloc_ccid_s2_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    chie_pkg::size_e                    rxreq_alloc_size_s2_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_CD_WIDTH-1:0]      rdata_cdmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_WL_WIDTH-1:0]      rdata_wlmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_CD_WIDTH-1:0]      wdata_cdmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_WL_WIDTH-1:0]      wdata_wlmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_WL_WIDTH-1:0]      dbf_wlmask_s1_q;
    logic [`SNF_PKTS*chie_pkg::DATA_WIDTH-1:0]  dbf_data_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_PKTS*chie_pkg::BE_WIDTH-1:0]    dbf_be_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    // Every per-entry vector holds one whole 64-byte line: SNF_PKTS packets of the
    // Data_Width the flit carries (SS2.10.4 p.2-136).
    // CHI E.b SS9.5 (p.9-347, MUST): "The Poison value, once set, must be
    // propagated along with the data", so the tag is held beside the line it
    // tags -- one bit per 64-bit chunk of the line.
    logic [`SNF_PKTS*chie_pkg::POISON_WIDTH-1:0] dbf_poison_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    // CHI E.b SS12.2 (p.12-373): one 4-bit Allocation Tag per aligned 16 bytes, so a
    // 64-byte line's worth is SNF_PKTS packets' Tag fields; SS13.10.39 (p.13-435) pairs
    // a TU bit with each. Buffered beside the data they tag, like Poison.
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]   dbf_tag_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_PKTS*chie_pkg::TU_WIDTH-1:0]    dbf_tu_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    // SS12.11.1 (p.12-386, MUST) owes a TagMatch its real verdict, so a TagOp=Match
    // write has to compare the Physical Tags it carries against the Allocation Tags
    // the location holds. Those live in AXI memory, so the write fetches them on the
    // read channel once its own data has been taken -- the fetch clobbers dbf_data_q
    // and dbf_be_q, which is why the operands are snapshotted here rather than read
    // back out of the shared buffer.
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]   dbf_match_tag_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_PKTS*chie_pkg::BE_WIDTH-1:0]    dbf_match_be_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]   dbf_alloc_tag_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_CD_WIDTH-1:0]      dbf_match_cdmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MASK_WL_WIDTH-1:0]      dbf_match_wlmask_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   match_perform_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   tagfetch_req_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   tagfetch_busy_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   tagmatch_done_q;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   tagmatch_pass_q;
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]   wdata_recv_match_tag_sx;
    logic [chie_pkg::TAG_WIDTH-1:0]     rxdat_match_tag_s0;
    wire                                rxdat_match_s0;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0] wdata_rec_idx_sx_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0] wdata_fifo_set_vec;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0] wdata_fifo_get_vec;
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   wdata_fifo_valid_sx;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0] wdata_fifo_entry_idx_sx[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   wdata_cancel_q;
    logic [`SNF_PKTS-1:0]               wdata_recv_cnt_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    logic [`SNF_MSHR_ENTRIES_NUM-1:0]   wrzero_pending_q;
    logic [`SNF_MSHR_ENTRIES_WIDTH-1:0] wrzero_inject_idx_sx;

    wire                                AXI_128;

    localparam [31:0]                        ENTRIES_M1 = `SNF_MSHR_ENTRIES_NUM-1;
    localparam [`SNF_MSHR_ENTRIES_WIDTH-1:0] IDX_LAST   = ENTRIES_M1[`SNF_MSHR_ENTRIES_WIDTH-1:0];
    wire                                   wdata_to_slave;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]     wdata_to_slave_idx;
    wire [`SNF_MASK_CD_WIDTH-1:0]          wdata_cdmask_next;
    wire [`SNF_PKTS-1:0]                   wdata_recv_sx;
    wire [`SNF_PKTS-1:0]                   wdata_recv_cnt_next;
    wire                                   wdata_recv_update;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]     wdata_recv_idx;
    logic [`SNF_PKTS*chie_pkg::DATA_WIDTH-1:0]     wdata_recv_data_sx;
    logic [`SNF_PKTS*chie_pkg::BE_WIDTH-1:0]       wdata_recv_be_sx;
    logic [`SNF_PKTS*chie_pkg::POISON_WIDTH-1:0]   wdata_recv_poison_sx;
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]      wdata_recv_tag_sx;
    logic [`SNF_PKTS*chie_pkg::TU_WIDTH-1:0]       wdata_recv_tu_sx;
    wire                                   wdata_cancel_recv_s0;
    wire                                   wrzero_inject_sx;
    logic [chie_pkg::DATA_WIDTH-1:0]       dbf_txdat_data_sx;
    logic [chie_pkg::BE_WIDTH-1:0]         dbf_txdat_be_sx;
    logic [chie_pkg::POISON_WIDTH-1:0]     dbf_txdat_poison_sx;
    logic [chie_pkg::TAG_WIDTH-1:0]        dbf_txdat_tag_sx;
    wire                                   dbf_txdat_en_sx;
    wire [1:0]                             dbf_txdat_pkt_sx;
    wire [`SNF_MASK_CD_WIDTH-1:0]          dbf_cdmask_s0;
    wire [`SNF_MASK_CD_WIDTH-1:0]          dbf_rd_cdmask_next_sel;
    wire [`SNF_MASK_CD_WIDTH-1:0]          dbf_rd_cdmask_next;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]     dbf_txdat_entry_idx_sx;
    logic [11:0]                           rxdat_txnid_s0;
    chie_pkg::dat_opcode_e                 rxdat_opcode_s0;
    logic [chie_pkg::BE_WIDTH-1:0]         rxdat_be_s0;
    logic [1:0]                            rxdat_dataid_s0;
    wire  [1:0]                            rxdat_pkt_s0;
    logic [chie_pkg::DATA_WIDTH-1:0]       rxdat_data_s0;
    logic [chie_pkg::POISON_WIDTH-1:0]     rxdat_poison_s0;
    logic [chie_pkg::TAG_WIDTH-1:0]        rxdat_tag_s0;
    logic [chie_pkg::TU_WIDTH-1:0]         rxdat_tu_s0;
    logic [`AXI4_RRESP_WIDTH-1:0]          rresp_q[0:`SNF_MSHR_ENTRIES_NUM-1];
    wire                                   rdata_recv_update_sx;
    wire [`SNF_MSHR_ENTRIES_WIDTH-1:0]     rdata_recv_entry_idx_sx;
    logic [`SNF_PKTS*chie_pkg::DATA_WIDTH-1:0] rdata_recv_data_sx;
    logic [`SNF_PKTS*chie_pkg::BE_WIDTH-1:0]   rdata_recv_be_sx;
    logic [`SNF_PKTS*chie_pkg::POISON_WIDTH-1:0]   rdata_recv_poison_sx;
    logic [`SNF_PKTS*chie_pkg::TAG_WIDTH-1:0]      rdata_recv_tag_sx;
     logic [1:0] mshr_txdat_ccid_sx;

    genvar entry;

    //rxdat decode
    assign rxdat_txnid_s0  = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.txnid  : '0;
    assign rxdat_opcode_s0 = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.opcode : chie_pkg::DAT_DATLCRDRETURN;
    assign rxdat_be_s0     = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.be     : '0;
    assign rxdat_dataid_s0 = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.dataid : '0;
    assign rxdat_data_s0   = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.data   : '0;
    assign rxdat_poison_s0 = (rxdat_valid_s0 == 1'b1) ? rxdatflit_s0.poison : '0;
    // SS12.5.2 (p.12-379, MUST): only a TagOp=Update write installs tags, and only
    // where TU says. Every other TagOp leaves the location's tags alone.
    assign rxdat_tag_s0    = ((rxdat_valid_s0 == 1'b1) && (rxdatflit_s0.tagop == 2'b10)) ? rxdatflit_s0.tag : '0;
    assign rxdat_tu_s0     = ((rxdat_valid_s0 == 1'b1) && (rxdatflit_s0.tagop == 2'b10)) ? rxdatflit_s0.tu  : '0;
    // SS12.5 (p.12-378, MUST): "When the TagOp values in the WriteData and Write
    // request are different, whether or not to perform a Tag Match must be decided
    // based on the TagOp value in the WriteData request."
    assign rxdat_match_s0     = (rxdat_valid_s0 == 1'b1) && (rxdatflit_s0.tagop == 2'b11);
    assign rxdat_match_tag_s0 = rxdat_match_s0 ? rxdatflit_s0.tag : '0;

    assign AXI_128 = (`AXI4_AXDATA_WIDTH == 128) ? 1'b1 : 1'b0;

    //************************************************************************//
    // CCID = addr[5:4]
    // cdmask : receive data bank
    // wlmask : the last data bank
    // dbf_cdmask_s0 : the first data bank
    //************************************************************************//
    assign dbf_cdmask_s0 = (AXI_128) ? ((rxreq_dbf_addr_s1[5:4] == 2'b00) ? 4'b0001
                                            : (((rxreq_dbf_addr_s1[5:4] == 2'b01) && ((rxreq_dbf_axlen_s1 == 8'd1) | ((rxreq_dbf_axlen_s1 == 8'd3)))) ? 4'b0001
                                            : ((rxreq_dbf_addr_s1[5:4] == 2'b01) ? 4'b0010
                                            : (((rxreq_dbf_addr_s1[5:4] == 2'b10) && (rxreq_dbf_axlen_s1 == 8'd3)) ? 4'b0001
                                            : ((rxreq_dbf_addr_s1[5:4] == 2'b10) ? 4'b0100
                                            : (((rxreq_dbf_addr_s1[5:4] == 2'b11) && (rxreq_dbf_axlen_s1 == 8'd3)) ? 4'b0001
                                            : (((rxreq_dbf_addr_s1[5:4] == 2'b11) && (rxreq_dbf_axlen_s1 == 8'd1)) ? 4'b0100
                                            : ((rxreq_dbf_addr_s1[5:4] == 2'b11) ? 4'b1000 : 4'b0000))))))))
                                    :(((rxreq_dbf_addr_s1[5] == 1'b1) && (rxreq_dbf_axlen_s1 == 8'd0)) ? 4'b1100 : 4'b0011);

    generate if (`AXI4_AXDATA_WIDTH == 128) begin:dbf_rd_wlmask_128_gen
        always_comb begin: wlmask_comb_logic
        dbf_wlmask_s1_q = 4'b0000;
            case(rxreq_dbf_addr_s1[5:4])
                2'b00:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b0001;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b0010;
                        8'd3:
                            dbf_wlmask_s1_q = 4'b1000;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                2'b01:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b0010;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b0010;
                        8'd3:
                            dbf_wlmask_s1_q = 4'b1000;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                2'b10:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b0100;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b1000;
                        8'd3:
                            dbf_wlmask_s1_q = 4'b1000;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                2'b11:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b1000;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b1000;
                        8'd3:
                            dbf_wlmask_s1_q = 4'b1000;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                default:begin
                    dbf_wlmask_s1_q = 4'b0000;
                end
            endcase
        end
    end else begin :dbf_rd_wlmask_256_gen
        always_comb begin: wlmask_comb_logic
            dbf_wlmask_s1_q = 4'b0000;
            case(rxreq_dbf_addr_s1[5])
                1'b0:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b0011;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b1100;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                1'b1:begin
                    case(rxreq_dbf_axlen_s1)
                        8'd0:
                            dbf_wlmask_s1_q = 4'b1100;
                        8'd1:
                            dbf_wlmask_s1_q = 4'b1100;
                        // CHI E.b Table 2-14 (SS2.10.1 p.2-134) caps Size at 64B and
                        // Table 4-2 (SS4.2 p.4-166) caps an HN-F to SN-F read at the same,
                        // so snf_mshr.v's Size decode emits only the arms above.
                        default:
                            dbf_wlmask_s1_q = 4'b0000;
                    endcase
                end
                default:begin
                    dbf_wlmask_s1_q = 4'b0000;
                end
            endcase
        end
    end
    endgenerate

    generate
       for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:req_alloc_info_timing_logic
            always_ff @(posedge clk or posedge rst)begin:ccid_axid_timing_logic
                if(rst)begin
                    rxreq_alloc_ccid_s2_q[entry]     <= 2'b0;
                    rxreq_alloc_size_s2_q[entry]     <= chie_pkg::SIZE_1B;
                end
                else if(rxreq_dbf_en_s1 && (entry == rxreq_dbf_entry_idx_s1))begin
                    rxreq_alloc_ccid_s2_q[entry]     <= rxreq_dbf_addr_s1[5:4];
                    rxreq_alloc_size_s2_q[entry]     <= rxreq_dbf_size_s1;
                end
                else if(mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                    rxreq_alloc_ccid_s2_q[entry]     <= 2'b0;
                    rxreq_alloc_size_s2_q[entry]     <= chie_pkg::SIZE_1B;
                end
            end
       end
    endgenerate

    //************************************************************************//
    //                        databuffer inout data                           //
    //************************************************************************//
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst) begin:rdat_receive_logic
                if (rst)begin
                    dbf_data_q[entry]   <= '0;
                    dbf_be_q[entry]     <= '0;
                    dbf_poison_q[entry] <= '0;
                    dbf_tag_q[entry]    <= '0;
                    dbf_tu_q[entry]     <= '0;
                end
                else if (rdata_recv_update_sx && (entry == rdata_recv_entry_idx_sx)
                         && tagfetch_busy_q[entry])begin
                    ;// a tag fetch carries no data this entry owes -- see dbf_alloc_tag_q
                end
                else if (rdata_recv_update_sx && (entry == rdata_recv_entry_idx_sx))begin
                    dbf_data_q[entry]   <= dbf_data_q[entry] | rdata_recv_data_sx;
                    dbf_be_q[entry]     <= dbf_be_q[entry] | rdata_recv_be_sx;
                    dbf_poison_q[entry] <= dbf_poison_q[entry] | rdata_recv_poison_sx;
                    dbf_tag_q[entry]    <= dbf_tag_q[entry]    | rdata_recv_tag_sx;
                end
                else if (wdata_recv_update && (entry == wdata_recv_idx))begin
                    dbf_data_q[entry]   <= dbf_data_q[entry] | wdata_recv_data_sx;
                    dbf_be_q[entry]     <= dbf_be_q[entry] | wdata_recv_be_sx;
                    dbf_poison_q[entry] <= dbf_poison_q[entry] | wdata_recv_poison_sx;
                    dbf_tag_q[entry]    <= dbf_tag_q[entry]    | wdata_recv_tag_sx;
                    dbf_tu_q[entry]     <= dbf_tu_q[entry]     | wdata_recv_tu_sx;
                end
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                    dbf_data_q[entry]   <= '0;
                    dbf_be_q[entry]     <= '0;
                    dbf_poison_q[entry] <= '0;
                    dbf_tag_q[entry]    <= '0;
                    dbf_tu_q[entry]     <= '0;
                end
                else begin
                    ;
                end
            end
        end
    endgenerate

    //************************************************************************//
    //                             AXI R Channel                              //
    //************************************************************************//
    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:dbf_rd_mask_update_timing_logic
            always_ff @(posedge clk or posedge rst)begin:rdat_mask_timing_logic
                if(rst)begin
                        rdata_cdmask_q[entry]   <= {`SNF_MASK_CD_WIDTH{1'b0}};
                        rdata_wlmask_q[entry]   <= {`SNF_MASK_WL_WIDTH{1'b0}};
                end
                else if(rxreq_dbf_en_s1 && !rxreq_dbf_wr_s1 && (entry == rxreq_dbf_entry_idx_s1))begin
                        rdata_cdmask_q[entry]   <= dbf_cdmask_s0;
                        rdata_wlmask_q[entry]   <= dbf_wlmask_s1_q;
                end
                // A write entry's own tag fetch reuses the read chunk mask, which is
                // free by then: nothing else on a write entry reads the R channel.
                else if(mshr_dbf_tagfetch_ack_sx && (entry == mshr_dbf_tagfetch_idx_sx))begin
                        rdata_cdmask_q[entry]   <= dbf_match_cdmask_q[entry];
                        rdata_wlmask_q[entry]   <= dbf_match_wlmask_q[entry];
                end
                else if(rdata_recv_update_sx && rlast && (entry == rdata_recv_entry_idx_sx))begin
                        rdata_cdmask_q[entry]    <= {`SNF_MASK_CD_WIDTH{1'b0}};
                        rdata_wlmask_q[entry]    <= {`SNF_MASK_WL_WIDTH{1'b0}};
                end
                else if(rdata_recv_update_sx && !rlast && AXI_128 && (entry == rdata_recv_entry_idx_sx))begin
                        rdata_cdmask_q[entry]    <= dbf_rd_cdmask_next;
                        rdata_wlmask_q[entry]    <= rdata_wlmask_q[entry];
                end
                else if(rdata_recv_update_sx && !rlast && !AXI_128 && (entry == rdata_recv_entry_idx_sx))begin
                        rdata_cdmask_q[entry]    <= rdata_cdmask_q[entry] ^ {4{1'b1}};
                        rdata_wlmask_q[entry]    <= rdata_wlmask_q[entry];
                end
                else begin
                    ;
                end
            end
        end
    endgenerate

    assign rready = 1'b1;
    // AMBA AXI4 (IHI 0022) Table A3-4 gives RRESP two error encodings, SLVERR and
    // DECERR, which share bit 1. Sec 9.2 (p.9-335, MUST) requires a transaction's
    // Data response carry the error in none or all of its packets, so the bit is
    // sticky across the burst rather than per beat.
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin
            always_ff @(posedge clk or posedge rst)begin : rresp_timing_logic
                if(rst)
                    rresp_q[entry] <= {`AXI4_RRESP_WIDTH{1'b0}};
                else if(rdata_recv_update_sx && (entry == rdata_recv_entry_idx_sx) && rresp[1])
                    rresp_q[entry] <= rresp;
                else if(mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))
                    rresp_q[entry] <= {`AXI4_RRESP_WIDTH{1'b0}};
                else
                    ;
            end
        end
    endgenerate

    //************************************************************************//
    //                    SS12.11.1 Tag Match verdict                          //
    //************************************************************************//
    // SS12.11.1 (p.12-386, MUST) fixes the TagMatch Resp three ways: Fail when MTE
    // is not supported, Pass when it is supported but the match was not performed,
    // and Accurate when it was. This Subordinate stores Allocation Tags, so only the
    // last two arms are reachable here.
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin: tagmatch_logic
            // The read window of this entry's own address, snapshotted at allocation
            // because dbf_cdmask_s0 is only live in that cycle.
            always_ff @(posedge clk or posedge rst) begin: dbf_match_mask_timing_logic
                if(rst)begin
                    dbf_match_cdmask_q[entry] <= {`SNF_MASK_CD_WIDTH{1'b0}};
                    dbf_match_wlmask_q[entry] <= {`SNF_MASK_WL_WIDTH{1'b0}};
                end
                else if(rxreq_dbf_en_s1 && rxreq_dbf_wr_s1 && (entry == rxreq_dbf_entry_idx_s1))begin
                    dbf_match_cdmask_q[entry] <= dbf_cdmask_s0;
                    dbf_match_wlmask_q[entry] <= dbf_wlmask_s1_q;
                end
            end

            // SS12.5.2 (p.12-379, MUST): "Tag Match must be performed for only those
            // tags that have at least one corresponding BE bit asserted." The byte
            // enables are snapshotted with the Physical Tags because the fetch that
            // follows overwrites dbf_be_q.
            always_ff @(posedge clk or posedge rst) begin: dbf_match_operand_timing_logic
                if(rst || (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx)))begin
                    dbf_match_tag_q[entry] <= '0;
                    dbf_match_be_q[entry]  <= '0;
                    match_perform_q[entry] <= 1'b0;
                end
                else if(wdata_recv_update && (entry == wdata_recv_idx))begin
                    dbf_match_tag_q[entry] <= dbf_match_tag_q[entry] | wdata_recv_match_tag_sx;
                    dbf_match_be_q[entry]  <= dbf_match_be_q[entry]  | wdata_recv_be_sx;
                    match_perform_q[entry] <= match_perform_q[entry] | rxdat_match_s0;
                end
            end

            always_ff @(posedge clk or posedge rst) begin: dbf_alloc_tag_timing_logic
                if(rst || (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx)))
                    dbf_alloc_tag_q[entry] <= '0;
                else if(rdata_recv_update_sx && (entry == rdata_recv_entry_idx_sx)
                        && tagfetch_busy_q[entry])
                    dbf_alloc_tag_q[entry] <= dbf_alloc_tag_q[entry] | rdata_recv_tag_sx;
            end

            always_ff @(posedge clk or posedge rst) begin: tagmatch_state_timing_logic
                if(rst || (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx)))begin
                    tagfetch_req_q[entry]  <= 1'b0;
                    tagfetch_busy_q[entry] <= 1'b0;
                    tagmatch_done_q[entry] <= 1'b0;
                    tagmatch_pass_q[entry] <= 1'b0;
                end
                // The write data is in. Either there are tags to compare, or SS12.5.2
                // (p.12-379) forbids the comparison -- all byte enables deasserted --
                // or SS12.5.1 (p.12-378) downgraded the WriteData TagOp to Invalid
                // because the write was canceled. The last two are SS12.11.1's
                // "supported but not performed", which is a Pass.
                else if(dbf_mshr_rxdat_ok_sx && (entry == dbf_mshr_rxdat_ok_idx_sx)
                        && ~tagmatch_done_q[entry] && ~tagfetch_busy_q[entry]
                        && ~tagfetch_req_q[entry])begin
                    if(match_perform_q[entry] && (|dbf_match_be_q[entry]))
                        tagfetch_req_q[entry]  <= 1'b1;
                    else begin
                        tagmatch_done_q[entry] <= 1'b1;
                        tagmatch_pass_q[entry] <= 1'b1;
                    end
                end
                else if(dbf_mshr_rxdat_cancel_sx && (entry == dbf_mshr_rxdat_cancel_idx_sx)
                        && ~tagmatch_done_q[entry])begin
                    tagmatch_done_q[entry] <= 1'b1;
                    tagmatch_pass_q[entry] <= 1'b1;
                end
                else if(mshr_dbf_tagfetch_ack_sx && (entry == mshr_dbf_tagfetch_idx_sx))begin
                    tagfetch_req_q[entry]  <= 1'b0;
                    tagfetch_busy_q[entry] <= 1'b1;
                end


                else if(rdata_recv_update_sx && rlast && (entry == rdata_recv_entry_idx_sx)
                        && tagfetch_busy_q[entry])begin
                    tagfetch_busy_q[entry] <= 1'b0;
                    tagmatch_done_q[entry] <= 1'b1;
                    tagmatch_pass_q[entry] <= chie_pkg::tag_match_pass(
                        dbf_match_tag_q[entry],
                        dbf_alloc_tag_q[entry] | rdata_recv_tag_sx,
                        dbf_match_be_q[entry]);
                end
            end

        end
    endgenerate

    assign dbf_mshr_tagfetch_req_sx  = tagfetch_req_q;
    assign dbf_mshr_tagmatch_done_sx = tagmatch_done_q;
    assign dbf_mshr_tagmatch_pass_sx = tagmatch_pass_q;

    assign rdata_recv_update_sx = rready && rvalid;
    assign dbf_rd_cdmask_next_sel = rdata_cdmask_q[rdata_recv_entry_idx_sx] << 1;
    assign dbf_rd_cdmask_next = ((|dbf_rd_cdmask_next_sel) == 1'b0) ? 4'b0001 : dbf_rd_cdmask_next_sel;
    assign rdata_recv_entry_idx_sx = rdata_recv_update_sx ? rid[`SNF_MSHR_ENTRIES_WIDTH-1:0] : {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
    generate if (`AXI4_AXDATA_WIDTH == 128) begin: rdata_recv_data_128_gen
        assign rdata_recv_data_sx = {{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][2]}},{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}},{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][0]}}} & {4{rdata}};
    end
    else begin: rdata_recv_data_256_gen
        assign rdata_recv_data_sx = {{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_RDATA_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}}} & {2{rdata}};
    end
    endgenerate
    assign rdata_recv_be_sx = '1;
    // The AXI sideband carries the location's Allocation Tags beside its Poison; see
    // axi4_defines.svh. One tag per 16 bytes, so the granule count follows the bus.
    generate if (`AXI4_AXDATA_WIDTH == 128) begin: rdata_recv_tag_128_gen
        assign rdata_recv_tag_sx = {{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][2]}},{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}},{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][0]}}} & {4{ruser[`AXI4_USER_TAG_RANGE]}};
    end
    else begin: rdata_recv_tag_256_gen
        assign rdata_recv_tag_sx = {{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_TAG_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}}} & {2{ruser[`AXI4_USER_TAG_RANGE]}};
    end
    endgenerate

    generate if (`AXI4_AXDATA_WIDTH == 128) begin: rdata_recv_poison_128_gen
        assign rdata_recv_poison_sx = {{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][2]}},{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}},{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][0]}}} & {4{ruser[`AXI4_USER_POISON_RANGE]}};
    end
    else begin: rdata_recv_poison_256_gen
        assign rdata_recv_poison_sx = {{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][3]}},{`AXI4_POISON_WIDTH{rdata_cdmask_q[rdata_recv_entry_idx_sx][1]}}} & {2{ruser[`AXI4_USER_POISON_RANGE]}};
    end
    endgenerate
    // A tag fetch rides the read channel on a WRITE entry, so it must not look like
    // that entry's read data arriving -- nothing upstream is waiting for a data
    // response from it.
    assign dbf_mshr_rdata_en_sx = rdata_recv_update_sx & (~tagfetch_busy_q[rdata_recv_entry_idx_sx]);
    assign dbf_mshr_rdata_idx_sx = rdata_recv_entry_idx_sx;
    assign dbf_mshr_rdata_cdmask_sx = rdata_cdmask_q[rdata_recv_entry_idx_sx];

    //************************************************************************//
    //                        DBUF TXDAT Channel                              //
    //************************************************************************//

    assign dbf_txdat_valid_sx = dbf_txdat_en_sx;
    assign dbf_txdat_en_sx = mshr_txdat_en_sx && txdat_dbf_rdy_s1;
    assign dbf_txdat_entry_idx_sx = mshr_txdat_entry_idx_sx;
    // Table 2-15 (SS2.10.4 p.2-136): DataID names the packet's place in the line.
    assign dbf_txdat_pkt_sx    = mshr_txdat_dataid_sx >> `SNF_PKT_CHUNKS_LOG2;
    assign dbf_txdat_data_sx   = (dbf_txdat_en_sx) ? dbf_data_q[dbf_txdat_entry_idx_sx][dbf_txdat_pkt_sx*chie_pkg::DATA_WIDTH +: chie_pkg::DATA_WIDTH] : '0;
    assign dbf_txdat_tag_sx    = (dbf_txdat_en_sx) ? dbf_tag_q[dbf_txdat_entry_idx_sx][dbf_txdat_pkt_sx*chie_pkg::TAG_WIDTH +: chie_pkg::TAG_WIDTH] : '0;
    assign dbf_txdat_poison_sx = (dbf_txdat_en_sx) ? dbf_poison_q[dbf_txdat_entry_idx_sx][dbf_txdat_pkt_sx*chie_pkg::POISON_WIDTH +: chie_pkg::POISON_WIDTH] : '0;
    assign dbf_txdat_be_sx     = (dbf_txdat_en_sx) ? dbf_be_q[dbf_txdat_entry_idx_sx][dbf_txdat_pkt_sx*chie_pkg::BE_WIDTH +: chie_pkg::BE_WIDTH] : '0;

    assign mshr_txdat_ccid_sx = rxreq_alloc_ccid_s2_q[dbf_txdat_entry_idx_sx];

    // output to mshr
    assign mshr_txdat_won_sx = txdat_dbf_won_sx;

    always_comb begin:txdat_package_comb_logic
        // RSVDC is the field this Subordinate never sources. Defaulting the whole
        // flit to zero covers it at any configured width; the assignments below
        // override every field that does carry a value.

        txdat_flit           = '0;
        txdat_flit.tgtid     = mshr_txdat_tgtid_sx;
        txdat_flit.srcid     = mshr_txdat_srcid_sx;
        txdat_flit.txnid     = mshr_txdat_txnid_sx;
        txdat_flit.homenid   = mshr_txdat_homenid_sx;
        txdat_flit.opcode    = mshr_txdat_opcode_sx;
        // AXI4 (IHI 0022) Table A3-4: RRESP[1] is the SLVERR/DECERR bit, which
        // SS9.2 (p.9-335) reports upstream as a Non-data Error.
        txdat_flit.resperr   = rresp_q[dbf_txdat_entry_idx_sx][1] ? chie_pkg::RESP_ERR_NON_DATA
                                                                  : mshr_txdat_resperr_sx;
        txdat_flit.resp      = mshr_txdat_resp_sx;
        txdat_flit.dbid      = mshr_txdat_dbid_sx;
        txdat_flit.ccid      = mshr_txdat_ccid_sx;
        txdat_flit.dataid    = mshr_txdat_dataid_sx;
        txdat_flit.tracetag  = mshr_txdat_tracetag_sx;
        txdat_flit.be        = dbf_txdat_be_sx;
        txdat_flit.data      = dbf_txdat_data_sx;
        // CHI E.b section 9.6 (p.9-348): odd byte parity over the data this packet carries.
        txdat_flit.datacheck = chie_pkg::datacheck_of(dbf_txdat_data_sx);
        txdat_flit.poison    = dbf_txdat_poison_sx;
        // CHI E.b Sec 12.4.1 (p.12-376, MUST): a Completer that holds the location's
        // Allocation Tags answers a Transfer or Fetch read with TagOp=Transfer. Table
        // 13-32 (Sec 13.10.37 p.13-435) makes those tags Clean and its TU field "not
        // applicable and must be set to zero", and requires "all tags corresponding to
        // data in the packet" -- which is the whole of this packet's Tag field.
        txdat_flit.tagop     = mshr_txdat_tag_return_sx ? 2'b01 : 2'b00;
        txdat_flit.tag       = mshr_txdat_tag_return_sx ? dbf_txdat_tag_sx : '0;
        txdat_flit.tu        = '0;
        // CHI E.b section 11.1.1 (p.11-360, MUST): a memory SN-F that does not source a
        // useful DataSource "must return 0b0111 as a default value", not the 0b0000 that
        // section reserves for a responder which is not one. This Subordinate drops
        // PrefetchTgt, so every read is a complete memory access -- 0b0111 exactly.
        txdat_flit.datasource.datasource = 4'b0111;
    end

    //************************************************************************//
    //                              W channel                                 //
    //************************************************************************//
    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:recv_data_cnt_timing_logic
            always_ff @(posedge clk or posedge rst) begin
                if (rst)begin
                    wdata_recv_cnt_q[entry] <= '0;
                end
                else if (wdata_recv_update && (entry == wdata_recv_idx))begin
                    wdata_recv_cnt_q[entry] <= wdata_recv_cnt_next;
                end
                else if (dbf_mshr_rxdat_ok_sx && (entry == dbf_mshr_rxdat_ok_idx_sx))begin
                    wdata_recv_cnt_q[entry] <= '0;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin : recv_idx_timing_logic
        if (rst)begin
            wdata_rec_idx_sx_q <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if (wdata_recv_update)begin
            wdata_rec_idx_sx_q <= wdata_recv_idx;
        end
        else if (dbf_mshr_rxdat_ok_sx)begin
            wdata_rec_idx_sx_q <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
    end

    // Sec 4.5.2 (p.4-200, MUST): "All data packets originally intended to be
    // transferred must be sent", so a write is known cancelled only once its
    // whole data phase has arrived -- the moment dbf_mshr_rxdat_ok_sx reports.
    // Held per entry so the two are read in the same clock phase.
    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:wdata_cancel_gen
            always_ff @(posedge clk or posedge rst) begin : wdata_cancel_timing_logic
                if (rst)
                    wdata_cancel_q[entry] <= 1'b0;
                else if (wdata_cancel_recv_s0 && (entry == wdata_recv_idx))
                    wdata_cancel_q[entry] <= 1'b1;
                else if (dbf_mshr_rxdat_ok_sx && (entry == dbf_mshr_rxdat_ok_idx_sx))
                    wdata_cancel_q[entry] <= 1'b0;
            end
        end
    endgenerate

    // Table 4-39 (p.4-219): WriteNoSnpZero's WriteData response is "None", so its
    // payload is sourced here -- a full line of zeros with every byte enable set --
    // and injected on the same completion path a real beat takes, on a cycle no
    // real beat is using.
    generate
        for(entry=0;entry<`SNF_MSHR_ENTRIES_NUM;entry=entry+1) begin:wrzero_pending_gen
            always_ff @(posedge clk or posedge rst)begin:wrzero_pending_timing_logic
                if (rst)
                    wrzero_pending_q[entry] <= 1'b0;
                else if (rxreq_dbf_en_s1 && rxreq_dbf_wrzero_s1 && (entry == rxreq_dbf_entry_idx_s1))
                    wrzero_pending_q[entry] <= 1'b1;
                else if (wrzero_inject_sx && (entry == wrzero_inject_idx_sx))
                    wrzero_pending_q[entry] <= 1'b0;
            end
        end
    endgenerate

    always_comb begin:wrzero_inject_idx_comb_logic
        wrzero_inject_idx_sx = {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        for(int i=`SNF_MSHR_ENTRIES_NUM-1; i>=0; i=i-1)begin
            if (wrzero_pending_q[i])
                wrzero_inject_idx_sx = i[`SNF_MSHR_ENTRIES_WIDTH-1:0];
        end
    end

    assign wrzero_inject_sx = (|wrzero_pending_q) & (~rxdat_valid_s0);

    assign wdata_recv_update = rxdat_valid_s0 | wrzero_inject_sx;
    assign wdata_recv_idx  = rxdat_valid_s0 ? rxdat_txnid_s0[`SNF_MSHR_ENTRIES_WIDTH-1:0] : wrzero_inject_idx_sx;
    assign wdata_recv_cnt_next = wdata_recv_cnt_q[wdata_recv_idx] | wdata_recv_sx;
    assign wdata_cancel_recv_s0 = rxdat_valid_s0 && (rxdat_opcode_s0 == chie_pkg::DAT_WRITEDATACANCEL);
    assign rxdat_pkt_s0  = rxdat_dataid_s0 >> `SNF_PKT_CHUNKS_LOG2;
    assign wdata_recv_sx = wrzero_inject_sx ? '1
                         : (wdata_recv_update == 1'b1) ? (`SNF_PKTS'(1) << rxdat_pkt_s0) : '0;
    // The received beat lands in the packet of the line its DataID names
    // (SS2.10.4 p.2-136). A Write Zero injects the whole line instead, and a
    // cancelled write contributes nothing.
    always_comb begin : wdata_recv_t
        wdata_recv_data_sx   = '0;
        wdata_recv_be_sx     = wrzero_inject_sx ? '1 : '0;
        wdata_recv_poison_sx = '0;
        wdata_recv_tag_sx    = '0;
        wdata_recv_tu_sx     = '0;
        wdata_recv_match_tag_sx = '0;
        if (!wrzero_inject_sx && (wdata_cancel_recv_s0 == 1'b0)) begin
            wdata_recv_data_sx[rxdat_pkt_s0*chie_pkg::DATA_WIDTH +: chie_pkg::DATA_WIDTH]        = rxdat_data_s0;
            wdata_recv_be_sx[rxdat_pkt_s0*chie_pkg::BE_WIDTH +: chie_pkg::BE_WIDTH]              = rxdat_be_s0;
            wdata_recv_poison_sx[rxdat_pkt_s0*chie_pkg::POISON_WIDTH +: chie_pkg::POISON_WIDTH]  = rxdat_poison_s0;
            wdata_recv_tag_sx[rxdat_pkt_s0*chie_pkg::TAG_WIDTH +: chie_pkg::TAG_WIDTH]           = rxdat_tag_s0;
            wdata_recv_tu_sx[rxdat_pkt_s0*chie_pkg::TU_WIDTH +: chie_pkg::TU_WIDTH]              = rxdat_tu_s0;
            wdata_recv_match_tag_sx[rxdat_pkt_s0*chie_pkg::TAG_WIDTH +: chie_pkg::TAG_WIDTH]     = rxdat_match_tag_s0;
        end
    end



    // SS2.10.4 (p.2-136): a write of Size bytes arrives in max(1, Size/packet bytes)
    // packets, one per DataID; a Write Zero's injected line holds all of them.
    localparam int PKT_BYTES_LOG2 = $clog2(chie_pkg::DATA_WIDTH / 8);
    wire [2:0] rxdat_ok_size = rxreq_alloc_size_s2_q[wdata_rec_idx_sx_q];
    wire [3:0] rxdat_ok_pkts = (int'(rxdat_ok_size) > PKT_BYTES_LOG2) ? (4'd1 << (int'(rxdat_ok_size) - PKT_BYTES_LOG2)) : 4'd1;
    assign dbf_mshr_rxdat_ok_sx = ($countones(wdata_recv_cnt_q[wdata_rec_idx_sx_q]) >= int'(rxdat_ok_pkts));
    assign dbf_mshr_rxdat_ok_idx_sx = wdata_rec_idx_sx_q;
    assign dbf_mshr_rxdat_cancel_sx = dbf_mshr_rxdat_ok_sx && wdata_cancel_q[dbf_mshr_rxdat_ok_idx_sx];
    assign dbf_mshr_rxdat_cancel_idx_sx = dbf_mshr_rxdat_ok_idx_sx;

    //************************************************************************//
    //                      write data to AXI slave                           //
    //************************************************************************//
    always_ff @(posedge clk or posedge rst)begin:wdata_fifo_set_vec_timing_logic
        if (rst)begin
                wdata_fifo_set_vec <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if (mshr_wdat_en_sx)begin
                wdata_fifo_set_vec <= (wdata_fifo_set_vec == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (wdata_fifo_set_vec + 1'b1);
        end
    end

    always_ff @(posedge clk or posedge rst)begin:wdata_fifo_get_vec_timing_logic
        if (rst)begin
                wdata_fifo_get_vec <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
        end
        else if (wvalid && wready && wlast)begin
                wdata_fifo_get_vec <= (wdata_fifo_get_vec == IDX_LAST) ? {`SNF_MSHR_ENTRIES_WIDTH{1'b0}} : (wdata_fifo_get_vec + 1'b1);
        end
    end

    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:wdata_fifo_set_timing_logic
            always_ff @(posedge clk or posedge rst)begin
                if (rst)begin
                    wdata_fifo_valid_sx[entry]        <= 1'b0;
                    wdata_fifo_entry_idx_sx[entry]    <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
                else if (mshr_wdat_en_sx && (entry == wdata_fifo_set_vec))begin
                    wdata_fifo_valid_sx[entry]        <= 1'b1;
                    wdata_fifo_entry_idx_sx[entry]    <= mshr_wdat_entry_idx_sx;
                end
                else if (wvalid && wready && wlast && (entry == wdata_fifo_get_vec))begin
                    wdata_fifo_valid_sx[entry]        <= 1'b0;
                    wdata_fifo_entry_idx_sx[entry]    <= {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
                end
            end
        end
    endgenerate

    assign wvalid = wdata_fifo_valid_sx[wdata_fifo_get_vec];

    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:dbf_wr_wlmask_update_timing_logic
            always_ff @(posedge clk or posedge rst)begin:wr_wlmask_timing_logic
                if (rst)begin
                    wdata_wlmask_q[entry]    <= {`SNF_MASK_WL_WIDTH{1'b0}};
                end
                else if (rxreq_dbf_wr_s1 && rxreq_dbf_en_s1 && (entry == rxreq_dbf_entry_idx_s1))begin
                    wdata_wlmask_q[entry]    <= dbf_wlmask_s1_q;
                end
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                    wdata_wlmask_q[entry]    <= 4'b0000;
                end
                else begin
                    ;
                end
            end
        end
    endgenerate

    generate
        for(entry = 0;entry<`SNF_MSHR_ENTRIES_NUM;entry = entry+1) begin:dbf_wr_cdmask_update_timing_logic
            always_ff @(posedge clk or posedge rst)begin:wr_cdmask_timing_logic
                if (rst)begin
                    wdata_cdmask_q[entry]  <= {`SNF_MASK_CD_WIDTH{1'b0}};
                end
                else if (rxreq_dbf_en_s1 && rxreq_dbf_wr_s1 && (entry == rxreq_dbf_entry_idx_s1))begin
                    wdata_cdmask_q[entry]  <= dbf_cdmask_s0;
                end
                else if (wdata_to_slave && (entry == wdata_to_slave_idx))begin
                    wdata_cdmask_q[entry]  <= wdata_cdmask_next;
                end
                else if (mshr_retired_valid_sx && (entry == mshr_retired_idx_sx))begin
                    wdata_cdmask_q[entry]  <= 4'b0000;
                end
                else begin
                    ;
                end
            end
        end
    endgenerate

    assign wdata_to_slave = wvalid & wready;
    assign wdata_to_slave_idx = wvalid ? wdata_fifo_entry_idx_sx[wdata_fifo_get_vec] : {`SNF_MSHR_ENTRIES_WIDTH{1'b0}};
    assign wdata_cdmask_next = ((AXI_128) ? ((|(wdata_cdmask_q[wdata_to_slave_idx] <<1) != 0) ? (wdata_cdmask_q[wdata_to_slave_idx] <<1) : 4'b0001)
                                                : wdata_cdmask_q[wdata_to_slave_idx] ^ {4{1'b1}});
    assign wdata = (AXI_128) ? (({`AXI4_WDATA_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_data_q[wdata_to_slave_idx][0*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH])
                                        | ({`AXI4_WDATA_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][1]}} & dbf_data_q[wdata_to_slave_idx][1*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH])
                                        | ({`AXI4_WDATA_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_data_q[wdata_to_slave_idx][2*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH])
                                        | ({`AXI4_WDATA_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][3]}} & dbf_data_q[wdata_to_slave_idx][3*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH]))
                                      : (({`AXI4_WDATA_WIDTH/2{wdata_cdmask_q[wdata_to_slave_idx][1:0]}} & dbf_data_q[wdata_to_slave_idx][0*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH])
                                        | ({`AXI4_WDATA_WIDTH/2{wdata_cdmask_q[wdata_to_slave_idx][3:2]}} & dbf_data_q[wdata_to_slave_idx][1*`AXI4_WDATA_WIDTH+:`AXI4_WDATA_WIDTH]));

    assign wstrb = (AXI_128) ? (({`AXI4_WSTRB_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_be_q[wdata_to_slave_idx][0*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH])
                                        | ({`AXI4_WSTRB_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][1]}} & dbf_be_q[wdata_to_slave_idx][1*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH])
                                        | ({`AXI4_WSTRB_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_be_q[wdata_to_slave_idx][2*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH])
                                        | ({`AXI4_WSTRB_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][3]}} & dbf_be_q[wdata_to_slave_idx][3*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH]))
                                      : (({`AXI4_WSTRB_WIDTH/2{wdata_cdmask_q[wdata_to_slave_idx][1:0]}} & dbf_be_q[wdata_to_slave_idx][0*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH])
                                        | ({`AXI4_WSTRB_WIDTH/2{wdata_cdmask_q[wdata_to_slave_idx][3:2]}} & dbf_be_q[wdata_to_slave_idx][1*`AXI4_WSTRB_WIDTH+:`AXI4_WSTRB_WIDTH]));

    // SS12.5.2 (p.12-379, MUST): a TagOp=Update write installs "only the Tags that
    // have TU asserted", so the TU bits cross with them and memory applies the mask.
    assign wuser[`AXI4_USER_TAG_RANGE] = (AXI_128)
        ? (({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_tag_q[wdata_to_slave_idx][0*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH])
         | ({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][1]}} & dbf_tag_q[wdata_to_slave_idx][1*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH])
         | ({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_tag_q[wdata_to_slave_idx][2*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH])
         | ({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][3]}} & dbf_tag_q[wdata_to_slave_idx][3*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH]))
        : (({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_tag_q[wdata_to_slave_idx][0*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH])
         | ({`AXI4_TAG_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_tag_q[wdata_to_slave_idx][1*`AXI4_TAG_WIDTH +: `AXI4_TAG_WIDTH]));
    assign wuser[`AXI4_USER_TU_RANGE]  = (AXI_128)
        ? (({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_tu_q[wdata_to_slave_idx][0*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH])
         | ({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][1]}} & dbf_tu_q[wdata_to_slave_idx][1*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH])
         | ({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_tu_q[wdata_to_slave_idx][2*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH])
         | ({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][3]}} & dbf_tu_q[wdata_to_slave_idx][3*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH]))
        : (({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_tu_q[wdata_to_slave_idx][0*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH])
         | ({`AXI4_TU_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_tu_q[wdata_to_slave_idx][1*`AXI4_TU_WIDTH +: `AXI4_TU_WIDTH]));
    assign wuser[`AXI4_USER_POISON_RANGE] = (AXI_128) ? (({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_poison_q[wdata_to_slave_idx][0*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH])
                                        | ({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][1]}} & dbf_poison_q[wdata_to_slave_idx][1*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH])
                                        | ({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_poison_q[wdata_to_slave_idx][2*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH])
                                        | ({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][3]}} & dbf_poison_q[wdata_to_slave_idx][3*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH]))
                                      : (({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][0]}} & dbf_poison_q[wdata_to_slave_idx][0*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH])
                                        | ({`AXI4_POISON_WIDTH{wdata_cdmask_q[wdata_to_slave_idx][2]}} & dbf_poison_q[wdata_to_slave_idx][1*`AXI4_POISON_WIDTH+:`AXI4_POISON_WIDTH]));

    assign wlast = (wvalid == 1'b1) ? ((wdata_cdmask_q[wdata_to_slave_idx] == wdata_wlmask_q[wdata_to_slave_idx]) ? 1'b1 : 1'b0) : 1'b0;

endmodule
