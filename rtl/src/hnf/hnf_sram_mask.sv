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
*    Bingcheng Jin <jinbingcheng@bosc.ac.cn>
*    Hongyu Gao <gaohongyu@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_sram_mask #(
        parameter RAM_ADDR_WIDTH = 10,
        parameter RAM_DATA_WIDTH = 512,
        parameter RAM_MASK_WIDTH = 16
    )
    (
    input wire CLK,
    input wire WE,
    input wire [RAM_ADDR_WIDTH-1:0] ADDR,
    input wire [RAM_MASK_WIDTH-1:0] WMASK,
    input wire [RAM_DATA_WIDTH-1:0] DATA_IN,
    output wire [RAM_DATA_WIDTH*RAM_MASK_WIDTH-1:0] DATA_OUT
    );
    localparam RAM_DEPTH = 2**RAM_ADDR_WIDTH;

    wire [RAM_DATA_WIDTH*RAM_MASK_WIDTH-1:0]         data_out_raw;
    logic  [RAM_DATA_WIDTH*RAM_MASK_WIDTH-1:0]         memory_data [RAM_DEPTH-1:0];

    integer i;
    genvar gi;

    generate
        for(gi=0;gi<RAM_MASK_WIDTH;gi=gi+1)begin
            always_ff @(posedge CLK)begin
                if(WE & WMASK[gi]) begin
                    memory_data[ADDR][gi*RAM_DATA_WIDTH +: RAM_DATA_WIDTH] <= DATA_IN;
                end
            end
        end
    endgenerate

    assign data_out_raw = memory_data[ADDR];

`ifdef HNF_DELAY_ONE_CYCLE

    logic  [RAM_DATA_WIDTH*RAM_MASK_WIDTH-1:0]         data_out_q;

    always_ff @(posedge CLK)begin
        data_out_q <= data_out_raw;
    end

    assign DATA_OUT = data_out_q;
`else
    assign DATA_OUT = data_out_raw;
`endif

endmodule

