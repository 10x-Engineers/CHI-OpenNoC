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
// The Requester half of a Home's link, shared by the Home benches. Included
// inside the bench module, which names BENCH, RN_NID and HOME_NID, instantiates
// the Home on the signals declared here, and sequences bring_up/finish_bench.
//
// dvm() judges a DVMOp at a Home that is no MN:
//   D1 Sec 2.3.7 (p.2-75): every DVMOp flow grants the NCBWrData first --
//      DBIDResp, or for a Non-sync the combined CompDBIDResp.
//   D2 Sec 2.3.7 (p.2-76, MUST): a Sync DVMOp takes the separate DBIDResp and a
//      Comp sent only after the write data.
//   D3 Table 9-12 (p.9-344): the DBIDResp carries RespErr OK.
// =============================================================================

    localparam CYCLE          = 10;
    localparam RESET_CYCLES   = 10;
    localparam TX_CRD         = 8;
    // Fail-safe on every wait below, raced against the flit it waits for.
    localparam TIMEOUT_CYCLES = 2000;

    reg  CLK = 1'b0;
    reg  RST = 1'b1;
    always #(CYCLE/2) CLK = ~CLK;

    reg  RXLINKACTIVEREQ = 1'b0;
    reg  TXLINKACTIVEACK = 1'b0;
    reg  RXSACTIVE       = 1'b0;
    wire TXLINKACTIVEREQ, RXLINKACTIVEACK, TXSACTIVE;
    always @(posedge CLK) TXLINKACTIVEACK <= RST ? 1'b0 : TXLINKACTIVEREQ;

    reg  RXREQFLITV = 1'b0, RXRSPFLITV = 1'b0, RXDATFLITV = 1'b0;
    reg  RXREQFLITPEND = 1'b0, RXRSPFLITPEND = 1'b0, RXDATFLITPEND = 1'b0;
    chie_pkg::req_flit_s RXREQFLIT = '0;
    chie_pkg::rsp_flit_s RXRSPFLIT = '0;
    chie_pkg::dat_flit_s RXDATFLIT = '0;
    wire RXREQLCRDV, RXRSPLCRDV, RXDATLCRDV;
    wire TXRSPFLITV, TXDATFLITV, TXRSPFLITPEND, TXDATFLITPEND;
    chie_pkg::rsp_flit_s TXRSPFLIT;
    chie_pkg::dat_flit_s TXDATFLIT;
    reg  TXREQLCRDV = 1'b0, TXRSPLCRDV = 1'b0, TXSNPLCRDV = 1'b0, TXDATLCRDV = 1'b0;

    integer errors = 0;
    integer crd_req = 0, crd_dat = 0;
    integer cycle = 0;

    task fail(input string what);
        begin
            $display("FAIL @%0t: %s", $time, what);
            errors = errors + 1;
        end
    endtask

    always @(posedge CLK) begin
        cycle = cycle + 1;
        if (RXREQLCRDV) crd_req = crd_req + 1;
        if (RXDATLCRDV) crd_dat = crd_dat + 1;
    end

    // Every protocol response the Home sends, with the cycle it arrived on.
    chie_pkg::rsp_flit_s rsp_q[$];
    integer              rsp_cyc[$];
    always @(posedge CLK)
        if (!RST && TXRSPFLITV && (TXRSPFLIT.opcode != chie_pkg::RSP_RSPLCRDRETURN)) begin
            rsp_q.push_back(TXRSPFLIT);
            rsp_cyc.push_back(cycle);
        end

    task grant_tx_credits;
        integer n;
        begin
            for (n = 0; n < TX_CRD; n = n + 1) begin
                @(negedge CLK);
                TXREQLCRDV = 1'b1; TXRSPLCRDV = 1'b1; TXSNPLCRDV = 1'b1; TXDATLCRDV = 1'b1;
                @(negedge CLK);
                TXREQLCRDV = 1'b0; TXRSPLCRDV = 1'b0; TXSNPLCRDV = 1'b0; TXDATLCRDV = 1'b0;
            end
        end
    endtask

    task send_req(input chie_pkg::req_flit_s f);
        begin
            wait (crd_req > 0);
            @(negedge CLK);
            RXREQFLITV = 1'b1; RXREQFLIT = f;
            @(negedge CLK);
            RXREQFLITV = 1'b0;
            crd_req = crd_req - 1;
        end
    endtask

    task send_dat(input chie_pkg::dat_flit_s f);
        begin
            wait (crd_dat > 0);
            @(negedge CLK);
            RXDATFLITV = 1'b1; RXDATFLIT = f;
            @(negedge CLK);
            RXDATFLITV = 1'b0;
            crd_dat = crd_dat - 1;
        end
    endtask

    // The next response for this TxnID, oldest first.
    task automatic take_rsp(input logic [11:0] txnid, output chie_pkg::rsp_flit_s r,
                            output integer at, output bit ok);
        integer n, i;
        begin
            ok = 1'b0;
            for (n = 0; n < TIMEOUT_CYCLES && !ok; n = n + 1) begin
                for (i = 0; i < rsp_q.size() && !ok; i = i + 1)
                    if (rsp_q[i].txnid == txnid) begin
                        r = rsp_q[i]; at = rsp_cyc[i];
                        rsp_q.delete(i); rsp_cyc.delete(i);
                        ok = 1'b1;
                    end
                if (!ok) @(posedge CLK);
            end
        end
    endtask

    // Table 8-8 (p.8-317): DVMOp type is Req.Addr[13:11], 0b100 a Synchronization.
    task automatic dvm(input bit sync, input logic [11:0] txnid);
        chie_pkg::req_flit_s req;
        chie_pkg::dat_flit_s dat;
        chie_pkg::rsp_flit_s r;
        integer              r_at, data_at;
        bit                  ok;
        string               what;
        begin
            what = sync ? "Sync DVMOp" : "Non-sync DVMOp";
            req            = '0;
            req.opcode     = chie_pkg::REQ_DVMOP;
            req.size       = chie_pkg::SIZE_8B;
            req.addr       = sync ? 'h2000 : '0;
            req.srcid      = RN_NID;
            req.tgtid      = HOME_NID;
            req.txnid      = txnid;
            req.allowretry = 1'b1;
            send_req(req);

            take_rsp(txnid, r, r_at, ok);
            if (!ok) begin
                fail($sformatf("%s got no response (Sec 2.3.7 p.2-75)", what));
                return;
            end
            if (r.opcode == chie_pkg::RSP_COMP) begin
                fail($sformatf("%s answered by a bare Comp with no DBIDResp -- Sec 2.3.7 (p.2-75) grants its NCBWrData first", what));
                return;
            end
            if (!(r.opcode inside {chie_pkg::RSP_DBIDRESP, chie_pkg::RSP_COMPDBIDRESP})) begin
                fail($sformatf("%s answered %s first", what, r.opcode.name()));
                return;
            end
            if (sync && r.opcode == chie_pkg::RSP_COMPDBIDRESP)
                fail("Sync DVMOp answered CompDBIDResp -- Sec 2.3.7 (p.2-76, MUST) gives it separate responses");
            if (r.opcode == chie_pkg::RSP_DBIDRESP && r.resperr != chie_pkg::RESP_ERR_NORM_OK)
                fail($sformatf("%s DBIDResp carries RespErr %s -- Table 9-12 (p.9-344) allows OK only", what, r.resperr.name()));

            // Table 8-2 (p.8-310): NonCopyBackWriteData, BE[7:0] only, CCID and DataID zero.
            dat           = '0;
            dat.opcode    = chie_pkg::DAT_NONCOPYBACKWRDATA;
            dat.srcid     = RN_NID;
            dat.tgtid     = r.srcid;
            dat.txnid     = r.dbid;
            dat.be        = 'hFF;
            dat.datacheck = chie_pkg::datacheck_of(dat.data);
            send_dat(dat);
            data_at = cycle;

            if (r.opcode == chie_pkg::RSP_DBIDRESP) begin
                take_rsp(txnid, r, r_at, ok);
                if (!ok)
                    fail($sformatf("%s got no Comp after its NCBWrData", what));
                else if (r.opcode != chie_pkg::RSP_COMP)
                    fail($sformatf("%s completed by %s, not Comp", what, r.opcode.name()));
                else if (sync && r_at < data_at)
                    fail("Sync DVMOp Comp sent before its write data -- Sec 2.3.7 (p.2-76, MUST)");
            end
        end
    endtask

    // Reset, ACTIVATE -> RUN in both directions, then TX L-Credits for the Home.
    task bring_up;
        begin
            repeat (RESET_CYCLES) @(posedge CLK);
            RST = 1'b0;
            RXLINKACTIVEREQ = 1'b1;
            fork begin
                fork
                    wait (RXLINKACTIVEACK && TXLINKACTIVEREQ && TXLINKACTIVEACK);
                    begin repeat (TIMEOUT_CYCLES) @(posedge CLK); fail("link never reached RUN"); end
                join_any
                disable fork;
            end join
            if (errors == 0) grant_tx_credits;
        end
    endtask

    task finish_bench;
        begin
            if (errors == 0) $display("%s: PASSED", BENCH);
            else             $display("%s: FAILED (%0d error(s))", BENCH, errors);
            $finish;
        end
    endtask
