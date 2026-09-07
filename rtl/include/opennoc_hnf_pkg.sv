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
  //   MakeInvalid -> CleanInvalid: SS4.2.2 (p.4-170) only permits the Dirty copy
  //     to be discarded, Table 4-38 (p.4-218) gives both Comp_I, and SS4.4.2
  //     (p.4-196) permits SnpCleanInvalid for any invalidating snoop.
  //   WriteUnique*Stash -> WriteUnique*: SS7.2 (p.7-296) "Permitted to ignore
  //     the stash hint in the Write request and process the request as a
  //     regular WriteUnique"; Table 4-39 (p.4-219) shares their completion row.
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
    case (op)
      chie_pkg::REQ_READSHARED           : return chie_pkg::REQ_READNOTSHAREDDIRTY;
      chie_pkg::REQ_MAKEREADUNIQUE       : return (excl & excl_store_fail) ? chie_pkg::REQ_READNOTSHAREDDIRTY
                                                                           : chie_pkg::REQ_READUNIQUE;
      chie_pkg::REQ_READPREFERUNIQUE     : return excl_seq_other_rn ? chie_pkg::REQ_READNOTSHAREDDIRTY
                                                                    : chie_pkg::REQ_READUNIQUE;
      chie_pkg::REQ_MAKEINVALID          : return chie_pkg::REQ_CLEANINVALID;
      chie_pkg::REQ_WRITEUNIQUEFULLSTASH : return chie_pkg::REQ_WRITEUNIQUEFULL;
      chie_pkg::REQ_WRITEUNIQUEPTLSTASH  : return chie_pkg::REQ_WRITEUNIQUEPTL;
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

  // Table 4-38 (SS4.7.2 p.4-218): StashOnceSep* completes with "Comp + StashDone
  // or CompStashDone"; this Home sends the combined form.
  function automatic logic hnf_serviced_as_stash_sep(chie_pkg::req_opcode_e op);
    return op == chie_pkg::REQ_STASHONCESEPSHARED || op == chie_pkg::REQ_STASHONCESEPUNIQUE;
  endfunction

endpackage

`endif
