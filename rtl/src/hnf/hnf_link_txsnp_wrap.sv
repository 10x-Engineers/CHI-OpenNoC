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
*    Jianhong Zhang <zhangjianhong@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module hnf_link_txsnp_wrap `HNF_PARAM
    (
    //global inputs
    input  wire                                clk,
    input  wire                                rst,

    //inputs from hnf_link
    input  wire                                txsnp_lcrdv,
    input  wire                                lcrd_return_en,
    input  wire                                txlink_run,
    output wire                                txsnp_flit_avail,

    //inputs from hnf_mshr_ctl
    input  wire                                mshr_txsnp_valid_sx1_q,
    input  wire [3:0]                          mshr_txsnp_qos_sx1,
    input  wire [11:0]                         mshr_txsnp_txnid_sx1_q,
    input  wire [chie_pkg::NID_WIDTH-1:0]      mshr_txsnp_fwdnid_sx1,
    input  wire [11:0]                         mshr_txsnp_fwdtxnid_sx1,
    input  chie_pkg::snp_opcode_e              mshr_txsnp_opcode_sx1,
    input  wire [chie_pkg::SNP_ADDR_WIDTH-1:0] mshr_txsnp_addr_sx1,
    input  wire                                mshr_txsnp_ns_sx1,
    input  wire                                mshr_txsnp_rettosrc_sx1,
    input  wire                                mshr_txsnp_tracetag_sx1,
    input  chie_pkg::mpam_s                    mshr_txsnp_mpam_sx1,
    input  wire [HNF_MSHR_RNF_NUM_PARAM-1:0]   mshr_txsnp_rn_vec_sx1,
    input  wire [HNF_MSHR_RNF_NUM_PARAM-1:0]   mshr_txsnp_stash_vec_sx1,
    input  chie_pkg::snp_opcode_e              mshr_txsnp_stash_opcode_sx1,
    input  wire [5:0]                          mshr_txsnp_stash_lpid_sx1,

    //outputs to hnf_link
    output logic                               txsnpflitv,
    output opennoc_hnf_pkg::snp_routed_s       txsnpflit,
    output wire                                txsnpflitpend,

    //outputs to hnf_mshr_ctl
    output wire                                txsnp_mshr_busy_sx1
    );

    //internal reg signals
    logic [`HNF_LCRD_SNP_CNT_WIDTH-1:0] txsnp_crd_cnt_q;
    logic [`MSHR_SNPCNT_WIDTH-1:0]      txsnp_cnt_q;
    logic [`MSHR_SNPCNT_WIDTH-1:0]      mshr_txsnp_rn_cnt;
    logic [HNF_MSHR_RNF_NUM_PARAM-1:0]  tgt_vec;
    logic [HNF_MSHR_RNF_NUM_PARAM-1:0]  tgt_vec_q;
    logic                               clr_1st;
    opennoc_hnf_pkg::snp_routed_s       txsnpflit_s0_q;
    logic [`HNF_LCRD_SNP_CNT_WIDTH-1:0] snp_crd_cnt_ns_s0;
    opennoc_hnf_pkg::snp_routed_s       txsnpflit_s0;
    opennoc_hnf_pkg::snp_routed_s       txsnpflit_base_s0;
    logic [HNF_MSHR_RNF_NUM_PARAM-1:0]  stash_vec_q;
    chie_pkg::snp_opcode_e              stash_opcode_q;
    logic [5:0]                         stash_lpid_q;
    logic [HNF_MSHR_RNF_NUM_PARAM-1:0]  stash_vec_sel;
    chie_pkg::snp_opcode_e              stash_opcode_sel;
    logic [5:0]                         stash_lpid_sel;
    logic                               found_rn_vec;
    logic [`RNF_WIDTH-1:0]              found_rn_vec_num;
    logic                               found_tgt_vec;
    logic [`RNF_WIDTH-1:0]              found_tgt_vec_num;
    logic [CHIE_NID_WIDTH_PARAM-1:0]    rnid_list_array[0:HNF_MSHR_RNF_NUM_PARAM-1];
    logic [`RNF_WIDTH-1:0]              snp_tgt_idx;
    logic                               snp_tgt_is_stash;

    //internal wire signals
    wire                                txsnp_busy_sx;
    wire                                txsnp_req_s0;
    wire                                txsnpflitv_s0;
    wire [`MSHR_SNPCNT_WIDTH-1:0]       txsnp_cnt_tmp;
    wire                                txsnp_crd_avail_s1;
    wire                                txsnpcrdv_s0;
    wire                                snp_crd_cnt_not_zero_sx;
    wire                                update_snp_crd_cnt_s0;
    wire                                txsnp_crd_cnt_inc_sx;
    wire                                txsnp_crd_cnt_dec_sx;
    wire [`HNF_LCRD_SNP_CNT_WIDTH-1:0]  snp_crd_cnt_inc_s0;
    wire [`HNF_LCRD_SNP_CNT_WIDTH-1:0]  snp_crd_cnt_dec_s0;
    wire [((HNF_MSHR_RNF_NUM_PARAM*CHIE_NID_WIDTH_PARAM)-1):0] rnnid_list;

    wire                                txsnp_lcrd_rtn_sx;

    //main function
    genvar                              i;

    assign rnnid_list = RNF_NID_LIST_PARAM;

    generate
        for(i=0; i<`RNF_NUM; i=i+1)begin
            always_comb begin
                rnid_list_array[i] = rnnid_list[i*CHIE_NID_WIDTH_PARAM+CHIE_NID_WIDTH_PARAM-1:i*CHIE_NID_WIDTH_PARAM];
            end
        end
    endgenerate

    always_comb begin:found_rn_vec_comb_logic
        found_rn_vec     = 1'b0;
        found_rn_vec_num = {`RNF_WIDTH{1'b0}};
        for (int i = 0; i<`RNF_NUM; i=i+1)begin
            if(mshr_txsnp_rn_vec_sx1[i] & ~found_rn_vec)begin
                found_rn_vec = 1'b1;
                found_rn_vec_num = i[`RNF_WIDTH-1:0];
            end
        end
    end

    always_comb begin:found_tgt_vec_comb_logic
        found_tgt_vec     = 1'b0;
        found_tgt_vec_num = {`RNF_WIDTH{1'b0}};
        for (int i = 0; i<`RNF_NUM; i=i+1)begin
            if(tgt_vec_q[i] & ~found_tgt_vec)begin
                found_tgt_vec = 1'b1;
                found_tgt_vec_num = i[`RNF_WIDTH-1:0];
            end
        end
    end

    always_comb begin: txsnp_wrap_compute_snp_cnt_comb_logic
        mshr_txsnp_rn_cnt = {`MSHR_SNPCNT_WIDTH{1'b0}};
        for (int i = 0; i < `RNF_NUM; i = i + 1) begin
            if (mshr_txsnp_rn_vec_sx1[i] == 1'b1) begin
                mshr_txsnp_rn_cnt = mshr_txsnp_rn_cnt + {{(`MSHR_SNPCNT_WIDTH-1){1'b0}},1'b1};
            end
        end
    end

    //lcrd_avail

    assign snp_crd_cnt_not_zero_sx = (txsnp_crd_cnt_q != 0);

    //outputs to mshr
    // Sec 14.2.1 / Table 14-2 (p.14-450, MUST): a credit held in ACTIVATE or
    // DEACTIVATE must not be used until the link is in RUN, so retiring the snoop
    // from the MSHR takes the same gate the flit does -- otherwise the fan-out is
    // consumed with nothing sent and Sec 4.4.1 (p.4-194, MUST) is broken.
    assign txsnp_mshr_busy_sx1 = ((mshr_txsnp_valid_sx1_q == 1'b1) && ((txsnp_cnt_q > 0) | (txsnp_busy_sx == 1'b1)));

    //read lcrd
    assign txsnpcrdv_s0            = txsnp_lcrdv;
    assign txsnp_crd_cnt_inc_sx    = txsnpcrdv_s0;
    assign txsnp_req_s0            = mshr_txsnp_valid_sx1_q;

    // select from new request and old request(snoop count > 1)
    always_comb begin: txsnpflit_s0_logic_c
        txsnpflit_base_s0 = (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}})? txsnpflit_s0_q : '0;
        if(txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}})begin
            txsnpflit_base_s0.tgtid = rnid_list_array[found_tgt_vec_num];
            // Sec 4.9 (p.4-240, MUST): "Home must only set RetToSrc on the Snoop
            // request to a single Request Node." Only the first snoopee of the
            // fan-out is built below; every re-drive here clears the bit.
            txsnpflit_base_s0.flit.rettosrc = 1'b0;
        end
        else if(mshr_txsnp_valid_sx1_q == 1'b1 & txsnp_mshr_busy_sx1 == 1'b0)begin
            //MSHR txsnpflit wrap
            txsnpflit_base_s0.flit.qos          = mshr_txsnp_qos_sx1;
            txsnpflit_base_s0.flit.srcid        = HNF_NID_PARAM[chie_pkg::NID_WIDTH-1:0];
            txsnpflit_base_s0.flit.txnid        = mshr_txsnp_txnid_sx1_q;
            txsnpflit_base_s0.flit.fwdnid       = mshr_txsnp_fwdnid_sx1;
            txsnpflit_base_s0.flit.fwdtxnid     = mshr_txsnp_fwdtxnid_sx1;
            txsnpflit_base_s0.flit.opcode       = mshr_txsnp_opcode_sx1;
            txsnpflit_base_s0.flit.addr         = mshr_txsnp_addr_sx1;
            txsnpflit_base_s0.flit.ns           = mshr_txsnp_ns_sx1;
            txsnpflit_base_s0.flit.donotgotosd  = {1{1'b1}};
            txsnpflit_base_s0.flit.rettosrc     = mshr_txsnp_rettosrc_sx1;
            txsnpflit_base_s0.flit.tracetag     = mshr_txsnp_tracetag_sx1;
`ifdef CHIE_MPAM_PRESENT
            // Sec 11.3 (p.11-365, MUST): MPAM is applicable only in Stash snoops; in
            // every other snoop it carries Table 11-5's (p.11-366) default settings.
            txsnpflit_base_s0.flit.mpam         = chie_pkg::mpam_default(mshr_txsnp_ns_sx1);
`endif
            //configure tgtid in txsnpflit
            txsnpflit_base_s0.tgtid = rnid_list_array[found_rn_vec_num];
        end
    end

    // Table 7-1 (SS7.1.1 p.7-295) gives the Stash target a different snoop from the
    // rest of the fan-out, so the opcode is per snoopee rather than per request.
    // Applied to the flit being sent and never to the preserved one: that copy is
    // what every later snoopee of this fan-out is re-driven from. SS4.9 (p.4-240,
    // MUST) makes RetToSrc "inapplicable and must be set to zero in ... Stash
    // snoops", and SS13.10.10 (p.13-419) carries StashLPID in the FwdTxnID bits.
    always_comb begin: txsnpflit_stash_override_c
        txsnpflit_s0 = txsnpflit_base_s0;
        if(snp_tgt_is_stash)begin
            txsnpflit_s0.flit.opcode   = stash_opcode_sel;
            txsnpflit_s0.flit.fwdtxnid = {6'b0, stash_lpid_sel};
            txsnpflit_s0.flit.rettosrc = 1'b0;
`ifdef CHIE_MPAM_PRESENT
            // Sec 11.3.3 (p.11-366, MUST): "MPAM values in Stash snoops must be the
            // same as in the request that generated the snoops."
            txsnpflit_s0.flit.mpam     = mshr_txsnp_mpam_sx1;
`endif
        end
    end

    assign snp_tgt_idx      = (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}}) ? found_tgt_vec_num : found_rn_vec_num;
    assign stash_vec_sel    = (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}}) ? stash_vec_q    : mshr_txsnp_stash_vec_sx1;
    assign stash_opcode_sel = (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}}) ? stash_opcode_q : mshr_txsnp_stash_opcode_sx1;
    assign stash_lpid_sel   = (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}}) ? stash_lpid_q   : mshr_txsnp_stash_lpid_sx1;

    // SNP_SNPLCRDRETURN is hnf_stash_snp_of()'s "not a Stash request" sentinel, so it
    // is never an opcode to send.
    assign snp_tgt_is_stash = ((txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}}) ? found_tgt_vec : found_rn_vec) &
                              stash_vec_sel[snp_tgt_idx] &
                              (stash_opcode_sel != chie_pkg::SNP_SNPLCRDRETURN);

    assign txsnp_cnt_tmp = (mshr_txsnp_valid_sx1_q & ~txsnp_mshr_busy_sx1)? mshr_txsnp_rn_cnt : {`MSHR_SNPCNT_WIDTH{1'b0}};

    //preserve flit if snoopee count > 1
    always_ff @(posedge clk or posedge rst) begin: txsnpflit_s0_q_logic_t
        if(rst == 1'b1)
            txsnpflit_s0_q <= '0;
        else if(txsnp_cnt_tmp > {{(`MSHR_SNPCNT_WIDTH-1){1'b0}},1'b1})
            txsnpflit_s0_q <= txsnpflit_base_s0;
        else
            txsnpflit_s0_q <= txsnpflit_s0_q;
    end

    // Held for the whole fan-out for the same reason the flit is: the MSHR clears
    // the entry's snoop state as it retires, and the later snoopees are driven from
    // what was captured when the fan-out started.
    always_ff @(posedge clk or posedge rst) begin: stash_sel_q_logic_t
        if(rst == 1'b1)begin
            stash_vec_q    <= {HNF_MSHR_RNF_NUM_PARAM{1'b0}};
            stash_opcode_q <= chie_pkg::SNP_SNPLCRDRETURN;
            stash_lpid_q   <= 6'b0;
        end
        else if(txsnp_cnt_tmp > {{(`MSHR_SNPCNT_WIDTH-1){1'b0}},1'b1})begin
            stash_vec_q    <= mshr_txsnp_stash_vec_sx1;
            stash_opcode_q <= mshr_txsnp_stash_opcode_sx1;
            stash_lpid_q   <= mshr_txsnp_stash_lpid_sx1;
        end
    end

    //just received it or not zero
    // Sec 14.2.1 (p.14-445, MUST): "An L-Credit cannot be used in the cycle it is
    // received." The counter already folds this cycle's grant in for the next one,
    // so the counted credits are the whole of what is spendable.
    assign txsnp_crd_avail_s1      = snp_crd_cnt_not_zero_sx;
    assign txsnp_busy_sx           = ~txsnp_crd_avail_s1 | (~txlink_run);
    assign txsnpflitv_s0           = (txsnp_req_s0 == 1'b1 | txsnp_cnt_q>0) & (txsnp_busy_sx == 1'b0);


    //clear the bit if that bit is ready to send
    always_comb begin : compute_target_need_to_be_send
        tgt_vec = mshr_txsnp_rn_vec_sx1;
        clr_1st = 1'b0;
        for (int i = 0; i < `RNF_NUM ; i = i + 1)begin
            if(mshr_txsnp_rn_vec_sx1[i] == 1'b1 & txsnp_busy_sx == 1'b0 & clr_1st == 1'b0)begin
                tgt_vec[i] = 1'b0;
                clr_1st    = 1'b1;
            end
            else begin
                tgt_vec[i] = tgt_vec[i];
                clr_1st    = clr_1st;
            end
        end
    end

    //save the rn vector and snoopee cnt
    always_ff @(posedge clk or posedge rst) begin: txsnp_cnt_q_logic_t
        if(rst == 1'b1)begin
            tgt_vec_q        <= {`RNF_NUM{1'b0}};
            txsnp_cnt_q      <= {`MSHR_SNPCNT_WIDTH{1'b0}};
        end
        // txsnp_cnt_tmp is the snoopee count of the fan-out being started, so an
        // empty target vector would wrap the counter to all-ones and drive snoops at
        // Request Nodes the MSHR never selected.
        else if((txsnp_busy_sx == 1'b0) & (mshr_txsnp_valid_sx1_q == 1'b1) & (txsnp_cnt_q == 0) & (txsnp_cnt_tmp != {`MSHR_SNPCNT_WIDTH{1'b0}}))begin
            tgt_vec_q        <= tgt_vec;
            txsnp_cnt_q      <= txsnp_cnt_tmp - {{(`MSHR_SNPCNT_WIDTH-1){1'b0}},1'b1};
        end
        //if src match, clear its valid, rn cnt-1
        else if((txsnp_crd_avail_s1 == 1'b1) & (txsnpflitv_s0 == 1'b1) & (txsnp_cnt_q > 0) & (found_tgt_vec == 1))begin
            txsnp_cnt_q                   <= txsnp_cnt_q - {{(`MSHR_SNPCNT_WIDTH-1){1'b0}},1'b1};
            tgt_vec_q[found_tgt_vec_num]  <= 1'b0;
        end
    end

    //can send packet,lcrdv-1
    assign txsnp_crd_cnt_dec_sx = txsnpflitv_s0 | txsnp_lcrd_rtn_sx;
    assign txsnp_lcrd_rtn_sx  = lcrd_return_en & snp_crd_cnt_not_zero_sx;
    // A snoop fans out over several flits, so the link stays needed until the
    // remaining targets have been sent, not just while a request is pending.
    assign txsnp_flit_avail   = txsnp_req_s0 | (txsnp_cnt_q > {`MSHR_SNPCNT_WIDTH{1'b0}});
    assign txsnpflitpend = 1'b1;

    always_ff @(posedge clk or posedge rst) begin: txsnpflit_logic_t
        if(rst == 1'b1)begin
            txsnpflit  <= '0;
            txsnpflitv <= 1'b0;
        end
        else if(txsnp_lcrd_rtn_sx == 1'b1)begin
            txsnpflit  <= '0;
            txsnpflitv <= 1'b1;
        end
        else if((txsnpflitv_s0 == 1'b1) & (txsnp_crd_avail_s1 == 1'b1))begin
            txsnpflit  <= txsnpflit_s0;
            txsnpflitv <= 1'b1;
        end
        else begin
            txsnpflitv <= 1'b0;
            txsnpflit  <= txsnpflit;
        end
    end

    assign update_snp_crd_cnt_s0   = txsnp_crd_cnt_inc_sx | txsnp_crd_cnt_dec_sx;
    assign snp_crd_cnt_inc_s0      = (txsnp_crd_cnt_q + 1'b1);
    assign snp_crd_cnt_dec_s0      = (txsnp_crd_cnt_q - 1'b1);

    always_comb begin: snp_crd_cnt_ns_s0_logic_c
        unique case({txsnp_crd_cnt_inc_sx, txsnp_crd_cnt_dec_sx})
            2'b00:
                snp_crd_cnt_ns_s0   = txsnp_crd_cnt_q;     // hold
            2'b01:
                snp_crd_cnt_ns_s0   = snp_crd_cnt_dec_s0;  // dec
            2'b10:
                snp_crd_cnt_ns_s0   = snp_crd_cnt_inc_s0;  // inc
            2'b11:
                snp_crd_cnt_ns_s0   = txsnp_crd_cnt_q;     // hold
            default:
                snp_crd_cnt_ns_s0 = {`HNF_LCRD_SNP_CNT_WIDTH{1'b0}};
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin: txsnp_crd_cnt_q_logic_t
        if (rst == 1'b1)
            txsnp_crd_cnt_q <= {`HNF_LCRD_SNP_CNT_WIDTH{1'b0}};
        else if (update_snp_crd_cnt_s0 == 1'b1)
            txsnp_crd_cnt_q <= snp_crd_cnt_ns_s0;
        else
            txsnp_crd_cnt_q <= txsnp_crd_cnt_q;
    end

    //-----------------------------------------------------------------------------
    // DISPLAY INFO
    //-----------------------------------------------------------------------------
`ifdef DISPLAY_INFO
    always_ff @(posedge clk)begin
        if(txsnpflitv)begin
            `display_info($sformatf("HNF TXSNP send a flit\n tgtid: %h\n opcode: %h\n txnid: %h\n fwdnid: %h\n fwdtxnid: %h\n addr: %h\n rettosrc: %h\n Time: %0d\n",txsnpflit.tgtid,txsnpflit.flit.opcode,txsnpflit.flit.txnid,txsnpflit.flit.fwdnid,txsnpflit.flit.fwdtxnid,txsnpflit.flit.addr,txsnpflit.flit.rettosrc,$time()));
        end
    end
`endif
endmodule
