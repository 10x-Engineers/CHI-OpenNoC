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

module hnf_link_txdat_wrap `HNF_PARAM
    (
    //global inputs
    input wire clk,
    input wire rst,

    //inputs from hnf_link
    input wire txdat_lcrdv,
    input wire lcrd_return_en,
    input wire txlink_run,
    output wire txdat_flit_avail,

    //inputs from hnf_mshr
    input wire [chie_pkg::NID_WIDTH-1:0] mshr_txdat_tgtid_sx2,
    input wire [11:0] mshr_txdat_txnid_sx2,
    input chie_pkg::dat_opcode_e mshr_txdat_opcode_sx2,
    input chie_pkg::resp_state_e mshr_txdat_resp_sx2,
    input chie_pkg::resp_err_e mshr_txdat_resperr_sx2,
    input wire [11:0] mshr_txdat_dbid_sx2,
    input wire [1:0] mshr_txdat_ccid_sx2,
    input wire mshr_txdat_tracetag_sx2,

    //inputs from hnf_data_buffer
    input wire dbf_txdat_valid_sx1,
    input wire [chie_pkg::DATA_WIDTH*2-1:0] dbf_txdat_data_sx1,
    input wire [`MSHR_ENTRIES_WIDTH-1:0] dbf_txdat_idx_sx1,
    input wire [chie_pkg::BE_WIDTH*2-1:0] dbf_txdat_be_sx1,
    input wire [1:0] dbf_txdat_pe_sx1,

    //outputs to hnf_link
    output logic txdatflitv,
    output chie_pkg::dat_flit_s txdatflit,
    output wire txdatflitpend,

    //outputs to hnf_mshr
    output logic txdat_mshr_clr_dbf_busy_valid_sx3,
    output logic  [`MSHR_ENTRIES_WIDTH-1:0] txdat_mshr_clr_dbf_busy_idx_sx3,
    output wire [`MSHR_ENTRIES_WIDTH-1:0] txdat_mshr_rd_idx_sx2,
    output wire txdat_mshr_busy_sx
    );

    //internal reg signals
    chie_pkg::dat_flit_s                    txdatflit_mshr_s0;
    logic                                           dbf_txdat_valid_entry1_sx;
    logic [chie_pkg::DATA_WIDTH*2-1:0]         dbf_txdat_data_entry1_sx;
    logic [`MSHR_ENTRIES_WIDTH-1:0]                 dbf_txdat_idx_entry1_sx;
    logic [chie_pkg::BE_WIDTH*2-1:0]           dbf_txdat_be_entry1_sx;
    logic [1:0]                                     dbf_txdat_pe_entry1_sx;
    logic                                           dbf_txdat_valid_entry2_sx;
    logic [chie_pkg::DATA_WIDTH*2-1:0]         dbf_txdat_data_entry2_sx;
    logic [`MSHR_ENTRIES_WIDTH-1:0]                 dbf_txdat_idx_entry2_sx;
    logic [chie_pkg::BE_WIDTH*2-1:0]           dbf_txdat_be_entry2_sx;
    logic [1:0]                                     dbf_txdat_pe_entry2_sx;
    logic [`HNF_LCRD_DAT_CNT_WIDTH-1:0]             txdat_crd_cnt_q;
    logic [`HNF_LCRD_DAT_CNT_WIDTH-1:0]             dat_crd_cnt_ns_s0;
    logic                                           dbf_txdat_valid_entry2_sx_ns;
    wire [1:0]        mshr_txdat_dataid_sx_ns;
    logic [chie_pkg::BE_WIDTH-1:0]             mshr_txdat_be_sx_ns;
    logic [chie_pkg::DATA_WIDTH-1:0]           mshr_txdat_data_sx_ns;

    //internal wire signals
    wire                                          dat_crd_cnt_not_zero_sx;
    wire                                          txdat_crd_avail_s1;
    wire                                          txdat_busy_sx;
    wire                                          txdatcrdv_s0;
    wire                                          txdat_crd_cnt_inc_sx;
    wire                                          txdat_req_s0;
    chie_pkg::dat_flit_s                   txdatflit_s0;
    wire                                          txdatflitv_s0;
    wire                                          txdat_crd_cnt_dec_sx;
    wire                                          update_dat_crd_cnt_s0;
    wire [`HNF_LCRD_DAT_CNT_WIDTH-1:0]            dat_crd_cnt_s1;
    wire [`HNF_LCRD_DAT_CNT_WIDTH-1:0]            dat_crd_cnt_inc_s0;
    wire [`HNF_LCRD_DAT_CNT_WIDTH-1:0]            dat_crd_cnt_dec_s0;
    wire                                          dbf_txdat_entry1_dealloc_sx;
    wire                                          dbf_txdat_entry2_dealloc_sx;

    wire                                              txdat_lcrd_rtn_sx;

    //main function
    assign dat_crd_cnt_not_zero_sx = (txdat_crd_cnt_q != 'd0);
    assign txdat_crd_avail_s1      = (txdat_lcrdv | dat_crd_cnt_not_zero_sx);
    assign txdat_busy_sx           = ~txdat_crd_avail_s1 | (~txlink_run);

    assign txdatcrdv_s0            = txdat_lcrdv;
    assign txdat_crd_cnt_inc_sx    = txdatcrdv_s0;
    assign txdat_req_s0            = (dbf_txdat_valid_entry1_sx | dbf_txdat_valid_entry2_sx_ns);

    //determine dataid
    assign mshr_txdat_dataid_sx_ns =    ({2{dbf_txdat_valid_entry2_sx_ns & dbf_txdat_pe_entry2_sx[0]}}    & 2'b00) |
           ({2{dbf_txdat_valid_entry2_sx_ns & (~dbf_txdat_pe_entry2_sx[0])}} & 2'b10) |
           ({2{(~dbf_txdat_valid_entry2_sx_ns) & dbf_txdat_pe_entry1_sx[0]}} & 2'b00) |
           ({2{(~dbf_txdat_valid_entry2_sx_ns) & (~dbf_txdat_pe_entry1_sx[0])}} & 2'b10);

    always_comb begin: txdat_be_sel_comb_logic
        mshr_txdat_be_sx_ns = '0;
        if(mshr_txdat_dataid_sx_ns == 2'b00 & dbf_txdat_valid_entry2_sx_ns)
            mshr_txdat_be_sx_ns = dbf_txdat_be_entry2_sx[chie_pkg::BE_WIDTH-1:0];
        else if(mshr_txdat_dataid_sx_ns == 2'b10 & dbf_txdat_valid_entry2_sx_ns)
            mshr_txdat_be_sx_ns = dbf_txdat_be_entry2_sx[(chie_pkg::BE_WIDTH*2)-1:chie_pkg::BE_WIDTH];
        else if(mshr_txdat_dataid_sx_ns == 2'b00 & dbf_txdat_valid_entry1_sx)
            mshr_txdat_be_sx_ns = dbf_txdat_be_entry1_sx[chie_pkg::BE_WIDTH-1:0];
        else if(mshr_txdat_dataid_sx_ns == 2'b10 & dbf_txdat_valid_entry1_sx)
            mshr_txdat_be_sx_ns = dbf_txdat_be_entry1_sx[(chie_pkg::BE_WIDTH*2)-1:chie_pkg::BE_WIDTH];
        else
            ;
    end

    always_comb begin: txdat_data_sel_comb_logic
        mshr_txdat_data_sx_ns = '0;
        if(mshr_txdat_dataid_sx_ns == 2'b00 & dbf_txdat_valid_entry2_sx_ns)
            mshr_txdat_data_sx_ns = dbf_txdat_data_entry2_sx[chie_pkg::DATA_WIDTH-1:0];
        else if(mshr_txdat_dataid_sx_ns == 2'b10 & dbf_txdat_valid_entry2_sx_ns)
            mshr_txdat_data_sx_ns = dbf_txdat_data_entry2_sx[(chie_pkg::DATA_WIDTH*2)-1:chie_pkg::DATA_WIDTH];
        else if(mshr_txdat_dataid_sx_ns == 2'b00 & dbf_txdat_valid_entry1_sx)
            mshr_txdat_data_sx_ns = dbf_txdat_data_entry1_sx[chie_pkg::DATA_WIDTH-1:0];
        else if(mshr_txdat_dataid_sx_ns == 2'b10 & dbf_txdat_valid_entry1_sx)
            mshr_txdat_data_sx_ns = dbf_txdat_data_entry1_sx[(chie_pkg::DATA_WIDTH*2)-1:chie_pkg::DATA_WIDTH];
        else
            ;
    end

    always_comb begin : combinational_logic1
        // RSVDC, DataCheck and Poison are the fields this node never sources.
        // Defaulting the whole flit to zero covers them at any configured width;
        // the assignments below override every field that does carry a value.
        txdatflit_mshr_s0 = '0;

        txdatflit_mshr_s0.qos       = '0;
        txdatflit_mshr_s0.tgtid     = mshr_txdat_tgtid_sx2;
        txdatflit_mshr_s0.srcid     = HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0];
        txdatflit_mshr_s0.txnid     = mshr_txdat_txnid_sx2;
        txdatflit_mshr_s0.homenid   = (mshr_txdat_opcode_sx2 == chie_pkg::DAT_COMPDATA)?HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0] : '0;
        txdatflit_mshr_s0.opcode    = mshr_txdat_opcode_sx2;
        txdatflit_mshr_s0.resperr   = mshr_txdat_resperr_sx2;
        txdatflit_mshr_s0.resp      = mshr_txdat_resp_sx2;
        txdatflit_mshr_s0.datasource.fwdstate  = '0;
        txdatflit_mshr_s0.cbusy     = '0;
        txdatflit_mshr_s0.dbid      = mshr_txdat_dbid_sx2;
        txdatflit_mshr_s0.ccid      = mshr_txdat_ccid_sx2;
        txdatflit_mshr_s0.dataid    = mshr_txdat_dataid_sx_ns;
        txdatflit_mshr_s0.tagop     = '0;
        txdatflit_mshr_s0.tag       = '0;
        txdatflit_mshr_s0.tu        = '0;
        txdatflit_mshr_s0.tracetag  = mshr_txdat_tracetag_sx2;
        txdatflit_mshr_s0.be        = mshr_txdat_be_sx_ns;
        txdatflit_mshr_s0.data      = mshr_txdat_data_sx_ns;
    end

    assign txdatflit_s0            = txdatflit_mshr_s0;
    assign dat_crd_cnt_s1          = txdat_crd_cnt_q;
    assign txdatflitv_s0           = (txdat_req_s0 & ~txdat_busy_sx);
    assign txdat_crd_cnt_dec_sx    = (txdatflitv_s0 & txdat_crd_avail_s1) | txdat_lcrd_rtn_sx;
    assign txdat_lcrd_rtn_sx  = lcrd_return_en & dat_crd_cnt_not_zero_sx;
    assign txdat_flit_avail   = txdat_req_s0;

    assign txdatflitpend = 1'b1;

    //txdatflit sending logic
    always_ff @(posedge clk or posedge rst) begin: txdatflit_logic_t
        if(rst == 1'b1)begin
            txdatflit  <= '0;
            txdatflitv <= 1'b0;
        end
        else if(txdat_lcrd_rtn_sx == 1'b1)begin
            txdatflit  <= '0;
            txdatflitv <= 1'b1;
        end
        else if((txdatflitv_s0 == 1'b1) & (txdat_crd_avail_s1 == 1'b1))begin
            txdatflit  <= txdatflit_s0;
            txdatflitv <= 1'b1;
        end
        else begin
            txdatflit  <= txdatflit;
            txdatflitv <= 1'b0;
        end
    end


    //deallocate entry if flit sent
    assign dbf_txdat_entry1_dealloc_sx = (txdatflitv_s0 & txdat_crd_avail_s1) & dbf_txdat_valid_entry1_sx &(~dbf_txdat_valid_entry2_sx_ns) & ~dbf_txdat_entry2_dealloc_sx &
           (dbf_txdat_pe_entry1_sx[0] ^ dbf_txdat_pe_entry1_sx[1]);

    assign dbf_txdat_entry2_dealloc_sx = (txdatflitv_s0 & txdat_crd_avail_s1) & dbf_txdat_valid_entry2_sx_ns &
           (dbf_txdat_pe_entry2_sx[0] ^ dbf_txdat_pe_entry2_sx[1]);

    assign txdat_mshr_busy_sx = (dbf_txdat_valid_entry1_sx && dbf_txdat_valid_entry2_sx);

    //clr busy logic
    always_ff @(posedge clk or posedge rst) begin: txdat_mshr_clr_dbf_busy_valid_sx3_logic_t
        if (rst == 1'b1)
            txdat_mshr_clr_dbf_busy_valid_sx3 <= 1'b0;
        else if(dbf_txdat_entry1_dealloc_sx | dbf_txdat_entry2_dealloc_sx)
            txdat_mshr_clr_dbf_busy_valid_sx3 <= 1'b1;
        else
            txdat_mshr_clr_dbf_busy_valid_sx3 <= 1'b0;
    end

    always_ff @(posedge clk or posedge rst) begin: txdat_mshr_clr_dbf_busy_idx_sx3_logic_t
        if (rst == 1'b1)
            txdat_mshr_clr_dbf_busy_idx_sx3 <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        else if(dbf_txdat_entry1_dealloc_sx)
            txdat_mshr_clr_dbf_busy_idx_sx3 <= dbf_txdat_idx_entry1_sx;
        else if(dbf_txdat_entry2_dealloc_sx)
            txdat_mshr_clr_dbf_busy_idx_sx3 <= dbf_txdat_idx_entry2_sx;
        else
            txdat_mshr_clr_dbf_busy_idx_sx3 <= {`MSHR_ENTRIES_WIDTH{1'b0}};
    end

    //receive dbf_txdat_valid_sx1, pass valid
    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_valid_entry1_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_valid_entry1_sx <= 1'b0;
        else if(dbf_txdat_valid_sx1 && !dbf_txdat_valid_entry1_sx)
            dbf_txdat_valid_entry1_sx <= 1'b1;
        else if(dbf_txdat_entry1_dealloc_sx)
            dbf_txdat_valid_entry1_sx <= 1'b0;
        else begin
        end
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_valid_entry2_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_valid_entry2_sx <= 1'b0;
        else if(dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)
            dbf_txdat_valid_entry2_sx <= 1'b1;
        else if(dbf_txdat_entry2_dealloc_sx)
            dbf_txdat_valid_entry2_sx <= 1'b0;
        else begin
        end
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_valid_entry2_sx_ns_logic_t
        if(rst == 1'b1)
            dbf_txdat_valid_entry2_sx_ns <= 1'b0;
        else if((dbf_txdat_valid_entry2_sx || (dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)) && (dbf_txdat_entry1_dealloc_sx || !dbf_txdat_valid_entry1_sx) && !dbf_txdat_entry2_dealloc_sx)
            dbf_txdat_valid_entry2_sx_ns <= 1'b1;
        else if(dbf_txdat_entry2_dealloc_sx)
            dbf_txdat_valid_entry2_sx_ns <= 1'b0;
        else begin
        end
    end

    //receive dbf_txdat_valid_sx1, pass index to mshr
    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_idx_entry1_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_idx_entry1_sx <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && !dbf_txdat_valid_entry1_sx)
            dbf_txdat_idx_entry1_sx <= dbf_txdat_idx_sx1;
        else begin
        end
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_idx_entry2_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_idx_entry2_sx <= {`MSHR_ENTRIES_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)
            dbf_txdat_idx_entry2_sx <= dbf_txdat_idx_sx1;
        else begin
        end
    end

    assign txdat_mshr_rd_idx_sx2 = dbf_txdat_valid_entry2_sx_ns? dbf_txdat_idx_entry2_sx : dbf_txdat_valid_entry1_sx? dbf_txdat_idx_entry1_sx : {`MSHR_ENTRIES_WIDTH{1'b0}};

    //receive dbf_txdat_valid_sx1, pass data
    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_data_entry1_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_data_entry1_sx <= {`CACHE_LINE_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && !dbf_txdat_valid_entry1_sx)
            dbf_txdat_data_entry1_sx <= dbf_txdat_data_sx1;
        else
            dbf_txdat_data_entry1_sx <= dbf_txdat_data_entry1_sx;
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_data_entry2_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_data_entry2_sx <= {`CACHE_LINE_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)
            dbf_txdat_data_entry2_sx <= dbf_txdat_data_sx1;
        else
            dbf_txdat_data_entry2_sx <= dbf_txdat_data_entry2_sx;
    end

    //receive dbf_txdat_valid_sx1, pass be
    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_be_entry1_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_be_entry1_sx <= {`CACHE_BE_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && !dbf_txdat_valid_entry1_sx)
            dbf_txdat_be_entry1_sx <= dbf_txdat_be_sx1;
        else
            dbf_txdat_be_entry1_sx <= dbf_txdat_be_entry1_sx;
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_be_entry2_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_be_entry2_sx <= {`CACHE_BE_WIDTH{1'b0}};
        else if(dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)
            dbf_txdat_be_entry2_sx <= dbf_txdat_be_sx1;
        else
            dbf_txdat_be_entry2_sx <= dbf_txdat_be_entry2_sx;
    end

    //receive dbf_txdat_valid_sx1, pass pe
    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_pe_entry1_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_pe_entry1_sx <= 2'b00;
        else if(dbf_txdat_valid_sx1 && !dbf_txdat_valid_entry1_sx)
            dbf_txdat_pe_entry1_sx <= dbf_txdat_pe_sx1;
        // Table 14-2 ACTIVATE (p.14-450, MUST): a credit must not be used until the
        // link is in RUN. Advancing the packet-enable pointer outside it drops the
        // beat it selects and leaves the entry undeallocatable.
        else if(dbf_txdat_valid_entry1_sx & (~dbf_txdat_valid_entry2_sx_ns) & (~txdat_busy_sx))
            dbf_txdat_pe_entry1_sx <= dbf_txdat_pe_entry1_sx[0]?{dbf_txdat_pe_entry1_sx[1],1'b0}:2'b00;
        else
            dbf_txdat_pe_entry1_sx <= dbf_txdat_pe_entry1_sx;
    end

    always_ff @(posedge clk or posedge rst) begin: dbf_txdat_pe_entry2_sx_logic_t
        if(rst == 1'b1)
            dbf_txdat_pe_entry2_sx <= 2'b00;
        else if(dbf_txdat_valid_sx1 && dbf_txdat_valid_entry1_sx && !dbf_txdat_valid_entry2_sx)
            dbf_txdat_pe_entry2_sx <= dbf_txdat_pe_sx1;
        else if( dbf_txdat_valid_entry2_sx_ns & (~txdat_busy_sx))
            dbf_txdat_pe_entry2_sx <= dbf_txdat_pe_entry2_sx[0]?{dbf_txdat_pe_entry2_sx[1],1'b0}:2'b00;
        else
            dbf_txdat_pe_entry2_sx <= dbf_txdat_pe_entry2_sx;
    end

    //L-credit logic
    assign update_dat_crd_cnt_s0   = txdat_crd_cnt_inc_sx | txdat_crd_cnt_dec_sx;
    assign dat_crd_cnt_inc_s0      = (dat_crd_cnt_s1 + 1'b1);
    assign dat_crd_cnt_dec_s0      = (dat_crd_cnt_s1 - 1'b1);

    always_comb begin: dat_crd_cnt_ns_s0_logic_c
        casez({txdat_crd_cnt_inc_sx, txdat_crd_cnt_dec_sx})
            2'b00:
                dat_crd_cnt_ns_s0 = txdat_crd_cnt_q;     // hold
            2'b01:
                dat_crd_cnt_ns_s0 = dat_crd_cnt_dec_s0;  // dec
            2'b10:
                dat_crd_cnt_ns_s0 = dat_crd_cnt_inc_s0;  // inc
            2'b11:
                dat_crd_cnt_ns_s0 = txdat_crd_cnt_q;     // hold
            default:
                dat_crd_cnt_ns_s0 = {`HNF_LCRD_DAT_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst)begin
        if (rst == 1'b1)
            txdat_crd_cnt_q <= {`HNF_LCRD_DAT_CNT_WIDTH{1'b0}};
        else if (update_dat_crd_cnt_s0 == 1'b1)
            txdat_crd_cnt_q <= dat_crd_cnt_ns_s0;
    end

    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(txdatflitv)begin
            `display_info($sformatf("HNF TXDAT send a flit\n tgtid: %h\n opcode: %h\n txnid: %h\n resp: %h\n resperr: %h\n dbid: %h\n dataid: %h\n be: %h\n data: %h\n Time: %0d\n",txdatflit.tgtid,txdatflit.opcode,txdatflit.txnid,txdatflit.resp,txdatflit.resperr,txdatflit.dbid,txdatflit.dataid,txdatflit.be,txdatflit.data,$time()));
        end
    end
`endif
endmodule
