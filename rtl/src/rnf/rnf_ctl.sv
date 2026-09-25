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
`include "axi4_defines.svh"

// The RN-F's core-side engine: an AXI4 read or write, or a cache maintenance
// operation, served from the cache or by the coherent transaction that makes it
// servable.
//
// Which transaction that is comes from the line's state and the core's intent
// (rnf_defines.svh): Table 4-4 (SS4.2.1 p.4-167), Table 4-10 (SS4.2.2 p.4-174)
// and Table 4-16 (SS4.2.3 p.4-181) say what each state permits.
//
//   read miss                -> ReadShared / ReadClean / ReadPreferUnique /
//                               ReadUnique, or a non-allocating ReadOnce*
//   write hit, Unique        -> nothing on the link; SS4.6's Table 4-32
//                               (p.4-209) makes UC -> UD a silent transition
//   write hit, Shared        -> CleanUnique, or MakeReadUnique
//   write miss, whole line   -> MakeUnique, or WriteUniqueFull/Zero(+CleanSh)
//   write miss, part of one  -> ReadUnique, or WriteUniquePtl(+CleanSh)
//   maintenance              -> WriteBackFull, WriteCleanFull, WriteEvictFull,
//                               WriteEvictOrEvict, Evict, CleanShared,
//                               CleanInvalid, MakeInvalid, and the Table 4-17
//                               (SS4.2.4 p.4-182) combinations of them
//   Device / Non-cacheable   -> ReadNoSnp, WriteNoSnp{Full,Ptl,Zero}, the cache
//                               bypassed (Table 2-11 SS2.9.4 p.2-129)
//
// A line is UCE when a CleanUnique ends from Invalid (Table 4-38 p.4-218): owned,
// with no valid bytes. A partial store into it makes it UDP (Table 4-32 p.4-209),
// which AWCOH=PARTIAL asks for; otherwise the store follows the CleanUnique with a
// ReadUnique (p.4-215: "the Requester needing to issue another transaction"), which
// Table 4-33 (p.4-212) permits from UCE. A UDP line is read by ReadUnique, merging
// the returned bytes under its own (Table 4-33 fn c), and written back by
// WriteBackPtl (Table 4-16 p.4-181).
//
// An AXI access with AxLOCK set and an AxID below 256 is an exclusive one for the
// Logical Processor AxID[7:0] names (SS6.3 p.6-286); a larger AxID is served as a
// plain access, since LPID is eight bits and IDs above it would alias. The Load
// sets that LP's monitor on the line, and the monitor is reset by the line leaving
// the cache -- an invalidating snoop among the ways -- or by a store to it
// (SS6.2.1 p.6-283). The Store passes silently from a Unique line, issues
// CleanUnique(Excl) or MakeReadUnique(Excl) from a Shared one, and fails without a
// transaction once the monitor is reset (SS6.3.3 p.6-290).
//
// Displacing a Dirty victim owes a WriteBackFull (Table 4-16 SS4.2.3 p.4-181);
// a Clean one is dropped silently, which Table 4-32 permits.
//
// Every request goes out with AllowRetry set, which SS2.11 (p.2-145, MUST)
// requires of a first attempt, so any of them may draw a RetryAck. The node then
// holds it until a PCrdGrant of the RetryAck's PCrdType, and resends it with
// AllowRetry clear. A P-Credit can land before the RetryAck it answers, so credits
// are banked per type rather than matched to a request; one the node holds when it
// has nothing left that could draw a RetryAck is surplus, and SS2.11.1 (p.2-147,
// MUST) has it returned.
//
// One transaction at a time: SS2.5.2 (p.2-87) bounds TxnID reuse by what is
// outstanding, so a single context needs no MSHR to stay legal.
module rnf_ctl `RNF_PARAM
    (
    input  wire                                 clk_i,
    input  wire                                 rst_i,

    // AXI4 subordinate, read channels
    input  wire [`AXI4_ARID_WIDTH-1:0]          ARID,
    input  wire [`AXI4_ARADDR_WIDTH-1:0]        ARADDR,
    input  wire [`AXI4_ARLEN_WIDTH-1:0]         ARLEN,
    input  wire [`AXI4_ARSIZE_WIDTH-1:0]        ARSIZE,
    input  wire [`AXI4_ARCACHE_WIDTH-1:0]       ARCACHE,
    input  wire [`AXI4_ARQOS_WIDTH-1:0]         ARQOS,
    input  wire [`RNF_AR_COH_W-1:0]             ARCOH,
    input  wire [`RNF_AR_ORD_W-1:0]             ARORD,
    input  wire [`AXI4_ARLOCK_WIDTH-1:0]        ARLOCK,
    input  wire [`AXI4_ARUSER_WIDTH-1:0]        ARUSER,
    input  wire                                 ARVALID,
    output wire                                 ARREADY,
    output wire [`AXI4_RID_WIDTH-1:0]           RID,
    output wire [`AXI4_RDATA_WIDTH-1:0]         RDATA,
    output wire [`AXI4_RRESP_WIDTH-1:0]         RRESP,
    output logic [`AXI4_RUSER_WIDTH-1:0]        RUSER,
    output wire                                 RLAST,
    output wire                                 RVALID,
    input  wire                                 RREADY,

    // AXI4 subordinate, write channels
    input  wire [`AXI4_AWID_WIDTH-1:0]          AWID,
    input  wire [`AXI4_AWADDR_WIDTH-1:0]        AWADDR,
    input  wire [`AXI4_AWLEN_WIDTH-1:0]         AWLEN,
    input  wire [`AXI4_AWSIZE_WIDTH-1:0]        AWSIZE,
    input  wire [`AXI4_AWCACHE_WIDTH-1:0]       AWCACHE,
    input  wire [`AXI4_AWQOS_WIDTH-1:0]         AWQOS,
    input  wire [`RNF_AW_COH_W-1:0]             AWCOH,
    input  wire [`AXI4_AWLOCK_WIDTH-1:0]        AWLOCK,
    input  wire [`AXI4_AWUSER_WIDTH-1:0]        AWUSER,
    input  wire                                 AWVALID,
    output wire                                 AWREADY,
    input  wire [`AXI4_WDATA_WIDTH-1:0]         WDATA,
    input  wire [`AXI4_WSTRB_WIDTH-1:0]         WSTRB,
    input  wire [`AXI4_WUSER_WIDTH-1:0]         WUSER,
    input  wire                                 WLAST,
    input  wire                                 WVALID,
    output wire                                 WREADY,
    output wire [`AXI4_BID_WIDTH-1:0]           BID,
    output wire [`AXI4_BRESP_WIDTH-1:0]         BRESP,
    output wire                                 BVALID,
    input  wire                                 BREADY,

    // Cache maintenance
    input  wire                                 CMVALID,
    output wire                                 CMREADY,
    input  wire [`RNF_CM_OP_W-1:0]              CMOP,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] CMADDR,
    output wire                                 CMDONE,
    output wire [1:0]                           CMRESP,

    // Cache
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_lu_addr_o,
    input  wire                                 cache_lu_hit_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_lu_state_i,
    input  wire [`RNF_WAY_W-1:0]                cache_lu_way_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_lu_data_i,
    input  wire [`RNF_META_W-1:0]               cache_lu_meta_i,
    input  wire [`RNF_WAY_W-1:0]                cache_vic_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_vic_state_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_vic_addr_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_vic_data_i,
    input  wire [`RNF_META_W-1:0]               cache_vic_meta_i,
    output wire                                 cache_fill_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_fill_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_fill_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_fill_state_o,
    output wire [`RNF_LINE_BITS-1:0]            cache_fill_data_o,
    output wire [`RNF_META_W-1:0]               cache_fill_meta_o,
    output wire                                 cache_upd_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_upd_addr_o,
    output wire [`RNF_WAY_W-1:0]                cache_upd_way_o,
    output wire [`RNF_CS_WIDTH-1:0]             cache_upd_state_o,

    // The snoop port's own cache writes, watched rather than arbitrated with:
    // Table 4-39 fn a (SS4.7.3 p.4-220) has a snoop change the line under a
    // pending CopyBack, and the WriteData that follows must carry the state it
    // left behind.
    input  wire                                 snp_upd_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_upd_addr_i,
    input  wire [`RNF_WAY_W-1:0]                snp_upd_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]             snp_upd_state_i,

    // Protocol layer, to the link
    output chie_pkg::req_flit_s                 prot_txreqflit_o,
    output wire                                 prot_txreqflitv_o,
    input  wire                                 prot_txreqflit_sent_i,
    output chie_pkg::rsp_flit_s                 prot_txrspflit_o,
    output wire                                 prot_txrspflitv_o,
    input  wire                                 prot_txrspflit_sent_i,
    output chie_pkg::dat_flit_s                 prot_txdatflit_o,
    output wire                                 prot_txdatflitv_o,
    input  wire                                 prot_txdatflit_sent_i,
    input  wire                                 prot_rxdatflitv_i,
    input  chie_pkg::dat_flit_s                 prot_rxdatflit_i,
    input  wire                                 rxdat_arr_v_i,
    input  chie_pkg::dat_flit_s                 rxdat_arr_flit_i,
    input  wire                                 prot_rxrspflitv_i,
    input  chie_pkg::rsp_flit_s                 prot_rxrspflit_i,

    // Table 15-1 (p.15-468): only Coherency Enabled permits a transaction that
    // caches a coherent location, and leaving it requires an empty cache.
    input  wire                                 coh_enabled_i,
    input  wire                                 coh_req_i,
    input  wire                                 cache_any_valid_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cache_flush_addr_i,
    input  wire [`RNF_WAY_W-1:0]                cache_flush_way_i,
    input  wire [`RNF_CS_WIDTH-1:0]             cache_flush_state_i,
    input  wire [`RNF_LINE_BITS-1:0]            cache_flush_data_i,
    input  wire [`RNF_META_W-1:0]               cache_flush_meta_i,
    input  wire                                 link_run_i,

    // SS4.11.1 (p.4-242, MUST): a snoop to a line whose Data response is part-way
    // in waits for the rest. Held until the fill has landed, since before then the
    // cache still shows the line as it was.
    output wire                                 defer_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] defer_addr_o,

    // SS13.10.44 (p.13-436, MUST): one Resp across every packet of the WriteData,
    // so a snoop to the CopyBack's line is not taken from its CompDBIDResp until
    // the way is retired.
    output wire                                 cb_hold_v_o,
    output wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cb_hold_addr_o,

    // The line the snoop port is answering.
    input  wire                                 snp_line_v_i,
    input  wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] snp_line_addr_i,

    output wire                                 txn_active_o
    );

    localparam logic [4:0] S_IDLE    = 5'd0;
    localparam logic [4:0] S_WDATA   = 5'd1;
    localparam logic [4:0] S_CB_REQ  = 5'd2;
    localparam logic [4:0] S_CB_DBID = 5'd3;
    localparam logic [4:0] S_CB_DAT  = 5'd4;
    localparam logic [4:0] S_REQ     = 5'd5;
    localparam logic [4:0] S_DATA    = 5'd6;
    localparam logic [4:0] S_ACK     = 5'd7;
    localparam logic [4:0] S_RESP    = 5'd8;
    localparam logic [4:0] S_BRESP   = 5'd9;
    localparam logic [4:0] S_PCRD    = 5'd10;
    localparam logic [4:0] S_PCRD_RET= 5'd11;
    localparam logic [4:0] S_WU_DAT  = 5'd12;
    localparam logic [4:0] S_CMRSP   = 5'd13;
    localparam logic [4:0] S_CMO     = 5'd14;
    localparam logic [4:0] S_RCPT    = 5'd15;

    // SS2.10.4 (p.2-136): a packet carries Data_Width/8 bytes, and Table 2-15 gives
    // the packet holding line bytes [p*PKT_B +: PKT_B] DataID p*DID_STEP.
    localparam int DW       = CHIE_DATA_WIDTH_PARAM;
    localparam int PKT_B    = DW / 8;
    localparam int NPKT     = `RNF_LINE_BYTES / PKT_B;
    localparam int DID_STEP = PKT_B / 16;
    localparam int PKT_W    = (NPKT == 1) ? 1 : $clog2(NPKT);
    localparam int PSN_PKT  = DW / 64;

    // What the request in S_REQ is waiting for.
    localparam logic [2:0] K_READ    = 3'd0;   // a Data response, the line filled from it
    localparam logic [2:0] K_MRU     = 3'd1;   // Comp, or a Data response if the line was lost
    localparam logic [2:0] K_OWN     = 3'd2;   // Comp granting ownership
    localparam logic [2:0] K_NOTE    = 3'd3;   // Comp and nothing else: Evict and the CMOs
    localparam logic [2:0] K_WU      = 3'd4;   // DBIDResp, WriteData, Comp, and a
                                               // Combined Write's CompCMO

    // Where the finished transaction is answered.
    localparam logic [1:0] CH_NONE   = 2'd0;
    localparam logic [1:0] CH_R      = 2'd1;
    localparam logic [1:0] CH_B      = 2'd2;
    localparam logic [1:0] CH_CM     = 2'd3;

    logic [4:0]                                 st_q;
    logic [`AXI4_ARID_WIDTH-1:0]                id_q;
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       addr_q;
    logic [11:0]                                txnid_q;
    logic [`RNF_LINE_BITS-1:0]                  line_q;
    logic [`RNF_CS_WIDTH-1:0]                   fill_state_q;
    logic [NPKT-1:0]                            got_q;      // Data packets received, by packet
    logic                                       got_rsp_q;
    logic                                       got_rcpt_q;     // an ordered read's ReadReceipt
    logic [CHIE_NID_WIDTH_PARAM-1:0]            ack_tgt_q;
    logic [11:0]                                ack_txnid_q;
    logic                                       ack_tt_q;
    logic                                       fill_v_q;
    logic                                       hit_q;
    logic                                       err_q;
    // SS9.3 (p.9-336, MUST): a Non-data Error leaves the cache as the request
    // found it.
    logic                                       nderr_q;
    // A Data packet of this transaction carried DERR.
    logic                                       data_err_q;
    // What is known of the bytes in line_q: DERR on them, the Poison of each
    // chunk, and which bytes are valid.
    logic                                       line_err_q;
    logic [7:0]                                 line_poison_q;
    logic [`RNF_LINE_BYTES-1:0]                 line_vmask_q;
    // The acquire was issued for a UDP line, whose own bytes survive it.
    logic                                       base_udp_q;
    // The store is applied to the line the transaction completes with.
    logic                                       apply_q;
    logic [7:0]                                 wpoison_q;

    // The Logical Processor of the access, and whether it is exclusive.
    logic [7:0]                                 lpid_q;
    logic                                       excl_q;
    logic                                       excl_pass_q;
    logic                                       exok_q;
    logic                                       core_q;
    logic [`AXI4_MPAM_WIDTH-1:0]                mpam_q;
    // SS10.2 (p.10-357): the QoS the core assigned the access, carried by every
    // message of the transaction that serves it.
    logic [3:0]                                 qos_q;
    // The access is Device or Normal Non-cacheable, served around the cache by
    // a Non-snoopable request: its Device and EWA memory attributes, and the
    // bytes of the line it names -- Size and the offset aligned to it.
    logic                                       nc_q;
    logic                                       dev_q;
    logic                                       ewa_q;
    chie_pkg::size_e                            sz_q;
    logic [`RNF_LINE_OFFSET_W-1:0]              off_q;
    logic [`RNF_LINE_OFFSET_W-1:0]              aw_lo_q, aw_hi_q;

    logic                                       is_wr_q;
    logic [`RNF_LINE_BITS-1:0]                  wbuf_q;
    logic [`RNF_LINE_BYTES-1:0]                 wbe_q;
    logic [1:0]                                 wchunk_q;
    // The 128-bit chunk a read returns. addr_q holds the line, not the access.
    logic [1:0]                                 rchunk_q;
    logic [`RNF_AW_COH_W-1:0]                   aw_coh_q;
    logic [`RNF_WAY_W-1:0]                      way_q;
    chie_pkg::req_opcode_e                      acq_op_q;
    chie_pkg::order_e                           ord_q;          // the Order a ReadOnce* went out with
    logic [2:0]                                 kind_q;
    logic                                       ack_q;     // ExpCompAck
    logic                                       alloc_q;   // the completion installs the line
    logic [1:0]                                 rsp_ch_q;

    // The line a CopyBack writes back or a drop retires: a displaced victim, the
    // target of a maintenance operation, or a line the flush empties. Its data
    // cannot change under us -- the snoop port writes state only -- but its state
    // can, which is what vic_state_q tracks.
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       vic_addr_q;
    logic [`RNF_WAY_W-1:0]                      vic_way_q;
    logic [`RNF_CS_WIDTH-1:0]                   vic_state_q;
    logic [`RNF_LINE_BITS-1:0]                  vic_data_q;
    logic [`RNF_META_W-1:0]                     vic_meta_q;
    chie_pkg::req_opcode_e                      cb_op_q;
    logic                                       cb_then_req_q;  // a request follows the CopyBack
    logic                                       cb_keep_q;      // WriteClean: the line stays, Clean
    logic                                       cb_ls_q;        // WriteEvictOrEvict's LikelyShared
    // SS2.11 (p.2-145): the request that drew a RetryAck, and what it waits for.
    logic                                       retry_q;
    logic [3:0]                                 retry_type_q;
    logic                                       retry_cb_q;
    // P-Credits held, per PCrdType, and the Completer each came from -- SS2.6.6
    // (p.2-112) addresses a PCrdReturn to "the SrcID of the credit that was
    // obtained".
    logic [1:0]                                 pcrd_cnt_q [16];
    logic [CHIE_NID_WIDTH_PARAM-1:0]            pcrd_src_q [16];
    logic [3:0]                                 ret_type_q;
    logic [3:0]                                 surplus_type;
    logic                                       surplus_v;

    // The acquire's own line, tracked the same way while the request is out.
    logic [`RNF_CS_WIDTH-1:0]                   acq_cs_q;
    logic                                       fill_uce_q;
    logic                                       chain_ru_q;
    // The WriteData in flight: its target, the DBID it answers, and which packet.
    logic [CHIE_NID_WIDTH_PARAM-1:0]            wr_tgt_q;
    logic [11:0]                                wr_txnid_q;
    logic                                       wr_tt_q;
    logic [PKT_W-1:0]                           wr_pkt_q;
    logic                                       wr_dbid_q;
    logic                                       wr_sent_q;
    logic                                       cb_done_q;
    logic                                       drop_q;
    // The CompCMO of the request in flight, and where S_CMO goes once it lands.
    logic                                       cmo_got_q;
    logic [4:0]                                 cmo_ret_st_q;

    // SS6.2.1 (p.6-283, MUST): each LP's exclusive monitor on the line of its Load.
    localparam int MON = RNF_EXCL_LP_NUM_PARAM;
    logic                                       mon_v_q    [MON];
    logic [7:0]                                 mon_lp_q   [MON];
    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0]       mon_addr_q [MON];
    logic [`RNF_WAY_W-1:0]                      mon_way_q  [MON];
    logic [$clog2(MON+1)-1:0]                   mon_rr_q;

    function automatic bit is_dirty(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UD) || (cs == `RNF_CS_SD) || (cs == `RNF_CS_UDP);
    endfunction

    function automatic bit is_unique(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UC) || (cs == `RNF_CS_UD) ||
               (cs == `RNF_CS_UCE) || (cs == `RNF_CS_UDP);
    endfunction

    // Table 4-39 (SS4.7.3 p.4-219): WriteCleanFull leaves the line Clean at the
    // sharing its WriteData named.
    function automatic logic [`RNF_CS_WIDTH-1:0] clean_of(logic [`RNF_CS_WIDTH-1:0] cs);
        case (cs)
            `RNF_CS_UD, `RNF_CS_UC: return `RNF_CS_UC;
            `RNF_CS_SD, `RNF_CS_SC: return `RNF_CS_SC;
            default:                return `RNF_CS_I;
        endcase
    endfunction

    // Table 4-33 (SS4.7.1 p.4-211) read grants, and Table 4-38's (p.4-218)
    // dataless ones, share the Comp-response reading of Table 13-35
    // (SS13.10.44 p.13-437).
    function automatic logic [`RNF_CS_WIDTH-1:0] cs_of_resp(chie_pkg::resp_state_e r);
        case (r)
            chie_pkg::RESP_SC:     return `RNF_CS_SC;
            chie_pkg::RESP_UC_UD:  return `RNF_CS_UC;
            chie_pkg::RESP_UC_PD:  return `RNF_CS_UD;
            chie_pkg::RESP_SD_PD:  return `RNF_CS_SD;
            default:               return `RNF_CS_I;
        endcase
    endfunction

    // Table 4-39 (SS4.7.3 p.4-220): a CopyBackWrData names the state the line is
    // in when the data is sent, which a snoop may have moved since the request.
    function automatic chie_pkg::resp_state_e cb_resp_of(logic [`RNF_CS_WIDTH-1:0] cs);
        case (cs)
            `RNF_CS_UD, `RNF_CS_UDP: return chie_pkg::RESP_UC_PD;
            `RNF_CS_SD:  return chie_pkg::RESP_SD_PD;
            `RNF_CS_UC:  return chie_pkg::RESP_UC_UD;
            `RNF_CS_SC:  return chie_pkg::RESP_SC;
            default:     return chie_pkg::RESP_I;
        endcase
    endfunction

    function automatic chie_pkg::req_opcode_e read_op(logic [`RNF_AR_COH_W-1:0] coh);
        case (coh)
            `RNF_AR_CLEAN:          return chie_pkg::REQ_READCLEAN;
            `RNF_AR_PREFER_UNIQUE:  return chie_pkg::REQ_READPREFERUNIQUE;
            `RNF_AR_UNIQUE:         return chie_pkg::REQ_READUNIQUE;
            `RNF_AR_ONCE:           return chie_pkg::REQ_READONCE;
            `RNF_AR_ONCE_CLEAN_INV: return chie_pkg::REQ_READONCECLEANINVALID;
            `RNF_AR_ONCE_MAKE_INV:  return chie_pkg::REQ_READONCEMAKEINVALID;
            default:                return chie_pkg::REQ_READSHARED;
        endcase
    endfunction

    // Table 4-16 (SS4.2.3 p.4-181): a Dirty line goes back Full, a UDP one Ptl.
    function automatic chie_pkg::req_opcode_e back_op(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UDP) ? chie_pkg::REQ_WRITEBACKPTL : chie_pkg::REQ_WRITEBACKFULL;
    endfunction

    // SS6.3 (p.6-286): the Snoopable Exclusive Loads this node issues.
    function automatic bit excl_load_op(chie_pkg::req_opcode_e op);
        return (op == chie_pkg::REQ_READSHARED) || (op == chie_pkg::REQ_READCLEAN) ||
               (op == chie_pkg::REQ_READPREFERUNIQUE);
    endfunction

    // A line whose bytes are not all valid cannot be served, nor kept Clean.
    function automatic bit is_short(logic [`RNF_CS_WIDTH-1:0] cs);
        return (cs == `RNF_CS_UCE) || (cs == `RNF_CS_UDP);
    endfunction

    // The Poison of each chunk after a merge: a chunk wholly overwritten takes the
    // new tag, and one only partly overwritten keeps the old one beside it, which
    // SS9.5 (p.9-347) permits as over-poisoning.
    function automatic logic [7:0] merge_poison(logic [7:0] base, logic [7:0] wpois,
                                                logic [`RNF_LINE_BYTES-1:0] be);
        for (int c = 0; c < 8; c++)
            merge_poison[c] = (&be[c*8 +: 8]) ? wpois[c]
                                             : (base[c] | ((|be[c*8 +: 8]) & wpois[c]));
    endfunction

    // SS2.3.2 (p.2-57, p.2-66): the Combined Writes without Persist, whose CMO leg
    // completes on a CompCMO of its own.
    function automatic bit is_cmb_write(chie_pkg::req_opcode_e op);
        return (op == chie_pkg::REQ_WRITENOSNPFULLCLEANSH)  ||
               (op == chie_pkg::REQ_WRITENOSNPFULLCLEANINV) ||
               (op == chie_pkg::REQ_WRITENOSNPPTLCLEANSH)   ||
               (op == chie_pkg::REQ_WRITENOSNPPTLCLEANINV)  ||
               (op == chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH) ||
               (op == chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH)  ||
               (op == chie_pkg::REQ_WRITEBACKFULLCLEANSH)   ||
               (op == chie_pkg::REQ_WRITEBACKFULLCLEANINV)  ||
               (op == chie_pkg::REQ_WRITECLEANFULLCLEANSH);
    endfunction

    function automatic bit is_write_zero(chie_pkg::req_opcode_e op);
        return (op == chie_pkg::REQ_WRITEUNIQUEZERO) || (op == chie_pkg::REQ_WRITENOSNPZERO);
    endfunction

    function automatic bit is_read_once(chie_pkg::req_opcode_e op);
        return (op == chie_pkg::REQ_READONCE) ||
               (op == chie_pkg::REQ_READONCECLEANINVALID) ||
               (op == chie_pkg::REQ_READONCEMAKEINVALID);
    endfunction

    function automatic logic [`RNF_LINE_BITS-1:0]
        merge_line(logic [`RNF_LINE_BITS-1:0]  base,
                   logic [`RNF_LINE_BITS-1:0]  wdat,
                   logic [`RNF_LINE_BYTES-1:0] be);
        for (int b = 0; b < `RNF_LINE_BYTES; b++)
            merge_line[b*8 +: 8] = be[b] ? wdat[b*8 +: 8] : base[b*8 +: 8];
    endfunction

    function automatic bit same_line(logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] a,
                                     logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] b);
        return a[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W] ==
               b[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W];
    endfunction

    // SS2.10.4 (p.2-136): the packets of a Size-byte transfer at `off` are those
    // holding the Size-aligned bytes around it; a line takes all of them.
    function automatic logic [NPKT-1:0] pkt_mask(logic [`RNF_LINE_OFFSET_W-1:0] off,
                                                 chie_pkg::size_e              sz);
        int unsigned nbytes = 32'd1 << sz;
        int unsigned lo     = int'(off) & ~(nbytes - 1);
        pkt_mask = '0;
        for (int p = 0; p < NPKT; p++)
            if (((p + 1) * PKT_B > lo) && (p * PKT_B < lo + nbytes)) pkt_mask[p] = 1'b1;
    endfunction

    function automatic logic [PKT_W-1:0] pkt_of_dataid(logic [1:0] dataid);
        return PKT_W'(dataid / 2'(DID_STEP));
    endfunction

    function automatic logic [PKT_W-1:0] first_pkt(logic [NPKT-1:0] m);
        first_pkt = '0;
        for (int p = NPKT - 1; p >= 0; p--) if (m[p]) first_pkt = PKT_W'(p);
    endfunction

    function automatic logic [PKT_W-1:0] last_pkt(logic [NPKT-1:0] m);
        last_pkt = '0;
        for (int p = 0; p < NPKT; p++) if (m[p]) last_pkt = PKT_W'(p);
    endfunction

    // Table 2-14 (SS2.10.1 p.2-134): the smallest Size whose aligned window holds
    // bytes lo..hi of the line.
    function automatic chie_pkg::size_e size_spanning(logic [`RNF_LINE_OFFSET_W-1:0] lo,
                                                      logic [`RNF_LINE_OFFSET_W-1:0] hi);
        size_spanning = chie_pkg::SIZE_64B;
        for (int k = 6; k >= 0; k--)
            if ((lo >> k) == (hi >> k)) size_spanning = chie_pkg::size_e'(k);
    endfunction

    // AMBA AXI4 (IHI 0022) Table A4-5: AxCACHE[1] low is Device, and high with
    // AxCACHE[3:2] low Normal Non-cacheable. Table 2-11 (SS2.9.4 p.2-129) gives
    // neither a Snoopable row, so neither is cached.
    function automatic bit axcache_nc(logic [3:0] cache);
        return !cache[1] || (cache[3:2] == 2'b00);
    endfunction

    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] ar_line =
        {ARADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] aw_line =
        {AWADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};
    wire chie_pkg::req_opcode_e ar_op = read_op(ARCOH);
    // SS4.2.1 (p.4-163): the ReadOnce family is non-allocating, so its data is not
    // cached and nothing is displaced for it.
    wire ar_alloc = !is_read_once(ar_op);
    // Table 4-1 (p.4-165): a ReadOnce* may carry Request Order and no other, and no
    // other read may be ordered at all.
    wire chie_pkg::order_e ar_ord = (is_read_once(ar_op) && ARORD[0]) ? chie_pkg::ORDER_REQ_WR_OBS
                                                                      : chie_pkg::ORDER_NONE;
    wire ar_nc = axcache_nc(ARCACHE);
    wire aw_nc = axcache_nc(AWCACHE);
    // The bytes of the line an AXI write burst addresses: one beat of 2^AWSIZE
    // bytes, or AWLEN+1 beats of the 16-byte lanes this port steps through.
    logic [`RNF_LINE_OFFSET_W-1:0] aw_lo, aw_hi;
    always_comb begin
        automatic int unsigned nb = 32'd1 << ((AWSIZE > `AXI4_AWSIZE_WIDTH'(4)) ? 4 : int'(AWSIZE));
        if (AWLEN == '0) begin
            aw_lo = `RNF_LINE_OFFSET_W'(int'(AWADDR[5:0]) & ~(nb - 1));
            aw_hi = `RNF_LINE_OFFSET_W'(int'(aw_lo) + nb - 1);
        end
        else begin
            aw_lo = {AWADDR[5:4], 4'h0};
            aw_hi = `RNF_LINE_OFFSET_W'((int'(AWADDR[5:4]) + int'(AWLEN) >= 3) ? 63
                                        : (int'(AWADDR[5:4]) + int'(AWLEN)) * 16 + 15);
        end
    end
    // A core read returns one AXI beat, so a Non-snoopable one asks for that beat
    // alone: SS2.9.3 (p.2-127, MUST) has a Device read "not read more data than
    // requested".
    wire chie_pkg::size_e ar_nc_sz =
        (ARSIZE > `AXI4_ARSIZE_WIDTH'(4)) ? chie_pkg::SIZE_16B : chie_pkg::size_e'(ARSIZE);
    // SS6.3 (p.6-286): LPID is eight bits, so only an AxID that fits one names an LP.
    wire ar_excl  = ARLOCK[0] && (ARID < `AXI4_ARID_WIDTH'(256));
    wire aw_excl  = AWLOCK[0] && (AWID < `AXI4_AWID_WIDTH'(256));
    wire [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] cm_line =
        {CMADDR[CHIE_REQ_ADDR_WIDTH_PARAM-1:`RNF_LINE_OFFSET_W], {`RNF_LINE_OFFSET_W{1'b0}}};

    // A read is taken ahead of a write, and a write ahead of maintenance, so the
    // lookup this cycle is the one the accepted channel needs.
    assign cache_lu_addr_o = (st_q != S_IDLE) ? addr_q  :
                             ARVALID          ? ar_line :
                             AWVALID          ? aw_line : cm_line;

    // SS15.2.1 (p.15-467, MUST) forbids issuing a caching transaction before
    // SYSCOACK, so no channel is accepted before Coherency Enabled.
    // A surplus P-Credit goes back before new work is taken: offering READY in
    // the same cycle the FSM leaves to return it would complete an AXI handshake
    // for a request nothing then serves.
    wire accept_ok = (st_q == S_IDLE) && !surplus_v && link_run_i && coh_enabled_i && coh_req_i;
    assign ARREADY = accept_ok;
    assign AWREADY = accept_ok && !ARVALID;
    assign CMREADY = accept_ok && !ARVALID && !AWVALID;
    assign WREADY  = (st_q == S_WDATA);

    // The looked-up way as the snoop port leaves it, for the same reason vic_sel_state
    // exists on the victim path: cache_lu_state_i is read combinationally, so a snoop
    // writing that way on the very edge a decision is taken is still ahead of it.
    // SS4.11.1 (p.4-242, MUST): the cache state must transition as the Snoop request
    // requires, and a decision taken from the pre-snoop state undoes that transition.
    // The hit qualifier goes stale with the state -- a line the snoop invalidated is a
    // miss, not a hit holding Invalid -- so both are bypassed together.
    wire lu_snp_sel = snp_upd_v_i && (snp_upd_way_i == cache_lu_way_i) &&
                      same_line(snp_upd_addr_i, cache_lu_addr_o);
    // Table 15-1 (p.15-468, MUST) still has snoops answered while coh_req_i is low, so
    // the flush port needs the same bypass as the lookup and victim ones.
    wire flush_snp_sel = snp_upd_v_i && (snp_upd_way_i == cache_flush_way_i) &&
                         same_line(snp_upd_addr_i, cache_flush_addr_i);
    wire [`RNF_CS_WIDTH-1:0] flush_sel_state = flush_snp_sel ? snp_upd_state_i : cache_flush_state_i;
    wire lu_hit_now = lu_snp_sel ? (snp_upd_state_i != `RNF_CS_I) : cache_lu_hit_i;
    wire [`RNF_CS_WIDTH-1:0] lu_state = !lu_hit_now ? `RNF_CS_I :
                                        lu_snp_sel  ? snp_upd_state_i : cache_lu_state_i;

    // Whether an LP's monitor is still set on a line.
    function automatic bit mon_set(logic [7:0] lp, logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] line);
        mon_set = 1'b0;
        for (int i = 0; i < MON; i++)
            if (mon_v_q[i] && (mon_lp_q[i] == lp) && same_line(mon_addr_q[i], line))
                mon_set = 1'b1;
    endfunction

    // The write including the beat being accepted this cycle: wbe_q and wbuf_q do
    // not carry it until the next edge, and the whole-line question is asked on
    // WLAST, which is that same cycle.
    logic [`RNF_LINE_BYTES-1:0] wbe_now;
    logic [`RNF_LINE_BITS-1:0]  wbuf_now;
    always_comb begin
        wbe_now  = wbe_q;
        wbuf_now = wbuf_q;
        case (wchunk_q)
            2'd0:    begin wbe_now[15:0]  = WSTRB; wbuf_now[127:0]   = WDATA; end
            2'd1:    begin wbe_now[31:16] = WSTRB; wbuf_now[255:128] = WDATA; end
            2'd2:    begin wbe_now[47:32] = WSTRB; wbuf_now[383:256] = WDATA; end
            default: begin wbe_now[63:48] = WSTRB; wbuf_now[511:384] = WDATA; end
        endcase
    end
    wire wr_full = &wbe_now;
    // SS9.5 (p.9-347): WUSER carries one Poison bit per 64 bits of WDATA.
    logic [7:0] wpoison_now;
    always_comb begin
        wpoison_now = wpoison_q;
        case (wchunk_q)
            2'd0:    wpoison_now[1:0] = WUSER[`AXI4_USER_POISON_RANGE];
            2'd1:    wpoison_now[3:2] = WUSER[`AXI4_USER_POISON_RANGE];
            2'd2:    wpoison_now[5:4] = WUSER[`AXI4_USER_POISON_RANGE];
            default: wpoison_now[7:6] = WUSER[`AXI4_USER_POISON_RANGE];
        endcase
    end
    wire wr_zero = wr_full && (wbuf_now == '0);

    // The displaced way as the snoop port leaves it: cache_vic_state_i is read
    // combinationally, so a snoop writing that way on the very edge the victim is
    // latched is still ahead of it. SS4.11.1 (p.4-242, MUST): the CopyBack carries
    // the state after the snoop is processed, and a line the snoop took is Invalid.
    wire vic_snp_sel = snp_upd_v_i && (snp_upd_way_i == cache_vic_way_i) &&
                       same_line(snp_upd_addr_i, cache_vic_addr_i);
    wire [`RNF_CS_WIDTH-1:0] vic_sel_state = vic_snp_sel ? snp_upd_state_i : cache_vic_state_i;

    // Whether the displaced way owes a write-back. Evaluated at the point the
    // transaction commits to filling, so cache_vic_* still describe the way the
    // fill will take.
    wire need_cb = is_dirty(vic_sel_state);

    // Table 2-8 (SS2.8.3 p.2-117) sets ExpCompAck per request: required for the
    // allocating reads and the ownership requests, and WriteEvictOrEvict; not
    // permitted for WriteBack, WriteClean, WriteEvictFull, Evict or a CMO; this
    // node leaves the optional ReadOnce* and WriteUnique cases without.
    always_comb begin
        prot_txreqflit_o              = '0;
        prot_txreqflit_o.srcid        = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txreqflit_o.tgtid        = CHIE_NID_WIDTH_PARAM'(HNF_NID_PARAM);
        prot_txreqflit_o.size         = chie_pkg::SIZE_64B;
        prot_txreqflit_o.allowretry   = !retry_q;
        prot_txreqflit_o.pcrdtype     = retry_q ? retry_type_q : 4'd0;
        prot_txreqflit_o.order        = chie_pkg::ORDER_NONE;
        prot_txreqflit_o.memattr.cacheable    = 1'b1;
        prot_txreqflit_o.memattr.device       = 1'b0;
        prot_txreqflit_o.memattr.early_wr_ack = 1'b1;
        prot_txreqflit_o.snpattr.snpattr      = 1'b1;
        prot_txreqflit_o.txnid        = txnid_q;
        prot_txreqflit_o.qos          = qos_q;
        // SS2.7 (p.2-113): the LP the access was made by; the node's own requests (a
        // displaced line's CopyBack, the Table 15-1 flush, maintenance) use LP 0.
        prot_txreqflit_o.lpid         = core_q ? lpid_q : 8'd0;
`ifdef CHIE_MPAM_PRESENT
        // SS11.3 (p.11-365, MUST): the core's label from AxUSER, and Table 11-5's
        // (p.11-366) defaults on a request the core did not make.
        prot_txreqflit_o.mpam         = core_q ? chie_pkg::mpam_s'(mpam_q)
                                               : chie_pkg::mpam_default(prot_txreqflit_o.ns);
`endif
        if (st_q == S_PCRD_RET) begin
            // SS2.6.6 (p.2-112): addressed to the credit's source, TxnID zero, and
            // the PCrdType it was granted under. Table A-2 (p.A-483) leaves every
            // other field inapplicable, so zero.
            prot_txreqflit_o          = '0;
            prot_txreqflit_o.srcid    = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
            prot_txreqflit_o.tgtid    = pcrd_src_q[ret_type_q];
            prot_txreqflit_o.opcode   = chie_pkg::REQ_PCRDRETURN;
            prot_txreqflit_o.pcrdtype = ret_type_q;
`ifdef CHIE_MPAM_PRESENT
            prot_txreqflit_o.mpam     = chie_pkg::mpam_default(1'b0);
`endif
        end
        else if (st_q == S_CB_REQ) begin
            prot_txreqflit_o.opcode       = cb_op_q;
            prot_txreqflit_o.addr         = vic_addr_q;
            prot_txreqflit_o.lpid         = 8'd0;
`ifdef CHIE_MPAM_PRESENT
            prot_txreqflit_o.mpam         = chie_pkg::mpam_default(prot_txreqflit_o.ns);
`endif
            prot_txreqflit_o.memattr.allocate = 1'b1;
            // SS2.8.3 (p.2-116, MUST): WriteEvictOrEvict sets ExpCompAck; SS4.2.3
            // (p.4-177) encodes the line's initial state in LikelyShared.
            prot_txreqflit_o.expcompack   = (cb_op_q == chie_pkg::REQ_WRITEEVICTOREVICT);
            prot_txreqflit_o.likelyshared = (cb_op_q == chie_pkg::REQ_WRITEEVICTOREVICT) && cb_ls_q;
        end
        else begin
            prot_txreqflit_o.opcode       = acq_op_q;
            prot_txreqflit_o.addr         = addr_q | CHIE_REQ_ADDR_WIDTH_PARAM'(off_q);
            prot_txreqflit_o.size         = sz_q;
            prot_txreqflit_o.expcompack   = ack_q;
            // SS2.11 (p.2-145): a resend keeps the first attempt's Order.
            prot_txreqflit_o.order        = ord_q;
            // SS6.3 (p.6-286): the Excl bit on this node's Exclusive Loads and Stores,
            // Snoopable and Non-snoopable (Tables 4-1/4-13 give ReadNoSnp and
            // WriteNoSnp Excl 0,1).
            prot_txreqflit_o.excl.excl    = excl_q && core_q &&
                                            (excl_load_op(acq_op_q) || nc_q ||
                                             (acq_op_q == chie_pkg::REQ_CLEANUNIQUE) ||
                                             (acq_op_q == chie_pkg::REQ_MAKEREADUNIQUE));
            // Table 4-1 (SS4.2.1 p.4-165) and Table 4-7 (SS4.2.2 p.4-172):
            // ReadOnceMakeInvalid and Evict are MemAttr 0101 only.
            prot_txreqflit_o.memattr.allocate = (acq_op_q != chie_pkg::REQ_EVICT) &&
                                                (acq_op_q != chie_pkg::REQ_READONCEMAKEINVALID);
            // Tables 4-1 (p.4-165) and 4-13 (SS4.2.3 p.4-178): a Device access is
            // MemAttr 001x and a Normal Non-cacheable one 000x, SnpAttr 0, with EWA
            // from AxCACHE[0] (Table 2-11 SS2.9.4 p.2-129).
            if (nc_q) begin
                prot_txreqflit_o.memattr.allocate     = 1'b0;
                prot_txreqflit_o.memattr.cacheable    = 1'b0;
                prot_txreqflit_o.memattr.device       = dev_q;
                prot_txreqflit_o.memattr.early_wr_ack = ewa_q;
                prot_txreqflit_o.snpattr.snpattr      = 1'b0;
            end
        end
    end

    // SS5.6.1 (p.5-274, MUST): "The response to a Snoop request that hazards with an
    // outstanding Evict must be SnpResp_I". A snoop taken before the drop reads the
    // line as it was, so its Evict waits until that response has gone.
    wire evict_snp_hazard = (acq_op_q == chie_pkg::REQ_EVICT) && snp_line_v_i &&
                            same_line(snp_line_addr_i, addr_q);

    assign prot_txreqflitv_o = ((st_q == S_REQ) && !evict_snp_hazard) ||
                               (st_q == S_CB_REQ) || (st_q == S_PCRD_RET);

    // SS2.6.1 (p.2-100, MUST): a CompAck takes its TgtID from the completion's
    // HomeNID and its TxnID from its DBID, not from this node's own request.
    always_comb begin
        prot_txrspflit_o        = '0;
        prot_txrspflit_o.tgtid  = ack_tgt_q;
        prot_txrspflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txrspflit_o.txnid  = ack_txnid_q;
        prot_txrspflit_o.opcode = chie_pkg::RSP_COMPACK;
        prot_txrspflit_o.qos    = qos_q;
        // SS11.5.1 (p.11-368, MUST): TraceTag reflected from the completion it acknowledges.
        prot_txrspflit_o.tracetag = ack_tt_q;
    end

    assign prot_txrspflitv_o = (st_q == S_ACK);

    // SS2.10.3 (p.2-135, MUST): "A Requester must deassert all BE values in
    // CopyBackWrData_I", and a deasserted byte enable "must set the associated
    // data byte value to zero". Every other CopyBackWrData of a Full CopyBack
    // asserts all 64 (SS4.2.3 p.4-177).
    wire cb_invalid = (cb_resp_of(vic_state_q) == chie_pkg::RESP_I);
    wire [`RNF_LINE_BITS-1:0] wu_line = merge_line(`RNF_LINE_BITS'(0), wbuf_q, wbe_q);
    // SS2.10.3 (p.2-135): a WriteBackPtl asserts the enables of the valid bytes, and
    // any deasserted enable zeroes its byte.
    wire [`RNF_LINE_BYTES-1:0] cb_be   = cb_invalid ? '0 :
                                         (cb_op_q == chie_pkg::REQ_WRITEBACKPTL) ? vic_meta_q[`RNF_META_VMASK]
                                                                                 : '1;
    wire [`RNF_LINE_BITS-1:0]  cb_line = merge_line(`RNF_LINE_BITS'(0), vic_data_q, cb_be);
    // SS9.5 (p.9-347, MUST): the Poison travels with the bytes it tags.
    logic [7:0] cb_poison, wu_poison;
    always_comb begin
        for (int c = 0; c < 8; c++) begin
            cb_poison[c] = vic_meta_q[64 + c] && (|cb_be[c*8 +: 8]);
            wu_poison[c] = wpoison_q[c]       && (|wbe_q[c*8 +: 8]);
        end
    end

    // The WriteData packets, the Non-CopyBack write's and the CopyBack's, one per
    // Table 2-15 (SS2.10.4 p.2-136) DataID.
    logic [DW-1:0]      wu_pkt_data [NPKT];
    logic [PKT_B-1:0]   wu_pkt_be   [NPKT];
    logic [PSN_PKT-1:0] wu_pkt_psn  [NPKT];
    logic [DW-1:0]      cb_pkt_data [NPKT];
    logic [PKT_B-1:0]   cb_pkt_be   [NPKT];
    logic [PSN_PKT-1:0] cb_pkt_psn  [NPKT];
    always_comb begin
        for (int p = 0; p < NPKT; p++) begin
            wu_pkt_data[p] = wu_line[p*DW +: DW];
            wu_pkt_be[p]   = wbe_q[p*PKT_B +: PKT_B];
            wu_pkt_psn[p]  = wu_poison[p*PSN_PKT +: PSN_PKT];
            cb_pkt_data[p] = cb_line[p*DW +: DW];
            cb_pkt_be[p]   = cb_be[p*PKT_B +: PKT_B];
            cb_pkt_psn[p]  = cb_poison[p*PSN_PKT +: PSN_PKT];
        end
    end

    always_comb begin
        prot_txdatflit_o        = '0;
        prot_txdatflit_o.tgtid  = wr_tgt_q;
        prot_txdatflit_o.srcid  = CHIE_NID_WIDTH_PARAM'(RNF_NID_PARAM);
        prot_txdatflit_o.txnid  = wr_txnid_q;
        prot_txdatflit_o.qos    = qos_q;
        // SS11.5.1 (p.11-368, MUST): TraceTag reflected from the DBID response that
        // drew the data.
        prot_txdatflit_o.tracetag = wr_tt_q;
        prot_txdatflit_o.dataid = 2'(int'(wr_pkt_q) * DID_STEP);
        if (st_q == S_WU_DAT) begin
            prot_txdatflit_o.opcode = chie_pkg::DAT_NONCOPYBACKWRDATA;
            // SS2.10.6 (p.2-139, MUST): CCID is Addr[5:4] of the request.
            prot_txdatflit_o.ccid   = off_q[5:4];
            prot_txdatflit_o.be     = wu_pkt_be[wr_pkt_q];
            prot_txdatflit_o.data   = wu_pkt_data[wr_pkt_q];
            prot_txdatflit_o.poison = wu_pkt_psn[wr_pkt_q];
        end
        else begin
            prot_txdatflit_o.opcode = chie_pkg::DAT_COPYBACKWRDATA;
            prot_txdatflit_o.ccid   = vic_addr_q[5:4];
            prot_txdatflit_o.resp   = cb_resp_of(vic_state_q);
            prot_txdatflit_o.be     = cb_pkt_be[wr_pkt_q];
            // SS9.4.3 (p.9-340, MUST): write data known to be corrupt carries an
            // error indication, and Table 9-7 makes DERR the one WriteData may carry.
            prot_txdatflit_o.resperr = (vic_meta_q[`RNF_META_DERR] && !cb_invalid)
                                       ? chie_pkg::RESP_ERR_DATA : chie_pkg::RESP_ERR_NORM_OK;
            prot_txdatflit_o.data   = cb_pkt_data[wr_pkt_q];
            prot_txdatflit_o.poison = cb_pkt_psn[wr_pkt_q];
        end
        // SS9.6 (p.9-348): odd byte parity over the data sent.
        prot_txdatflit_o.datacheck = chie_pkg::datacheck_of(prot_txdatflit_o.data);
    end

    // The WriteData packets of the transaction in flight: the Size-aligned window a
    // Non-CopyBack write names, and every packet of a CopyBack's line.
    wire [NPKT-1:0]  wu_mask     = pkt_mask(off_q, sz_q);
    wire [PKT_W-1:0] wu_first    = first_pkt(wu_mask);
    wire             wr_last_pkt = (st_q == S_WU_DAT) ? (wr_pkt_q == last_pkt(wu_mask))
                                                      : (wr_pkt_q == PKT_W'(NPKT - 1));

    assign prot_txdatflitv_o = (st_q == S_CB_DAT) || (st_q == S_WU_DAT);

    wire rx_rsp_txn  = prot_rxrspflitv_i && (prot_rxrspflit_i.txnid == txnid_q);
    wire rx_comp     = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMP);
    wire rx_sep      = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_RESPSEPDATA);
    wire rx_rcpt     = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_READRECEIPT);
    // SS2.3.2 (p.2-52): write data follows "DBIDResp, DBIDRespOrd, or CompDBIDResp".
    wire rx_dbid     = rx_rsp_txn && ((prot_rxrspflit_i.opcode == chie_pkg::RSP_DBIDRESP) ||
                                      (prot_rxrspflit_i.opcode == chie_pkg::RSP_DBIDRESPORD));
    // SS2.3.2 (p.2-51) / Table 4-39 (p.4-219): a CopyBack completes with the
    // combined CompDBIDResp, never a separate DBIDResp and Comp.
    wire rx_compdbid = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMPDBIDRESP);
    wire rx_retryack = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_RETRYACK);
    function automatic bit is_read_data(chie_pkg::dat_flit_s f, logic [11:0] txnid);
        return (f.txnid == txnid) &&
               ((f.opcode == chie_pkg::DAT_COMPDATA) || (f.opcode == chie_pkg::DAT_DATASEPRESP));
    endfunction

    wire rx_compcmo      = rx_rsp_txn && (prot_rxrspflit_i.opcode == chie_pkg::RSP_COMPCMO);
    wire rx_dat_mine     = prot_rxdatflitv_i && is_read_data(prot_rxdatflit_i, txnid_q);
    wire rx_dat_arriving = rxdat_arr_v_i && is_read_data(rxdat_arr_flit_i, txnid_q);
    wire rx_dat_comb = rx_dat_mine &&
                       (prot_rxdatflit_i.opcode == chie_pkg::DAT_COMPDATA);

    // A PCrdGrant names no transaction, so it is taken whatever this node is doing.
    wire rx_pcrdgrant = prot_rxrspflitv_i &&
                        (prot_rxrspflit_i.opcode == chie_pkg::RSP_PCRDGRANT);

    // SS2.11 (p.2-145): "The transaction must only be retried by the Requester when
    // a PCrdGrant is received with the correct PCrdType" -- one already banked, or
    // one landing this cycle.
    wire pcrd_ready = (pcrd_cnt_q[retry_type_q] != 2'd0) ||
                      (rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == retry_type_q));
    wire pcrd_use   = (st_q == S_PCRD) && pcrd_ready;

    // Idle, nothing outstanding can still draw a RetryAck, so a held credit is one
    // no request needs.
    always_comb begin
        surplus_v    = 1'b0;
        surplus_type = 4'd0;
        for (int t = 0; t < 16; t++) begin
            if (!surplus_v && (pcrd_cnt_q[t] != 2'd0)) begin
                surplus_v    = 1'b1;
                surplus_type = 4'(t);
            end
        end
    end
    wire pcrd_ret_sent = (st_q == S_PCRD_RET) && prot_txreqflit_sent_i;

    // Table 15-1 (p.15-468): no coherent data in Disconnect, so a Requester that has
    // decided to leave empties its cache first. Held while the previous invalidate
    // has yet to land: the scan would still see that line and write it back twice.
    wire flush_v = !coh_req_i && cache_any_valid_i && !cb_done_q && !drop_q;

    // SS9.3 (p.9-336): NormalOkay and ExclusiveOkay are both success; the other
    // two are the endpoint reporting an error.
    function automatic bit is_err(chie_pkg::resp_err_e e);
        return (e == chie_pkg::RESP_ERR_DATA) || (e == chie_pkg::RESP_ERR_NON_DATA);
    endfunction

    wire rx_err = (rx_rsp_txn && is_err(prot_rxrspflit_i.resperr)) ||
                  (rx_dat_mine && is_err(prot_rxdatflit_i.resperr));
    wire rx_nderr = (rx_rsp_txn && (prot_rxrspflit_i.resperr == chie_pkg::RESP_ERR_NON_DATA)) ||
                    (rx_dat_mine && (prot_rxdatflit_i.resperr == chie_pkg::RESP_ERR_NON_DATA));
    wire nderr_now = nderr_q || rx_nderr;
    // SS9.4.1 (p.9-337): a Data Error on read data marks those bytes corrupt. On a
    // Dataless Comp (Table 9-4 p.9-339) it names another component's data, so the
    // line this node holds is untouched.
    wire rx_derr_dat = rx_dat_mine && (prot_rxdatflit_i.resperr == chie_pkg::RESP_ERR_DATA);
    wire data_err_now = data_err_q || rx_derr_dat;

    // The line the transaction installs: the store merged over whatever the
    // acquire brought back, or over the copy already resident.
    wire [`RNF_LINE_BITS-1:0] fill_line = (is_wr_q && apply_q) ? merge_line(line_q, wbuf_q, wbe_q)
                                                               : line_q;

    // The acquire's line as it stands this cycle, including a snoop writing it on
    // the very edge its completion arrives -- acq_cs_q alone would miss that one.
    wire acq_snp_now = snp_upd_v_i && same_line(snp_upd_addr_i, addr_q);
    wire [`RNF_CS_WIDTH-1:0] acq_cs_now = acq_snp_now ? snp_upd_state_i : acq_cs_q;
    wire                     acq_lost   = (acq_cs_now == `RNF_CS_I);

    wire vic_snp_now = snp_upd_v_i && (snp_upd_way_i == vic_way_q) &&
                       same_line(snp_upd_addr_i, vic_addr_q);
    wire [`RNF_CS_WIDTH-1:0] vic_state_now = vic_snp_now ? snp_upd_state_i : vic_state_q;

    // Table 4-34 (SS4.7.1 p.4-213): MakeReadUnique's data is the Requester's to
    // use only once it has lost its own copy; p.4-215 has one still held "use its
    // own copy of the cache line, rather than the copy returned".
    wire take_data = (kind_q != K_MRU) || acq_lost;

    // SS2.10.4 (p.2-136): the read is whole once every packet its Size names is in.
    wire [PKT_W-1:0] rx_pkt  = pkt_of_dataid(prot_rxdatflit_i.dataid);
    wire [NPKT-1:0]  got_now = got_q | ((rx_dat_mine ? NPKT'(1) : NPKT'(0)) << rx_pkt);
    wire data_done  = (&(got_now | ~pkt_mask(off_q, sz_q))) && (got_rsp_q || rx_sep || rx_dat_comb);
    // SS2.8.5 (p.2-119): an ordered read is released by its ReadReceipt, or by a
    // RespSepData sent in its place, and stays outstanding until then (SS2.11 p.2-146).
    wire rcpt_owed  = (ord_q != chie_pkg::ORDER_NONE) &&
                      !(got_rcpt_q || rx_rcpt || got_rsp_q || rx_sep);

    wire wu_dbid_now = wr_dbid_q || rx_dbid || rx_compdbid;
    wire wu_comp_now = got_rsp_q || rx_comp || rx_compdbid;

    // SS2.11 (p.2-146): a transaction is outstanding until every response it is owed
    // has arrived, CompCMO among them, and SS2.3.2 (p.2-58, p.2-66) orders the CompCMO
    // against none of the others -- so it is taken in whichever state it lands in.
    wire cmo_got_now = cmo_got_q || rx_compcmo;
    wire wu_cmo_now  = !is_cmb_write(acq_op_q) || cmo_got_now;
    wire cb_cmo_now  = !is_cmb_write(cb_op_q)  || cmo_got_now;

    function automatic bit same_set(logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] a,
                                    logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] b);
        return a[`RNF_LINE_OFFSET_W +: `RNF_SET_W] == b[`RNF_LINE_OFFSET_W +: `RNF_SET_W];
    endfunction

    function automatic bit mon_has_lp(logic [7:0] lp);
        mon_has_lp = 1'b0;
        for (int i = 0; i < MON; i++)
            if (mon_v_q[i] && (mon_lp_q[i] == lp)) mon_has_lp = 1'b1;
    endfunction

    function automatic bit mon_full();
        mon_full = 1'b1;
        for (int i = 0; i < MON; i++)
            if (!mon_v_q[i]) mon_full = 1'b0;
    endfunction

    // The LP's own entry, else a free one, else the round-robin victim.
    function automatic int set_slot(logic [7:0] lp);
        set_slot = -1;
        for (int i = MON-1; i >= 0; i--)
            if (mon_v_q[i] && (mon_lp_q[i] == lp)) set_slot = i;
        if (set_slot < 0)
            for (int i = MON-1; i >= 0; i--)
                if (!mon_v_q[i]) set_slot = i;
        if (set_slot < 0) set_slot = int'(mon_rr_q);
    endfunction

    wire rx_exok  = (rx_rsp_txn  && (prot_rxrspflit_i.resperr == chie_pkg::RESP_ERR_EX_OK)) ||
                    (rx_dat_mine && (prot_rxdatflit_i.resperr == chie_pkg::RESP_ERR_EX_OK));
    wire exok_now = exok_q || rx_exok;
    // A procedural read, so the monitor table itself is in its sensitivity.
    logic mon_ok;
    always_comb mon_ok = mon_set(lpid_q, addr_q);

    // The bytes the line still holds valid, which returned data does not overwrite.
    wire [`RNF_LINE_BYTES-1:0] merge_vm = acq_lost ? '0 : line_vmask_q;

    // SS6.3.1 (p.6-288, MUST): a MakeReadUnique(Excl) response in Shared state fails,
    // and one in Unique state passes only if the LP monitor is still set. Table 4-37
    // (SS4.7.1 p.4-217) keeps a held line as it was on a failure, and fills a lost
    // one Shared from the data returned.
    wire [`RNF_CS_WIDTH-1:0] mru_rsp_cs = rx_dat_mine ? cs_of_resp(prot_rxdatflit_i.resp) :
                                          rx_comp     ? cs_of_resp(prot_rxrspflit_i.resp) :
                                                        fill_state_q;
    wire mru_shared = (mru_rsp_cs == `RNF_CS_SC);
    wire mru_pass   = (kind_q != K_MRU) || (!mru_shared && !acq_lost && mon_ok);
    wire mru_fill   = !excl_q || (kind_q != K_MRU) || acq_lost || mru_pass;
    // SPEC-AMBIGUITY: SS6.3.3 (p.6-291) -- Table 4-38 (p.4-218) lists only Comp_UC for
    // CleanUnique; a failed CleanUnique(Excl) "has not propagated", so the Home has
    // invalidated no other copy and the line is left as the request found it.
    wire own_pass   = exok_now && !acq_lost && mon_ok;

    logic [4:0] fin_st;
    always_comb begin
        case (rsp_ch_q)
            CH_R:    fin_st = S_RESP;
            CH_B:    fin_st = S_BRESP;
            CH_CM:   fin_st = S_CMRSP;
            default: fin_st = S_IDLE;
        endcase
    end

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i == 1'b1) begin
            st_q          <= S_IDLE;
            id_q          <= '0;
            addr_q        <= '0;
            txnid_q       <= '0;
            line_q        <= '0;
            fill_state_q  <= `RNF_CS_I;
            got_q         <= '0;
            got_rsp_q     <= 1'b0;
            ack_tgt_q     <= '0;
            ack_txnid_q   <= '0;
            ack_tt_q      <= 1'b0;
            fill_v_q      <= 1'b0;
            hit_q         <= 1'b0;
            err_q         <= 1'b0;
            nderr_q       <= 1'b0;
            data_err_q    <= 1'b0;
            line_err_q    <= 1'b0;
            line_poison_q <= 8'h00;
            line_vmask_q  <= '0;
            base_udp_q    <= 1'b0;
            apply_q       <= 1'b1;
            wpoison_q     <= 8'h00;
            lpid_q        <= 8'd0;
            excl_q        <= 1'b0;
            excl_pass_q   <= 1'b0;
            exok_q        <= 1'b0;
            core_q        <= 1'b0;
            mpam_q        <= '0;
            qos_q         <= 4'd0;
            nc_q          <= 1'b0;
            dev_q         <= 1'b0;
            ewa_q         <= 1'b0;
            sz_q          <= chie_pkg::SIZE_64B;
            off_q         <= '0;
            aw_lo_q       <= '0;
            aw_hi_q       <= '0;
            for (int i = 0; i < MON; i++) begin
                mon_v_q[i]    <= 1'b0;
                mon_lp_q[i]   <= 8'd0;
                mon_addr_q[i] <= '0;
                mon_way_q[i]  <= '0;
            end
            mon_rr_q      <= '0;
            is_wr_q       <= 1'b0;
            wbuf_q        <= '0;
            wbe_q         <= '0;
            wchunk_q      <= 2'd0;
            rchunk_q      <= 2'd0;
            aw_coh_q      <= `RNF_AW_CACHED;
            way_q         <= '0;
            acq_op_q      <= chie_pkg::REQ_READSHARED;
            ord_q         <= chie_pkg::ORDER_NONE;
            got_rcpt_q    <= 1'b0;
            kind_q        <= K_READ;
            ack_q         <= 1'b0;
            alloc_q       <= 1'b0;
            rsp_ch_q      <= CH_NONE;
            vic_addr_q    <= '0;
            vic_way_q     <= '0;
            vic_state_q   <= `RNF_CS_I;
            vic_data_q    <= '0;
            vic_meta_q    <= `RNF_META_FULL;
            cb_op_q       <= chie_pkg::REQ_WRITEBACKFULL;
            cb_then_req_q <= 1'b0;
            cb_keep_q     <= 1'b0;
            cb_ls_q       <= 1'b0;
            acq_cs_q      <= `RNF_CS_I;
            retry_q       <= 1'b0;
            retry_type_q  <= 4'd0;
            retry_cb_q    <= 1'b0;
            ret_type_q    <= 4'd0;
            for (int t = 0; t < 16; t++) begin
                pcrd_cnt_q[t] <= 2'd0;
                pcrd_src_q[t] <= '0;
            end
            fill_uce_q    <= 1'b0;
            chain_ru_q    <= 1'b0;
            wr_tgt_q      <= '0;
            wr_txnid_q    <= '0;
            wr_tt_q       <= 1'b0;
            wr_pkt_q      <= '0;
            wr_dbid_q     <= 1'b0;
            wr_sent_q     <= 1'b0;
            cb_done_q     <= 1'b0;
            drop_q        <= 1'b0;
            cmo_got_q     <= 1'b0;
            cmo_ret_st_q  <= S_IDLE;
        end
        else begin
            automatic logic                                 set_now  = 1'b0;
            automatic logic [7:0]                           set_lp   = lpid_q;
            automatic logic [CHIE_REQ_ADDR_WIDTH_PARAM-1:0] set_addr = addr_q;
            automatic logic [`RNF_WAY_W-1:0]                set_way  = way_q;
            fill_v_q  <= 1'b0;
            cb_done_q <= 1'b0;
            drop_q    <= 1'b0;

            for (int t = 0; t < 16; t++) begin
                automatic logic inc = rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == 4'(t));
                automatic logic dec = (pcrd_use      && (retry_type_q == 4'(t))) ||
                                      (pcrd_ret_sent && (ret_type_q   == 4'(t)));
                pcrd_cnt_q[t] <= pcrd_cnt_q[t] + {1'b0, inc} - {1'b0, dec};
                if (inc) pcrd_src_q[t] <= prot_rxrspflit_i.srcid;
            end

            if (acq_snp_now && (st_q != S_IDLE))
                acq_cs_q <= snp_upd_state_i;
            // SS6.3 (p.6-286): EXOK on any response of the transaction.
            if (rx_exok) exok_q <= 1'b1;

            // Each attempt's CompCMO is its own: a request resent after RetryAck owes
            // a fresh one.
            if (((st_q == S_REQ) || (st_q == S_CB_REQ)) && prot_txreqflit_sent_i)
                cmo_got_q <= 1'b0;
            if (rx_compcmo) begin
                cmo_got_q <= 1'b1;
                // SS9.4.3 (p.9-341): CompCMO carries the CMO leg's error, which the
                // core is owed as it is a Comp's.
                if (is_err(prot_rxrspflit_i.resperr)) err_q <= 1'b1;
            end

            // Table 4-39 fn a (p.4-220): the snoop port may move the victim while
            // its CopyBack awaits CompDBIDResp, and the WriteData must say so.
            if (vic_snp_now)
                vic_state_q <= snp_upd_state_i;

            case (st_q)
                S_IDLE: begin
                    got_q      <= '0;
                    got_rsp_q  <= 1'b0;
                    err_q      <= 1'b0;
                    nderr_q    <= 1'b0;
                    data_err_q <= 1'b0;
                    wr_pkt_q   <= '0;
                    wr_dbid_q  <= 1'b0;
                    wr_sent_q  <= 1'b0;
                    cb_keep_q  <= 1'b0;
                    exok_q     <= 1'b0;
                    base_udp_q <= 1'b0;
                    got_rcpt_q <= 1'b0;
                    ord_q      <= chie_pkg::ORDER_NONE;
                    nc_q       <= 1'b0;
                    sz_q       <= chie_pkg::SIZE_64B;
                    off_q      <= '0;
                    if (surplus_v) begin
                        ret_type_q <= surplus_type;
                        st_q       <= S_PCRD_RET;
                    end
                    else if (flush_v) begin
                        qos_q       <= 4'd0;
                        vic_addr_q  <= cache_flush_addr_i;
                        vic_way_q   <= cache_flush_way_i;
                        vic_state_q <= flush_sel_state;
                        vic_data_q  <= cache_flush_data_i;
                        vic_meta_q  <= cache_flush_meta_i;
                        rsp_ch_q    <= CH_NONE;
                        core_q      <= 1'b0;
                        excl_q      <= 1'b0;
                        // SS4.1 (p.4-160): a Dirty line is the only copy, so it goes
                        // back; Table 4-32 (p.4-209) lets a Clean one go silently.
                        if (is_dirty(flush_sel_state)) begin
                            cb_op_q       <= back_op(flush_sel_state);
                            cb_then_req_q <= 1'b0;
                            st_q          <= S_CB_REQ;
                        end
                        else drop_q <= 1'b1;
                    end
                    else if (ARVALID && ARREADY) begin
                        id_q          <= ARID;
                        addr_q        <= ar_line;
                        rchunk_q      <= ARADDR[5:4];
                        is_wr_q       <= 1'b0;
                        rsp_ch_q      <= CH_R;
                        core_q        <= 1'b1;
                        lpid_q        <= ARID[7:0];
                        excl_q        <= ar_excl;
                        mpam_q        <= ARUSER[`AXI4_USER_MPAM_RANGE];
                        qos_q         <= ARQOS;
                        dev_q         <= !ARCACHE[1];
                        ewa_q         <= ARCACHE[0];
                        excl_pass_q   <= 1'b0;
                        way_q         <= lu_hit_now ? cache_lu_way_i : cache_vic_way_i;
                        line_err_q    <= lu_hit_now && cache_lu_meta_i[`RNF_META_DERR];
                        line_poison_q <= lu_hit_now ? cache_lu_meta_i[`RNF_META_POISON] : 8'h00;
                        line_vmask_q  <= lu_hit_now ? cache_lu_meta_i[`RNF_META_VMASK] : '0;
                        acq_cs_q      <= lu_state;
                        // Table 2-11 (SS2.9.4 p.2-129): a Device or Non-cacheable read
                        // is a ReadNoSnp of the beat, which the cache neither serves
                        // nor keeps. Table 4-1 (SS4.2.1 p.4-165) gives Device nRnE
                        // Order 11 and Normal Non-cacheable 00.
                        if (ar_nc) begin
                            nc_q       <= 1'b1;
                            acq_cs_q   <= `RNF_CS_I;
                            hit_q      <= 1'b0;
                            line_err_q <= 1'b0;
                            line_poison_q <= 8'h00;
                            line_vmask_q  <= '0;
                            sz_q       <= ar_nc_sz;
                            // SS2.10.2 (p.2-134): a Device access reads from its Addr to
                            // the next Size boundary, so the beat's own address is kept.
                            off_q      <= ARADDR[5:0];
                            acq_op_q   <= chie_pkg::REQ_READNOSNP;
                            ord_q      <= ARCACHE[1] ? chie_pkg::ORDER_NONE : chie_pkg::ORDER_END_POINT;
                            kind_q     <= K_READ;
                            alloc_q    <= 1'b0;
                            ack_q      <= 1'b0;
                            st_q       <= S_REQ;
                        end
                        else if (lu_hit_now && !is_short(lu_state)) begin
                            line_q      <= cache_lu_data_i;
                            hit_q       <= 1'b1;
                            // SS6.3.3 (p.6-290): a Load of a line already held needs
                            // no transaction, and sets the monitor.
                            excl_pass_q <= ar_excl;
                            set_now      = ar_excl;
                            set_lp       = ARID[7:0];
                            set_addr     = ar_line;
                            set_way      = cache_lu_way_i;
                            st_q        <= S_RESP;
                        end
                        // Table 4-4 (SS4.2.1 p.4-167): a line short of valid bytes is
                        // read by ReadUnique, which Table 4-33 (p.4-212) ends UD from
                        // UDP, merging the returned bytes under its own.
                        else if (lu_hit_now) begin
                            line_q     <= cache_lu_data_i;
                            hit_q      <= 1'b0;
                            base_udp_q <= (lu_state == `RNF_CS_UDP);
                            acq_op_q   <= chie_pkg::REQ_READUNIQUE;
                            kind_q     <= K_READ;
                            alloc_q    <= 1'b1;
                            ack_q      <= 1'b1;
                            st_q       <= S_REQ;
                        end
                        else begin
                            hit_q    <= 1'b0;
                            acq_op_q <= ar_op;
                            ord_q    <= ar_ord;
                            kind_q   <= K_READ;
                            alloc_q  <= ar_alloc;
                            ack_q    <= ar_alloc;
                            vic_addr_q <= cache_vic_addr_i;
                            vic_way_q  <= cache_vic_way_i;
                            vic_state_q<= vic_sel_state;
                            vic_data_q <= cache_vic_data_i;
                            vic_meta_q <= cache_vic_meta_i;
                            cb_op_q       <= back_op(vic_sel_state);
                            cb_then_req_q <= 1'b1;
                            st_q <= (need_cb && ar_alloc) ? S_CB_REQ : S_REQ;
                        end
                    end
                    else if (AWVALID && AWREADY) begin
                        id_q     <= AWID;
                        addr_q   <= aw_line;
                        is_wr_q  <= 1'b1;
                        rsp_ch_q <= CH_B;
                        aw_coh_q <= AWCOH;
                        core_q   <= 1'b1;
                        lpid_q   <= AWID[7:0];
                        excl_q   <= aw_excl;
                        mpam_q   <= AWUSER[`AXI4_USER_MPAM_RANGE];
                        qos_q    <= AWQOS;
                        nc_q     <= aw_nc;
                        dev_q    <= !AWCACHE[1];
                        ewa_q    <= AWCACHE[0];
                        aw_lo_q  <= aw_lo;
                        aw_hi_q  <= aw_hi;
                        excl_pass_q <= 1'b0;
                        apply_q  <= 1'b1;
                        wpoison_q <= 8'h00;
                        wbe_q    <= '0;
                        wbuf_q   <= '0;
                        wchunk_q <= AWADDR[5:4];
                        st_q     <= S_WDATA;
                    end
                    else if (CMVALID && CMREADY) begin
                        qos_q       <= 4'd0;
                        addr_q      <= cm_line;
                        is_wr_q     <= 1'b0;
                        rsp_ch_q    <= CH_CM;
                        alloc_q     <= 1'b0;
                        ack_q       <= 1'b0;
                        kind_q      <= K_NOTE;
                        core_q      <= 1'b0;
                        excl_q      <= 1'b0;
                        excl_pass_q <= 1'b0;
                        vic_addr_q  <= cm_line;
                        vic_way_q   <= cache_lu_way_i;
                        vic_state_q <= lu_state;
                        vic_data_q  <= cache_lu_data_i;
                        vic_meta_q  <= cache_lu_meta_i;
                        cb_then_req_q <= 1'b0;
                        cb_ls_q     <= (lu_state == `RNF_CS_SC);
                        case (CMOP)
                            `RNF_CM_EVICT_SILENT, `RNF_CM_EVICT_NOTIFY,
                            `RNF_CM_EVICT_RETURN, `RNF_CM_EVICT_OFFER: begin
                                acq_op_q <= chie_pkg::REQ_EVICT;
                                if (!lu_hit_now) st_q <= S_CMRSP;
                                // Table 4-16 (SS4.2.3 p.4-181): a Dirty line leaves by
                                // WriteBack whatever the core asked.
                                else if (is_dirty(lu_state)) begin
                                    cb_op_q <= back_op(lu_state);
                                    st_q    <= S_CB_REQ;
                                end
                                else if (CMOP == `RNF_CM_EVICT_SILENT) begin
                                    drop_q <= 1'b1;
                                    st_q   <= S_CMRSP;
                                end
                                else if ((CMOP == `RNF_CM_EVICT_RETURN) && (lu_state == `RNF_CS_UC)) begin
                                    cb_op_q <= chie_pkg::REQ_WRITEEVICTFULL;
                                    st_q    <= S_CB_REQ;
                                end
                                else if ((CMOP == `RNF_CM_EVICT_OFFER) &&
                                         ((lu_state == `RNF_CS_UC) || (lu_state == `RNF_CS_SC))) begin
                                    cb_op_q <= chie_pkg::REQ_WRITEEVICTOREVICT;
                                    st_q    <= S_CB_REQ;
                                end
                                // Table 4-38 (SS4.7.2 p.4-218): the line goes to I
                                // before the Evict is issued. SS4.6's Table 4-32
                                // (p.4-209) makes that Evict the visible form of the
                                // SC and UCE evictions, which WriteEvictFull is not.
                                else begin
                                    drop_q <= 1'b1;
                                    st_q   <= S_REQ;
                                end
                            end
                            `RNF_CM_CLEAN: begin
                                // Table 4-16 (p.4-181): WriteCleanFull is issued from UD
                                // or SD only, and a UDP line has no Clean form to keep.
                                if (lu_state == `RNF_CS_UDP) begin
                                    err_q <= 1'b1;
                                    st_q  <= S_CMRSP;
                                end
                                else if (is_dirty(lu_state)) begin
                                    cb_op_q   <= chie_pkg::REQ_WRITECLEANFULL;
                                    cb_keep_q <= 1'b1;
                                    st_q      <= S_CB_REQ;
                                end
                                else st_q <= S_CMRSP;
                            end
                            `RNF_CM_CLEAN_SHARED, `RNF_CM_CLEAN_SHARED_EVICT: begin
                                acq_op_q <= chie_pkg::REQ_CLEANSHARED;
                                // Table 4-17 (SS4.2.4 p.4-182): a Dirty line folds its
                                // CopyBack into the CMO, keeping a Clean copy or not.
                                // Table 4-17 (SS4.2.4 p.4-182) combines no CMO with
                                // WriteBackPtl, so a UDP line goes back first.
                                if (lu_state == `RNF_CS_UDP) begin
                                    cb_op_q       <= chie_pkg::REQ_WRITEBACKPTL;
                                    cb_then_req_q <= 1'b1;
                                    st_q          <= S_CB_REQ;
                                end
                                else if (is_dirty(lu_state)) begin
                                    cb_op_q   <= (CMOP == `RNF_CM_CLEAN_SHARED)
                                                 ? chie_pkg::REQ_WRITECLEANFULLCLEANSH
                                                 : chie_pkg::REQ_WRITEBACKFULLCLEANSH;
                                    cb_keep_q <= (CMOP == `RNF_CM_CLEAN_SHARED);
                                    st_q      <= S_CB_REQ;
                                end
                                // Table 4-10 (SS4.2.2 p.4-174): CleanShared from UC,
                                // SC or I only.
                                else begin
                                    drop_q <= lu_hit_now &&
                                              ((CMOP == `RNF_CM_CLEAN_SHARED_EVICT) ||
                                               (lu_state == `RNF_CS_UCE));
                                    st_q   <= S_REQ;
                                end
                            end
                            `RNF_CM_CLEAN_INVALID: begin
                                acq_op_q <= chie_pkg::REQ_CLEANINVALID;
                                if (lu_state == `RNF_CS_UDP) begin
                                    cb_op_q       <= chie_pkg::REQ_WRITEBACKPTL;
                                    cb_then_req_q <= 1'b1;
                                    st_q          <= S_CB_REQ;
                                end
                                else if (is_dirty(lu_state)) begin
                                    cb_op_q <= chie_pkg::REQ_WRITEBACKFULLCLEANINV;
                                    st_q    <= S_CB_REQ;
                                end
                                // Table 4-38 (p.4-218): CleanInvalid is issued from I.
                                else begin
                                    drop_q <= lu_hit_now;
                                    st_q   <= S_REQ;
                                end
                            end
                            `RNF_CM_MAKE_INVALID: begin
                                acq_op_q <= chie_pkg::REQ_MAKEINVALID;
                                // Table 4-32 (p.4-209) has no silent SD -> I, so a Shared
                                // Dirty line is written back first.
                                if (lu_state == `RNF_CS_SD) begin
                                    cb_op_q       <= chie_pkg::REQ_WRITEBACKFULL;
                                    cb_then_req_q <= 1'b1;
                                    st_q          <= S_CB_REQ;
                                end
                                else begin
                                    drop_q <= lu_hit_now;
                                    st_q   <= S_REQ;
                                end
                            end
                            default: begin
                                err_q <= 1'b1;
                                st_q  <= S_CMRSP;
                            end
                        endcase
                    end
                end

                S_WDATA: begin
                    if (WVALID) begin
                        case (wchunk_q)
                            2'd0: begin wbuf_q[127:0]   <= WDATA; wbe_q[15:0]  <= WSTRB; end
                            2'd1: begin wbuf_q[255:128] <= WDATA; wbe_q[31:16] <= WSTRB; end
                            2'd2: begin wbuf_q[383:256] <= WDATA; wbe_q[47:32] <= WSTRB; end
                            default: begin wbuf_q[511:384] <= WDATA; wbe_q[63:48] <= WSTRB; end
                        endcase
                        wchunk_q  <= wchunk_q + 2'd1;
                        wpoison_q <= wpoison_now;
                        if (WLAST) begin
                            way_q         <= lu_hit_now ? cache_lu_way_i : cache_vic_way_i;
                            line_err_q    <= lu_hit_now && cache_lu_meta_i[`RNF_META_DERR];
                            line_poison_q <= lu_hit_now ? cache_lu_meta_i[`RNF_META_POISON] : 8'h00;
                            line_vmask_q  <= lu_hit_now ? cache_lu_meta_i[`RNF_META_VMASK] : '0;
                            alloc_q       <= 1'b1;
                            ack_q         <= 1'b1;
                            // Table 2-11 (SS2.9.4 p.2-129): a Device or Non-cacheable
                            // write is a WriteNoSnp of the bytes the burst addresses,
                            // Full only for a whole line, and Table 4-13 (SS4.2.3
                            // p.4-178) gives Device nRnE Order 11. SS4.2.3 (p.4-176)
                            // makes a line of zeros WriteNoSnpZero's.
                            if (nc_q) begin
                                hit_q    <= 1'b0;
                                alloc_q  <= 1'b0;
                                ack_q    <= 1'b0;
                                acq_cs_q <= `RNF_CS_I;
                                kind_q   <= K_WU;
                                sz_q     <= wr_full ? chie_pkg::SIZE_64B : size_spanning(aw_lo_q, aw_hi_q);
                                off_q    <= wr_full ? '0 :
                                            `RNF_LINE_OFFSET_W'(int'(aw_lo_q) &
                                                                ~((32'd1 << size_spanning(aw_lo_q, aw_hi_q)) - 1));
                                acq_op_q <= wr_zero ? chie_pkg::REQ_WRITENOSNPZERO :
                                            wr_full ? chie_pkg::REQ_WRITENOSNPFULL
                                                    : chie_pkg::REQ_WRITENOSNPPTL;
                                ord_q    <= dev_q ? chie_pkg::ORDER_END_POINT : chie_pkg::ORDER_NONE;
                                st_q     <= S_REQ;
                            end
                            // SS6.3.3 (p.6-290, MUST): an Exclusive Store whose monitor
                            // is reset fails, and issues no transaction.
                            else if (excl_q && !(lu_hit_now && !is_short(lu_state) &&
                                            mon_set(lpid_q, addr_q))) begin
                                hit_q   <= 1'b1;
                                apply_q <= 1'b0;
                                st_q    <= S_BRESP;
                            end
                            // A Unique line is already this node's to modify; Table
                            // 4-32 (SS4.6 p.4-209) makes the store silent, UD once every
                            // byte is valid and UDP until then. SS6.3.3 (p.6-290) passes
                            // an Exclusive Store from it without a transaction.
                            else if (lu_hit_now && is_unique(lu_state)) begin
                                line_q       <= cache_lu_data_i;
                                fill_state_q <= `RNF_CS_UC;
                                hit_q        <= 1'b1;
                                fill_v_q     <= 1'b1;
                                excl_pass_q  <= excl_q;
                                st_q         <= S_BRESP;
                            end
                            else begin
                                hit_q <= 1'b0;
                                if (lu_hit_now) begin
                                    // SC or SD: Table 4-38 (p.4-218) and Table 4-36
                                    // (SS4.7.1 p.4-216) end both Unique, and the node
                                    // keeps its own bytes.
                                    line_q   <= cache_lu_data_i;
                                    acq_cs_q <= lu_state;
                                    if (aw_coh_q == `RNF_AW_READ_UNIQUE) begin
                                        acq_op_q <= chie_pkg::REQ_MAKEREADUNIQUE;
                                        kind_q   <= K_MRU;
                                    end
                                    else begin
                                        acq_op_q <= chie_pkg::REQ_CLEANUNIQUE;
                                        kind_q   <= K_OWN;
                                    end
                                    st_q <= S_REQ;
                                end
                                else if ((aw_coh_q == `RNF_AW_IMMEDIATE) ||
                                         (aw_coh_q == `RNF_AW_IMMEDIATE_CLSH)) begin
                                    // Table 4-16 (SS4.2.3 p.4-181): WriteUnique writes a
                                    // line that is Invalid here, and leaves it so.
                                    alloc_q <= 1'b0;
                                    ack_q   <= 1'b0;
                                    kind_q  <= K_WU;
                                    if (aw_coh_q == `RNF_AW_IMMEDIATE_CLSH)
                                        acq_op_q <= wr_full ? chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH
                                                            : chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH;
                                    else
                                        acq_op_q <= wr_zero ? chie_pkg::REQ_WRITEUNIQUEZERO :
                                                    wr_full ? chie_pkg::REQ_WRITEUNIQUEFULL
                                                            : chie_pkg::REQ_WRITEUNIQUEPTL;
                                    st_q <= S_REQ;
                                end
                                else begin
                                    line_q     <= '0;
                                    acq_cs_q   <= `RNF_CS_I;
                                    // Table 4-38 (p.4-218): MakeUnique needs no data
                                    // fetched, so it is the whole-line store's request.
                                    // A partial one reads the bytes it does not write,
                                    // or with PARTIAL takes a CleanUnique from I to UCE
                                    // and keeps only its own bytes.
                                    if (wr_full) begin
                                        acq_op_q <= chie_pkg::REQ_MAKEUNIQUE;
                                        kind_q   <= K_OWN;
                                    end
                                    else if (aw_coh_q == `RNF_AW_PARTIAL) begin
                                        acq_op_q <= chie_pkg::REQ_CLEANUNIQUE;
                                        kind_q   <= K_OWN;
                                    end
                                    else begin
                                        acq_op_q <= chie_pkg::REQ_READUNIQUE;
                                        kind_q   <= K_READ;
                                    end
                                    vic_addr_q <= cache_vic_addr_i;
                                    vic_way_q  <= cache_vic_way_i;
                                    vic_state_q<= vic_sel_state;
                                    vic_data_q <= cache_vic_data_i;
                                    vic_meta_q <= cache_vic_meta_i;
                                    cb_op_q       <= back_op(vic_sel_state);
                                    cb_then_req_q <= 1'b1;
                                    st_q       <= need_cb ? S_CB_REQ : S_REQ;
                                end
                            end
                        end
                    end
                end

                S_CB_REQ: begin
                    if (prot_txreqflit_sent_i) st_q <= S_CB_DBID;
                end

                S_CB_DBID: begin
                    if (rx_retryack) begin
                        retry_q      <= 1'b1;
                        retry_type_q <= prot_rxrspflit_i.pcrdtype;
                        retry_cb_q   <= 1'b1;
                        st_q         <= S_PCRD;
                    end
                    else if (rx_compdbid) begin
                        retry_q    <= 1'b0;
                        wr_tgt_q   <= prot_rxrspflit_i.srcid;
                        wr_txnid_q <= prot_rxrspflit_i.dbid;
                        wr_tt_q    <= prot_rxrspflit_i.tracetag;
                        wr_pkt_q   <= '0;
                        if (!cb_then_req_q && rx_err) err_q <= 1'b1;
                        st_q       <= S_CB_DAT;
                    end
                    // Table 4-39 (p.4-220) fn c: a Home that wants no data answers
                    // WriteEvictOrEvict with Comp, and the line still ends Invalid.
                    else if (rx_comp && (cb_op_q == chie_pkg::REQ_WRITEEVICTOREVICT)) begin
                        retry_q     <= 1'b0;
                        ack_tgt_q   <= prot_rxrspflit_i.srcid;
                        ack_txnid_q <= prot_rxrspflit_i.dbid;
                        ack_tt_q    <= prot_rxrspflit_i.tracetag;
                        cb_done_q   <= 1'b1;
                        if (rx_err) err_q <= 1'b1;
                        st_q        <= S_ACK;
                    end
                end

                S_CB_DAT: begin
                    if (prot_txdatflit_sent_i) begin
                        if (wr_last_pkt) begin
                            // The way is free only now; cb_hold_v_o keeps this
                            // line's snoops queued until the retirement lands.
                            cb_done_q <= 1'b1;
                            wr_pkt_q  <= '0;
                            if (cb_cmo_now) begin
                                txnid_q <= txnid_q + 12'd1;
                                st_q    <= cb_then_req_q ? S_REQ : fin_st;
                            end
                            else begin
                                cmo_ret_st_q <= cb_then_req_q ? S_REQ : fin_st;
                                st_q         <= S_CMO;
                            end
                        end
                        else wr_pkt_q <= wr_pkt_q + 1'b1;
                    end
                end

                S_REQ: begin
                    if (prot_txreqflit_sent_i) st_q <= S_DATA;
                end

                S_DATA: begin
                    if (rx_retryack) begin
                        retry_q      <= 1'b1;
                        retry_type_q <= prot_rxrspflit_i.pcrdtype;
                        retry_cb_q   <= 1'b0;
                        st_q         <= S_PCRD;
                    end
                    else begin
                    retry_q <= 1'b0;
                    if (rx_err)      err_q      <= 1'b1;
                    if (rx_nderr)    nderr_q    <= 1'b1;
                    if (rx_derr_dat) data_err_q <= 1'b1;

                    if (rx_sep || rx_comp) begin
                        ack_tgt_q   <= prot_rxrspflit_i.srcid;
                        ack_txnid_q <= prot_rxrspflit_i.dbid;
                        ack_tt_q    <= prot_rxrspflit_i.tracetag;
                    end
                    if (rx_sep) got_rsp_q <= 1'b1;
                    if (rx_rcpt) got_rcpt_q <= 1'b1;
                    if (rx_dat_comb) begin
                        ack_tgt_q   <= prot_rxdatflit_i.homenid;
                        ack_txnid_q <= prot_rxdatflit_i.dbid;
                        ack_tt_q    <= prot_rxdatflit_i.tracetag;
                    end
                    // Table 4-33 (SS4.7.1 p.4-211) puts a read's granted state on
                    // the DATA half of both shapes; Table 4-38 (p.4-218) puts a
                    // Dataless one on the Comp.
                    if (rx_dat_mine) fill_state_q <= cs_of_resp(prot_rxdatflit_i.resp);
                    if (rx_comp)     fill_state_q <= cs_of_resp(prot_rxrspflit_i.resp);

                    // SS2.10.4 (p.2-136): packet p carries line bytes [p*PKT_B +: PKT_B].
                    // Table 4-33 fn c (p.4-212): returned bytes fill only those the
                    // line does not already hold valid.
                    if (rx_dat_mine) begin
                        // Unsigned: a size cast keeps its operand's signedness, so a
                        // signed offset of 32+ would index below zero.
                        automatic int unsigned base = int'(rx_pkt) * PSN_PKT;
                        if (take_data) begin
                            for (int unsigned b = 0; b < PKT_B; b++)
                                if (!merge_vm[`RNF_LINE_OFFSET_W'(base*8 + b)])
                                    line_q[(base*8 + b)*8 +: 8] <= prot_rxdatflit_i.data[b*8 +: 8];
                            for (int unsigned c = 0; c < PSN_PKT; c++)
                                line_poison_q[3'(base + c)] <=
                                    (&merge_vm[(base + c)*8 +: 8]) ? line_poison_q[3'(base + c)] :
                                    (prot_rxdatflit_i.poison[c] |
                                     (line_poison_q[3'(base + c)] & (|merge_vm[(base + c)*8 +: 8])));
                        end
                        got_q[rx_pkt] <= 1'b1;
                    end

                    case (kind_q)
                        K_READ, K_MRU: begin
                            // The line takes its granted state on the completion,
                            // not on this node's CompAck, so the fill lands now: a
                            // snoop released by the deferral below must find the
                            // state already there.
                            if (data_done) begin
                                fill_v_q <= alloc_q && !nderr_now && mru_fill;
                                apply_q  <= !excl_q || mru_pass;
                                if (take_data) begin
                                    line_err_q   <= data_err_now;
                                    line_vmask_q <= '1;
                                end
                                // Table 4-33 (p.4-212): ReadUnique ends a UDP line UD.
                                if (base_udp_q && !acq_lost) fill_state_q <= `RNF_CS_UD;
                                if (ack_q) st_q <= S_ACK;
                                else if (rcpt_owed) st_q <= S_RCPT;
                                else begin
                                    txnid_q <= txnid_q + 12'd1;
                                    st_q    <= fin_st;
                                end
                                // SS6.3.1 (p.6-286): an Exclusive Load passes on EXOK, and
                                // ReadPreferUnique, which may not carry it, on any grant.
                                if (excl_q && !is_wr_q && alloc_q && !nderr_now &&
                                    (kind_q == K_READ) &&
                                    (exok_now || !excl_load_op(acq_op_q) ||
                                     (acq_op_q == chie_pkg::REQ_READPREFERUNIQUE))) begin
                                    excl_pass_q <= 1'b1;
                                    set_now      = 1'b1;
                                end
                                if (excl_q && is_wr_q) excl_pass_q <= mru_pass;
                                // A chained ReadUnique's line is UCE, owning no bytes.
                                // SS9.3 leaves it UCE; Table 4-32 (SS4.6 p.4-209) then
                                // permits the silent eviction to I, so the line can
                                // never be served or merged into with no data behind it.
                                if (nderr_now && !nc_q && cache_lu_hit_i && (cache_lu_state_i == `RNF_CS_UCE)) begin
                                    vic_addr_q <= addr_q;
                                    vic_way_q  <= cache_lu_way_i;
                                    drop_q     <= 1'b1;
                                end
                            end
                            else if ((kind_q == K_MRU) && rx_comp && (got_q == '0)) begin
                                fill_v_q    <= !nderr_now && (!excl_q || mru_pass);
                                apply_q     <= !excl_q || mru_pass;
                                excl_pass_q <= excl_q && mru_pass;
                                st_q        <= S_ACK;
                            end
                        end
                        K_OWN: begin
                            if (rx_comp) begin
                                // SS6.3.3 (p.6-291, MUST): an Exclusive CleanUnique passes
                                // on EXOK only while the LP monitor is still set.
                                fill_v_q    <= !nderr_now && (!excl_q || own_pass);
                                apply_q     <= !excl_q || own_pass;
                                excl_pass_q <= excl_q && own_pass;
                                st_q        <= S_ACK;
                            end
                        end
                        K_NOTE: begin
                            if (rx_comp) begin
                                txnid_q <= txnid_q + 12'd1;
                                st_q    <= fin_st;
                            end
                        end
                        default: begin
                            if (rx_dbid || rx_compdbid) begin
                                wr_tgt_q   <= prot_rxrspflit_i.srcid;
                                wr_txnid_q <= prot_rxrspflit_i.dbid;
                                wr_tt_q    <= prot_rxrspflit_i.tracetag;
                                wr_dbid_q  <= 1'b1;
                            end
                            if (rx_comp || rx_compdbid) got_rsp_q <= 1'b1;
                            if (wu_dbid_now) begin
                                if (!is_write_zero(acq_op_q) && !wr_sent_q) begin
                                    wr_pkt_q <= wu_first;
                                    st_q     <= S_WU_DAT;
                                end
                                else if (wu_comp_now && wu_cmo_now) begin
                                    txnid_q <= txnid_q + 12'd1;
                                    st_q    <= fin_st;
                                end
                                else if (wu_comp_now) begin
                                    cmo_ret_st_q <= fin_st;
                                    st_q         <= S_CMO;
                                end
                            end
                        end
                    endcase

                    // Table 4-38 (p.4-218): the line went Invalid under the
                    // CleanUnique, which therefore ends UCE. The bytes held in
                    // line_q are what the snoop took away, so none survive. A
                    // dataless MakeReadUnique completion to a lost line takes the
                    // same path. A partial store then either keeps its own bytes
                    // (PARTIAL) or follows with the ReadUnique that fills the rest.
                    if (rx_comp && acq_lost && !nderr_now && (got_q == '0) && !excl_q &&
                        ((acq_op_q == chie_pkg::REQ_CLEANUNIQUE) ||
                         (acq_op_q == chie_pkg::REQ_MAKEREADUNIQUE))) begin
                        line_q        <= '0;
                        line_err_q    <= 1'b0;
                        line_poison_q <= 8'h00;
                        line_vmask_q  <= '0;
                        if (!(&wbe_q) && (aw_coh_q != `RNF_AW_PARTIAL)) begin
                            fill_uce_q <= 1'b1;
                            chain_ru_q <= 1'b1;
                        end
                    end
                    end
                end

                S_WU_DAT: begin
                    if (rx_err) err_q <= 1'b1;
                    if (rx_comp) got_rsp_q <= 1'b1;
                    if (prot_txdatflit_sent_i) begin
                        if (wr_last_pkt) begin
                            wr_sent_q <= 1'b1;
                            if (!(got_rsp_q || rx_comp))
                                st_q <= S_DATA;
                            else if (wu_cmo_now) begin
                                txnid_q <= txnid_q + 12'd1;
                                st_q    <= fin_st;
                            end
                            else begin
                                cmo_ret_st_q <= fin_st;
                                st_q         <= S_CMO;
                            end
                        end
                        else wr_pkt_q <= wr_pkt_q + 1'b1;
                    end
                end

                // SS2.11 (p.2-145): held until a P-Credit of the RetryAck's type,
                // then resent. The resend keeps its TxnID, which the same section
                // frees for reuse as soon as the RetryAck arrives.
                S_PCRD: begin
                    if (pcrd_ready) st_q <= retry_cb_q ? S_CB_REQ : S_REQ;
                end

                S_PCRD_RET: begin
                    if (prot_txreqflit_sent_i) st_q <= S_IDLE;
                end

                // The write leg is done and the CMO leg still owes its CompCMO; the
                // core's response and the TxnID both wait for it.
                S_CMO: begin
                    if (rx_compcmo) begin
                        txnid_q <= txnid_q + 12'd1;
                        st_q    <= cmo_ret_st_q;
                    end
                end

                // An ordered read has its data but still owes its ReadReceipt; the
                // core's response and the TxnID both wait for it.
                S_RCPT: begin
                    if (rx_rcpt) begin
                        txnid_q <= txnid_q + 12'd1;
                        st_q    <= fin_st;
                    end
                end

                S_ACK: begin
                    retry_q <= 1'b0;
                    if (prot_txrspflit_sent_i) begin
                        txnid_q <= txnid_q + 12'd1;
                        if (chain_ru_q) begin
                            // p.4-215: the other transaction the lost line costs.
                            chain_ru_q <= 1'b0;
                            fill_uce_q <= 1'b0;
                            got_q      <= '0;
                            got_rsp_q  <= 1'b0;
                            data_err_q <= 1'b0;
                            line_err_q <= 1'b0;
                            acq_op_q   <= chie_pkg::REQ_READUNIQUE;
                            kind_q     <= K_READ;
                            st_q       <= S_REQ;
                        end
                        else st_q <= fin_st;
                    end
                end

                S_RESP: begin
                    if (RREADY) st_q <= S_IDLE;
                end

                S_BRESP: begin
                    if (BREADY) st_q <= S_IDLE;
                end

                S_CMRSP: st_q <= S_IDLE;

                default: st_q <= S_IDLE;
            endcase

            // SS6.2.1 (p.6-283): a monitor is reset when its line leaves the cache
            // -- an invalidating snoop, a write-back or drop, a fill displacing it --
            // or is stored to.
            for (int i = 0; i < MON; i++) begin
                if (set_now && (i == set_slot(set_lp)) &&
                    !(snp_upd_v_i && (snp_upd_state_i == `RNF_CS_I) &&
                      same_line(snp_upd_addr_i, set_addr))) begin
                    mon_v_q[i]    <= 1'b1;
                    mon_lp_q[i]   <= set_lp;
                    mon_addr_q[i] <= set_addr;
                    mon_way_q[i]  <= set_way;
                end
                else if (mon_v_q[i] &&
                         ((snp_upd_v_i && (snp_upd_state_i == `RNF_CS_I) &&
                           same_line(snp_upd_addr_i, mon_addr_q[i])) ||
                          (cache_upd_v_o && (cache_upd_state_o == `RNF_CS_I) &&
                           same_line(cache_upd_addr_o, mon_addr_q[i])) ||
                          (cache_fill_v_o && same_line(cache_fill_addr_o, mon_addr_q[i]) &&
                           is_wr_q && apply_q) ||
                          (cache_fill_v_o && (cache_fill_way_o == mon_way_q[i]) &&
                           same_set(cache_fill_addr_o, mon_addr_q[i]) &&
                           !same_line(cache_fill_addr_o, mon_addr_q[i]))))
                    mon_v_q[i] <= 1'b0;
            end
            if (set_now && !mon_has_lp(set_lp) && mon_full())
                mon_rr_q <= (mon_rr_q == ($clog2(MON+1))'(MON-1)) ? '0 : (mon_rr_q + 1'b1);
        end
    end

    // The store's final state. Table 4-38 (p.4-218) ends CleanUnique and
    // MakeUnique Unique, Table 4-36 (p.4-216) does the same for MakeReadUnique,
    // and the merge that follows makes the line Dirty.
    // Table 4-32 (p.4-209): the store leaves the line UD once every byte is valid,
    // and UDP until then.
    wire                        store_fill = is_wr_q && apply_q;
    wire [`RNF_LINE_BYTES-1:0]  fill_vmask = store_fill ? (line_vmask_q | wbe_q) : line_vmask_q;
    wire [`RNF_CS_WIDTH-1:0]    wr_fill_state =
        (fill_state_q == `RNF_CS_I) ? `RNF_CS_I :
        (&fill_vmask)               ? `RNF_CS_UD : `RNF_CS_UDP;

    assign cache_fill_v_o     = fill_v_q;
    assign cache_fill_addr_o  = addr_q;
    assign cache_fill_way_o   = way_q;
    assign cache_fill_state_o = fill_uce_q ? `RNF_CS_UCE :
                                store_fill ? wr_fill_state : fill_state_q;
    assign cache_fill_data_o  = fill_line;
    // A store covering the whole line replaces every corrupt byte.
    assign cache_fill_meta_o  = {line_err_q && !(store_fill && (&wbe_q)),
                                 store_fill ? merge_poison(line_poison_q, wpoison_q, wbe_q)
                                            : line_poison_q,
                                 fill_uce_q ? {`RNF_LINE_BYTES{1'b0}} : fill_vmask};

    // Retiring the written-back way, which the fill behind it would otherwise
    // leave Dirty for the window between the two. WriteCleanFull keeps it Clean.
    assign cache_upd_v_o     = cb_done_q || drop_q;
    assign cache_upd_addr_o  = vic_addr_q;
    assign cache_upd_way_o   = vic_way_q;
    assign cache_upd_state_o = (cb_done_q && cb_keep_q) ? clean_of(vic_state_now) : `RNF_CS_I;

    // The 128-bit chunk the access falls in. A fixed set of slices rather than a
    // variable base, so the select cannot read past the line.
    logic [`AXI4_RDATA_WIDTH-1:0] rdata_c;
    always_comb begin
        case (rchunk_q)
            2'd0:    rdata_c = line_q[127:0];
            2'd1:    rdata_c = line_q[255:128];
            2'd2:    rdata_c = line_q[383:256];
            default: rdata_c = line_q[511:384];
        endcase
    end

    // SS9.3 (p.9-336): a non-OK RespErr is the endpoint's, and the core is owed
    // it rather than a silent OKAY.
    // AMBA AXI4 (IHI 0022) A7.2: EXOKAY for an exclusive access that passed.
    // SS6.3.2 (p.6-289): a Non-snoopable Exclusive passes on the EXOK the PoS
    // returned; a Snoopable one on this node's own monitor.
    wire       excl_ok  = nc_q ? (excl_q && exok_q) : excl_pass_q;
    wire [1:0] axi_resp = err_q ? 2'b10 : excl_ok ? 2'b01 : 2'b00;

    assign RVALID = (st_q == S_RESP);
    assign RDATA  = rdata_c;
    assign RID    = id_q;
    // A hit on a line whose bytes arrived with DERR returns them with it.
    assign RRESP  = line_err_q ? 2'b10 : axi_resp;
    // SS9.5 (p.9-347, MUST): the Poison of the two 64-bit chunks returned.
    always_comb begin
        RUSER = '0;
        RUSER[`AXI4_USER_POISON_RANGE] = line_poison_q[2*rchunk_q +: 2];
    end
    assign RLAST  = 1'b1;

    assign BVALID = (st_q == S_BRESP);
    assign BID    = `AXI4_BID_WIDTH'(id_q);
    assign BRESP  = axi_resp;

    assign CMDONE = (st_q == S_CMRSP);
    assign CMRESP = err_q ? 2'b10 : 2'b00;

    // From the first Data packet until the fill it completes has been written. SS4.11.1
    // (p.4-242, MUST) is judged at the interface, so a packet counts from its cycle on the pins.
    assign defer_v_o    = ((st_q == S_DATA) &&
                           ((got_q != '0) || rx_dat_mine || rx_dat_arriving)) || fill_v_q;
    assign defer_addr_o = addr_q;

    assign cb_hold_v_o    = (st_q == S_CB_DAT) || cb_done_q;
    assign cb_hold_addr_o = vic_addr_q;

    // SS14.7.1 (p.14-460): a held surplus P-Credit is a PCrdReturn this node still
    // owes, so it counts as work in progress even from idle.
    assign txn_active_o = (st_q != S_IDLE) || surplus_v;

    // A single-outstanding Requester draws at most one RetryAck at a time, so a
    // conformant Completer never grants it more than a few credits of one type
    // before they are used or returned. Two bits wrapping would silently lose one.
`ifdef ASSERT_CHECKER_ON
    for (genvar gt = 0; gt < 16; gt++) begin : g_pcrd_sat
        assert_checker #(
                           3,
                           "RN-F P-Credit bank saturated: a PCrdGrant arrived with three of its type already held")
                       PCRD_SAT_check (
                           .clk   ( clk_i ),
                           .rst   ( rst_i ),
                           .cond  ( rx_pcrdgrant && (prot_rxrspflit_i.pcrdtype == 4'(gt)) &&
                                    (pcrd_cnt_q[gt] == 2'd3) )
                       );
    end
`endif

endmodule
