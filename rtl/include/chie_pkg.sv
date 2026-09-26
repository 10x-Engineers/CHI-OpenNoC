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
*/

// CHI Issue E.b flit layout as types rather than bit ranges.
//
// The interface widths are the ones IHI 0050E.b SS16.1 leaves IMPLEMENTATION
// DEFINED, so they are seeded by `define and can be overridden at compile time
// by the integration that instantiates a node. The defaults match the parameter
// defaults in each node's *_param.svh.

`ifndef CHIE_PKG_SV
`define CHIE_PKG_SV

`ifndef CHIE_REQ_ADDR_WIDTH
  `define CHIE_REQ_ADDR_WIDTH 44
`endif
`ifndef CHIE_NID_WIDTH
  `define CHIE_NID_WIDTH 7
`endif
`ifndef CHIE_DATA_WIDTH
  `define CHIE_DATA_WIDTH 256
`endif
// Section 13.10.56 (p.13-441) makes RSVDC optional and its width implementation
// defined -- "the permitted field widths are 4-bit, 8-bit, 12-bit, 16-bit, 24-bit,
// and 32-bit", and they "can be different between REQ and DAT channels". A packed
// struct cannot hold a zero-width member, so the DEFINE's presence is the field's
// presence and its value is the width; leave it undefined for an interface without
// the bus. chie_flit_opt_check holds each node's parameter to what is declared here.
//
// Section 11.3 (p.11-365) gives MPAM the same shape: the field "is either 0 bits or
// 11 bits", so `CHIE_MPAM_PRESENT is its presence and section 16.1's (p.16-471)
// MPAM_Support = MPAM_9_1 is what defining it declares.
package chie_pkg;

  parameter int REQ_ADDR_WIDTH = `CHIE_REQ_ADDR_WIDTH;
  parameter int NID_WIDTH      = `CHIE_NID_WIDTH;
  parameter int DATA_WIDTH     = `CHIE_DATA_WIDTH;
  parameter int BE_WIDTH        = DATA_WIDTH / 8;    // one byte enable per data byte
  parameter int DATACHECK_WIDTH = DATA_WIDTH / 8;    // SS9.6: one odd-parity bit per byte
  parameter int POISON_WIDTH    = DATA_WIDTH / 64;   // SS9.5: one bit per 8-byte chunk
  parameter int SNP_ADDR_WIDTH = REQ_ADDR_WIDTH - 3;   // Table 13-8: no line offset
  parameter int TAG_WIDTH      = DATA_WIDTH / 32;
  parameter int TU_WIDTH       = DATA_WIDTH / 128;
  // Table 13-32 (SS13.10.37 p.13-435).
  localparam logic [1:0] TAGOP_INVALID  = 2'b00;
  localparam logic [1:0] TAGOP_TRANSFER = 2'b01;
  localparam logic [1:0] TAGOP_UPDATE   = 2'b10;
  localparam logic [1:0] TAGOP_MATCH    = 2'b11;
`ifdef CHIE_REQ_RSVDC_WIDTH
  parameter int REQ_RSVDC_WIDTH = `CHIE_REQ_RSVDC_WIDTH;
`else
  parameter int REQ_RSVDC_WIDTH = 0;
`endif
`ifdef CHIE_DAT_RSVDC_WIDTH
  parameter int DAT_RSVDC_WIDTH = `CHIE_DAT_RSVDC_WIDTH;
`else
  parameter int DAT_RSVDC_WIDTH = 0;
`endif
  // Section 13.10.56 (p.13-441) makes the field optional, and a wire cannot be zero
  // bits wide -- so the plumb between a node's ingress and its egress carries this
  // padded width instead.
  parameter int REQ_RSVDC_BUS_WIDTH = (REQ_RSVDC_WIDTH == 0) ? 1 : REQ_RSVDC_WIDTH;
  typedef logic [REQ_RSVDC_BUS_WIDTH-1:0] req_rsvdc_t;

`ifdef CHIE_MPAM_PRESENT
  parameter int MPAM_WIDTH = 11;
