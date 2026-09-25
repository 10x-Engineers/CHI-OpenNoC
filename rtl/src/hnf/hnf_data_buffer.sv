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
*    Wenhao Li <liwenhao@bosc.ac.cn>
*    Hongyu Gao <gaohongyu@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_data_buffer `HNF_PARAM
    (
    //global inputs
    input  wire                               clk,
    input  wire                               rst,

    //inputs from hnf_link_rxdat_parse
    input  wire                               li_dbf_rxdat_valid_s0,
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     li_dbf_rxdat_txnid_s0,
    input  chie_pkg::dat_opcode_e             li_dbf_rxdat_opcode_s0,
    input  wire [1:0]                         li_dbf_rxdat_dataid_s0,
    input  wire [chie_pkg::BE_WIDTH-1:0]      li_dbf_rxdat_be_s0,
    input  wire [chie_pkg::DATA_WIDTH-1:0]    li_dbf_rxdat_data_s0,
    input  wire [chie_pkg::POISON_WIDTH-1:0]  li_dbf_rxdat_poison_s0,
    input  wire [1:0]                         li_dbf_rxdat_tagop_s0,
    input  wire [chie_pkg::TAG_WIDTH-1:0]     li_dbf_rxdat_tag_s0,
    input  wire [chie_pkg::TU_WIDTH-1:0]      li_dbf_rxdat_tu_s0,

    //inputs from hnf_mshr_ctl
    //inputs from hnf_mshr_ctl -- Atomic execution (SS4.2.5 p.4-184)
    input  wire                               mshr_dbf_atm_set_s0,
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     mshr_dbf_atm_idx_s0,
    input  chie_pkg::req_opcode_e             mshr_dbf_atm_op_s0,
    input  wire [5:0]                         mshr_dbf_atm_off_s0,
    input  wire [6:0]                         mshr_dbf_atm_len_s0,
    input  wire                               mshr_dbf_atm_end_s0,
    input  wire                               mshr_dbf_rd_atm_sx1,
    input  wire [chie_pkg::BE_WIDTH*2-1:0]    mshr_dbf_rd_atm_be_sx1,
    input  wire [1:0]                         mshr_dbf_rd_atm_pe_sx1,
    input  wire [1:0]                         mshr_dbf_rd_pe_sx1,

    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     mshr_dbf_rd_idx_sx1_q,
    input  wire                               mshr_dbf_rd_valid_sx1_q,
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     mshr_dbf_retired_idx_sx1_q,
    input  wire                               mshr_dbf_retired_valid_sx1_q,
    // A line of zeros the Home sources itself, for the two transactions that get
    // no data from anywhere else: an errored read, which Sec 9.4.4 (p.9-342, MUST)
    // still owes its data packets, and a Write Zero, whose WriteData response
    // Table 4-39 (p.4-219) gives as None. The TXDAT wrapper derives DataID and the
    // beat count from the presence bits alone.
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     mshr_dbf_home_fill_idx_sx1_q,
    input  wire                               mshr_dbf_home_fill_valid_sx1_q,
    input  wire [`CACHE_BE_WIDTH-1:0]         mshr_dbf_home_fill_be_sx1_q,
    input  wire [1:0]                         mshr_dbf_home_fill_pe_sx1_q,

    //inputs from hnf_cache_pipeline
    input  wire                               pipe_dbf_wr_valid_sx9_q,
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     pipe_dbf_wr_idx_sx9_q,
    input  wire [chie_pkg::DATA_WIDTH*2-1:0]  pipe_dbf_wr_data_sx9_q,
    input  wire [`CACHE_POISON_WIDTH-1:0]     pipe_dbf_wr_poison_sx9_q,
    input  wire [`CACHE_TAGV_WIDTH-1:0]       pipe_dbf_wr_tagv_sx9_q,
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]     pipe_dbf_rd_idx_sx2_q,
    input  wire                               pipe_dbf_rd_idx_sx2_valid_q,


    //outputs to hnf_cache_pipeline
    output logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_pipe_rd_data_sx7_q,
    output wire [`CACHE_POISON_WIDTH-1:0]     dbf_pipe_rd_poison_sx7_q,
    output wire [`CACHE_TAGV_WIDTH-1:0]       dbf_pipe_rd_tagv_sx7_q,

    //outputs to hnf_link_txdat_wrap
    //outputs to hnf_mshr_ctl
    // Sec 2.10.3 (p.2-135) lets a SnpRespDataPtl assert "any combination of byte
    // enables", all of them included, so whether the line this entry holds is
    // complete is a property of the accumulated BE, not of the opcode that
    // delivered it.
    output wire [`MSHR_ENTRIES_NUM-1:0]       dbf_mshr_be_full_sx,
    output wire [`MSHR_ENTRIES_NUM-1:0]       dbf_mshr_tagmatch_pass_sx,
    // The same property combinationally, before the RXDAT flit now on the wire is
    // merged -- the MSHR's S0 decision cannot wait for dbf_mshr_be_full_sx.
    output wire                               dbf_mshr_be_full_s0,
    // SS12.4.1 (p.12-376): the Allocation Tags this entry holds, and whether they are Dirty.
    output wire [`MSHR_ENTRIES_NUM-1:0]       dbf_mshr_tags_full_sx,
    output wire [`MSHR_ENTRIES_NUM-1:0]       dbf_mshr_tags_any_sx,
    output wire [`MSHR_ENTRIES_NUM-1:0]       dbf_mshr_tags_dirty_sx,
    output wire                               dbf_mshr_tags_full_s0,
    output wire [`CACHE_TAG_WIDTH-1:0]        dbf_txdat_match_tag_sx1,

    output wire                               dbf_txdat_valid_sx1,
    output wire [`MSHR_ENTRIES_WIDTH-1:0]     dbf_txdat_idx_sx1,
    output wire [chie_pkg::BE_WIDTH*2-1:0]    dbf_txdat_be_sx1,
    output wire [chie_pkg::DATA_WIDTH*2-1:0]  dbf_txdat_data_sx1,
    output wire [1:0]                         dbf_txdat_pe_sx1,
    output wire [`CACHE_POISON_WIDTH-1:0]     dbf_txdat_poison_sx1,
    output wire [`CACHE_TAGV_WIDTH-1:0]       dbf_txdat_tagv_sx1
    );

    //internal signals
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_data_q[0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::BE_WIDTH*2-1:0]   dbf_be_q[0:`MSHR_ENTRIES_NUM-1];
    // SS4.4.2 (p.4-196, MUST) merges a partial Snoop response with "any dirty data
    // received with the Snoop response", and SS5.1.5 (p.5-251) fills the remainder
    // from memory -- so the Snoopee's copy wins and memory only completes it.
    // dbf_be_q records that a byte is present, never who supplied it, so this marks
    // the bytes that came from the Home's own fill (a memory CompData or an L3 read)
    // and are therefore still superseded by a Snoopee's.
    logic [chie_pkg::BE_WIDTH*2-1:0]   dbf_fill_q[0:`MSHR_ENTRIES_NUM-1];
    logic [1:0]                        dbf_pe_q[0:`MSHR_ENTRIES_NUM-1];
    // SS9.5 (p.9-347, MUST): "The Poison value, once set, must be propagated along
    // with the data." Chunk-granular, so it accumulates per 64-bit chunk rather
    // than following the byte-wise merge below.
    logic [`CACHE_POISON_WIDTH-1:0]    dbf_poison_q[0:`MSHR_ENTRIES_NUM-1];
    opennoc_hnf_pkg::hnf_tagv_s        dbf_tagv_q[0:`MSHR_ENTRIES_NUM-1];
    opennoc_hnf_pkg::hnf_tagv_s        temp_li_tagv;
    opennoc_hnf_pkg::hnf_tagv_s        temp_pipe_tagv;
    // SS12.5.2 (p.12-379): a Match write's Physical Tags, apart from the Allocation Tags.
    logic [`CACHE_TAG_WIDTH-1:0]       dbf_match_tag_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`CACHE_TAG_WIDTH-1:0]       temp_li_match_tag;
    logic [chie_pkg::BE_WIDTH*2-1:0]   dbf_match_be_q[0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::BE_WIDTH*2-1:0]   temp_li_match_be;
    logic [`CACHE_POISON_WIDTH-1:0]    temp_li_poison;
    logic [`CACHE_POISON_WIDTH-1:0]    temp_pipe_poison;
    // SS4.2.5 (p.4-187, MUST): an Atomic returns "the original value at the addressed
    // location", so dbf_data_q must keep the line as fetched and the operand is held
    // apart until the result is written out to the L3 below. One RXDAT packet holds
    // it whole -- Table 2-16 (SS2.10.5 p.2-137) caps Size at 32 bytes and SS2.10.5
    // aligns the payload to it, so it never crosses a packet boundary.
    logic [chie_pkg::DATA_WIDTH-1:0]   dbf_atm_data_q[0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::BE_WIDTH-1:0]     dbf_atm_be_q  [0:`MSHR_ENTRIES_NUM-1];
    logic                              dbf_atm_v_q   [0:`MSHR_ENTRIES_NUM-1];
    chie_pkg::req_opcode_e             dbf_atm_op_q  [0:`MSHR_ENTRIES_NUM-1];
    logic [5:0]                        dbf_atm_off_q [0:`MSHR_ENTRIES_NUM-1];
    logic [6:0]                        dbf_atm_len_q [0:`MSHR_ENTRIES_NUM-1];
    logic                              dbf_atm_end_q [0:`MSHR_ENTRIES_NUM-1];
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_atm_result_sx2;
    wire                               dbf_atm_rd_sx2;
    wire                               li_dbf_atm_operand_s0;
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_pipe_rd_data_sx3_q;
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_pipe_rd_data_sx4_q;
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_pipe_rd_data_sx5_q;
    logic [chie_pkg::DATA_WIDTH*2-1:0] dbf_pipe_rd_data_sx6_q;
    // The line's Poison and Allocation Tags, which travel to the L3 beside its data.
    localparam DBF_SB_WIDTH = `CACHE_POISON_WIDTH + `CACHE_TAGV_WIDTH;
    logic [DBF_SB_WIDTH-1:0]           dbf_pipe_rd_sb_sx3_q;
    logic [DBF_SB_WIDTH-1:0]           dbf_pipe_rd_sb_sx4_q;
    logic [DBF_SB_WIDTH-1:0]           dbf_pipe_rd_sb_sx5_q;
    logic [DBF_SB_WIDTH-1:0]           dbf_pipe_rd_sb_sx6_q;
    logic [DBF_SB_WIDTH-1:0]           dbf_pipe_rd_sb_sx7_q;

    logic [chie_pkg::DATA_WIDTH*2-1:0] temp_li_data;
    logic [chie_pkg::BE_WIDTH*2-1:0]   temp_li_be;
    logic [chie_pkg::BE_WIDTH*2-1:0]   temp_li_fill;

    logic [chie_pkg::DATA_WIDTH*2-1:0] temp_pipe_data;
    logic [chie_pkg::BE_WIDTH*2-1:0]   temp_pipe_be;
    logic [chie_pkg::BE_WIDTH*2-1:0]   temp_pipe_fill;

    // Element idx of a line-wide vector of 2*w lies in the packet DataID names.
    function automatic logic in_half(logic [1:0] dataid, int idx, int w);
        return ((dataid == 2'b00) && (idx < w)) || ((dataid == 2'b10) && (idx >= w));
    endfunction

    localparam DBF_PKT_BYTE_NUM  = chie_pkg::DATA_WIDTH/8;
    localparam DBF_PKT_IDX_WIDTH = $clog2(DBF_PKT_BYTE_NUM);

    wire [DBF_PKT_IDX_WIDTH:0] offset;

    assign offset=(li_dbf_rxdat_dataid_s0 == 2'b10)?DBF_PKT_BYTE_NUM[DBF_PKT_IDX_WIDTH:0]:{(DBF_PKT_IDX_WIDTH+1){1'b0}};

    assign li_dbf_atm_operand_s0 = li_dbf_rxdat_valid_s0 & dbf_atm_v_q[li_dbf_rxdat_txnid_s0] &
           ((li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA) |
            (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK));

    genvar i;
    generate
        for(i = 0;i<(chie_pkg::DATA_WIDTH*2)/8;i = i+1) begin:get_wt_temp
            // i counts bytes across the two-packet line, offset selects which packet
            // arrived, so the difference is the byte's index inside that packet. The
            // DataID guards below are what pair the two, and offset is a multiple of
            // DBF_PKT_BYTE_NUM, so this width carries the difference exactly.
            wire [DBF_PKT_IDX_WIDTH-1:0] rxdat_byte_idx;
            assign rxdat_byte_idx = i[DBF_PKT_IDX_WIDTH-1:0] - offset[DBF_PKT_IDX_WIDTH-1:0];

            always_comb begin//linklist temp data
                if (li_dbf_rxdat_valid_s0&&pipe_dbf_wr_valid_sx9_q&&(li_dbf_rxdat_txnid_s0 == pipe_dbf_wr_idx_sx9_q)) begin//write conflict
                    if ((li_dbf_rxdat_dataid_s0 == 2'b00&&i<chie_pkg::DATA_WIDTH/8)||(li_dbf_rxdat_dataid_s0 == 2'b10&&i >= chie_pkg::DATA_WIDTH/8)) begin//first package
                        temp_li_data[i*8+:8] = li_dbf_rxdat_be_s0[rxdat_byte_idx]?li_dbf_rxdat_data_s0[rxdat_byte_idx*8+:8]:(dbf_be_q[li_dbf_rxdat_txnid_s0][i]?dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8]:pipe_dbf_wr_data_sx9_q[i*8+:8]);
                        temp_li_be[i]        = 1;
                        temp_li_fill[i]      = li_dbf_rxdat_be_s0[rxdat_byte_idx]?1'b0:(dbf_be_q[li_dbf_rxdat_txnid_s0][i]?dbf_fill_q[li_dbf_rxdat_txnid_s0][i]:1'b1);
                    end
                    else begin//The rest
                        temp_li_data[i*8+:8] = dbf_be_q[li_dbf_rxdat_txnid_s0][i]?dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8]:pipe_dbf_wr_data_sx9_q[i*8+:8];
                        temp_li_be[i]        = 1;
                        temp_li_fill[i]      = dbf_be_q[li_dbf_rxdat_txnid_s0][i]?dbf_fill_q[li_dbf_rxdat_txnid_s0][i]:1'b1;
                    end
                end
                else begin
                    if (li_dbf_rxdat_valid_s0 && ((li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_COPYBACKWRDATA)||(li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA)||(li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK))) begin//over write
                        if ((li_dbf_rxdat_dataid_s0 == 2'b00&&i<chie_pkg::DATA_WIDTH/8)||(li_dbf_rxdat_dataid_s0 == 2'b10&&i >= chie_pkg::DATA_WIDTH/8))begin
                            temp_li_data[i*8+:8] = li_dbf_rxdat_be_s0[rxdat_byte_idx]?li_dbf_rxdat_data_s0[rxdat_byte_idx*8+:8]:dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = li_dbf_rxdat_be_s0[rxdat_byte_idx]||dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                            temp_li_fill[i]      = li_dbf_rxdat_be_s0[rxdat_byte_idx]?1'b0:dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                        else begin
                            temp_li_data[i*8+:8] = dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                            temp_li_fill[i]      = dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                    end
                    else if (li_dbf_rxdat_valid_s0 && ((li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATA)||(li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATAFWDED)||(li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_SNPRESPDATAPTL))) begin//merge
                        if ((li_dbf_rxdat_dataid_s0 == 2'b00&&i<chie_pkg::DATA_WIDTH/8)||(li_dbf_rxdat_dataid_s0 == 2'b10&&i >= chie_pkg::DATA_WIDTH/8))begin
                            // SS4.4.2 (p.4-196, MUST) / SS5.1.5 (p.5-251): a byte the Home's
                            // own fill supplied is superseded here, not kept.
                            temp_li_data[i*8+:8] = (li_dbf_rxdat_be_s0[rxdat_byte_idx]&&(!dbf_be_q[li_dbf_rxdat_txnid_s0][i]||dbf_fill_q[li_dbf_rxdat_txnid_s0][i]))?li_dbf_rxdat_data_s0[rxdat_byte_idx*8+:8]:dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = li_dbf_rxdat_be_s0[rxdat_byte_idx]||dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                            temp_li_fill[i]      = li_dbf_rxdat_be_s0[rxdat_byte_idx]?1'b0:dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                        else begin
                            temp_li_data[i*8+:8] = dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                            temp_li_fill[i]      = dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                    end
                    else if (li_dbf_rxdat_valid_s0 && (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_COMPDATA))begin
                        if ((li_dbf_rxdat_dataid_s0 == 2'b00&&i<chie_pkg::DATA_WIDTH/8)||(li_dbf_rxdat_dataid_s0 == 2'b10&&i >= chie_pkg::DATA_WIDTH/8))begin
                            // SS2.10.3 (p.2-135) scopes Byte Enables to Writes and Snoop responses,
                            // so a CompData carries the whole packet and every byte of it is valid.
                            temp_li_data[i*8+:8] = !dbf_be_q[li_dbf_rxdat_txnid_s0][i]?li_dbf_rxdat_data_s0[rxdat_byte_idx*8+:8]:dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = 1;
                            temp_li_fill[i]      = !dbf_be_q[li_dbf_rxdat_txnid_s0][i]?1'b1:dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                        else begin
                            temp_li_data[i*8+:8] = dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                            temp_li_be[i]        = dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                            temp_li_fill[i]      = dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                        end
                    end
                    else begin
                        temp_li_data[i*8+:8] = dbf_data_q[li_dbf_rxdat_txnid_s0][i*8+:8];
                        temp_li_be[i]        = dbf_be_q[li_dbf_rxdat_txnid_s0][i];
                        temp_li_fill[i]      = dbf_fill_q[li_dbf_rxdat_txnid_s0][i];
                    end
                end
            end

            // An L3 read is the Home's own image of the line, so it is a fill on the
            // same terms as a memory CompData.
            always_comb begin//pipe temp data
                if(pipe_dbf_wr_valid_sx9_q && pipe_dbf_rd_idx_sx2_valid_q)begin
                    temp_pipe_data[i*8+:8] = pipe_dbf_wr_data_sx9_q[i*8+:8];
                    temp_pipe_be[i]        = 1;
                    temp_pipe_fill[i]      = 1'b1;
                end
                else if (pipe_dbf_wr_valid_sx9_q&&!(li_dbf_rxdat_valid_s0&&!li_dbf_atm_operand_s0&&(li_dbf_rxdat_txnid_s0 == pipe_dbf_wr_idx_sx9_q)))begin
                    temp_pipe_data[i*8+:8] = dbf_be_q[pipe_dbf_wr_idx_sx9_q][i]?dbf_data_q[pipe_dbf_wr_idx_sx9_q][i*8+:8]:pipe_dbf_wr_data_sx9_q[i*8+:8];
                    temp_pipe_be[i]        = 1;
                    temp_pipe_fill[i]      = dbf_be_q[pipe_dbf_wr_idx_sx9_q][i]?dbf_fill_q[pipe_dbf_wr_idx_sx9_q][i]:1'b1;
                end
                else begin
                    temp_pipe_data[i*8+:8] = dbf_data_q[pipe_dbf_wr_idx_sx9_q][i*8+:8];
                    temp_pipe_be[i]        = dbf_be_q[pipe_dbf_wr_idx_sx9_q][i];
                    temp_pipe_fill[i]      = dbf_fill_q[pipe_dbf_wr_idx_sx9_q][i];
                end
            end
        end
    endgenerate

    // SS9.5 (p.9-347, MUST): Poison "must be propagated along with the data", so a chunk's
    // Poison is that of every source still supplying one of its bytes.
    localparam POISON_CHUNK_BYTES = chie_pkg::DATA_WIDTH / (8*chie_pkg::POISON_WIDTH);
    wire li_pipe_same = li_dbf_rxdat_valid_s0 && pipe_dbf_wr_valid_sx9_q && (li_dbf_rxdat_txnid_s0 == pipe_dbf_wr_idx_sx9_q);
    wire li_write     = (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_COPYBACKWRDATA) ||
                              (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA) ||
                              (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK);
    wire li_fill      = (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_COMPDATA);
    generate
        for(i = 0;i<`CACHE_POISON_WIDTH;i = i+1) begin:get_poison_temp
            wire covered;
            wire [POISON_CHUNK_BYTES-1:0] li_chunk_be;
            wire [POISON_CHUNK_BYTES-1:0] li_takes;
            wire [POISON_CHUNK_BYTES-1:0] pipe_held_own;
            wire li_base_poison;
            assign covered = li_dbf_rxdat_valid_s0 && (li_dbf_rxdat_opcode_s0 != chie_pkg::DAT_WRITEDATACANCEL) &&
                             in_half(li_dbf_rxdat_dataid_s0, i, chie_pkg::POISON_WIDTH);
            assign li_chunk_be = li_fill ? {POISON_CHUNK_BYTES{1'b1}}
                                         : li_dbf_rxdat_be_s0[(i % chie_pkg::POISON_WIDTH)*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES];
            // The bytes of the chunk this packet supplies, by the byte merge's precedence.
            assign li_takes = li_chunk_be & (li_write ? {POISON_CHUNK_BYTES{1'b1}} :
                                             li_fill  ? ~dbf_be_q[li_dbf_rxdat_txnid_s0][i*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES] :
                                                        (~dbf_be_q[li_dbf_rxdat_txnid_s0][i*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES] |
                                                          dbf_fill_q[li_dbf_rxdat_txnid_s0][i*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES]));
            assign pipe_held_own = dbf_be_q[pipe_dbf_wr_idx_sx9_q][i*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES] &
                                   ~dbf_fill_q[pipe_dbf_wr_idx_sx9_q][i*POISON_CHUNK_BYTES +: POISON_CHUNK_BYTES];

            // An eviction swap replaces the line outright; a fill supplies only unheld bytes.
            assign temp_pipe_poison[i] = (pipe_dbf_wr_valid_sx9_q && pipe_dbf_rd_idx_sx2_valid_q)
                                       ? pipe_dbf_wr_poison_sx9_q[i]
                                       : (((|pipe_held_own) & dbf_poison_q[pipe_dbf_wr_idx_sx9_q][i]) |
                                          ((~&pipe_held_own) & pipe_dbf_wr_poison_sx9_q[i]));
            assign li_base_poison = li_pipe_same ? temp_pipe_poison[i] : dbf_poison_q[li_dbf_rxdat_txnid_s0][i];
            assign temp_li_poison[i] = (covered & (&li_takes))
                                     ? li_dbf_rxdat_poison_s0[i % chie_pkg::POISON_WIDTH]
                                     : (li_base_poison | (covered & (|li_takes) & li_dbf_rxdat_poison_s0[i % chie_pkg::POISON_WIDTH]));
        end
    endgenerate

    // SS12.5.2 (p.12-379, MUST): Update installs "only the Tags that have TU asserted",
    // Dirty; Transfer's Clean tags (SS12.13 p.12-390) fill only where none is held.
    function automatic opennoc_hnf_pkg::hnf_tagv_s tagv_merge_li(
        opennoc_hnf_pkg::hnf_tagv_s     base,
        logic                           covered,
        logic [1:0]                     dataid,
        logic [1:0]                     tagop,
        logic [chie_pkg::TAG_WIDTH-1:0] tag,
        logic [chie_pkg::TU_WIDTH-1:0]  tu);
        opennoc_hnf_pkg::hnf_tagv_s     r;
        logic                           upd, cln, in_pkt;
        r = base;
        for (int t = 0; t < 2*chie_pkg::TU_WIDTH; t++) begin
            in_pkt = covered && in_half(dataid, t, chie_pkg::TU_WIDTH);
            upd    = in_pkt && (tagop == chie_pkg::TAGOP_UPDATE) && tu[t % chie_pkg::TU_WIDTH];
            cln    = in_pkt && (tagop == chie_pkg::TAGOP_TRANSFER) && !base.valid[t];
            if (upd || cln) begin
                r.tag[t*4 +: 4] = tag[(t % chie_pkg::TU_WIDTH)*4 +: 4];
                r.valid[t]      = 1'b1;
            end
            if (upd) r.dirty = 1'b1;
        end
        return r;
    endfunction

    // A fill -- the L3's image of the line -- supplies a tag only where the buffer
    // holds none of its own, the precedence dbf_fill_q gives its bytes.
    function automatic opennoc_hnf_pkg::hnf_tagv_s tagv_fill(
        opennoc_hnf_pkg::hnf_tagv_s held,
        opennoc_hnf_pkg::hnf_tagv_s fill);
        opennoc_hnf_pkg::hnf_tagv_s r;
        r = held;
        for (int t = 0; t < 2*chie_pkg::TU_WIDTH; t++)
            if (!held.valid[t]) begin
                r.tag[t*4 +: 4] = fill.tag[t*4 +: 4];
                r.valid[t]      = fill.valid[t];
            end
        r.dirty = held.dirty | fill.dirty;
        return r;
    endfunction

    // SS12.9.4 (p.12-384, MUST): a SnpRespDataPtl's tags are "ignored by the receiver".
    // A beat with no BE is still covered: SS12.5.2 (p.12-379) lets a Ptl Update assert TU alone.
    wire li_tag_covered = li_dbf_rxdat_valid_s0 && (li_dbf_rxdat_opcode_s0 != chie_pkg::DAT_SNPRESPDATAPTL);

    assign temp_pipe_tagv = (pipe_dbf_wr_valid_sx9_q && pipe_dbf_rd_idx_sx2_valid_q)
                          ? pipe_dbf_wr_tagv_sx9_q
                          : tagv_fill(dbf_tagv_q[pipe_dbf_wr_idx_sx9_q], pipe_dbf_wr_tagv_sx9_q);
    assign temp_li_tagv   = tagv_merge_li(li_pipe_same ? tagv_fill(dbf_tagv_q[li_dbf_rxdat_txnid_s0], pipe_dbf_wr_tagv_sx9_q)
                                                       : dbf_tagv_q[li_dbf_rxdat_txnid_s0],
                                          li_tag_covered, li_dbf_rxdat_dataid_s0, li_dbf_rxdat_tagop_s0,
                                          li_dbf_rxdat_tag_s0, li_dbf_rxdat_tu_s0);

    // SS12.5 (p.12-378, MUST): the WriteData's TagOp decides the match, scoped by SS12.5.2
    // (p.12-379, MUST) to the write's own byte enables, not a fill's.
    wire li_match = li_tag_covered && (li_dbf_rxdat_tagop_s0 == chie_pkg::TAGOP_MATCH) &&
                    ((li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NONCOPYBACKWRDATA) ||
                     (li_dbf_rxdat_opcode_s0 == chie_pkg::DAT_NCBWRDATACOMPACK));
    generate
        for(i = 0;i<2*chie_pkg::TU_WIDTH;i = i+1) begin:get_match_temp
            wire match_covered = li_match && in_half(li_dbf_rxdat_dataid_s0, i, chie_pkg::TU_WIDTH);
            assign temp_li_match_tag[i*4 +: 4] = match_covered
                ? li_dbf_rxdat_tag_s0[(i % chie_pkg::TU_WIDTH)*4 +: 4]
                : dbf_match_tag_q[li_dbf_rxdat_txnid_s0][i*4 +: 4];
        end
        for(i = 0;i<(chie_pkg::BE_WIDTH*2);i = i+1) begin:get_match_be_temp
            assign temp_li_match_be[i] = dbf_match_be_q[li_dbf_rxdat_txnid_s0][i] |
                   (li_match && in_half(li_dbf_rxdat_dataid_s0, i, chie_pkg::BE_WIDTH) &&
                    li_dbf_rxdat_be_s0[i % chie_pkg::BE_WIDTH]);
        end
    endgenerate

    generate
        for(i = 0;i<`MSHR_ENTRIES_NUM;i = i+1) begin:load_wt_temp
            always_ff @(posedge clk or posedge rst)begin
                if(rst)begin
                    dbf_data_q[i]   <= 'd0;
                    dbf_be_q[i]     <= 'd0;
                    dbf_fill_q[i]   <= 'd0;
                    dbf_pe_q[i]     <= 'd0;
                    dbf_poison_q[i] <= 'd0;
                    dbf_tagv_q[i]   <= 'd0;
                    dbf_match_tag_q[i] <= 'd0;
                    dbf_match_be_q[i] <= 'd0;
                end
                else begin
                    if (mshr_dbf_retired_valid_sx1_q && i == mshr_dbf_retired_idx_sx1_q) begin//entry retired
                        dbf_data_q[i]   <= 'd0;
                        dbf_be_q[i]     <= 'd0;
                        dbf_fill_q[i]   <= 'd0;
                        dbf_pe_q[i]     <= 'd0;
                        dbf_poison_q[i] <= 'd0;
                        dbf_tagv_q[i]   <= 'd0;
                        dbf_match_tag_q[i] <= 'd0;
                        dbf_match_be_q[i] <= 'd0;
                    end
                    else if (li_dbf_atm_operand_s0 && i == li_dbf_rxdat_txnid_s0)begin
                        //Atomic operand: kept out of the line, see dbf_atm_data_q
                        // SS12.7 (p.12-381): its Physical Tags are the ones matched.
                        dbf_match_tag_q[i] <= temp_li_match_tag;
                        dbf_match_be_q[i]  <= temp_li_match_be;
                        if (pipe_dbf_wr_valid_sx9_q && i == pipe_dbf_wr_idx_sx9_q) begin
                            dbf_data_q[i]   <= temp_pipe_data;
                            dbf_be_q[i]     <= temp_pipe_be;
                            dbf_fill_q[i]   <= temp_pipe_fill;
                            dbf_pe_q[i]     <= 2'b11;
                            dbf_poison_q[i] <= temp_pipe_poison;
                            dbf_tagv_q[i]   <= temp_pipe_tagv;
                        end
                    end
                    else if (li_dbf_rxdat_valid_s0 && pipe_dbf_wr_valid_sx9_q && i == li_dbf_rxdat_txnid_s0 && i== pipe_dbf_wr_idx_sx9_q)begin
                        dbf_data_q[i]   <= temp_li_data;
                        dbf_be_q[i]     <= temp_li_be;
                        dbf_fill_q[i]   <= temp_li_fill;
                        dbf_pe_q[i]     <= 2'b11;
                        dbf_poison_q[i] <= temp_li_poison;
                        dbf_tagv_q[i]   <= temp_li_tagv;
                        dbf_match_tag_q[i] <= temp_li_match_tag;
                        dbf_match_be_q[i] <= temp_li_match_be;
                    end
                    else if(li_dbf_rxdat_valid_s0 && i == li_dbf_rxdat_txnid_s0)begin
                        dbf_data_q[i]   <= temp_li_data;
                        dbf_be_q[i]     <= temp_li_be;
                        dbf_fill_q[i]   <= temp_li_fill;
                        dbf_pe_q[i]     <= (li_dbf_rxdat_dataid_s0 == 2'b00) ? (dbf_pe_q[i] | 2'b01) : (dbf_pe_q[i] | 2'b10);
                        dbf_poison_q[i] <= temp_li_poison;
                        dbf_tagv_q[i]   <= temp_li_tagv;
                        dbf_match_tag_q[i] <= temp_li_match_tag;
                        dbf_match_be_q[i] <= temp_li_match_be;
                    end
                    else if (pipe_dbf_wr_valid_sx9_q && i == pipe_dbf_wr_idx_sx9_q)begin
                        dbf_data_q[i]   <= temp_pipe_data;
                        dbf_be_q[i]     <= temp_pipe_be;
                        dbf_fill_q[i]   <= temp_pipe_fill;
                        dbf_pe_q[i]     <= 2'b11;
                        dbf_poison_q[i] <= temp_pipe_poison;
                        dbf_tagv_q[i]   <= temp_pipe_tagv;
                    end
                    else if (mshr_dbf_home_fill_valid_sx1_q && i == mshr_dbf_home_fill_idx_sx1_q)begin
                        // SS9.4.4 (p.9-342) / a Write Zero: the Home's own bytes, not a fill
                        // standing in for a copy it has yet to see, so nothing supersedes them.
                        dbf_data_q[i]   <= 'd0;
                        dbf_be_q[i]     <= mshr_dbf_home_fill_be_sx1_q;
                        dbf_fill_q[i]   <= 'd0;
                        dbf_pe_q[i]     <= mshr_dbf_home_fill_pe_sx1_q;
                        dbf_poison_q[i] <= 'd0;
                        dbf_tagv_q[i]   <= 'd0;
                        dbf_match_tag_q[i] <= 'd0;
                        dbf_match_be_q[i] <= 'd0;
                    end
                    else begin
                    end
                end
            end
        end
    endgenerate

    generate
        for(i = 0;i<`MSHR_ENTRIES_NUM;i = i+1) begin:atm_record
            always_ff @(posedge clk or posedge rst)begin
                if(rst)begin
                    dbf_atm_v_q[i]    <= 1'b0;
                    dbf_atm_op_q[i]   <= chie_pkg::REQ_REQLCRDRETURN;
                    dbf_atm_off_q[i]  <= 6'd0;
                    dbf_atm_len_q[i]  <= 7'd0;
                    dbf_atm_end_q[i]  <= 1'b0;
                end
                else if(mshr_dbf_atm_set_s0 && i == mshr_dbf_atm_idx_s0)begin
                    dbf_atm_v_q[i]    <= 1'b1;
                    dbf_atm_op_q[i]   <= mshr_dbf_atm_op_s0;
                    dbf_atm_off_q[i]  <= mshr_dbf_atm_off_s0;
                    dbf_atm_len_q[i]  <= mshr_dbf_atm_len_s0;
                    dbf_atm_end_q[i]  <= mshr_dbf_atm_end_s0;
                end
                else if(mshr_dbf_retired_valid_sx1_q && i == mshr_dbf_retired_idx_sx1_q)
                    dbf_atm_v_q[i]    <= 1'b0;
                else
                    ;
            end

            always_ff @(posedge clk or posedge rst)begin
                if(rst)begin
                    dbf_atm_data_q[i] <= 'd0;
                    dbf_atm_be_q[i]   <= 'd0;
                end
                else if(li_dbf_atm_operand_s0 && i == li_dbf_rxdat_txnid_s0)begin
                    dbf_atm_data_q[i] <= li_dbf_rxdat_data_s0;
                    dbf_atm_be_q[i]   <= li_dbf_rxdat_be_s0;
                end
                else if(mshr_dbf_retired_valid_sx1_q && i == mshr_dbf_retired_idx_sx1_q)begin
                    dbf_atm_data_q[i] <= 'd0;
                    dbf_atm_be_q[i]   <= 'd0;
                end
                else
                    ;
            end
        end
    endgenerate

    // The read-modify-write, on the one path that carries the line out to the L3.
    // Table 4-19 (SS4.2.5 p.4-185) and Table 4-20 (p.4-186) give the arithmetic;
    // SS2.10.5 (p.2-137) the placement -- the element sits at Addr[5:0] within the
    // line, and AtomicCompare's Swap half at that offset with bit[log2(len)] flipped.
    assign dbf_atm_rd_sx2 = pipe_dbf_rd_idx_sx2_valid_q & dbf_atm_v_q[pipe_dbf_rd_idx_sx2_q];

    always_comb begin : dbf_atm_rmw
        logic [`MSHR_ENTRIES_WIDTH-1:0] a_idx;
        chie_pkg::req_opcode_e          a_op;
        int unsigned                    a_len, a_off, a_soff, a_poff;
        logic [127:0]                   a_init128, a_cmp128, a_swap128, a_wr128;
        logic [63:0]                    a_res;
        logic                           a_match;

        a_idx              = pipe_dbf_rd_idx_sx2_q;
        dbf_atm_result_sx2 = dbf_data_q[a_idx];
        a_op               = dbf_atm_op_q[a_idx];
        a_len              = {25'd0, dbf_atm_len_q[a_idx]};
        a_off              = {26'd0, dbf_atm_off_q[a_idx]};
        a_soff             = {26'd0, chie_pkg::atomic_swap_off(dbf_atm_off_q[a_idx], a_len)};
        // The operand is one RXDAT packet, so its bytes are indexed inside that
        // packet rather than inside the line.
        a_poff             = a_off & (DBF_PKT_BYTE_NUM - 1);
        a_soff             = a_soff & (DBF_PKT_BYTE_NUM - 1);

        a_init128 = 128'd0;
        a_cmp128  = 128'd0;
        a_swap128 = 128'd0;
        for (int unsigned b = 0; b < 16; b = b + 1)
            if (b < a_len) begin
                a_init128[b*8 +: 8] = dbf_data_q[a_idx][((a_off + b) & 63)*8 +: 8];
                a_cmp128 [b*8 +: 8] = dbf_atm_data_q[a_idx][((a_poff + b) & (DBF_PKT_BYTE_NUM-1))*8 +: 8];
                a_swap128[b*8 +: 8] = dbf_atm_data_q[a_idx][((a_soff + b) & (DBF_PKT_BYTE_NUM-1))*8 +: 8];
            end

        a_match = chie_pkg::atomic_compare_eq(a_init128, a_cmp128, a_len);
        a_res   = chie_pkg::atomic_alu(a_op, a_len, dbf_atm_end_q[a_idx],
                                       a_init128[63:0], a_cmp128[63:0]);

        // Table 2-16 (SS2.10.5 p.2-137) bounds AtomicStore/Load/Swap at 8 bytes and
        // only AtomicCompare at 16, so the ALU result is the narrower source, widened
        // here to the one vector the write-back indexes.
        a_wr128 = (a_op == chie_pkg::REQ_ATOMICCOMPARE) ? (a_match ? a_swap128 : a_init128)
                                                        : {64'd0, a_res};

        if (dbf_atm_rd_sx2)
            for (int unsigned b = 0; b < 16; b = b + 1)
                if (b < a_len)
                    dbf_atm_result_sx2[((a_off + b) & 63)*8 +: 8] = a_wr128[b*8 +: 8];
    end

    always_ff @(posedge clk or posedge rst)begin :pipe_rd
        if(rst)begin
            dbf_pipe_rd_data_sx3_q   <= 'd0;
            dbf_pipe_rd_data_sx4_q   <= 'd0;
            dbf_pipe_rd_data_sx5_q   <= 'd0;
            dbf_pipe_rd_data_sx6_q   <= 'd0;
            dbf_pipe_rd_data_sx7_q   <= 'd0;
            dbf_pipe_rd_sb_sx3_q     <= 'd0;
            dbf_pipe_rd_sb_sx4_q     <= 'd0;
            dbf_pipe_rd_sb_sx5_q     <= 'd0;
            dbf_pipe_rd_sb_sx6_q     <= 'd0;
            dbf_pipe_rd_sb_sx7_q     <= 'd0;
        end
        else begin
            dbf_pipe_rd_data_sx3_q   <= pipe_dbf_rd_idx_sx2_valid_q?dbf_atm_result_sx2:dbf_pipe_rd_data_sx3_q;
            dbf_pipe_rd_data_sx4_q   <= dbf_pipe_rd_data_sx3_q;
            dbf_pipe_rd_data_sx5_q   <= dbf_pipe_rd_data_sx4_q;
            dbf_pipe_rd_sb_sx3_q     <= pipe_dbf_rd_idx_sx2_valid_q ? {dbf_poison_q[pipe_dbf_rd_idx_sx2_q], dbf_tagv_q[pipe_dbf_rd_idx_sx2_q]}
                                                                    : dbf_pipe_rd_sb_sx3_q;
            dbf_pipe_rd_sb_sx4_q     <= dbf_pipe_rd_sb_sx3_q;
            dbf_pipe_rd_sb_sx5_q     <= dbf_pipe_rd_sb_sx4_q;
`ifdef HNF_DELAY_ONE_CYCLE

            dbf_pipe_rd_data_sx6_q   <= dbf_pipe_rd_data_sx5_q;
            dbf_pipe_rd_data_sx7_q   <= dbf_pipe_rd_data_sx6_q;
            dbf_pipe_rd_sb_sx6_q     <= dbf_pipe_rd_sb_sx5_q;
            dbf_pipe_rd_sb_sx7_q     <= dbf_pipe_rd_sb_sx6_q;
`else
            dbf_pipe_rd_data_sx7_q   <= dbf_pipe_rd_data_sx5_q;
            dbf_pipe_rd_sb_sx7_q     <= dbf_pipe_rd_sb_sx5_q;
`endif

        end
    end
    assign {dbf_pipe_rd_poison_sx7_q, dbf_pipe_rd_tagv_sx7_q} = dbf_pipe_rd_sb_sx7_q;

    assign dbf_txdat_valid_sx1 = mshr_dbf_rd_valid_sx1_q;//tx read
    assign dbf_txdat_idx_sx1   = mshr_dbf_rd_idx_sx1_q;
    // SS4.2.5 (p.4-187, MUST): an Atomic's inbound data size is its outbound size
    // (half for AtomicCompare) with "byte enables asserted for all valid data", so
    // its CompData carries that extent and nothing else. dbf_data_q still holds the
    // line as fetched, which is the original value that MUST returns.
    assign dbf_txdat_be_sx1    = mshr_dbf_rd_atm_sx1 ? (dbf_be_q[mshr_dbf_rd_idx_sx1_q] & mshr_dbf_rd_atm_be_sx1)
                                                     :  dbf_be_q[mshr_dbf_rd_idx_sx1_q];

    generate
        for (genvar be_e = 0; be_e < `MSHR_ENTRIES_NUM; be_e = be_e + 1) begin : dbf_be_full
            assign dbf_mshr_be_full_sx[be_e] = &dbf_be_q[be_e];
        end
    endgenerate
    assign dbf_mshr_be_full_s0 = &temp_li_be;
    assign dbf_txdat_data_sx1  = dbf_data_q[mshr_dbf_rd_idx_sx1_q];
    // Sec 2.10.4 (p.2-136): what the completion owes, intersected with what the
    // buffer actually holds.
    assign dbf_txdat_pe_sx1    = mshr_dbf_rd_atm_sx1 ? mshr_dbf_rd_atm_pe_sx1
                                                    : (dbf_pe_q[mshr_dbf_rd_idx_sx1_q] & mshr_dbf_rd_pe_sx1);
    assign dbf_txdat_poison_sx1 = dbf_poison_q[mshr_dbf_rd_idx_sx1_q];
    assign dbf_txdat_tagv_sx1   = dbf_tagv_q[mshr_dbf_rd_idx_sx1_q];
    assign dbf_txdat_match_tag_sx1 = dbf_match_tag_q[mshr_dbf_rd_idx_sx1_q];

    // SS12.11.1 (p.12-386, MUST): an accurate verdict where performed, Pass where not; a
    // performed granule with no Allocation Tag is memory without MTE, Fail (SS12.11.3 p.12-387).
    generate
        for(i = 0;i<`MSHR_ENTRIES_NUM;i = i+1) begin:tagmatch_verdict
            logic pass;
            always_comb begin
                pass = chie_pkg::tag_match_pass(dbf_match_tag_q[i], dbf_tagv_q[i].tag, dbf_match_be_q[i]);
                for (int t = 0; t < 2*chie_pkg::TU_WIDTH; t++)
                    if ((|dbf_match_be_q[i][t*chie_pkg::LINE_BE_PER_TAG +: chie_pkg::LINE_BE_PER_TAG]) &&
                        !dbf_tagv_q[i].valid[t])
                        pass = 1'b0;
            end
            assign dbf_mshr_tagmatch_pass_sx[i] = pass;
            assign dbf_mshr_tags_full_sx[i]     = opennoc_hnf_pkg::hnf_tagv_full(dbf_tagv_q[i]);
            assign dbf_mshr_tags_any_sx[i]      = opennoc_hnf_pkg::hnf_tagv_any(dbf_tagv_q[i]);
            assign dbf_mshr_tags_dirty_sx[i]    = dbf_tagv_q[i].dirty;
        end
    endgenerate
    assign dbf_mshr_tags_full_s0 = opennoc_hnf_pkg::hnf_tagv_full(temp_li_tagv);

endmodule
