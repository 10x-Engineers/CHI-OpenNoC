/*
* Copyright (c) 2026 10xEngineers
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*/

`include "rnf_param.svh"
`include "rnf_defines.svh"

// The RN-F's DVMOp issuer: one DVM operation from the core's DVM port, sent to the
// Miscellaneous Node through SS2.3.7's (p.2-75) flow -- the request, DBIDResp or
// CompDBIDResp, the 8-byte NonCopyBackWriteData, then Comp. The core supplies the
// payload as Table 8-8 (p.8-317) lays it out: DVMADDR is Req.Addr, DVMDATA the
// write data, DVMDOMAIN the SnpAttr (Table 8-10 p.8-321).
//
// It runs only while rnf_ctl is idle and holds rnf_ctl off until done, so the node
// keeps one transaction outstanding and its one TxnID is unique (SS2.5.2 p.2-87).
// A RetryAck is served as SS2.11 (p.2-145) has it: the request is resent with
// AllowRetry clear once a PCrdGrant of its PCrdType has arrived, which may be first.
// A P-Credit still held once the DVMOp is done is surplus, and SS2.11.1 (p.2-147,
// MUST) has it returned before the port is free again.
module rnf_dvm `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    input  wire                                 DVMVALID,
    output wire                                 DVMREADY,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] DVMADDR,
    input  wire [63:0]                          DVMDATA,
    input  wire                                 DVMDOMAIN,
    output wire                                 DVMDONE,
    output wire [1:0]                           DVMRESP,

    // rnf_ctl idle, and Coherency Enabled: Table 15-1 (p.15-468) lets a Request
    // Node send DVM transactions in no other state.
    input  wire                                 start_ok_i,
    output wire                                 active_o,

    output chie_pkg::req_flit_s                 prot_txreqflit_o,
    output wire                                 prot_txreqflitv_o,
    input  wire                                 prot_txreqflit_sent_i,
    output chie_pkg::dat_flit_s                 prot_txdatflit_o,
    output wire                                 prot_txdatflitv_o,
    input  wire                                 prot_txdatflit_sent_i,
    input  wire                                 prot_rxrspflitv_i,
    input  chie_pkg::rsp_flit_s                 prot_rxrspflit_i
    );

    localparam logic [3:0] D_IDLE = 4'd0;
    localparam logic [3:0] D_REQ  = 4'd1;
    localparam logic [3:0] D_WAIT = 4'd2;
    localparam logic [3:0] D_PCRD = 4'd3;
    localparam logic [3:0] D_DAT  = 4'd4;
    localparam logic [3:0] D_COMP = 4'd5;
    localparam logic [3:0] D_DONE = 4'd6;
    localparam logic [3:0] D_PRET = 4'd7;
    localparam logic [3:0] D_PCHK = 4'd8;

    localparam logic [11:0] DVM_TXNID = 12'h000;

    logic [3:0]                           st_q;
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] addr_q;
    logic [63:0]                          data_q;
    logic                                 domain_q;
    logic                                 retry_q;
    logic [3:0]                           pcrdtype_q;
    logic [1:0]                           pcrd_cnt_q [16];
    logic [CHIE_NID_WIDTH_PARAM-1:0]      pcrd_src_q [16];
    logic [3:0]                           ret_type_q;
    logic [CHIE_NID_WIDTH_PARAM-1:0]      grant_src_q;
    logic [11:0]                          dbid_q;
    logic                                 grant_tt_q;
    logic                                 comp_q;
    chie_pkg::resp_err_e                  resperr_q;

    wire rsp_mine  = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == DVM_TXNID);
    wire rx_grant  = rsp_mine && ((prot_rxrspflit_i.opcode == chie_pkg::RSP_DBIDRESP) ||
                                  (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMPDBIDRESP));
    wire rx_comp   = rsp_mine && ((prot_rxrspflit_i.opcode == chie_pkg::RSP_COMP) ||
                                  (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMPDBIDRESP));
    wire rx_retry  = rsp_mine && (prot_rxrspflit_i.opcode == chie_pkg::RSP_RETRYACK);
    wire rx_pcrd   = prot_rxrspflitv_i && (prot_rxrspflit_i.opcode == chie_pkg::RSP_PCRDGRANT);

    logic       surplus_v;
    logic [3:0] surplus_type;
    always_comb begin
        surplus_v    = 1'b0;
        surplus_type = 4'd0;
        for (int t = 0; t < 16; t++)
            if (!surplus_v && (pcrd_cnt_q[t] != 2'd0)) begin
                surplus_v    = 1'b1;
                surplus_type = 4'(t);
            end
    end
    wire pcrd_use      = (st_q == D_PCRD) && (pcrd_cnt_q[pcrdtype_q] != 2'd0);
    wire pcrd_ret_sent = (st_q == D_PRET) && prot_txreqflit_sent_i;

    assign DVMREADY  = (st_q == D_IDLE) && start_ok_i;
    assign active_o  = (st_q != D_IDLE);
    assign DVMDONE   = (st_q == D_DONE);
    assign DVMRESP   = resperr_q;

    // Table 8-1 (p.8-309/8-310): Size 8 bytes, NS, LikelyShared, Order, MemAttr, Excl,
    // ExpCompAck, TagOp and MPAM zero; PCrdType zero unless resent on a P-Credit.
    always_comb begin
        prot_txreqflit_o                = '0;
        prot_txreqflit_o.tgtid          = CHIE_NID_WIDTH_PARAM'(MN_NID_PARAM);
        prot_txreqflit_o.srcid          = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txreqflit_o.txnid          = DVM_TXNID;
        prot_txreqflit_o.opcode         = chie_pkg::REQ_DVMOP;
        prot_txreqflit_o.size           = chie_pkg::SIZE_8B;
        prot_txreqflit_o.addr           = addr_q;
        prot_txreqflit_o.allowretry     = !retry_q;
        prot_txreqflit_o.pcrdtype       = retry_q ? pcrdtype_q : 4'd0;
        prot_txreqflit_o.snpattr.snpattr = domain_q;
        if (st_q == D_PRET) begin
            // SS2.6.6 (p.2-112): to the credit's source, TxnID zero, under the
            // PCrdType it was granted with; Table A-2 (p.A-483) zeroes the rest.
            prot_txreqflit_o          = '0;
            prot_txreqflit_o.srcid    = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
            prot_txreqflit_o.tgtid    = pcrd_src_q[ret_type_q];
            prot_txreqflit_o.opcode   = chie_pkg::REQ_PCRDRETURN;
            prot_txreqflit_o.pcrdtype = ret_type_q;
`ifdef CHIE_MPAM_PRESENT
            prot_txreqflit_o.mpam     = chie_pkg::mpam_default(1'b0);
`endif
        end
    end
    assign prot_txreqflitv_o = (st_q == D_REQ) || (st_q == D_PRET);

    // Table 8-2 (p.8-310/8-311): to the grant's SrcID under its DBID, BE[7:0] only,
    // CCID, DataID, Resp and the tag fields zero. SS11.5.1 (p.11-368, MUST): TraceTag
    // reflects the grant.
    always_comb begin
        prot_txdatflit_o           = '0;
        prot_txdatflit_o.tgtid     = grant_src_q;
        prot_txdatflit_o.srcid     = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txdatflit_o.txnid     = dbid_q;
        prot_txdatflit_o.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
        prot_txdatflit_o.tracetag  = grant_tt_q;
        prot_txdatflit_o.be        = chie_pkg::BE_WIDTH'(8'hFF);
        prot_txdatflit_o.data      = chie_pkg::DATA_WIDTH'(data_q);
        prot_txdatflit_o.datacheck = chie_pkg::datacheck_of(prot_txdatflit_o.data);
    end
    assign prot_txdatflitv_o = (st_q == D_DAT);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            st_q        <= D_IDLE;
            addr_q      <= '0;
            data_q      <= '0;
            domain_q    <= 1'b0;
            retry_q     <= 1'b0;
            pcrdtype_q  <= '0;
            ret_type_q  <= '0;
            for (int t = 0; t < 16; t++) begin
                pcrd_cnt_q[t] <= '0;
                pcrd_src_q[t] <= '0;
            end
            grant_src_q <= '0;
            dbid_q      <= '0;
            grant_tt_q  <= 1'b0;
            comp_q      <= 1'b0;
            resperr_q   <= chie_pkg::RESP_ERR_NORM_OK;
        end
        else begin
            for (int t = 0; t < 16; t++) begin
                automatic logic inc = active_o && rx_pcrd && (prot_rxrspflit_i.pcrdtype == 4'(t));
                automatic logic dec = (pcrd_use      && (pcrdtype_q == 4'(t))) ||
                                      (pcrd_ret_sent && (ret_type_q == 4'(t)));
                pcrd_cnt_q[t] <= pcrd_cnt_q[t] + {1'b0, inc} - {1'b0, dec};
                if (inc) pcrd_src_q[t] <= prot_rxrspflit_i.srcid;
            end
            if (rx_comp) begin
                comp_q    <= 1'b1;
                resperr_q <= prot_rxrspflit_i.resperr;
            end
            case (st_q)
                D_IDLE:
                    if (DVMVALID && DVMREADY) begin
                        addr_q    <= DVMADDR;
                        data_q    <= DVMDATA;
                        domain_q  <= DVMDOMAIN;
                        retry_q   <= 1'b0;
                        comp_q    <= 1'b0;
                        resperr_q <= chie_pkg::RESP_ERR_NORM_OK;
                        st_q      <= D_REQ;
                    end
                D_REQ:
                    if (prot_txreqflit_sent_i) st_q <= D_WAIT;
                D_WAIT:
                    if (rx_retry) begin
                        retry_q    <= 1'b1;
                        pcrdtype_q <= prot_rxrspflit_i.pcrdtype;
                        st_q       <= D_PCRD;
                    end
                    else if (rx_grant) begin
                        grant_src_q <= prot_rxrspflit_i.srcid;
                        dbid_q      <= prot_rxrspflit_i.dbid;
                        grant_tt_q  <= prot_rxrspflit_i.tracetag;
                        st_q        <= D_DAT;
                    end
                D_PCRD:
                    if (pcrd_use) st_q <= D_REQ;
                D_DAT:
                    if (prot_txdatflit_sent_i) st_q <= (comp_q || rx_comp) ? D_DONE : D_COMP;
                D_COMP:
                    if (rx_comp) st_q <= D_DONE;
                // A PCrdGrant landing now is banked this cycle, so it is checked for
                // on the next.
                D_DONE, D_PCHK:
                    if (surplus_v) begin
                        ret_type_q <= surplus_type;
                        st_q       <= D_PRET;
                    end
                    else if (rx_pcrd) st_q <= D_PCHK;
                    else st_q <= D_IDLE;
                D_PRET:
                    if (pcrd_ret_sent) st_q <= D_PCHK;
                default:
                    st_q <= D_IDLE;
            endcase
        end
    end

`ifdef ASSERT_CHECKER_ON
    // SS2.11.1 (p.2-147, MUST): a P-Credit no request needs is returned, so the port
    // never goes idle holding one.
    assert_checker #(
                       3,
                       "RN-F DVM port went idle holding a P-Credit it will not return")
                   DVM_PCRD_HELD_check (
                       .clk   ( clk_i ),
                       .rst   ( rst_i ),
                       .cond  ( (st_q == D_IDLE) && surplus_v )
                   );
`endif

endmodule
