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

`ifndef OPENNOC_HNF_PKG_SV
`define OPENNOC_HNF_PKG_SV

// The name is prefixed because this design is compiled into whatever
// namespace integrates it, and a node-local package name like rni_pkg or
// hnf_pkg is one an integrator is likely to have already.
package opennoc_hnf_pkg;

  // The SNP flit together with the snoopee it is addressed to. Table 13-8
  // (SS13.6 p.13-421) gives the SNP channel no TgtID -- the interconnect routes
  // the snoop -- so this NodeID is HN-F's own routing envelope and travels
  // beside the flit rather than in it.
  typedef struct packed {
    logic [chie_pkg::NID_WIDTH-1:0] tgtid;
    chie_pkg::snp_flit_s            flit;
  } snp_routed_s;

  // SS13.10.31 (p.13-433) scopes SnoopMe to the Atomics, where Table 13-6 has it
  // displace Excl on the shared REQ bit -- so the Excl bit of an Atomic is not an
  // Exclusive request and must not be read as one.
  function automatic logic hnf_atomic(chie_pkg::req_opcode_e op);
    return (op >= chie_pkg::REQ_ATOMICSTORE_ADD) && (op <= chie_pkg::REQ_ATOMICCOMPARE);
  endfunction

  // Table 4-40 (SS4.7.4 p.4-219): an AtomicStore completes with Comp, the other three
  // with CompData carrying SS4.2.5's (p.4-187, MUST) "original value at the addressed
  // location".
  function automatic logic hnf_atomic_returns_data(chie_pkg::req_opcode_e op);
    return (op >= chie_pkg::REQ_ATOMICLOAD_ADD) && (op <= chie_pkg::REQ_ATOMICCOMPARE);
  endfunction

  // SS2.10.5 (p.2-137): Size is the whole outbound payload, and an AtomicCompare
  // concatenates equal Compare and Swap halves -- so the element the operation reads,
  // writes and returns is half of it (Table 2-16 p.2-137).
  function automatic int unsigned hnf_atomic_elem_bytes(chie_pkg::req_opcode_e op,
                                                        chie_pkg::size_e       size);
    int unsigned n;
    n = 32'd1 << size;
    return (op == chie_pkg::REQ_ATOMICCOMPARE) ? (n >> 1) : n;
  endfunction

  // SS2.10.5 (p.2-137): "the Swap data address can be determined by inverting bit[n]
  // in the Compare data address where n = log2(Compare data size in bytes)" -- which
  // for a power-of-two element size is the offset XOR that size.
  function automatic logic [5:0] hnf_atomic_swap_off(logic [5:0]  cmp_off,
                                                    int unsigned elem_bytes);
    return cmp_off ^ elem_bytes[5:0];
  endfunction

  function automatic logic [63:0] hnf_atomic_mask(int unsigned nbytes);
    logic [63:0] m;
    m = 64'd0;
    for (int unsigned b = 0; b < 8; b = b + 1)
      if (b < nbytes)
        m[b*8 +: 8] = 8'hff;
    return m;
  endfunction

  function automatic logic [63:0] hnf_atomic_bswap(logic [63:0] v, int unsigned nbytes);
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
  function automatic logic [63:0] hnf_atomic_alu(chie_pkg::req_opcode_e op,
                                                 int unsigned          nbytes,
                                                 logic                 big_endian,
                                                 logic [63:0]          initial_data,
                                                 logic [63:0]          txn_data);
    logic [63:0]        m, a, b, res;
    logic signed [63:0] sa, sb;
    int unsigned        sh;

    m  = hnf_atomic_mask(nbytes);
    a  = (big_endian ? hnf_atomic_bswap(initial_data, nbytes) : initial_data) & m;
    b  = (big_endian ? hnf_atomic_bswap(txn_data,     nbytes) : txn_data)     & m;
    sh = 32'd64 - nbytes * 32'd8;
    sa = $signed(a << sh) >>> sh;
    sb = $signed(b << sh) >>> sh;

    case (op)
      chie_pkg::REQ_ATOMICSTORE_ADD,
      chie_pkg::REQ_ATOMICLOAD_ADD  : res = a + b;
      chie_pkg::REQ_ATOMICSTORE_CLR,
      chie_pkg::REQ_ATOMICLOAD_CLR  : res = a & ~b;
      chie_pkg::REQ_ATOMICSTORE_EOR,
      chie_pkg::REQ_ATOMICLOAD_EOR  : res = a ^ b;
      chie_pkg::REQ_ATOMICSTORE_SET,
      chie_pkg::REQ_ATOMICLOAD_SET  : res = a | b;
      chie_pkg::REQ_ATOMICSTORE_SMAX,
      chie_pkg::REQ_ATOMICLOAD_SMAX : res = (sb > sa) ? b : a;
      chie_pkg::REQ_ATOMICSTORE_SMIN,
      chie_pkg::REQ_ATOMICLOAD_SMIN : res = (sb < sa) ? b : a;
      chie_pkg::REQ_ATOMICSTORE_UMAX,
      chie_pkg::REQ_ATOMICLOAD_UMAX : res = (b > a) ? b : a;
      chie_pkg::REQ_ATOMICSTORE_UMIN,
      chie_pkg::REQ_ATOMICLOAD_UMIN : res = (b < a) ? b : a;
      chie_pkg::REQ_ATOMICSWAP      : res = b;
      default                       : res = a;
    endcase

    res = res & m;
    return big_endian ? hnf_atomic_bswap(res, nbytes) : res;
  endfunction

  // SS4.2.5 (p.4-186): AtomicCompare writes the Swap value only "if the values
  // match", which is a byte equality against the addressed location -- no arithmetic,
  // so SS2.10.5's Endian bit does not reach it.
  function automatic logic hnf_atomic_compare_eq(logic [127:0] initial_data,
                                                 logic [127:0] compare_data,
                                                 int unsigned  nbytes);
    logic eq;
    eq = 1'b1;
    for (int unsigned b = 0; b < 16; b = b + 1)
      if ((b < nbytes) && (initial_data[b*8 +: 8] != compare_data[b*8 +: 8]))
        eq = 1'b0;
    return eq;
  endfunction

  // The request this Home services a received one as. Each row is a permission
  // the spec gives the Home outright, so the MSHR decodes one opcode per class:
  //   ReadShared -> ReadNotSharedDirty: Table 4-33 (SS4.7.1 p.4-212) gives it the
  //     same rows plus SD_PD, and SS4.4.2 (p.4-196) lets SnpNotSharedDirty(Fwd)
  //     serve it.
  //   MakeReadUnique -> ReadUnique: Table 4-34 (p.4-213) permits CompData_UC and
  //     CompData_UD_PD for the Excl and non-Excl forms alike, and SS4.7.1
  //     (p.4-214) permits SnpUnique in place of SnpCleanInvalid. A failed
  //     MakeReadUnique(Excl) -> ReadNotSharedDirty instead: SS6.3.1 (p.6-289,
  //     MUST) forbids an Invalidating snoop, permits SnpNotSharedDirty(Fwd), and
  //     fixes the response at SC where other copies exist and UC/UD otherwise --
  //     ReadNotSharedDirty's own Table 4-33 rows.
  //   ReadPreferUnique -> ReadUnique: SS4.2.1 (p.4-164) provides the data Unique
  //     "unless another Request Node is currently performing an exclusive
  //     sequence using the same address", in which case -> ReadNotSharedDirty,
  //     Table 4-33's (p.4-212) CompData_SC row. SS4.4.2 (p.4-194) permits any
  //     snoop that reaches Table 4-6's (p.4-168) required peer state.
  //   CleanSharedPersist(Sep) -> CleanShared: Table 4-24 (SS4.4.2 p.4-195) gives all
  //     three SnpCleanShared and Table 4-38 (p.4-218) the same no-change rows; what
  //     the Home owes after it is hnf_persist_cmo()'s.
  //   MakeInvalid -> CleanInvalid: SS4.2.2 (p.4-170) only permits the Dirty copy
  //     to be discarded, Table 4-38 (p.4-218) gives both Comp_I, and SS4.4.2
  //     (p.4-196) permits SnpCleanInvalid for any invalidating snoop.
  //   WriteBackPtl -> WriteBackFull: Table 4-39 (SS4.7.3 p.4-219) gives both the
  //     same CompDBIDResp and the same final I. SS4.1 (p.4-160, MUST) leaves the
  //     merge of its partial data to the Completer of the WriteNoSnpPtl the Home
  //     forwards.
  //   WriteUnique*Stash -> WriteUnique*: SS7.2 (p.7-296) "Permitted to ignore
  //     the stash hint in the Write request and process the request as a
  //     regular WriteUnique"; Table 4-39 (p.4-219) shares their completion row.
  //   a Combined Write -> its write leg: SS4.2.4 (p.4-183) defines the fifteen as
  //     "for each Write request" plus a CMO, and lets the receiver "separate the
  //     write and the CMO request and process them separately" provided "the CMO
  //     request must be ordered behind the write". The write is serviced as the
  //     Write it names, and hnf_combined_write() is what makes the entry owe the
  //     CMO leg's CompCMO behind it.
  //   Write Zero -> the *Full write of the same address region: SS4.2.3 (p.4-176)
  //     is "write data value of zero without transferring data bytes", and
  //     Table 4-13 (p.4-178) gives it Size=64, so it is that write over a line the
  //     Home sources itself. Table 4-39 (p.4-219) shares the completion row -- the
  //     only delta is the WriteData response of None, which hnf_write_zero() below
  //     is what the MSHR reads to source the bytes and to withhold DWT.
  //   StashOnce* -> Evict: SS2.3.4 (p.2-71) permits the Home to ignore a Stash
  //     request, SS7.3 (p.7-297, MUST) still owes the Comp, Comp_I when the
  //     Home did not look up its cache; Table 4-38 gives Evict that same Comp_I
  //     from the same Invalid Requester, and Table 4-24 (p.4-195) snoops for
  //     neither. StashOnceSep* additionally owes the StashDone half, carried on
  //     hnf_serviced_as_stash_sep().
  // `excl_store_fail` is the PoC monitor's verdict on an Exclusive Store
  // (Table 6-1 p.6-287, "Address content modified"); `excl_seq_other_rn` is
  // whether another Request Node holds a monitor on the line.
  function automatic chie_pkg::req_opcode_e hnf_serviced_as(chie_pkg::req_opcode_e op,
                                                            logic excl,
                                                            logic excl_store_fail,
                                                            logic excl_seq_other_rn);
    // SS16.3.2 (p.16-479): "atomic operation execution can be supported at any point
    // within an interconnect", and this Home executes. Table 4-40 (SS4.7.4 p.4-219)
    // grants a DBID for the operand and leaves every peer cache Invalid, which is
    // WriteUniquePtl's own shape -- invalidating snoop, byte-enabled write data, the
    // line fetched and merged. What the operand is merged *with* is hnf_atomic_alu().
    if (hnf_atomic(op)) return chie_pkg::REQ_WRITEUNIQUEPTL;
    case (op)
      chie_pkg::REQ_READSHARED           : return chie_pkg::REQ_READNOTSHAREDDIRTY;
      chie_pkg::REQ_MAKEREADUNIQUE       : return (excl & excl_store_fail) ? chie_pkg::REQ_READNOTSHAREDDIRTY
                                                                           : chie_pkg::REQ_READUNIQUE;
      chie_pkg::REQ_READPREFERUNIQUE     : return excl_seq_other_rn ? chie_pkg::REQ_READNOTSHAREDDIRTY
                                                                    : chie_pkg::REQ_READUNIQUE;
      chie_pkg::REQ_MAKEINVALID          : return chie_pkg::REQ_CLEANINVALID;
      chie_pkg::REQ_CLEANSHAREDPERSIST,
      chie_pkg::REQ_CLEANSHAREDPERSISTSEP: return chie_pkg::REQ_CLEANSHARED;
      chie_pkg::REQ_WRITEUNIQUEFULLSTASH : return chie_pkg::REQ_WRITEUNIQUEFULL;
      chie_pkg::REQ_WRITEUNIQUEPTLSTASH  : return chie_pkg::REQ_WRITEUNIQUEPTL;
      chie_pkg::REQ_WRITEUNIQUEZERO      : return chie_pkg::REQ_WRITEUNIQUEFULL;
      chie_pkg::REQ_WRITENOSNPZERO       : return chie_pkg::REQ_WRITENOSNPFULL;
      chie_pkg::REQ_WRITENOSNPFULLCLEANSH,
      chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITENOSNPFULLCLEANINV       : return chie_pkg::REQ_WRITENOSNPFULL;
      chie_pkg::REQ_WRITENOSNPPTLCLEANSH,
      chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP,
      chie_pkg::REQ_WRITENOSNPPTLCLEANINV        : return chie_pkg::REQ_WRITENOSNPPTL;
      chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH,
      chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP : return chie_pkg::REQ_WRITEUNIQUEFULL;
      chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH,
      chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP  : return chie_pkg::REQ_WRITEUNIQUEPTL;
      chie_pkg::REQ_WRITEBACKPTL,
      chie_pkg::REQ_WRITEBACKFULLCLEANSH,
      chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEBACKFULLCLEANINV        : return chie_pkg::REQ_WRITEBACKFULL;
      chie_pkg::REQ_WRITECLEANFULLCLEANSH,
      chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP  : return chie_pkg::REQ_WRITECLEANFULL;
      chie_pkg::REQ_STASHONCESHARED,
      chie_pkg::REQ_STASHONCEUNIQUE,
      chie_pkg::REQ_STASHONCESEPSHARED,
      chie_pkg::REQ_STASHONCESEPUNIQUE   : return chie_pkg::REQ_EVICT;
      default                            : return op;
    endcase
  endfunction

  // SS6.3.1 (p.6-287, MUST): "ReadPreferUnique and MakeReadUnique do not use
  // RespErr to determine the pass or fail of an Exclusive operation", and
  // (p.6-288) EXOK "is not permitted in response to a MakeReadUnique(Excl)".
  function automatic logic hnf_excl_no_exok(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_READPREFERUNIQUE || op == chie_pkg::REQ_MAKEREADUNIQUE;
  endfunction

  // The Exclusive Loads and Stores the PoC monitor sees on top of the ones it
  // decodes itself: SS6.3 (p.6-286) names ReadShared and ReadPreferUnique as
  // Snoopable Exclusive Loads -- Table 6-1 (p.6-287) sets the monitor bit for
  // both -- and MakeReadUnique(Excl) as the Exclusive Store the monitor decides.
  function automatic logic hnf_excl_load_as(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_READSHARED || op == chie_pkg::REQ_READPREFERUNIQUE;
  endfunction
  function automatic logic hnf_excl_store_as(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_MAKEREADUNIQUE;
  endfunction

  // The requests that owe a Persist response on top of their completion. Table 4-38
  // (SS4.7.2 p.4-218) gives CleanSharedPersist a bare Comp and CleanSharedPersistSep
  // "Comp + Persist or CompPersist"; SS4.2.4 (p.4-182) has a Persistent CMO combined
  // with a write "treated as a CleanSharedPersistSep", so the six WriteCleanShPerSep
  // forms owe one too -- which SS2.3.2 Alt 2a2 (p.2-67) lets the Home fold into a
  // single CompPersist, exactly as the standalone request does.
  function automatic logic hnf_persist_response(chie_pkg::req_opcode_e op);
    case (op)
      chie_pkg::REQ_CLEANSHAREDPERSISTSEP,
      chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP : return 1'b1;
      default                                   : return 1'b0;
    endcase
  endfunction

  // The requests whose completion has to reach the Point of Persistence. SS4.2.2
  // (p.4-171, MUST) makes that a downstream obligation for a Home that is not the
  // PoP, and SS16.1 (p.16-471, MUST) fixes the shape when the Subordinate's own
  // CleanSharedPersistSep support is not declared, which SS16.1 (p.16-470) says to
  // assume: a substituted CleanSharedPersist whose Comp the Home's own Persist
  // waits on.
  function automatic logic hnf_persist_cmo(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_CLEANSHAREDPERSIST || hnf_persist_response(op);
  endfunction

  // Table 4-17's (SS4.2.4 p.4-182) fifteen Combined Writes, whose CMO leg SS2.3.2
  // (p.2-58/p.2-66) answers with CompCMO -- enumerated rather than taken as an opcode
  // range, the gaps inside that range being RESERVED. The six persistent forms fold
  // that CompCMO into the CompPersist hnf_persist_response() elects.
  function automatic logic hnf_combined_write(chie_pkg::req_opcode_e op);
    case (op)
      chie_pkg::REQ_WRITENOSNPFULLCLEANSH,
      chie_pkg::REQ_WRITENOSNPFULLCLEANINV,
      chie_pkg::REQ_WRITENOSNPFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITENOSNPPTLCLEANSH,
      chie_pkg::REQ_WRITENOSNPPTLCLEANINV,
      chie_pkg::REQ_WRITENOSNPPTLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEUNIQUEFULLCLEANSH,
      chie_pkg::REQ_WRITEUNIQUEFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEUNIQUEPTLCLEANSH,
      chie_pkg::REQ_WRITEUNIQUEPTLCLEANSHPERSEP,
      chie_pkg::REQ_WRITEBACKFULLCLEANSH,
      chie_pkg::REQ_WRITEBACKFULLCLEANINV,
      chie_pkg::REQ_WRITEBACKFULLCLEANSHPERSEP,
      chie_pkg::REQ_WRITECLEANFULLCLEANSH,
      chie_pkg::REQ_WRITECLEANFULLCLEANSHPERSEP : return 1'b1;
      default                                   : return 1'b0;
    endcase
  endfunction

  // Table 4-39 (p.4-219) gives a Write Zero a WriteData response of None, so the
  // Home sources the line: SS4.2.3's (p.4-176) "write data value of zero without
  // transferring data bytes".
  function automatic logic hnf_write_zero(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_WRITEUNIQUEZERO || op == chie_pkg::REQ_WRITENOSNPZERO;
  endfunction

  // The two reads whose own snoop this Home sends, told from the opcode as sent
  // because hnf_serviced_as() folds both into another row. SS4.4.2 (p.4-196) permits
  // "SnpNotSharedDirty or SnpShared or SnpClean for ReadNotSharedDirty, ReadShared,
  // and ReadClean" interchangeably -- Table 4-42 (SS4.8.1 p.4-223) gives the three
  // one row set -- but their forwarding twins are not: SnpSharedFwd is permitted for
  // ReadShared alone, because Table 4-53 (SS4.8.3 p.4-234) lets it forward SD_PD and
  // Table 4-33 (SS4.7.1 p.4-212) gives only ReadShared that row.
  function automatic logic hnf_read_shared(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_READSHARED;
  endfunction

  // SS4.3 (p.4-192): "Home is expected to use SnpPreferUniqueFwd or SnpPreferUnique
  // in response to ReadPreferUnique". Sent where this Home serves the line Shared --
  // SS4.2.1 (p.4-164)'s "another Request Node is currently performing an exclusive
  // sequence" -- because SS4.8.3 (p.4-237) lets the Snoopee choose whether to
  // invalidate and says "the Snoop response must be inspected" to find out, which a
  // directory written before that response cannot do. Serving the line Unique keeps
  // SnpUnique, whose Table 4-43 (p.4-224) rows SnpPreferUnique shares there anyway.
  function automatic logic hnf_read_prefer_unique(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_READPREFERUNIQUE;
  endfunction

  // Table 13-15 (SS13.10 p.13-425) does not put every forwarding snoop one nibble
  // above its own twin: SnpPreferUniqueFwd (0x16) is one above SnpPreferUnique
  // (0x15), where the other five are +0x10.
  function automatic chie_pkg::snp_opcode_e hnf_snp_fwd_of(chie_pkg::snp_opcode_e op);
    case (op)
      chie_pkg::SNP_SNPPREFERUNIQUE   : return chie_pkg::SNP_SNPPREFERUNIQUEFWD;
      chie_pkg::SNP_SNPSHARED         : return chie_pkg::SNP_SNPSHAREDFWD;
      chie_pkg::SNP_SNPCLEAN          : return chie_pkg::SNP_SNPCLEANFWD;
      chie_pkg::SNP_SNPONCE           : return chie_pkg::SNP_SNPONCEFWD;
      chie_pkg::SNP_SNPNOTSHAREDDIRTY : return chie_pkg::SNP_SNPNOTSHAREDDIRTYFWD;
      chie_pkg::SNP_SNPUNIQUE         : return chie_pkg::SNP_SNPUNIQUEFWD;
      default                         : return op;
    endcase
  endfunction

  // The CopyBack whose data is partial: Table 4-16 (SS4.2.3 p.4-181) gives a UDP
  // line WriteBackPtl and nothing else.
  function automatic logic hnf_write_partial(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_WRITEBACKPTL;
  endfunction

  // Table 4-38 (SS4.7.2 p.4-218): StashOnceSep* completes with "Comp + StashDone
  // or CompStashDone"; this Home sends the combined form.
  function automatic logic hnf_serviced_as_stash_sep(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_STASHONCESEPSHARED || op == chie_pkg::REQ_STASHONCESEPUNIQUE;
  endfunction

  // The six requests that carry a stash hint: Table 7-3 (SS7.5.1 p.7-300) gives
  // each a StashNID/StashNIDValid, and Table 7-1 (SS7.1.1 p.7-295) the snoop its
  // target receives.
  function automatic logic hnf_stash_req(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_WRITEUNIQUEFULLSTASH ||
           op == chie_pkg::REQ_WRITEUNIQUEPTLSTASH  ||
           op == chie_pkg::REQ_STASHONCESHARED      ||
           op == chie_pkg::REQ_STASHONCEUNIQUE      ||
           op == chie_pkg::REQ_STASHONCESEPSHARED   ||
           op == chie_pkg::REQ_STASHONCESEPUNIQUE;
  endfunction

  // The Stash requests that carry no write data. SS7.3 (p.7-297) snoops only the
  // named target for these -- a stash hint invalidates nothing, so a peer holding
  // the line is left alone -- where SS4.4.1 (p.4-194, MUST) has a WriteUnique*Stash
  // additionally invalidate "all Non-stash target Request Nodes that have a copy".
  function automatic logic hnf_stash_dataless(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_STASHONCESHARED    ||
           op == chie_pkg::REQ_STASHONCEUNIQUE    ||
           op == chie_pkg::REQ_STASHONCESEPSHARED ||
           op == chie_pkg::REQ_STASHONCESEPUNIQUE;
  endfunction

  // Table 13-29 (SS13.10.33 p.13-433): 0b000 No Read, 0b001 Read, and 0b010-0b111
  // Reserved -- so the field has two readings and neither "bit 0" nor "non-zero"
  // is one of them.
  function automatic logic hnf_data_pull(logic [2:0] f);
    return f == 3'b001;
  endfunction

  // Table 7-2 (SS7.1.1 p.7-295): the Read a Data Pull implies, "which is how the
  // Home must treat it" (restated per-snoop at SS4.8.2 p.4-227/4-228).
  function automatic chie_pkg::req_opcode_e hnf_stash_pull_read_of(chie_pkg::snp_opcode_e op);
    return (op == chie_pkg::SNP_SNPSTASHSHARED) ? chie_pkg::REQ_READNOTSHAREDDIRTY
                                                : chie_pkg::REQ_READUNIQUE;
  endfunction

  // Table 7-1 (SS7.1.1 p.7-295): the snoop the Stash target receives. SS4.4.2
  // (p.4-196) expressly permits sending it "to the target RN ... if the target RN
  // does not have the cache line", which is what makes it a stash at all.
  function automatic chie_pkg::snp_opcode_e hnf_stash_snp_of(chie_pkg::req_opcode_e op);
    case (op)
      chie_pkg::REQ_WRITEUNIQUEFULLSTASH : return chie_pkg::SNP_SNPMAKEINVALIDSTASH;
      chie_pkg::REQ_WRITEUNIQUEPTLSTASH  : return chie_pkg::SNP_SNPUNIQUESTASH;
      chie_pkg::REQ_STASHONCEUNIQUE,
      chie_pkg::REQ_STASHONCESEPUNIQUE   : return chie_pkg::SNP_SNPSTASHUNIQUE;
      chie_pkg::REQ_STASHONCESHARED,
      chie_pkg::REQ_STASHONCESEPSHARED   : return chie_pkg::SNP_SNPSTASHSHARED;
      default                            : return chie_pkg::SNP_SNPLCRDRETURN;
    endcase
  endfunction

endpackage

`endif