`else
  parameter int MPAM_WIDTH = 0;
`endif

  // Section 11.3 Figure 11-3 (p.11-365): MPAM[0]=MPAMNS, MPAM[9:1]=PartID,
  // MPAM[10]=PerfMonGroup.
  typedef struct packed {
    logic       perfmongroup;
    logic [8:0] partid;
    logic       mpamns;
  } mpam_s;

  // Table 11-5 (section 11.3.2 p.11-366): the default settings a message that does
  // not use MPAM must carry -- PartID 0, PerfMonGroup 0, MPAMNS = the message's NS.
  function automatic mpam_s mpam_default(logic ns);
    mpam_default = '{perfmongroup: 1'b0, partid: '0, mpamns: ns};
  endfunction

  // ---------------------------------------------------------------------------
  // Encoded fields. Table 13-x gives each channel its own opcode space and its
  // own width, so they are separate types -- an RSP opcode cannot be compared
  // against a REQ one.
  // ---------------------------------------------------------------------------
  typedef enum logic [6:0] {
    REQ_REQLCRDRETURN               = {1'h0, 6'h00},
    REQ_READSHARED                  = {1'h0, 6'h01},
    REQ_READCLEAN                   = {1'h0, 6'h02},
    REQ_READONCE                    = {1'h0, 6'h03},
    REQ_READNOSNP                   = {1'h0, 6'h04},
    REQ_PCRDRETURN                  = {1'h0, 6'h05},
    REQ_READUNIQUE                  = {1'h0, 6'h07},
    REQ_CLEANSHARED                 = {1'h0, 6'h08},
    REQ_CLEANINVALID                = {1'h0, 6'h09},
    REQ_MAKEINVALID                 = {1'h0, 6'h0a},
    REQ_CLEANUNIQUE                 = {1'h0, 6'h0b},
    REQ_MAKEUNIQUE                  = {1'h0, 6'h0c},
    REQ_EVICT                       = {1'h0, 6'h0d},
    REQ_READNOSNPSEP                = {1'h0, 6'h11},
    REQ_CLEANSHAREDPERSISTSEP       = {1'h0, 6'h13},
    REQ_DVMOP                       = {1'h0, 6'h14},
    REQ_WRITEEVICTFULL              = {1'h0, 6'h15},
    REQ_WRITECLEANFULL              = {1'h0, 6'h17},
    REQ_WRITEUNIQUEPTL              = {1'h0, 6'h18},
    REQ_WRITEUNIQUEFULL             = {1'h0, 6'h19},
    REQ_WRITEBACKPTL                = {1'h0, 6'h1a},
    REQ_WRITEBACKFULL               = {1'h0, 6'h1b},
    REQ_WRITENOSNPPTL               = {1'h0, 6'h1c},
    REQ_WRITENOSNPFULL              = {1'h0, 6'h1d},
    REQ_WRITEUNIQUEFULLSTASH        = {1'h0, 6'h20},
    REQ_WRITEUNIQUEPTLSTASH         = {1'h0, 6'h21},
    REQ_STASHONCESHARED             = {1'h0, 6'h22},
    REQ_STASHONCEUNIQUE             = {1'h0, 6'h23},
    REQ_READONCECLEANINVALID        = {1'h0, 6'h24},
    REQ_READONCEMAKEINVALID         = {1'h0, 6'h25},
    REQ_READNOTSHAREDDIRTY          = {1'h0, 6'h26},
    REQ_CLEANSHAREDPERSIST          = {1'h0, 6'h27},
    REQ_ATOMICSTORE_ADD             = {1'h0, 6'h28},
    REQ_ATOMICSTORE_CLR             = {1'h0, 6'h29},
    REQ_ATOMICSTORE_EOR             = {1'h0, 6'h2a},
    REQ_ATOMICSTORE_SET             = {1'h0, 6'h2b},
    REQ_ATOMICSTORE_SMAX            = {1'h0, 6'h2c},
    REQ_ATOMICSTORE_SMIN            = {1'h0, 6'h2d},
    REQ_ATOMICSTORE_UMAX            = {1'h0, 6'h2e},
    REQ_ATOMICSTORE_UMIN            = {1'h0, 6'h2f},
    REQ_ATOMICLOAD_ADD              = {1'h0, 6'h30},
    REQ_ATOMICLOAD_CLR              = {1'h0, 6'h31},
    REQ_ATOMICLOAD_EOR              = {1'h0, 6'h32},
    REQ_ATOMICLOAD_SET              = {1'h0, 6'h33},
    REQ_ATOMICLOAD_SMAX             = {1'h0, 6'h34},
    REQ_ATOMICLOAD_SMIN             = {1'h0, 6'h35},
    REQ_ATOMICLOAD_UMAX             = {1'h0, 6'h36},
    REQ_ATOMICLOAD_UMIN             = {1'h0, 6'h37},
    REQ_ATOMICSWAP                  = {1'h0, 6'h38},
    REQ_ATOMICCOMPARE               = {1'h0, 6'h39},
    REQ_PREFETCHTGT                 = {1'h0, 6'h3a},
    REQ_MAKEREADUNIQUE              = {1'h1, 6'h01},
    REQ_WRITEEVICTOREVICT           = {1'h1, 6'h02},
    REQ_WRITEUNIQUEZERO             = {1'h1, 6'h03},
    REQ_WRITENOSNPZERO              = {1'h1, 6'h04},
    REQ_STASHONCESEPSHARED          = {1'h1, 6'h07},
    REQ_STASHONCESEPUNIQUE          = {1'h1, 6'h08},
    REQ_READPREFERUNIQUE            = {1'h1, 6'h0c},
    REQ_WRITENOSNPFULLCLEANSH       = {1'h1, 6'h10},
    REQ_WRITENOSNPFULLCLEANINV      = {1'h1, 6'h11},
    REQ_WRITENOSNPFULLCLEANSHPERSEP = {1'h1, 6'h12},
    REQ_WRITEUNIQUEFULLCLEANSH      = {1'h1, 6'h14},
    REQ_WRITEUNIQUEFULLCLEANSHPERSEP= {1'h1, 6'h16},
    REQ_WRITEBACKFULLCLEANSH        = {1'h1, 6'h18},
    REQ_WRITEBACKFULLCLEANINV       = {1'h1, 6'h19},
    REQ_WRITEBACKFULLCLEANSHPERSEP  = {1'h1, 6'h1a},
    REQ_WRITECLEANFULLCLEANSH       = {1'h1, 6'h1c},
    REQ_WRITECLEANFULLCLEANSHPERSEP = {1'h1, 6'h1e},
    REQ_WRITENOSNPPTLCLEANSH        = {1'h1, 6'h20},
    REQ_WRITENOSNPPTLCLEANINV       = {1'h1, 6'h21},
    REQ_WRITENOSNPPTLCLEANSHPERSEP  = {1'h1, 6'h22},
    REQ_WRITEUNIQUEPTLCLEANSH       = {1'h1, 6'h24},
    REQ_WRITEUNIQUEPTLCLEANSHPERSEP = {1'h1, 6'h26}
  } req_opcode_e;

  typedef enum logic [4:0] {
    RSP_RSPLCRDRETURN = 5'h00,
    RSP_SNPRESP       = 5'h01,
    RSP_COMPACK       = 5'h02,
    RSP_RETRYACK      = 5'h03,
    RSP_COMP          = 5'h04,
    RSP_COMPDBIDRESP  = 5'h05,
    RSP_DBIDRESP      = 5'h06,
    RSP_PCRDGRANT     = 5'h07,
    RSP_READRECEIPT   = 5'h08,
    RSP_SNPRESPFWDED  = 5'h09,
    RSP_TAGMATCH      = 5'h0a,
    RSP_RESPSEPDATA   = 5'h0b,
    RSP_PERSIST       = 5'h0c,
    RSP_COMPPERSIST   = 5'h0d,
    RSP_DBIDRESPORD   = 5'h0e,
    RSP_STASHDONE     = 5'h10,
    RSP_COMPSTASHDONE = 5'h11,
    RSP_COMPCMO       = 5'h14
  } rsp_opcode_e;

  typedef enum logic [3:0] {
    DAT_DATLCRDRETURN     = 4'h0,
    DAT_SNPRESPDATA       = 4'h1,
    DAT_COPYBACKWRDATA    = 4'h2,
    DAT_NONCOPYBACKWRDATA = 4'h3,
    DAT_COMPDATA          = 4'h4,
    DAT_SNPRESPDATAPTL    = 4'h5,
    DAT_SNPRESPDATAFWDED  = 4'h6,
    DAT_WRITEDATACANCEL   = 4'h7,
    DAT_DATASEPRESP       = 4'hb,
    DAT_NCBWRDATACOMPACK  = 4'hc
  } dat_opcode_e;

  typedef enum logic [4:0] {
    SNP_SNPLCRDRETURN        = 5'h00,
    SNP_SNPSHARED            = 5'h01,
    SNP_SNPCLEAN             = 5'h02,
    SNP_SNPONCE              = 5'h03,
    SNP_SNPNOTSHAREDDIRTY    = 5'h04,
    SNP_SNPUNIQUESTASH       = 5'h05,
    SNP_SNPMAKEINVALIDSTASH  = 5'h06,
    SNP_SNPUNIQUE            = 5'h07,
    SNP_SNPCLEANSHARED       = 5'h08,
    SNP_SNPCLEANINVALID      = 5'h09,
    SNP_SNPMAKEINVALID       = 5'h0a,
    SNP_SNPSTASHUNIQUE       = 5'h0b,
    SNP_SNPSTASHSHARED       = 5'h0c,
    SNP_SNPDVMOP             = 5'h0d,
    SNP_SNPQUERY             = 5'h10,
    SNP_SNPSHAREDFWD         = 5'h11,
    SNP_SNPCLEANFWD          = 5'h12,
    SNP_SNPONCEFWD           = 5'h13,
    SNP_SNPNOTSHAREDDIRTYFWD = 5'h14,
    SNP_SNPPREFERUNIQUE      = 5'h15,
    SNP_SNPPREFERUNIQUEFWD   = 5'h16,
    SNP_SNPUNIQUEFWD         = 5'h17
  } snp_opcode_e;

  // Table 13-31 (SS13.10.32). EX_OK and DATA are the two the macro header left
  // commented out, so a raw literal was the only way to name them.
  typedef enum logic [1:0] {
    RESP_ERR_NORM_OK  = 2'b00,
    RESP_ERR_EX_OK    = 2'b01,
    RESP_ERR_DATA     = 2'b10,
    RESP_ERR_NON_DATA = 2'b11
  } resp_err_e;

  // Table 13-30 (SS13.10.32). One field, read two ways: the mnemonics below are
  // the Snoop-response reading, and a CompData reads 010/110/111 as UC/UD_PD/SD_PD.
  typedef enum logic [2:0] {
    RESP_I     = 3'b000,
    RESP_SC    = 3'b001,
    RESP_UC_UD = 3'b010,
    RESP_SD    = 3'b011,
    RESP_I_PD  = 3'b100,
    RESP_SC_PD = 3'b101,
    RESP_UC_PD = 3'b110,
    RESP_SD_PD = 3'b111
  } resp_state_e;

  // Table 2-9 (SS2.8 p.2-119). All four encodings, including the reserved one --
  // the macro header left the whole group commented out.
  typedef enum logic [1:0] {
    ORDER_NONE          = 2'b00,
    ORDER_RSVD          = 2'b01,
    ORDER_REQ_WR_OBS    = 2'b10,
    ORDER_END_POINT     = 2'b11
  } order_e;

  // Table 2-16 (SS2.10.5 p.2-137).
  typedef enum logic [2:0] {
    SIZE_1B  = 3'h0,
    SIZE_2B  = 3'h1,
    SIZE_4B  = 3'h2,
    SIZE_8B  = 3'h3,
    SIZE_16B = 3'h4,
    SIZE_32B = 3'h5,
    SIZE_64B = 3'h6
  } size_e;

  // Table 2-11 (SS2.9.4 p.2-129). Named bits rather than four indices into a
  // 4-bit field.
  typedef struct packed {
    logic allocate;
    logic cacheable;
    logic device;
    logic early_wr_ack;
  } memattr_s;

  // ---------------------------------------------------------------------------
  // Flit layouts. Field order is MSB-first, so the declaration reads as the
  // packet diagram does. Fields the spec overlays on one another -- Table 13-6's
  // Excl/SnoopMe, SS13.10.24's SnpAttr/DoDWT, SS13.10.54's DataSource/FwdState/
  // DataPull -- are packed unions, which is what makes them one set of bits with
  // several names rather than several fields.
  //
  // RSVDC and MPAM sit at the MSB end of the flits that carry them, present only when
  // their defines are. Section 13.10.56 (p.13-441) gives RSVDC the REQ and DAT
  // channels and no other; section 16.1 (p.16-471) puts MPAM "on all address
  // channels", which is REQ and SNP. The MSB end is not a style choice: chi_xp_channel
  // reads QoS at [3:1] and TgtID at [FLIT_TGT_OFFSET +: NID_WIDTH], so a field added
  // below those would mis-route every flit in the fabric.
  // ---------------------------------------------------------------------------
  typedef union packed {
    logic excl;
    logic snoopme;
  } req_excl_u;

  typedef union packed {
    logic snpattr;
    logic dodwt;
  } req_snpattr_u;

  typedef union packed {
    logic stashnidvalid;
    logic endian;
  } req_stashnidvalid_u;

  typedef struct packed {
`ifdef CHIE_REQ_RSVDC_WIDTH
    logic [`CHIE_REQ_RSVDC_WIDTH-1:0] rsvdc;
