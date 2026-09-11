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
*    Guo Bing <guobing@bosc.ac.cn>
*    Chunyan Lin <linchunyan@bosc.ac.cn>
*/

`include "hnf_defines.svh"
`include "hnf_param.svh"

module tb_snf `HNF_PARAM
    (
        //global inputs
        CLK,
        RST,

        RXREQFLITV,
        RXREQFLIT,

        RXDATFLITV,
        RXDATFLIT,

        TXRSPFLITV,
        TXRSPFLIT,

        TXDATFLITV,
        TXDATFLIT,

        dbg_sn_wr_en,
        dbg_sn_addr,
        dbg_sn_wr_data,

        dbg_sn_rd_en,
        dbg_sn_rd_data
    );
    input wire                                 CLK;
    input wire                                 RST;

    input wire                                 RXREQFLITV;
    input chie_pkg::req_flit_s RXREQFLIT;

    input wire                                 RXDATFLITV;
    input chie_pkg::dat_flit_s RXDATFLIT;

    input wire                                 dbg_sn_wr_en;
    input wire                                 dbg_sn_rd_en;
    input wire [chie_pkg::REQ_ADDR_WIDTH-1:0] dbg_sn_addr;
    input wire [chie_pkg::DAT_FLIT_WIDTH*2-1:0]    dbg_sn_wr_data;

    output wire [chie_pkg::DAT_FLIT_WIDTH*2-1:0]   dbg_sn_rd_data;

    output reg                                 TXRSPFLITV;
    output chie_pkg::rsp_flit_s TXRSPFLIT;

    output reg                                 TXDATFLITV;
    output chie_pkg::dat_flit_s TXDATFLIT;

    //internal wire
    wire                                       rxreqflit_v;
    chie_pkg::req_flit_s rxreqflit;
    wire                                       rxdatflit_v;
    chie_pkg::dat_flit_s rxdatflit;
    wire                                       rxreq_is_rdnosnp;
    wire                                       rxreq_is_wrnosnpf;
    wire                                       rxreq_is_wrnosnpp;
    wire                                       rxreq_is_wrnosnp;
    wire                                       rxreq_is_noncopybackwrdata;
    wire                                       dyn_req;
    wire                                       static_req;
    wire                                       wr_dataid0;
    wire                                       wr_dataid2;
    wire                                       wr_en_id0;
    wire                                       wr_en_id2;
    wire                                       rxreq_ord;
    wire                                       rdnsnp_recipt;
    wire                                       rd_en;
    wire                                       wr_en;
    wire [511:0]                               wr_data;
    wire [511:0]                               rd_data;
    wire [(chie_pkg::DATA_WIDTH*2)-1:0]   wr_new_data;
    wire                                       mem_empty;
    wire                                       mem_full;
    wire                                       wrnosnp_dwt;
    wire                                       ncbwrdata_from_rn;
    wire                                       dat_cancel;

    //internal regs
    //reg [511:0]                                rd_data_out;
    chie_pkg::dat_flit_s txdatflit_tmp0;
    chie_pkg::dat_flit_s txdatflit_tmp1;
    logic [$bits(txdatflit_tmp0.tgtid)-1:0]    txdat_tgtid;
    logic [$bits(txdatflit_tmp0.txnid)-1:0]    txdat_txnid;
    logic [$bits(txdatflit_tmp0.dbid)-1:0]     txdat_dbid;
    reg                                        send_data0;
    reg                                        send_data1;
    chie_pkg::rsp_flit_s txrspflit_tmp;
    logic [$bits(txrspflit_tmp.tgtid)-1:0]     txrsp_tgtid;
    logic [$bits(txrspflit_tmp.txnid)-1:0]     txrsp_txnid;
    logic [$bits(txrspflit_tmp.opcode)-1:0]    txrsp_opcode;
    reg                                        send_rsp;
    reg [chie_pkg::DATA_WIDTH-1:0]        wr_data_l;
    reg [chie_pkg::DATA_WIDTH-1:0]        wr_data_h;
    reg                                        wr_en_q;
    reg [chie_pkg::REQ_ADDR_WIDTH-1:0]        addr;
    reg [chie_pkg::REQ_ADDR_WIDTH-1:0]        addr_q;
    reg                                        wrnosnp_dwt_q;
    reg                                        ncbwrdata_from_rn_q;

    //main methods
    //rxreq logic
    assign rxreqflit = RXREQFLITV? RXREQFLIT:{chie_pkg::REQ_FLIT_WIDTH{1'b0}};
    assign rxreqflit_v = RXREQFLITV;

    assign rxdatflit = RXDATFLITV? RXDATFLIT:{chie_pkg::DAT_FLIT_WIDTH{1'b0}};
    assign rxdatflit_v = RXDATFLITV;

    assign dyn_req = (rxreqflit.allowretry == 1'b1);
    assign static_req = rxreqflit_v & (rxreqflit.allowretry == 1'b0);

    assign rxreq_is_rdnosnp = rxreqflit_v & (rxreqflit.opcode == chie_pkg::REQ_READNOSNP);
    assign rxreq_is_wrnosnpf = rxreqflit_v & (rxreqflit.opcode == chie_pkg::REQ_WRITENOSNPFULL);
    assign rxreq_is_wrnosnpp = rxreqflit_v & (rxreqflit.opcode == chie_pkg::REQ_WRITENOSNPPTL);
    assign wrnosnp_dwt = (rxreq_is_wrnosnpf | rxreq_is_wrnosnpp) & (rxreqflit.snpattr.dodwt == 1'b1);

    assign rxreq_is_wrnosnp = (rxreq_is_wrnosnpf | rxreq_is_wrnosnpp);
    assign rxreq_ord = (rxreqflit.order == 2'b01);

    assign rdnsnp_recipt = rxreqflit_v & rxreq_ord;

    assign rd_en = dbg_sn_rd_en? 1'b1:rxreq_is_rdnosnp? 1'b1:1'b0;

    assign rxreq_is_noncopybackwrdata = rxdatflit_v & (rxdatflit.opcode == chie_pkg::DAT_NONCOPYBACKWRDATA);
    assign wr_dataid0 = (rxdatflit.dataid == 2'b00);
    assign wr_dataid2 = (rxdatflit.dataid == 2'b10);
    assign ncbwrdata_from_rn = wr_en_id2 & (rxdatflit.srcid == `RN0_ID);

    assign wr_en_id0 = rxreq_is_noncopybackwrdata & wr_dataid0;
    assign wr_en_id2 = rxreq_is_noncopybackwrdata & wr_dataid2;
    assign dat_cancel = ~(|rxdatflit.be) & rxdatflit_v;

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            ncbwrdata_from_rn_q <= 1'b0;
        else if(ncbwrdata_from_rn ==  1'b1)
            ncbwrdata_from_rn_q <= 1'b1;
        else
            ncbwrdata_from_rn_q <= 1'b0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            wrnosnp_dwt_q <= '0;
        else if(wrnosnp_dwt ==  1'b1)
            wrnosnp_dwt_q <= 1'b1;
        else
            wrnosnp_dwt_q <= 1'b0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            addr_q <= '0;
        else if(rxreq_is_wrnosnp ==  1'b1)
            addr_q <= rxreqflit.addr;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            wr_data_l <= {256{1'b0}};
        else if(wr_en_id0 ==  1'b1)
            wr_data_l <= rxdatflit.data;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            wr_data_h <= {256{1'b0}};
        else if(wr_en_id2 ==  1'b1)
            wr_data_h <= rxdatflit.data;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            wr_en_q <= 1'b0;
        else if(wr_en_id2 ==  1'b1)
            wr_en_q <= wr_en_id2 & ~dat_cancel;
        else
            wr_en_q <= 1'b0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txdat_tgtid <= {7{1'b0}};
        else if(rxreqflit_v ==  1'b1)
            txdat_tgtid <= rxreqflit.returnnid;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txdat_txnid <= {12{1'b0}};
        else if(rxreqflit_v ==  1'b1)
            txdat_txnid <= rxreqflit.returntxnid;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txdat_dbid <= {12{1'b0}};
        else if(rxreqflit_v ==  1'b1)
            txdat_dbid <= rxreqflit.txnid;
        else
            ;
    end

    //always@(posedge CLK or negedge RST)
    //begin
    //  if(RST == 1'b1)
    //    rd_data_out <= {512{1'b0}};
    //  else
    //    rd_data_out <= rd_data;
    //end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            send_data0 <= 1'b0;
        else if(rxreq_is_rdnosnp)
            send_data0 <= 1'b1;
        else
            send_data0 <= 1'b0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            send_data1 <= 1'b0;
        else
            send_data1 <= send_data0;
    end

    assign wr_new_data = {wr_data_h,wr_data_l};

    assign wr_data = dbg_sn_wr_en? dbg_sn_wr_data:wr_en_q? wr_new_data:'d0;

    assign wr_en = dbg_sn_wr_en? 1'b1:wr_en_q? 1'b1:1'b0;

    generate
        if(CHIE_DATACHECK_WIDTH_PARAM != 0)begin
            always @*begin
                txdatflit_tmp0.datacheck = '0;
                txdatflit_tmp1.datacheck = '0;
            end
        end
        if(CHIE_POISON_WIDTH_PARAM != 0)begin
            always @*begin
                txdatflit_tmp0.poison = '0;
                txdatflit_tmp1.poison = '0;
            end
        end
    endgenerate

    always@*begin
        txdatflit_tmp0.qos      = '0;
        txdatflit_tmp0.tgtid    = txdat_tgtid;
        txdatflit_tmp0.srcid    = `SN_ID;
        txdatflit_tmp0.txnid    = txdat_txnid;
        txdatflit_tmp0.homenid  = `HNF0_ID;
        txdatflit_tmp0.opcode   = chie_pkg::DAT_COMPDATA;
        txdatflit_tmp0.resperr  = '0;
        txdatflit_tmp0.resp     = chie_pkg::RESP_UC_UD;
        txdatflit_tmp0.datasource.fwdstate = '0;
        txdatflit_tmp0.cbusy    = '0;
        txdatflit_tmp0.dbid     = txdat_dbid;
        txdatflit_tmp0.ccid     = '0;
        txdatflit_tmp0.dataid   = 2'b00;
        txdatflit_tmp0.tagop    = '0;
        txdatflit_tmp0.tag      = '0;
        txdatflit_tmp0.tu       = '0;
        txdatflit_tmp0.tracetag = '0;
        txdatflit_tmp0.be       = {chie_pkg::BE_WIDTH{1'b1}};
        txdatflit_tmp0.data     = rd_data[255:0];
    end

    always@*begin
        txdatflit_tmp1.qos      = '0;
        txdatflit_tmp1.tgtid    = txdat_tgtid;
        txdatflit_tmp1.srcid    = `SN_ID;
        txdatflit_tmp1.txnid    = txdat_txnid;
        txdatflit_tmp1.homenid  = `HNF0_ID;
        txdatflit_tmp1.opcode   = chie_pkg::DAT_COMPDATA;
        txdatflit_tmp1.resperr  = '0;
        txdatflit_tmp1.resp     = chie_pkg::RESP_UC_UD;
        txdatflit_tmp1.datasource.fwdstate = '0;
        txdatflit_tmp1.cbusy    = '0;
        txdatflit_tmp1.dbid     = txdat_dbid;
        txdatflit_tmp1.ccid     = '0;
        txdatflit_tmp1.dataid   = 2'b10;
        txdatflit_tmp1.tagop    = '0;
        txdatflit_tmp1.tag      = '0;
        txdatflit_tmp1.tu       = '0;
        txdatflit_tmp1.tracetag = '0;
        txdatflit_tmp1.be       = {chie_pkg::BE_WIDTH{1'b1}};
        txdatflit_tmp1.data     = rd_data[511:256];
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)begin
            TXDATFLITV <= 1'b0;
            TXDATFLIT <= {512{1'b0}};
        end
        else if(send_data0)begin
            TXDATFLITV <= 1'b1;
            TXDATFLIT <= txdatflit_tmp0;
        end
        else if(send_data1)begin
            TXDATFLITV <= 1'b1;
            TXDATFLIT <= txdatflit_tmp1;
        end
        else begin
            TXDATFLITV <= 1'b0;
        end
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txrsp_tgtid <= {7{1'b0}};
        else if(wrnosnp_dwt == 1'b1 & rxreqflit_v ==  1'b1)
            txrsp_tgtid <= `RN0_ID;
        else if(ncbwrdata_from_rn == 1'b1)
            txrsp_tgtid <= `HNF0_ID;
        else if(rxreqflit_v ==  1'b1)
            txrsp_tgtid <= rxreqflit.srcid;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txrsp_txnid <= {12{1'b0}};
        else if(rxreqflit_v ==  1'b1)
            txrsp_txnid <= rxreqflit.txnid;
        else
            ;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            txrsp_opcode <= '0;
        else if((rxreqflit_v ==  1'b1))
            txrsp_opcode <= wrnosnp_dwt? chie_pkg::RSP_DBIDRESP:(rxreq_is_wrnosnpf | rxreq_is_wrnosnpp)? chie_pkg::RSP_COMPDBIDRESP:rdnsnp_recipt? chie_pkg::RSP_READRECEIPT:'d0;
        else if((rxdatflit_v ==  1'b1))
            txrsp_opcode <= ncbwrdata_from_rn? chie_pkg::RSP_COMP:'d0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)
            send_rsp <= 1'b0;
        else if(rxreq_is_wrnosnpf | rxreq_is_wrnosnpp | rdnsnp_recipt | wrnosnp_dwt | ncbwrdata_from_rn)
            send_rsp <= 1'b1;
        else
            send_rsp <= 1'b0;
    end

    always @*begin
        txrspflit_tmp.qos      = '0;
        txrspflit_tmp.tgtid    = txrsp_tgtid;
        txrspflit_tmp.srcid    = `SN_ID;
        txrspflit_tmp.txnid    = txrsp_txnid;
        txrspflit_tmp.opcode   = txrsp_opcode;
        txrspflit_tmp.resperr  = '0;
        txrspflit_tmp.resp     = '0;
        txrspflit_tmp.fwdstate = '0;
        txrspflit_tmp.cbusy    = '0;
        txrspflit_tmp.dbid     = '0;
        txrspflit_tmp.pcrdtype = '0;
        txrspflit_tmp.tagop    = '0;
        txrspflit_tmp.tracetag = '0;
    end

    always@(posedge CLK or posedge RST)begin
        if(RST == 1'b1)begin
            TXRSPFLITV <= 1'b0;
            TXRSPFLIT <= {chie_pkg::RSP_FLIT_WIDTH{1'b0}};
        end
        else if(send_rsp)begin
            TXRSPFLITV <= 1'b1;
            TXRSPFLIT <= txrspflit_tmp;
        end
        else begin
            TXRSPFLITV <= 1'b0;
        end
    end

    always@*begin
        if(RST == 1'b1)
            addr = '0;
        else if(dbg_sn_wr_en | dbg_sn_rd_en)
            addr = dbg_sn_addr;
        else if(wr_en_q)
            addr = addr_q;
        else if(rxreqflit_v)
            addr = rxreqflit.addr;
        else
            ;
    end

    assign dbg_sn_rd_data = rd_data;

    tb_snf_sram u_snf_sram(
                    .clk     (CLK     ),
                    .rst     (RST     ),
                    .addr    (addr    ),
                    .rd_en   (rd_en   ),
                    .wr_en   (wr_en   ),
                    .wr_data (wr_data ),
                    .rd_data (rd_data ),
                    .empty   (mem_empty),
                    .full    (mem_full)
                );

endmodule
