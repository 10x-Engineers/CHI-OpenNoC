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
*    Guo Bing <guobing@bosc.ac.cn>
*    Nana Cai <cainana@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_mshr_addr_buffer `HNF_PARAM
    (
    //global inputs
    input  wire                                clk,
    input  wire                                rst,

    //compare req
    input  wire                                li_mshr_rxreq_valid_s0,                     //inputs from hnf_link_rxreq_parse
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:0] li_mshr_rxreq_addr_s0,                      //inputs from hnf_link_rxreq_parse
    output logic                               rxreq_cam_hazard_s1_q,                      //outputs to hnf_mshr_bypass and hnf_mshr_ctl
    output logic [`MSHR_ENTRIES_NUM-1:0]       rxreq_cam_hazard_entry_s1_q,                //outputs to hnf_mshr_bypass and hnf_mshr_ctl

    //compare pipe
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:0] pipe_mshr_addr_sx2_q,                       //inputs from hnf_cache_pipeline
    input  wire                                pipe_mshr_addr_valid_sx2_q,                 //inputs from hnf_cache_pipeline
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      pipe_mshr_addr_idx_sx2_q,                   //inputs from hnf_cache_pipeline
    output logic [`MSHR_ENTRIES_NUM-1:0]       pipe_cam_hazard_entry_sx3_q,                //outputs to hnf_mshr_ctl
    output logic [`MSHR_ENTRIES_NUM-1:0]       pipe_sleep_entry_sx3_q,                     //outputs to hnf_mshr_ctl
    output logic                               mshr_l3_hazard_valid_sx3_q,                 //outputs to hnf_mshr_ctl and hnf_cache_pipeline

    //compare evict victim
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] pipe_evict_cam_addr_sx4,  //inputs from hnf_cache_pipeline
    input  wire                                pipe_evict_cam_valid_sx4,                   //inputs from hnf_cache_pipeline
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      pipe_evict_cam_idx_sx4,                     //inputs from hnf_cache_pipeline
    input  wire [`MSHR_ENTRIES_NUM-1:0]        mshr_mem_busy_sx,                           //inputs from hnf_mshr_ctl
    output logic                               mshr_evict_hazard_sx5,                      //outputs to hnf_cache_pipeline

    //read_port
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      mshr_l3_entry_idx_sx1_q,                    //inputs from hnf_mshr_ctl
    input  wire [11:0]                         mshr_txsnp_rd_idx_sx1_q,                    //inputs from hnf_mshr_ctl
    input  wire [11:0]                         mshr_txreq_rd_idx_sx1_q,                    //inputs from hnf_mshr_ctl
    output wire [chie_pkg::REQ_ADDR_WIDTH-1:0] mshr_l3_addr_sx1,                           //outputs to hnf_cache_pipeline
    output wire [chie_pkg::SNP_ADDR_WIDTH-1:0] mshr_txsnp_addr_sx1,                        //outputs to hnf_link_txsnp_wrap
    output wire [chie_pkg::REQ_ADDR_WIDTH-1:0] mshr_txreq_addr_sx1,                        //outputs to hnf_link_txreq_wrap

    //write_port_req
    input  wire                                mshr_alloc_en_s1_q,                         //inputs from hnf_mshr_qos
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      mshr_entry_idx_alloc_s1_q,                  //inputs from hnf_mshr_qos

    //write_port_cpl
    input  wire                                l3_evict_sx7_q,                             //inputs from hnf_cache_pipeline
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      l3_mshr_entry_sx7_q,                        //inputs from hnf_cache_pipeline
    input  wire [chie_pkg::REQ_ADDR_WIDTH-1:0] l3_evict_addr_sx7_q,                        //inputs from hnf_cache_pipeline

    //retire
    input  wire [`MSHR_ENTRIES_WIDTH-1:0]      mshr_dbf_retired_idx_sx1_q,                 //inputs from hnf_mshr_ctl
    input  wire                                mshr_dbf_retired_valid_sx1_q,               //inputs from hnf_mshr_ctl

    //input form qos(not use)
    input  wire [`MSHR_ENTRIES_NUM-1:0]        mshr_entry_alloc_s1_q

    );
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0] abf_sx_q[0:`MSHR_ENTRIES_NUM-1];
    logic [`MSHR_ENTRIES_NUM-1:0]        abf_can_compare_sx_q;
    logic [`MSHR_ENTRIES_NUM-1:0]        abf_internal_evict_addr_valid_sx_q;
    logic                                li_mshr_rxreq_valid_s1_q;
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0] li_mshr_rxreq_addr_s1_q;
    logic                                pipe_mshr_addr_valid_sx3_q;
    logic [chie_pkg::REQ_ADDR_WIDTH-1:0] pipe_mshr_addr_sx3_q;
    logic [`MSHR_ENTRIES_WIDTH-1:0]      pipe_mshr_addr_idx_sx3_q;
    logic                                pipe_evict_cam_valid_sx5_q;
    logic [chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] pipe_evict_cam_addr_sx5_q;
    logic [`MSHR_ENTRIES_WIDTH-1:0]      pipe_evict_cam_idx_sx5_q;

    genvar                               i;
    function automatic logic [`MSHR_ENTRIES_NUM-1:0] trans_id2num(input logic [`MSHR_ENTRIES_WIDTH-1:0] id);
        trans_id2num     = 0;
        trans_id2num[id] = 1;
    endfunction


    always_ff @(posedge clk or posedge rst) begin:com_port0_delay
        if(rst)begin
            li_mshr_rxreq_valid_s1_q<='d0;
            li_mshr_rxreq_addr_s1_q <='d0;
        end
        else begin
            li_mshr_rxreq_valid_s1_q<=li_mshr_rxreq_valid_s0;
            li_mshr_rxreq_addr_s1_q <=li_mshr_rxreq_addr_s0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin:com_port1_delay
        if(rst)begin
            pipe_mshr_addr_valid_sx3_q  <='d0;
            pipe_mshr_addr_sx3_q        <='d0;
            pipe_mshr_addr_idx_sx3_q    <='d0;
        end
        else begin
            pipe_mshr_addr_valid_sx3_q  <=pipe_mshr_addr_valid_sx2_q;
            pipe_mshr_addr_sx3_q        <=pipe_mshr_addr_sx2_q      ;
            pipe_mshr_addr_idx_sx3_q    <=pipe_mshr_addr_idx_sx2_q  ;
        end
    end

    always_ff @(posedge clk or posedge rst) begin:com_port2_delay
        if(rst)begin
            pipe_evict_cam_valid_sx5_q <='d0;
            pipe_evict_cam_addr_sx5_q  <='d0;
            pipe_evict_cam_idx_sx5_q   <='d0;
        end
        else begin
            pipe_evict_cam_valid_sx5_q <=pipe_evict_cam_valid_sx4;
            pipe_evict_cam_addr_sx5_q  <=pipe_evict_cam_addr_sx4 ;
            pipe_evict_cam_idx_sx5_q   <=pipe_evict_cam_idx_sx4  ;
        end
    end

    generate
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            always_ff @(posedge clk or posedge rst) begin:write_buffer
                if(rst == 1'b1)
                    abf_sx_q[i] <= '0;
                else if(mshr_alloc_en_s1_q == 1'b1 && mshr_entry_idx_alloc_s1_q == i)
                    abf_sx_q[i] <= li_mshr_rxreq_addr_s1_q;
                else if(l3_evict_sx7_q == 1'b1 && l3_mshr_entry_sx7_q == i[`MSHR_ENTRIES_WIDTH-1:0])
                    abf_sx_q[i] <= l3_evict_addr_sx7_q;
                else
                    abf_sx_q[i] <= abf_sx_q[i];
            end
        end
    endgenerate

    generate
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            always_ff @(posedge clk or posedge rst) begin:can_compare_evict
                if(rst == 1'b1)begin
                    abf_can_compare_sx_q[i]               <= 1'b0;
                    abf_internal_evict_addr_valid_sx_q[i] <= 1'b0;
                end
                else begin
                    if(mshr_dbf_retired_valid_sx1_q == 1'b1 && mshr_dbf_retired_idx_sx1_q == i[`MSHR_ENTRIES_WIDTH-1:0])begin
                        abf_can_compare_sx_q[i]               <= 1'b0;
                        abf_internal_evict_addr_valid_sx_q[i] <= 1'b0;
                    end
                    else begin
                        if(l3_evict_sx7_q && i == l3_mshr_entry_sx7_q)begin
                            abf_can_compare_sx_q[i]                 <= 1'b0;
                            abf_internal_evict_addr_valid_sx_q[i]   <= 1'b1;
                        end
                        else if(mshr_alloc_en_s1_q && i == mshr_entry_idx_alloc_s1_q)begin
                            abf_can_compare_sx_q[i]                 <= 1'b1;
                            abf_internal_evict_addr_valid_sx_q[i]   <= 1'b0;
                        end
                        else if(li_mshr_rxreq_valid_s1_q && (abf_can_compare_sx_q[i] | abf_internal_evict_addr_valid_sx_q[i]) == 1'b1 && abf_sx_q[i][chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] == li_mshr_rxreq_addr_s1_q[chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET])begin
                            // The matched entry leaves both CAMs and the entry
                            // allocating this cycle becomes the next link, which
                            // is what keeps the sleeper chain single-linked.
                            if(mshr_alloc_en_s1_q)begin
                                abf_can_compare_sx_q[i]               <= 1'b0;
                                abf_internal_evict_addr_valid_sx_q[i] <= 1'b0;
                            end
                            else begin
                                abf_can_compare_sx_q[i]               <= abf_can_compare_sx_q[i]              ;
                                abf_internal_evict_addr_valid_sx_q[i] <= abf_internal_evict_addr_valid_sx_q[i];
                            end
                        end
                        else begin
                            abf_can_compare_sx_q[i]                 <= abf_can_compare_sx_q[i]                 ;
                            abf_internal_evict_addr_valid_sx_q[i]   <= abf_internal_evict_addr_valid_sx_q[i]   ;
                        end
                    end
                end
            end
        end
    endgenerate

    always_comb begin:req_compare_s0
        rxreq_cam_hazard_s1_q = 1'b0;
        rxreq_cam_hazard_entry_s1_q = 'd0;
        for (int i = 0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            // Sec 2.8.1 (p.2-114, MUST): "All writes to the same location are
            // serialized", and Sec 4.11 (p.4-242, MUST) places that on the
            // interconnect. An entry that turned into an internal evict still owns
            // a downstream write of that line, so a request arriving for it must
            // sleep behind that write -- Table 4-14 (p.4-179) pins every HN-F to
            // SN-F write to Order=0b00, so nothing else can express the order.
            if(mshr_alloc_en_s1_q && (abf_can_compare_sx_q[i] | abf_internal_evict_addr_valid_sx_q[i]) == 1'b1 && abf_sx_q[i][chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] == li_mshr_rxreq_addr_s1_q[chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET]
                    && ~(mshr_dbf_retired_valid_sx1_q == 1'b1 && mshr_dbf_retired_idx_sx1_q == i[`MSHR_ENTRIES_WIDTH-1:0]) && ~(l3_evict_sx7_q == 1'b1 && l3_mshr_entry_sx7_q == i[`MSHR_ENTRIES_WIDTH-1:0]))begin
                rxreq_cam_hazard_s1_q = 1'b1;
                rxreq_cam_hazard_entry_s1_q = trans_id2num(i[`MSHR_ENTRIES_WIDTH-1:0]);
            end
            else begin
                rxreq_cam_hazard_s1_q = rxreq_cam_hazard_s1_q;
                rxreq_cam_hazard_entry_s1_q = rxreq_cam_hazard_entry_s1_q;
            end
        end
    end

    always_comb begin:req_compare_s1
        pipe_cam_hazard_entry_sx3_q = 'd0;
        pipe_sleep_entry_sx3_q      = 'd0;
        mshr_l3_hazard_valid_sx3_q  = 'd0;
        for (int i = 0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(pipe_mshr_addr_valid_sx3_q && abf_sx_q[i][chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] == pipe_mshr_addr_sx3_q[chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET]
                    && abf_internal_evict_addr_valid_sx_q[i] == 1'b1 && ~(mshr_dbf_retired_valid_sx1_q == 1'b1 && mshr_dbf_retired_idx_sx1_q == i[`MSHR_ENTRIES_WIDTH-1:0]))begin
                pipe_cam_hazard_entry_sx3_q = trans_id2num(i[`MSHR_ENTRIES_WIDTH-1:0]);
                pipe_sleep_entry_sx3_q      = trans_id2num(pipe_mshr_addr_idx_sx3_q);
                mshr_l3_hazard_valid_sx3_q  = 'd1;
            end
            else begin
                pipe_cam_hazard_entry_sx3_q = pipe_cam_hazard_entry_sx3_q;
                pipe_sleep_entry_sx3_q      = pipe_sleep_entry_sx3_q     ;
                mshr_l3_hazard_valid_sx3_q  = mshr_l3_hazard_valid_sx3_q ;
            end
        end
    end

    // Sec 4.11 (p.4-242, MUST): "It is the responsibility of the interconnect ... to
    // ensure that there is a defined order in which transactions to the same cache
    // line can occur". An eviction turns into a downstream write of the victim
    // line, and Table 4-14 (p.4-179) pins it to Order=0b00 -- so it must not be
    // taken while another entry already has a memory access armed for that line.
    // The eviction is vetoed rather than slept: the evicting entry's own
    // l3_evict_sx7_q is one of only two wake sources, so sleeping it cannot wake.
    always_comb begin:evict_compare_sx5
        mshr_evict_hazard_sx5 = 1'b0;
        for (int i = 0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            if(pipe_evict_cam_valid_sx5_q && abf_can_compare_sx_q[i] == 1'b1 && mshr_mem_busy_sx[i] == 1'b1
                    && abf_sx_q[i][chie_pkg::REQ_ADDR_WIDTH-1:`CACHE_BLOCK_OFFSET] == pipe_evict_cam_addr_sx5_q
                    && pipe_evict_cam_idx_sx5_q != i[`MSHR_ENTRIES_WIDTH-1:0]
                    && ~(mshr_dbf_retired_valid_sx1_q == 1'b1 && mshr_dbf_retired_idx_sx1_q == i[`MSHR_ENTRIES_WIDTH-1:0]))begin
                mshr_evict_hazard_sx5 = 1'b1;
            end
            else begin
                mshr_evict_hazard_sx5 = mshr_evict_hazard_sx5;
            end
        end
    end

    assign mshr_l3_addr_sx1=abf_sx_q[mshr_l3_entry_idx_sx1_q];
    assign mshr_txsnp_addr_sx1=abf_sx_q[mshr_txsnp_rd_idx_sx1_q[`MSHR_ENTRIES_WIDTH-1:0]][chie_pkg::REQ_ADDR_WIDTH-1:3];
    assign mshr_txreq_addr_sx1=abf_sx_q[mshr_txreq_rd_idx_sx1_q[`MSHR_ENTRIES_WIDTH-1:0]];
    //-----------------------------------------------------------------------------
    // DISPLAY FATAL
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_FATAL
    always_ff @(posedge clk or posedge rst)begin
        `display_fatal(!((mshr_alloc_en_s1_q==1) && (mshr_dbf_retired_valid_sx1_q==1) && (mshr_entry_idx_alloc_s1_q==mshr_dbf_retired_idx_sx1_q)),$sformatf("Fatal info: a mshr entry %0h enqueue and dequeue at the same time\n",mshr_entry_idx_alloc_s1_q));
        `display_fatal(!((mshr_alloc_en_s1_q==1) && (l3_evict_sx7_q==1) && (mshr_entry_idx_alloc_s1_q==l3_mshr_entry_sx7_q)),$sformatf("Fatal info: a mshr entry %0h enqueue and L3 evict at the same time\n",mshr_entry_idx_alloc_s1_q));
    end

    logic [`MSHR_ENTRIES_NUM-1:0] abf_valid_sx_q;
    generate
        for(i=0;i<`MSHR_ENTRIES_NUM;i=i+1)begin
            always_ff @(posedge clk or posedge rst)begin
                if(rst == 1'b1)begin
                    abf_valid_sx_q[i] <= 0;
                end
                else begin
                    if(mshr_alloc_en_s1_q && (mshr_entry_idx_alloc_s1_q==i))begin
                        abf_valid_sx_q[i] <= 1;
                    end
                    else if(mshr_dbf_retired_valid_sx1_q && (mshr_dbf_retired_idx_sx1_q==i))begin
                        abf_valid_sx_q[i] <= 0;
                    end
                end
            end
        end
    endgenerate
    always_ff @(posedge clk or posedge rst)begin
        `display_fatal(!(mshr_dbf_retired_valid_sx1_q && (!abf_valid_sx_q[mshr_dbf_retired_idx_sx1_q])),"Fatal info: A invalid mshr entry is retiring\n");
        `display_fatal(!(l3_evict_sx7_q && (!abf_valid_sx_q[l3_mshr_entry_sx7_q])),"Fatal info: A invalid mshr entry is L3 evicting\n");
        `display_fatal(!(mshr_alloc_en_s1_q && (abf_valid_sx_q[mshr_entry_idx_alloc_s1_q])),"Fatal info: A valid mshr entry is repeat enqueuing\n");
    end
`endif
endmodule