`endif
`ifdef CHIE_MPAM_PRESENT
    mpam_s                    mpam;
`endif
    logic                     tracetag;
    logic [1:0]               tagop;
    logic                     expcompack;
    req_excl_u                excl;
    logic [7:0]               lpid;
    req_snpattr_u             snpattr;
    memattr_s                 memattr;
    logic [3:0]               pcrdtype;
    order_e                   order;
    logic                     allowretry;
    logic                     likelyshared;
    logic                     ns;
    logic [REQ_ADDR_WIDTH-1:0] addr;
    size_e                    size;
    req_opcode_e              opcode;
    logic [11:0]              returntxnid;
    req_stashnidvalid_u       stashnidvalid;
    logic [NID_WIDTH-1:0]     returnnid;   // StashNID on a Stash request
    logic [11:0]              txnid;
    logic [NID_WIDTH-1:0]     srcid;
    logic [NID_WIDTH-1:0]     tgtid;
    logic [3:0]               qos;
  } req_flit_s;

  typedef union packed {
    logic [2:0] fwdstate;
    logic [2:0] datapull;
  } rsp_fwdstate_u;

  typedef struct packed {
    logic                 tracetag;
    logic [1:0]           tagop;
    logic [3:0]           pcrdtype;
    logic [11:0]          dbid;
    logic [2:0]           cbusy;
    rsp_fwdstate_u        fwdstate;
    resp_state_e          resp;
    resp_err_e            resperr;
    rsp_opcode_e          opcode;
    logic [11:0]          txnid;
    logic [NID_WIDTH-1:0] srcid;
    logic [NID_WIDTH-1:0] tgtid;
    logic [3:0]           qos;
  } rsp_flit_s;

  typedef union packed {
    logic [3:0] datasource;
    logic [3:0] fwdstate;
    logic [3:0] datapull;
  } dat_datasource_u;

  typedef struct packed {
    logic [POISON_WIDTH-1:0]    poison;
    logic [DATACHECK_WIDTH-1:0] datacheck;
    logic [DATA_WIDTH-1:0]      data;
    logic [BE_WIDTH-1:0]        be;
`ifdef CHIE_DAT_RSVDC_WIDTH
    logic [`CHIE_DAT_RSVDC_WIDTH-1:0] rsvdc;
`endif
    logic                       tracetag;
    logic [TU_WIDTH-1:0]        tu;
    logic [TAG_WIDTH-1:0]       tag;
    logic [1:0]                 tagop;
    logic [1:0]                 dataid;
    logic [1:0]                 ccid;
    logic [11:0]                dbid;
    logic [2:0]                 cbusy;
    dat_datasource_u            datasource;
    resp_state_e                resp;
    resp_err_e                  resperr;
    dat_opcode_e                opcode;
    logic [NID_WIDTH-1:0]       homenid;
    logic [11:0]                txnid;
    logic [NID_WIDTH-1:0]       srcid;
    logic [NID_WIDTH-1:0]       tgtid;
    logic [3:0]                 qos;
  } dat_flit_s;

  // ---------------------------------------------------------------------------
  // Retry-mechanism payloads. Not flits: these are what a node's QoS block hands
  // its TXRSP block through a width-parameterised sync_fifo. They live here
  // rather than per node because every node that implements SS2.11 retry queues
  // exactly these fields, and did so through its own copy of one running-sum
  // macro set.
  // ---------------------------------------------------------------------------

  // What a retried request has to keep so its RetryAck can be built later
  // (SS2.11 p.2-145: the PCrdType granted must match the one retried under).
  typedef struct packed {
    logic [3:0]           pcrdtype;
    logic                 trace;
    logic [3:0]           qos;
    logic [11:0]          txnid;
    logic [NID_WIDTH-1:0] srcid;
  } retry_ackq_s;

  // A PCrdGrant binds to no transaction (SS2.6.5 p.2-112 sets its TxnID to zero),
  // so the queue carries only who to grant to and under which credit type.
  typedef struct packed {
    logic [3:0]           pcrdtype;
    logic [3:0]           qos;
    logic [NID_WIDTH-1:0] srcid;
  } pcrdgrantq_s;

  // SS13.10.11 (p.13-427) overlays StashLPID/StashLPIDValid and VMIDExt on the
  // FwdTxnID bits.
  typedef union packed {
    logic [11:0] fwdtxnid;
    logic [11:0] vmidext;
    struct packed {
      logic [5:0] unused;
      logic       stashlpidvalid;
      logic [4:0] stashlpid;
    } stash;
  } snp_fwdtxnid_u;

  typedef struct packed {
`ifdef CHIE_MPAM_PRESENT
    mpam_s                      mpam;
`endif
    logic                       tracetag;
    logic                       rettosrc;
    logic                       donotgotosd;
    logic                       ns;
    logic [SNP_ADDR_WIDTH-1:0]  addr;
    snp_opcode_e                opcode;
    snp_fwdtxnid_u              fwdtxnid;
    logic [NID_WIDTH-1:0]       fwdnid;
    logic [11:0]                txnid;
    logic [NID_WIDTH-1:0]       srcid;
    logic [3:0]                 qos;
  } snp_flit_s;

  // Table 13-8 (p.13-413) gives the SNP channel no TgtID, so the snoopee a Home or MN
  // addresses travels beside the flit as the fabric's routing envelope.
  typedef struct packed {
    logic [NID_WIDTH-1:0] tgtid;
    snp_flit_s            flit;
  } snp_routed_s;

  // CHI E.b section 9.6 (p.9-348): "The DAT packet carries eight Data Check bits per
  // 64 bits of data. The Data Check bit is a parity bit that generates Odd Byte
  // parity." One bit per data byte, so DATACHECK_WIDTH == BE_WIDTH.
  //
  // Bit i covers byte lane i. Section 13.10.52 (p.13-436) says only that a bit supplies
  // parity "for the corresponding byte of Data" and never fixes the mapping, so this
  // is a declared convention rather than a derived one -- it matches the CHI VIP's
  // chi_pkg::compute_datacheck(), and a peer that orders the bits differently would
  // disagree on every beat. See the DataCheck row of the README's Features table.
  // SS12.5.2 (p.12-379, MUST): "Tag Match must be performed for only those tags that
  // have at least one corresponding BE bit asserted. A Tag Match must not be performed
  // when all BE bits are set to zero." Over one 64-byte line: SS12.2 (p.12-373) gives
  // it one four-bit tag per aligned 16 bytes -- four tags against 64 byte enables at
  // any Data_Width. A line with no enabled byte returns 1, which SS12.11.1 (p.12-386,
  // MUST) makes a Pass at a Completer that supports MTE -- the caller decides that it does.
  parameter int LINE_TAG_NUM = 64/16;
  parameter int LINE_BE_PER_TAG = 16;
  function automatic logic tag_match_pass(logic [(4*LINE_TAG_NUM)-1:0] phys,
                                          logic [(4*LINE_TAG_NUM)-1:0] alloc,
                                          logic [63:0]                 be);
    tag_match_pass = 1'b1;
    for (int t = 0; t < LINE_TAG_NUM; t++)
      if (|be[t*LINE_BE_PER_TAG +: LINE_BE_PER_TAG])
        if (phys[t*4 +: 4] != alloc[t*4 +: 4]) tag_match_pass = 1'b0;
  endfunction

  function automatic logic [DATACHECK_WIDTH-1:0] datacheck_of(logic [DATA_WIDTH-1:0] data);
    for (int i = 0; i < DATACHECK_WIDTH; i++) datacheck_of[i] = ~(^data[i*8 +: 8]);
  endfunction

  // The one read of REQ MPAM, so no node needs its own `ifdef. With the field absent
  // the request cannot have used MPAM, which Table 11-5 (p.11-366) makes the default.
  function automatic mpam_s req_mpam_of(req_flit_s f);
