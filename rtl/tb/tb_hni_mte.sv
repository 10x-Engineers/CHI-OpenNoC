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
// =============================================================================
// tb_hni_mte -- a TagOp Match write and Atomic at the HN-I, which holds no
// Allocation Tags. Sec 12.11.3 (p.12-387, MUST): the Completer "is still required
// to send a TagMatch response", reporting Fail; Table A-8 (p.A-488) gives it
// TxnID 0 and Sec 12.10 (p.12-385) the request's TagGroupID. The AXI side accepts
// every write and answers it OKAY, and answers every read -- the one an executed
// Atomic makes -- with zeros.
// SPEC-AMBIGUITY: Table B-3 (p.B-495) names no ICN(HN-I) TagMatch source; the
// Sec 12.11 MUST governs here.
// =============================================================================
`include "axi4_defines.svh"
`include "hni_defines.svh"
`include "hni_param.svh"

module tb_hni_mte;

    localparam string BENCH = "tb_hni_mte";
    localparam RN_NID       = 8;
    localparam HOME_NID     = 0;

`include "tb_home_peer.svh"

    wire [10:0] AWID;
    wire        AWVALID, WVALID, WLAST, BREADY;
    reg         BVALID = 1'b0;
    reg  [10:0] BID    = '0;
    logic [10:0] aw_ids[$];
    integer      w_bursts = 0;
    always @(posedge CLK) begin
        if (!RST && AWVALID)        aw_ids.push_back(AWID);
        if (!RST && WVALID && WLAST) w_bursts = w_bursts + 1;
        if (BVALID && BREADY)       BVALID <= 1'b0;
        else if (!BVALID && aw_ids.size() > 0 && w_bursts > 0) begin
            BVALID   <= 1'b1;
            BID      <= aw_ids.pop_front();
            w_bursts = w_bursts - 1;
        end
    end

    wire [10:0] ARID;
    wire [7:0]  ARLEN;
    wire        ARVALID, RREADY;
    reg         RVALID = 1'b0, RLAST = 1'b0;
    reg  [10:0] RID    = '0;
    integer     r_left = 0;
    logic [10:0] ar_ids[$];
    logic [7:0]  ar_lens[$];
    always @(posedge CLK) begin
        if (!RST && ARVALID) begin
            ar_ids.push_back(ARID);
            ar_lens.push_back(ARLEN);
        end
        if (RVALID && RREADY) begin
            if (RLAST) begin
                RVALID <= 1'b0;
                RLAST  <= 1'b0;
            end else begin
                r_left = r_left - 1;
                RLAST  <= (r_left == 0);
            end
        end else if (!RVALID && ar_ids.size() > 0) begin
            RVALID <= 1'b1;
            RID    <= ar_ids.pop_front();
            r_left = ar_lens.pop_front();
            RLAST  <= (r_left == 0);
        end
    end

    hni u_hni (
        .CLK(CLK), .RST(RST),
        .TXLINKACTIVEREQ(TXLINKACTIVEREQ), .TXLINKACTIVEACK(TXLINKACTIVEACK),
        .RXLINKACTIVEREQ(RXLINKACTIVEREQ), .RXLINKACTIVEACK(RXLINKACTIVEACK),
        .TXSACTIVE(TXSACTIVE), .RXSACTIVE(RXSACTIVE),
        .RXREQFLITV(RXREQFLITV), .RXREQFLIT(RXREQFLIT), .RXREQFLITPEND(RXREQFLITPEND), .RXREQLCRDV(RXREQLCRDV),
        .RXRSPFLITV(RXRSPFLITV), .RXRSPFLIT(RXRSPFLIT), .RXRSPFLITPEND(RXRSPFLITPEND), .RXRSPLCRDV(RXRSPLCRDV),
        .RXDATFLITV(RXDATFLITV), .RXDATFLIT(RXDATFLIT), .RXDATFLITPEND(RXDATFLITPEND), .RXDATLCRDV(RXDATLCRDV),
        .TXRSPFLITV(TXRSPFLITV), .TXRSPFLIT(TXRSPFLIT), .TXRSPFLITPEND(TXRSPFLITPEND), .TXRSPLCRDV(TXRSPLCRDV),
        .TXDATFLITV(TXDATFLITV), .TXDATFLIT(TXDATFLIT), .TXDATFLITPEND(TXDATFLITPEND), .TXDATLCRDV(TXDATLCRDV),
        .ARID(ARID), .ARADDR(), .ARLEN(ARLEN), .ARSIZE(), .ARBURST(), .ARLOCK(), .ARCACHE(), .ARPROT(),
        .ARQOS(), .ARREGION(), .ARUSER(), .ARVALID(ARVALID), .ARREADY(1'b1),
        .RID(RID), .RDATA('0), .RUSER('0), .RRESP('0), .RLAST(RLAST), .RVALID(RVALID), .RREADY(RREADY),
        .AWID(AWID), .AWADDR(), .AWLEN(), .AWSIZE(), .AWBURST(), .AWLOCK(), .AWCACHE(), .AWPROT(),
        .AWQOS(), .AWREGION(), .AWUSER(), .AWVALID(AWVALID), .AWREADY(1'b1),
        .WDATA(), .WUSER(), .WSTRB(), .WLAST(WLAST), .WVALID(WVALID), .WREADY(1'b1),
        .BID(BID), .BRESP('0), .BVALID(BVALID), .BREADY(BREADY)
    );

    // A write or Atomic with TagOp Match and TagGroupID tgid, to Normal WriteBack
    // memory (Sec 12.1 p.12-372); judges the TagMatch the HN-I owes it.
    task automatic match_req(input chie_pkg::req_opcode_e op, input logic [11:0] txnid,
                             input logic [7:0] tgid);
        chie_pkg::req_flit_s req;
        chie_pkg::dat_flit_s dat;
        chie_pkg::rsp_flit_s r;
        integer              r_at;
        bit                  ok;
        begin
            req                  = '0;
            req.opcode           = op;
            req.size             = chie_pkg::SIZE_8B;
            req.addr             = 'h6000 + (txnid << 6);
            req.srcid            = RN_NID;
            req.tgtid            = HOME_NID;
            req.txnid            = txnid;
            req.allowretry       = 1'b1;
            req.memattr.cacheable = 1'b1;
            req.tagop            = chie_pkg::TAGOP_MATCH;
            req.lpid             = tgid;   // TagGroupID (Sec 13.10.40 p.13-435)
            send_req(req);
            take_rsp(txnid, r, r_at, ok);
            if (!ok || !(r.opcode inside {chie_pkg::RSP_DBIDRESP, chie_pkg::RSP_COMPDBIDRESP})) begin
                fail($sformatf("%s was not granted", op.name()));
                return;
            end
            dat           = '0;
            dat.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
            dat.srcid     = RN_NID;
            dat.tgtid     = r.srcid;
            dat.txnid     = r.dbid;
            dat.be        = 'hFF;
            dat.tagop     = chie_pkg::TAGOP_MATCH;
            dat.datacheck = chie_pkg::datacheck_of(dat.data);
            send_dat(dat);
            if (r.opcode == chie_pkg::RSP_DBIDRESP) begin
                take_rsp(txnid, r, r_at, ok);
                if (!ok) fail($sformatf("%s never completed", op.name()));
            end
            take_rsp_op(chie_pkg::RSP_TAGMATCH, r, ok);
            if (!ok)
                fail($sformatf("no TagMatch for a TagOp Match %s -- Sec 12.11.3 (p.12-387, MUST) owes one", op.name()));
            else begin
                if (r.resp[0] != 1'b0)
                    fail("TagMatch reports Pass from a Completer holding no tags -- Sec 12.11.3 requires Fail");
                if (r.txnid != '0)
                    fail($sformatf("TagMatch TxnID 0x%0h -- Table A-8 (p.A-488) gives it zero", r.txnid));
                if (r.dbid[7:0] != tgid)
                    fail($sformatf("TagMatch TagGroupID 0x%0h, request's 0x%0h (Sec 12.10 p.12-385)", r.dbid[7:0], tgid));
                if (r.tgtid != RN_NID)
                    fail("TagMatch not addressed to the Requester's SrcID (Sec 12.11.1 p.12-386)");
            end
        end
    endtask

    initial begin
        bring_up;
        if (errors == 0) begin
            match_req(chie_pkg::REQ_WRITENOSNPPTL,     12'h41, 8'h5);
            match_req(chie_pkg::REQ_ATOMICSTORE_ADD,   12'h42, 8'h9);
        end
        finish_bench;
    end

endmodule
