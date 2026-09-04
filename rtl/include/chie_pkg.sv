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
    REQ_SNOOPFILTEREVICT            = {1'h1, 6'h00},
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
  // RSVDC is absent: SS16.1 makes its width IMPLEMENTATION DEFINED and every
  // node in this repo declares it 0. A build that wants it must add it here,
  // and chie_flit_rsvdc_check enforces that rather than letting the layout
  // silently disagree with the macro header.
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

  parameter int REQ_FLIT_WIDTH = $bits(req_flit_s);
  parameter int RSP_FLIT_WIDTH = $bits(rsp_flit_s);
  parameter int DAT_FLIT_WIDTH = $bits(dat_flit_s);
  parameter int SNP_FLIT_WIDTH = $bits(snp_flit_s);

endpackage

`endif