`ifdef CHIE_MPAM_PRESENT
    return f.mpam;
`else
    return mpam_default(f.ns);
`endif
  endfunction

  // The one read of REQ RSVDC, so no node needs an `ifdef of its own. With the
  // field absent there is nothing to propagate, which section 13.10.56 (p.13-441)
  // leaves IMPLEMENTATION DEFINED anyway.
  function automatic req_rsvdc_t req_rsvdc_of(req_flit_s f);
`ifdef CHIE_REQ_RSVDC_WIDTH
    return f.rsvdc;
`else
    return '0;
`endif
  endfunction

  // SS13.10.31 (p.13-433) scopes SnoopMe to the Atomics, where Table 13-6 has it
  // displace Excl on the shared REQ bit -- so the Excl bit of an Atomic is not an
  // Exclusive request and must not be read as one.
  function automatic logic atomic_req(req_opcode_e op);
    return (op >= REQ_ATOMICSTORE_ADD) && (op <= REQ_ATOMICCOMPARE);
  endfunction

  // Table 4-40 (SS4.7.4 p.4-219): an AtomicStore completes with Comp, the other three
  // with CompData carrying SS4.2.5's (p.4-187, MUST) "original value at the addressed
  // location".
  function automatic logic atomic_returns_data(req_opcode_e op);
    return (op >= REQ_ATOMICLOAD_ADD) && (op <= REQ_ATOMICCOMPARE);
  endfunction

  // SS2.10.5 (p.2-137): Size is the whole outbound payload, and an AtomicCompare
  // concatenates equal Compare and Swap halves -- so the element the operation reads,
  // writes and returns is half of it (Table 2-16 p.2-137).
  function automatic int unsigned atomic_elem_bytes(req_opcode_e op,
                                                    size_e       size);
    int unsigned n;
    n = 32'd1 << size;
    return (op == REQ_ATOMICCOMPARE) ? (n >> 1) : n;
  endfunction

  // SS4.2.5 (p.4-187, MUST): an Atomic's inbound data is its outbound size, and half
  // of it for AtomicCompare.
  function automatic size_e atomic_in_size(req_opcode_e op, size_e size);
    return ((op == REQ_ATOMICCOMPARE) && (size != SIZE_1B)) ? size_e'(size - 3'd1) : size;
  endfunction

  // SS2.10.5 (p.2-137): "the Swap data address can be determined by inverting bit[n]
  // in the Compare data address where n = log2(Compare data size in bytes)" -- which
  // for a power-of-two element size is the offset XOR that size.
  function automatic logic [5:0] atomic_swap_off(logic [5:0]  cmp_off,
                                                int unsigned elem_bytes);
    return cmp_off ^ elem_bytes[5:0];
  endfunction

  function automatic logic [63:0] atomic_mask(int unsigned nbytes);
    logic [63:0] m;
    m = 64'd0;
    for (int unsigned b = 0; b < 8; b = b + 1)
      if (b < nbytes)
        m[b*8 +: 8] = 8'hff;
    return m;
  endfunction

  function automatic logic [63:0] atomic_bswap(logic [63:0] v, int unsigned nbytes);
    logic [63:0] r;
    int unsigned src;
    r = 64'd0;
    for (int unsigned b = 0; b < 8; b = b + 1)
      if (b < nbytes) begin
        src = nbytes - 1 - b;
        r[b*8 +: 8] = v[src*8 +: 8];
      end
    return r;
  endfunction

  // Table 4-19 (SS4.2.5 p.4-185) and Table 4-20 (p.4-186) give the eight AtomicStore
  // and eight AtomicLoad operations, and p.4-186 AtomicSwap's. SS2.10.5 (p.2-138):
  // "for arithmetic operations, such as ADD, MAX, and MIN the component performing
  // the operation needs to know the format of the data" -- so both operands are
  // brought to a common order first. The bitwise rows are byte-invariant, which is
  // why the same swap in and out serves them unchanged.
  function automatic logic [63:0] atomic_alu(req_opcode_e op,
                                             int unsigned nbytes,
                                             logic        big_endian,
                                             logic [63:0] initial_data,
                                             logic [63:0] txn_data);
    logic [63:0]        m, a, b, res;
    logic signed [63:0] sa, sb;
    int unsigned        sh;

    m  = atomic_mask(nbytes);
    a  = (big_endian ? atomic_bswap(initial_data, nbytes) : initial_data) & m;
    b  = (big_endian ? atomic_bswap(txn_data,     nbytes) : txn_data)     & m;
    sh = 32'd64 - nbytes * 32'd8;
    sa = $signed(a << sh) >>> sh;
    sb = $signed(b << sh) >>> sh;

    case (op)
      REQ_ATOMICSTORE_ADD,
      REQ_ATOMICLOAD_ADD  : res = a + b;
      REQ_ATOMICSTORE_CLR,
      REQ_ATOMICLOAD_CLR  : res = a & ~b;
      REQ_ATOMICSTORE_EOR,
      REQ_ATOMICLOAD_EOR  : res = a ^ b;
      REQ_ATOMICSTORE_SET,
      REQ_ATOMICLOAD_SET  : res = a | b;
      REQ_ATOMICSTORE_SMAX,
      REQ_ATOMICLOAD_SMAX : res = (sb > sa) ? b : a;
      REQ_ATOMICSTORE_SMIN,
      REQ_ATOMICLOAD_SMIN : res = (sb < sa) ? b : a;
      REQ_ATOMICSTORE_UMAX,
      REQ_ATOMICLOAD_UMAX : res = (b > a) ? b : a;
      REQ_ATOMICSTORE_UMIN,
      REQ_ATOMICLOAD_UMIN : res = (b < a) ? b : a;
      REQ_ATOMICSWAP      : res = b;
      default             : res = a;
    endcase

    res = res & m;
    return big_endian ? atomic_bswap(res, nbytes) : res;
  endfunction

  // Table 4-19 (SS4.2.5 p.4-185) and Table 4-20 (p.4-186): the MAX and MIN rows
  // update the location only "if" their condition holds, where the other rows
  // always do.
  function automatic logic atomic_conditional(req_opcode_e op);
    return op inside {REQ_ATOMICSTORE_SMAX, REQ_ATOMICSTORE_SMIN, REQ_ATOMICSTORE_UMAX, REQ_ATOMICSTORE_UMIN,
                      REQ_ATOMICLOAD_SMAX,  REQ_ATOMICLOAD_SMIN,  REQ_ATOMICLOAD_UMAX,  REQ_ATOMICLOAD_UMIN};
  endfunction

  // SS4.2.5 (p.4-186): AtomicCompare writes the Swap value only "if the values
  // match", which is a byte equality against the addressed location -- no arithmetic,
  // so SS2.10.5's Endian bit does not reach it.
  function automatic logic atomic_compare_eq(logic [127:0] initial_data,
                                             logic [127:0] compare_data,
                                             int unsigned  nbytes);
    logic eq;
    eq = 1'b1;
    for (int unsigned b = 0; b < 16; b = b + 1)
      if ((b < nbytes) && (initial_data[b*8 +: 8] != compare_data[b*8 +: 8]))
        eq = 1'b0;
    return eq;
  endfunction

  parameter int REQ_FLIT_WIDTH = $bits(req_flit_s);
  parameter int RSP_FLIT_WIDTH = $bits(rsp_flit_s);
  parameter int DAT_FLIT_WIDTH = $bits(dat_flit_s);
  parameter int SNP_FLIT_WIDTH = $bits(snp_flit_s);

endpackage

`endif
