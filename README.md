# CHI-OpenNoC

An open-source **AMBA CHI (Issue E.b)** interconnect, in synthesisable SystemVerilog.

[![Lint](https://github.com/10x-Engineers/CHI-OpenNoC/actions/workflows/lint.yml/badge.svg)](https://github.com/10x-Engineers/CHI-OpenNoC/actions/workflows/lint.yml)
[![Licence: Mulan PSL v2](https://img.shields.io/badge/licence-Mulan%20PSL%20v2-blue.svg)](LICENSE)
[![Spec: CHI E.b](https://img.shields.io/badge/spec-AMBA%20CHI%20Issue%20E.b-informational.svg)](https://developer.arm.com/documentation/ihi0050/latest/)

CHI is the coherent fabric protocol behind essentially every modern Arm-class SoC,
and until now there has been no open implementation of it to build on, read, or
test against. This repository is one: four CHI nodes and a crosspoint, with no
vendor macros, no encrypted blocks and no licence server between you and the
source.

```
        RN-I  ──AXI4──┐                                    ┌── AXI4──  memory
   (AXI manager)      │                                    │
                      ├─ CHI ─┤ crosspoint ├─ CHI ─┤  HN-F ─┴─ CHI ─┤  SN-F
        RN-F  ────────┘        (mesh / ring)          HN-I ───AXI4──┘
     (yours)
```

| | |
| :-- | :-- |
| **Protocol** | AMBA CHI Issue E.b (Arm IHI 0050E.b) |
| **Language** | SystemVerilog throughout — packed structs, enums, ANSI ports |
| **Nodes** | HN-F (coherent Home + L3 + snoop filter), HN-I (I/O Home), RN-I (AXI4→CHI bridge), SN-F (CHI→AXI4 memory Subordinate), mesh/ring crosspoints |
| **Dependencies** | none — all memories are inferred arrays; no technology cells, no third-party IP |
| **Licence** | Mulan PSL v2 |

> **This is 10xEngineers' fork of [RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC)**,
> taken at `4f57dda` (upstream tip, 2025-06-25). The original design is the work of
> the Beijing Institute of Open Source Chip and its copyright headers are kept.
> Protocol fixes found by driving the design with a CHI verification IP land here,
> and upstream's issue backlog is mirrored here too.

---

## Table of contents

- [Status](#status)
- [Quick start](#quick-start)
- [Building a system](#building-a-system)
- [Configuration](#configuration)
- [The nodes](#the-nodes)
- [CHI feature support](#chi-feature-support)
- [Verification](#verification)
- [Repository layout](#repository-layout)
- [Contributing](#contributing)
- [Licence](#licence)

---

## Status

**Simulation-proven, not silicon-proven.** Read this section before you plan
anything around it.

| | |
| :-- | :-- |
| ✅ **Elaborates clean** | Verilator ≥ 5.0 lints all four nodes with zero errors and zero `ALWNEVER`/`COMBDLY`/`LATCH`/`CASEINCOMPLETE` warnings, gated in CI on every push and PR. The lint also compiles the design's own `ASSERT_CHECKER_ON` / `DISPLAY_FATAL` blocks, and they now **run** as well: the CHI VIP builds every OpenNoC target with `+define+DISPLAY_FATAL+ASSERT_CHECKER_ON`, so an invariant the design states about itself is checked on every regression rather than only parsed. |
| ✅ **Protocol-verified against a CHI VIP** | Every node has been driven by an independent Issue-E.b verification IP with an [AMBA CHI Issue E.b PDF] as its oracle. Over 90 protocol defects have been found and fixed this way; see [Verification](#verification). |
| ✅ **SystemVerilog throughout** | Flits and AXI channels are packed structs with enums for the encoded fields; ANSI port lists; no `reg`, no bare `always @`. See [Types, not bit ranges](#types-not-bit-ranges). |
| ⚠️ **Not synthesis-hardened** | SRAMs are behavioural arrays with an `FPGA_MEMORY` swap-in hook. No timing constraints, no lint against a synthesis ruleset, no power intent, no DFT. |
| ⚠️ **Feature-incomplete against the spec** | Atomics, MTE, MPAM and DVM are not implemented, and no node stashes — the HN-F completes a Stash request conformantly, without acting on the hint. The [support matrix](#chi-feature-support) says exactly what is and is not, per node, with the decode site for each claim. |
| ⚠️ **Parameter space is narrow** | The defaults are the only combination that is regularly exercised. See [Configuration](#configuration) for the specific ones that are load-bearing. |

The [open issue tracker](https://github.com/10x-Engineers/CHI-OpenNoC/issues) is
the authoritative list of known defects. Nothing is hidden behind a "known
limitations" paragraph that nobody updates.

---

---

## Quick start

### Prerequisites

| Tool | Needed for | Notes |
| :-- | :-- | :-- |
| Verilator ≥ 5.0 | `tools/lint.sh` | The only licence-free step. What CI runs. |
| Xcelium **or** VCS | `tools/link_check.sh`, `rtl/Makefile` | Verilator 5.048 segfaults constructing the HN-F model (in `VL_MURMUR64_HASH`), so behavioural simulation needs a commercial simulator. |
| Python 3 + `jinja2` | the topology generators | `pip install jinja2`. There is no `requirements.txt`. |

### Lint every node

```bash
./tools/lint.sh              # all four nodes
./tools/lint.sh hnf snf      # just the ones you name
```

Fails on any error, or on a warning class that indicates a real design mistake
(never-executing `always` blocks, blocking assignments in sequential logic,
inferred latches, incomplete cases). Width warnings are counted and printed but
not gated.

### Run the link-activation conformance bench

```bash
./tools/link_check.sh              # Xcelium
SIM=vcs ./tools/link_check.sh      # VCS
```

Drives `hnf.sv` through the CHI Chapter 14 `LINKACTIVE` state machine — STOP →
ACTIVATE → RUN → DEACTIVATE → STOP — and checks the L-Credit and flit rules that
hold in each state. Prints `tb_hnf_link: PASSED`.

### Run the HN-F regression

```bash
cd rtl
make com                     # compile (VCS)
make sim                     # run
make run_dve                 # open the waveform viewer
make clean
```

`make sim` replays 136 recorded stimulus/response cases from `rtl/case/` against
`hnf.sv` and self-checks every response flit. `TOP_TB=tb_rni make com sim` runs the
RN-I's AXI-side bench instead.

> The HN-F flow is the one that works out of the box. `rtl/tb/tb_snf.sv` is in the
> filelist but has no Makefile target — `TOP_TB=tb_snf` produces an option-less
> `vcs` invocation. Fixing that is [#101](https://github.com/10x-Engineers/CHI-OpenNoC/issues/101).

---

---

## Building a system

A crosspoint instance carries **one** CHI channel. Four of them make a routing
node (`tools/mesh_generator/chi_xp_node.sv`, `tools/ring_generator/chi_ring_node.sv`),
and the generators stamp out a whole fabric of those:

```bash
cd tools/mesh_generator     # the generators load their Jinja template from ./template,
./mesh_gen.py -f mesh_2x2.json      # so they must be run from their own directory

cd ../ring_generator
./ring_gen.py -f ring_8.json
```

Each writes a `mesh_wrapper_{X}x{Y}.sv` / `ring_wrapper_{N}.sv` into the current
directory. To use one, take the wrapper plus `chi_xp_node.sv` (or
`chi_ring_node.sv`) and `rtl/misc/chi_xp_channel.sv` (or `chi_ring_channel.sv`).

The JSON schema is documented in `tools/mesh_generator/README.md`; `mesh_2x2.json`
and `ring_8.json` are worked examples.

---

---

## Configuration

Every node takes its parameters from a macro in `rtl/include/*_param.svh` rather
than an inline list:

```verilog
module hnf `HNF_PARAM ( ... );      // the parameter list lives in hnf_param.svh
```

so you override them the usual way at instantiation, and `` `HNF_PARAM_INST ``
passes them down a hierarchy.

### The parameters that matter

| Parameter | Default | Notes |
| :-- | --: | :-- |
| `CHIE_REQ_ADDR_WIDTH_PARAM` | 44 | CHI request address width. |
| `CHIE_NID_WIDTH_PARAM` | `chie_pkg::NID_WIDTH` (7) | NodeID width. Section 16.1 allows 7..11; only the crosspoint range-checks it. |
| `CHIE_DATA_WIDTH_PARAM` | 256 | CHI data width. **Not currently configurable** — the beat-count and DataID logic assumes a 64-byte line is exactly two packets, which only holds at 256. Section 16.1 makes 128 and 512 legal too — [#170](https://github.com/10x-Engineers/CHI-OpenNoC/issues/170). |
| `CHIE_BE_WIDTH_PARAM` | `chie_pkg::BE_WIDTH` (32) | Derived as `DATA_WIDTH/8`; no longer settable independently. |
| `CHIE_POISON_WIDTH_PARAM` | `chie_pkg::POISON_WIDTH` (4) | Derived as `DATA_WIDTH/64`; no longer settable independently. |
| `CHIE_DATACHECK_WIDTH_PARAM` | `chie_pkg::DATACHECK_WIDTH` (32) | Derived as `DATA_WIDTH/8`; no longer settable independently. |
| `AXI4_AXDATA_WIDTH_PARAM` | 128 | AXI data width on HN-I / RN-I / SN-F. |
| `AXI4_PA_WIDTH_PARAM` | `opennoc_rni_pkg::PA_WIDTH` (44) on RN-I, **32** on HN-I and SN-F | AXI address width. Deliberately different: RN-I is a manager port, the others face memory. |
| `HNF_MSHR_RNF_NUM_PARAM` + `RNF_NID_LIST_PARAM` | 4, `{48,16,40,8}` | How many coherent Requesters the Home serves, and their NodeIDs. |
| `HNF_L3_CACHE_SIZE_PARAM` / `HNF_L3_WAY_NUM_PARAM` | 4096 KB / 16 | L3 geometry. Line size is fixed at 64 B. |
| `HNF_SF_ENTRIES_NUM_PARAM` / `HNF_SF_WAY_NUM_PARAM` | 131072 / 16 | Snoop filter geometry. |
| `*_MSHR_ENTRIES_NUM_PARAM` | 32 | Outstanding transactions per node. |
| `XP_LCRD_NUM_PARAM` | 15 | Maximum outstanding L-Credits per channel. Section 14.2.1 caps this at 15; the counters are 4 bits wide, so a larger value will not fit. |

### Types, not bit ranges

Flits and AXI channels are **packed structs**, not vectors sliced by macro:

```systemverilog
input  chie_pkg::req_flit_s  rxreqflit;          // not [`CHIE_REQ_FLIT_RANGE]
assign rxreq_valid_s0 = rxreqflit.opcode != chie_pkg::REQ_REQLCRDRETURN;
```

`rtl/include/chie_pkg.sv` carries the REQ/RSP/DAT/SNP layouts, the opcode enums
for each channel, and enums for RespErr, Resp, Order, Size and MemAttr. Fields the
spec overlays on one another — Table 13-6's Excl/SnoopMe, section 13.10.24's SnpAttr/DoDWT,
section 13.10.54's DataSource/FwdState/DataPull, section 13.10.11's FwdTxnID/StashLPID/VMIDExt —
are `union packed`, which is what makes them one set of bits with several names
rather than several fields.

Three consequences worth knowing:

- **Field access is tool-checked.** A TxnID slice can no longer be written with a
  DBID value, and an opcode constant cannot be compared against another channel's
  encoding — the enums are distinct types.
- **The section 16.1 widths are seeded by `` `define ``.** `CHIE_NID_WIDTH`,
  `CHIE_REQ_ADDR_WIDTH` and `CHIE_DATA_WIDTH` default in `chie_pkg.sv` and are
  overridable at compile time; each node's `*_param.svh` derives its own
  `CHIE_*_WIDTH_PARAM` from them, so a node cannot disagree with the package.
- **RSVDC is present only when declared.** Section 13.10.56 makes the field optional
  and its width implementation defined, and a packed struct cannot hold a zero-width
  member — so `CHIE_REQ_RSVDC_WIDTH` / `CHIE_DAT_RSVDC_WIDTH` being *defined* is what
  puts it in the layout, at that width. `chie_flit_rsvdc_check` holds each node's
  parameter to the package rather than letting the layout silently shift.

`chi_chan_if.sv` bundles one channel's link-layer signals (flit, FLITV, FLITPEND,
LCRDV) with `tx`/`rx` modports. Node **port lists stay flat** — an integrator wires
those — so the interface is for use inside a node.

### Sharp edges

These are real, and none of them is checked at elaboration:

- **The AXI address width differs by node** — 44 bits on RN-I (a manager port
  carrying the full PA) against 32 on HN-I and SN-F (memory-side ports). That
  one is deliberate: they are different buses. The **CHI** widths no longer
  diverge — every node's `CHIE_*_WIDTH_PARAM` default now derives from
  `chie_pkg`, so four nodes on one link can no longer default to different flit
  widths the way they used to (RN-I once defaulted NodeID to 11 against the
  others' 7, and Poison/DataCheck to 0 against 4/32).
- **`*_MSHR_ENTRIES_WIDTH_PARAM` must be kept equal to `$clog2` of its
  `_NUM_PARAM` by hand.** Nothing checks it.
- **The HN-F's QoS pool sizes are baked into a `HNF_MSHR_ENTRIES_NUM_PARAM == 32`
  ternary** (`hnf_defines.svh`'s `QOS_*_POOL_NUM`), so any value other than 32 silently gets
  the 64-entry pool numbers.
- **The Back-Invalidate Queue depth is not a parameter** —
  `localparam BIQ_NUM = 8` in `hnf_cache_pipeline.sv`.
- **The generated mesh and ring wrappers pin NodeID width to 7** and X/Y IDs to 3
  bits; only the hand-written `chi_xp_node.sv` / `chi_ring_node.sv` forward
  `CHIE_NID_WIDTH_PARAM`.

### FPGA and ASIC memories

The four HN-F SRAM wrappers (`hnf_tag_sram.sv`, `hnf_data_sram.sv`, `hnf_sf_sram.sv`,
`hnf_lru_sram.sv`) each carry an `` `ifndef FPGA_MEMORY `` / `` `else `` pair. The
default branch is a behavioural inferred array; the `FPGA_MEMORY` branch is the
swap-in point for a block-RAM primitive or a compiled macro.
`` `HNF_DELAY_ONE_CYCLE `` adds a registered read output for a pipelined macro.
Both switches are commented out in `rtl/include/hnf_defines.svh`.

---

---

## The nodes

Each node is a standalone Verilog module with a CHI port and, where it bridges,
one AXI4 port. There is no top-level SoC wrapper — you instantiate what you need.

| Node | Top module | CHI channels | Other port | Role |
| :-- | :-- | :-- | :-- | :-- |
| **HN-F** | `rtl/src/hnf/hnf.sv` | RX REQ/RSP/DAT, TX REQ/RSP/SNP/DAT | — | Coherent Home. Point of Coherency **and** Point of Serialisation: L3 cache, snoop filter, snoop generation, exclusive monitor, and a downstream REQ port to an SN-F. |
| **HN-I** | `rtl/src/hni/hni.sv` | RX REQ/RSP/DAT, TX RSP/DAT | AXI4 **manager** | I/O Home. Non-coherent: no snoop port, no cache. Terminates Non-snoopable traffic onto AXI4, with a 16-region address decode. |
| **RN-I** | `rtl/src/rni/rni.sv` | TX REQ/RSP/DAT, RX RSP/DAT | AXI4 **subordinate** | Requester bridge. Turns AXI4 bursts into CHI requests, segmented at 64-byte and 4 KB boundaries. No snoop port — it is an I/O Requester, not an RN-F. |
| **SN-F** | `rtl/src/snf/snf.sv` | RX REQ/DAT, TX RSP/DAT | AXI4 **manager** | Memory Subordinate. Terminates the Home's downstream reads and writes onto AXI4. |
| **Crosspoint** | `rtl/misc/chi_xp_channel.sv`, `chi_ring_channel.sv` | one channel each | — | Routing element, **one CHI channel per instance**. Four are assembled into a node by `tools/*/chi_*_node.sv`; a whole mesh or ring is assembled by the generators. |

**There is no RN-F in this repository.** The HN-F is built to serve coherent
Request Nodes with caches — that is the whole point of its snoop filter and snoop
generation — but the RN-F itself is yours to bring. `HNF_MSHR_RNF_NUM_PARAM` and
`RNF_NID_LIST_PARAM` are how you tell the Home about them.

---

---

## CHI feature support

Every claim below is read from the decode site in the RTL and cites it, so it can
be checked against the source rather than taken on trust — and so that changing
one of those sites is visibly a change to this table.

| Status | Meaning |
| :---: | :--- |
| 🟢 | **Serviced** — decoded into real behaviour and completed. |
| 🟡 | **Partial** — some of the family is serviced, the rest is not. |
| ⚪ | **Error-completed** — not implemented, but answered conformantly: a Non-data Error per CHI E.b section 9.1, with section 9.4.4's transaction structure kept intact, so the grant, the write data and the read data still happen. A Requester sees a clean failure, not a hang. |
| 🔴 | **Not implemented, and not answered** — the request is accepted onto the link and nothing comes back. |
| ⬛ | **Correctly given no response** — section 4.5.1's own two exceptions (`PrefetchTgt`, `PCrdReturn`), and Link-layer credit return, which is not a transaction. |
| — | Not applicable to that node's role. |

Most of the ⚪ at the HN-I is what Table B-1 (p.B-492) itself provides for: those
requests reach an HN-I as its **permitted**, not expected, target, and the table
says a permitted target "must complete the transaction in a protocol compliant
manner, this might require the use of an error response". The ⚪ that is a real
gap rather than a declaration is the Atomics, which Table B-1 makes **expected**
at both Homes — [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68).

### Summary

| Node | Requests serviced | Everything else |
| :--- | ---: | :--- |
| **SN-F** | 16 | ⚪ NDERR catch-all — `snf_mshr.sv`'s `rxreq_err_s0` |
| **HN-I** | 24 | ⚪ NDERR catch-all, shaped per request class — `hni_mshr.sv`'s `rxreq_err_s0` |
| **HN-F** | 51, plus 9 snoops and their 5 forwarding forms | ⚪ NDERR catch-all — `hnf_mshr_ctl.sv`'s `op_err*` classes |
| **RN-I** | generates 4 | it is a Requester — see [What the RN-I generates](#what-the-rn-i-generates) |

All three Completers now answer everything they do not implement. The HN-F count
is the 21 opcodes `hnf_mshr_ctl.sv` decodes in its own right — `SnoopFilterEvict`
among them, whose encoding its internal back-invalidate shares
(`hnf_link_rxreq_parse.sv`'s back-invalidate-queue injection) — plus the thirty
`opennoc_hnf_pkg.sv`'s `hnf_serviced_as()` maps onto one of those twins, each
mapping a permission the spec gives the Home outright, cited beside it. Two of
them, MakeReadUnique(Excl) and ReadPreferUnique, pick their twin from the PoC
monitor's same-cycle verdict. What is left over is the 18 Atomics, `DVMOp` and
`ReadNoSnpSep`.

### Request opcodes

| Request | SN-F | HN-I | HN-F |
| :--- | :---: | :---: | :---: |
| `ReadNoSnp` | 🟢 | 🟢 | 🟢 |
| `ReadNoSnpSep` | 🟢 | — | — Table B-1 (p.B-492) gives it no Requester row: a Home only ever issues it, so a Home receiving one answers section 9.1's NDERR |
| `ReadOnce` | — | 🟢 | 🟢 |
| `ReadOnceCleanInvalid`, `ReadOnceMakeInvalid` | — | ⚪ | 🟢 ReadOnce's non-allocating data return with `SnpUnique` to every holder (Table 4-24 p.4-194) and the Dirty copy written back (section 4.2.1 p.4-163) |
| `ReadClean`, `ReadNotSharedDirty`, `ReadUnique` | — | 🟢 | 🟢 |
| `ReadShared` | — | ⚪ | 🟢 served as `ReadNotSharedDirty` — Table 4-33 (p.4-212) gives it those rows, section 4.4.2 (p.4-196) permits that snoop |
| `ReadPreferUnique`, `MakeReadUnique` | — | ⚪ | 🟢 served as `ReadUnique` — Table 4-34 (p.4-213) permits `CompData_UC`/`_UD_PD` for MakeReadUnique, section 4.7.1 (p.4-214) the `SnpUnique`; a failed MakeReadUnique(Excl) and a ReadPreferUnique while another Requester's exclusive sequence is live take `ReadNotSharedDirty`'s Shared path (section 6.3.1 p.6-289, section 4.2.1 p.4-164); neither carries EXOK (section 6.3.1 p.6-287) |
| `WriteNoSnpFull`, `WriteNoSnpPtl` | 🟢 | 🟢 | 🟢 |
| `WriteNoSnpZero` | 🟢 | 🟢 | 🟢 served as `WriteNoSnpFull` over a line of zeros the Home sources — §4.2.3 (p.4-176), Table 4-39 (p.4-219) |
| `WriteUniqueFull`, `WriteUniquePtl` | — | 🟢 | 🟢 |
| `WriteUniqueZero` | ⚪ | ⚪ | 🟢 served as `WriteUniqueFull` over a line of zeros the Home sources — §4.2.3 (p.4-176), Table 4-39 (p.4-219) |
| `WriteBackFull`, `WriteCleanFull`, `WriteEvictFull` | — | 🟢 | 🟢 |
| `WriteEvictOrEvict` | — | ⚪ | 🟢 on section 2.3.2's (p.2-55) `CompDBIDResp` alternative |
| `WriteBackPtl` | — | ⚪ | 🟢 serviced as `WriteBackFull`, never allocated into the L3 (no byte enables there) and forwarded to the Subordinate as `WriteNoSnpPtl` |
| `WriteUniqueFullStash`, `WriteUniquePtlStash` | — | ⚪ | 🟢 served as `WriteUniqueFull`/`Ptl` — section 7.2 (p.7-296) permits ignoring the hint |
| `StashOnceShared`, `StashOnceUnique`, `StashOnceSepShared`, `StashOnceSepUnique` | — | ⚪ | 🟢 completed `Comp_I` / `CompStashDone` without stashing — section 2.3.4 (p.2-71), section 7.3 (p.7-297), Table 4-38 (p.4-218) |
| `WriteNoSnp*` Combined Writes (6) | 🟢 | 🟢 | 🟢 write leg + `CompCMO`; the two `*CleanShPerSep` fold their `CompCMO` and Persist into one `CompPersist` (section 2.3.2 Alt 2a2, p.2-67) |
| `WriteUnique*` / `WriteBack*` / `WriteClean*` Combined Writes (9) | ⚪ | ⚪ | 🟢 write leg + `CompCMO`; the four `*CleanShPerSep` fold their `CompCMO` and Persist into one `CompPersist` and never allocate into the L3, section 4.2.2 (p.4-171) sending them downstream |
| `CleanShared`, `CleanInvalid` | 🟢 | 🟢 | 🟢 |
| `MakeInvalid` | 🟢 | 🟢 | 🟢 served as `CleanInvalid` — section 4.2.2 (p.4-170) only permits the Dirty copy to be dropped, Table 4-38 (p.4-218) gives both `Comp_I` |
| `CleanSharedPersist`, `CleanSharedPersistSep` | 🟢 | 🟢 | 🟢 serviced as `CleanShared`, with a `CleanSharedPersist` sent downstream and the completion held for the Subordinate's `Comp` (section 16.1, p.16-471) |
| `CleanUnique`, `MakeUnique`, `Evict` | — | ⚪ | 🟢 |
| Atomics — `AtomicStore`, `AtomicLoad`, `AtomicSwap`, `AtomicCompare` | ⚪ | ⚪ | ⚪ [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) — `DBIDResp` then a `CompData` NDERR over the returned extent for the three that return data (section 2.3.3, section 4.2.5, section 9.4.4) |
| `SnoopFilterEvict` | ⚪ | ⚪ | 🟢 |
| `DVMOp` | ⚪ | ⚪ | ⚪ [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) |
| `PrefetchTgt`, `PCrdReturn` | ⬛ | ⬛ | ⬛ |
| `ReqLCrdReturn` | ⬛ | ⬛ | ⬛ |

Decode sites: `snf_mshr.sv`'s `rxreq_rd_s0` / `rxreq_wr_s0` / `rxreq_cmo_s0`,
`hni_mshr.sv`'s `rxreq_rd_s0` / `rxreq_wrf_s0` / `rxreq_wrp_s0` / `rxreq_cmo_s0`,
and for the HN-F `opennoc_hnf_pkg.sv`'s `hnf_serviced_as()` followed by the `op_*`
chain in `hnf_mshr_ctl.sv`.

### Snoops — HN-F only

An SN-F and an HN-I hold no cached copy and are no Point of Coherency (section 1.6), so
neither issues a snoop and neither has a SNP port.

| Snoop | | Where |
| :--- | :---: | :--- |
| `SnpOnce`, `SnpClean`, `SnpNotSharedDirty`, `SnpUnique` | 🟢 | `hnf_mshr_ctl.sv`'s `l3_opcode_decode_comb_logic` |
| `SnpCleanShared`, `SnpCleanInvalid`, `SnpMakeInvalid` | 🟢 | the CMO- and back-invalidate-driven snoops |
| `SnpOnceFwd`, `SnpCleanFwd`, `SnpNotSharedDirtyFwd`, `SnpUniqueFwd` | 🟢 | `opennoc_hnf_pkg.sv`'s `hnf_snp_fwd_of()` — a table, not `+16`, because Table 13-15 (p.13-425) puts `SnpPreferUniqueFwd` one encoding above its twin and not one nibble. Elected on a snoop-direct L3 miss for a non-Exclusive allocating read (`hnf_mshr_ctl.sv`'s `mshr_dct_set_sx8`); never for `ReadOnce{CleanInvalid,MakeInvalid}`, whose only Forwarding shape is `SnpOnceFwd` (section 4.4.2 p.4-196) |
| `SnpShared`, `SnpPreferUnique`, `SnpPreferUniqueFwd` | 🟢 | `SnpShared` for a `ReadShared`, `SnpPreferUnique` for the `ReadPreferUnique` this Home serves Shared (`hnf_mshr_ctl.sv`'s `l3_opcode_decode_comb_logic`) |
| `SnpSharedFwd` | ⚪ | not elected: section 4.4.2 (p.4-196) permits `SnpNotSharedDirtyFwd` for a `ReadShared` too, and Table 4-53 (p.4-234) lets `SnpSharedFwd` forward `SD_PD` — passing dirtiness to the Requester rather than to this Home |
| `SnpQuery` | ⚪ | not generated: section 6.2.3 (p.6-284) makes it one of three permitted ways to resolve an Exclusive Store and this Home implements the PoC monitor (`hnf_mshr_global_monitor.sv`) |
| `SnpStash*`, `SnpDVMOp` | 🔴 | never generated — [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68), with the Stash and DVM requests they belong to |
| `DoNotGoToSD`, on every snoop sent | 🟢 | hardwired to 1 in `hnf_link_txsnp_wrap.sv`. Section 13.10.34 (p.13-434) makes the bit free on `SnpOnce`/`SnpClean`/`SnpShared`/`SnpNotSharedDirty`/`SnpPreferUnique` and their forwarding twins, and must-be-1 on the ten invalidating and Stash snoops; the two that must carry zero, `SnpQuery` and `SnpDVMOp`, are never generated, so 1 is legal on every snoop this Home sends. It does mean a Snoopee never keeps the line Shared Dirty against this Home — Table 4-42 footnote c (p.4-223) withdraws that row |
| Responses decoded: `SnpResp`, `SnpRespData`, `SnpRespFwded`, `SnpRespDataFwded` | 🟢 | `hnf_mshr_ctl.sv`'s `mshr_snprspfwd_s0` / `mshr_snpdatfwd_s0` |
| `SnpRespDataPtl` | 🟢 | decoded and merged under its byte enables (`hnf_mshr_ctl.sv`'s `mshr_snpdat_v_s0`, `hnf_data_buffer.sv`). Whether the line is whole is read from the accumulated byte enables, not from the opcode (`mshr_snp_full_line_s1`) — where they leave bytes invalid the Home reads memory and merges before completing, section 5.1.5 (p.5-251) |

### Features

| Feature | SN-F | HN-I | RN-I | HN-F | Where |
| :--- | :---: | :---: | :---: | :---: | :--- |
| Chapter 14 link activation | 🟢 | 🟢 | 🟢 | 🟢 | the shared `chi_link_handshake` on the HN-F, HN-I and RN-I; the SN-F drives its own FSM, which waits out section 14.6.3's input race and gates every Protocol flit on its own TXLINK state |
| `TXSACTIVE` per section 14.7.4 | 🟢 | 🟢 | —¹ | 🟢 | tracks outstanding Protocol-layer work on all three nodes that have the port; at the HN-F a retried request holds it only while its P-Credit is outstanding (section 14.7.1) |
| Retry (`RetryAck` / `PCrdGrant`) | 🟢 | 🟢 | 🟡 | 🟢 | each node's `*_qos.sv`; the RN-I stores `PCrdType` and re-sends with `AllowRetry=0` but never sends `PCrdReturn`, which section 2.11.1 (p.2-147, MUST) owes for a credit it does not use — [#171](https://github.com/10x-Engineers/CHI-OpenNoC/issues/171) |
| QoS | 🟢 | 🟢 | 🟢 | 🟢 | 2 classes at the SN-F/HN-I (`snf_qos.sv` / `hni_qos.sv`'s `qpc_high_s0` / `qpc_low_s0`), 4 at the HN-F (`hnf_mshr_qos.sv`'s `qos_class_pool_s0`); the RN-I passes `AxQOS` through |
| DMT | 🟢 | — | — | 🟢 | `snf_mshr.sv`'s `rxreq_dodmt_s0` (`ReturnNID != SrcID`), `hnf_mshr_ctl.sv`'s `mshr_l3_dmt_sx7` |
| DWT | 🟢 | — | — | 🟢 | `hnf_mshr_bypass.sv`'s `do_dwt_*_s0`, `hnf_mshr_ctl.sv`'s `mshr_txreq_dodwt_sx1`. Always elected, not a parameter |
| DCT (forwarding snoops) | — | — | — | 🟢 | `hnf_mshr_ctl.sv`'s `mshr_dct_set_sx8` |
| Snoop filter | — | — | — | 🟢 | `hnf_sf_sram.sv` |
| L3 / system cache | — | — | — | 🟢 | `hnf_data_sram.sv`, `hnf_tag_sram.sv`, `hnf_lru_sram.sv` |
| Exclusives | —² | 🟢³ | 🟢⁴ | 🟢 | `hnf_mshr_global_monitor.sv`: Excl `ReadNoSnp`/`ReadNotSharedDirty`/`ReadClean`/`ReadShared`/`ReadPreferUnique` load, `WriteNoSnp*`/`CleanUnique`/`MakeReadUnique` store — the last three read from the opcode as **sent**, since `hnf_serviced_as()` folds them into another row; `hni_global_monitor.sv`: Excl `ReadNoSnp` load, `WriteNoSnp*` store; `rni_segburst.sv`: `AxLOCK` carried as `Excl` |
| CMOs | 🟢 | 🟢 | — | 🟢 | all five at every node; at the HN-F the two persistent ones are serviced as `CleanShared` with section 16.1's (p.16-471) substituted `CleanSharedPersist` downstream |
| Combined Writes | 🟡 | 🟡 | — | 🟢 | the six `WriteNoSnp` forms are serviced at the SN-F and HN-I; the HN-F serves all fifteen of Table 4-17 (p.4-182) |
| Write Zero | 🟡 | 🟢 | — | 🟢 | both are serviced at the HN-F; `WriteNoSnpZero` at the SN-F and HN-I, `WriteUniqueZero` still error-completed there |
| Atomics | ⚪ | ⚪ | — | ⚪ | section 16.1 leaves `Atomic_Transactions` False when undeclared, and section 16.3.3 then makes the error response the correct answer |
| Stash | ⚪ | ⚪ | — | 🟡 | the HN-F completes every Stash request without stashing and without an error (section 2.3.4 p.2-71, section 9.4.6 p.9-344); no Stash snoop is generated |
| System coherency interface (Chapter 15) | — | — | —¹ | 🔴 | no node has a `SYSCOREQ`/`SYSCOACK` port. Section 15.2.2 (p.15-468) puts three MUSTs on the interconnect side and Table 15-1 (p.15-468) bars it from snooping a Requester that has left coherency; the HN-F snoops every `RNF_NID_LIST_PARAM` entry from reset — [#174](https://github.com/10x-Engineers/CHI-OpenNoC/issues/174) |
| MTE / `TagOp` | 🔴 | 🔴 | 🔴 | 🔴 | every `TagOp` field is tied to zero — [#166](https://github.com/10x-Engineers/CHI-OpenNoC/issues/166), [#167](https://github.com/10x-Engineers/CHI-OpenNoC/issues/167) |
| MPAM | 🔴 | 🔴 | 🔴 | 🔴 | absent from `chie_pkg`'s `req_flit_s` and `snp_flit_s` — the field is not in the layout — [#165](https://github.com/10x-Engineers/CHI-OpenNoC/issues/165) |
| RSVDC | 🟡 | 🟡 | 🟡 | 🟡 | in the REQ and DAT layout when `CHIE_REQ_RSVDC_WIDTH` / `CHIE_DAT_RSVDC_WIDTH` is defined — section 13.10.56 (p.13-441) makes the field optional and a packed struct cannot hold a zero-width member, so the define's presence is the field's. `chie_flit_rsvdc_check` holds each node's parameter to the layout and to the section's 4/8/12/16/24/32 set. **Not propagated across the Home**: the same section makes propagation implementation defined, and the HN-F drops it — [#180](https://github.com/10x-Engineers/CHI-OpenNoC/issues/180) |
| DataCheck | 🟢 | 🟢 | 🟢 | 🟢 | `chie_pkg::datacheck_of()` at each node's DAT builder, so `Data_Check = Odd_Parity` and `Check_Type = Odd_Parity_Byte_Data` (section 16.1 p.16-470/16-471). Sourced, not checked: section 9.6 (p.9-348) puts the parity obligation on the Transmitter, and section 9.8's (p.9-352) conversion MUST applies only where support differs across the interface, which it does not here. **Bit i covers byte lane i** — section 13.10.52 (p.13-436) never fixes the mapping, so a peer must adopt the same convention |
| Poison | 🔴 | 🟢 | 🔴 | 🔴 | **HN-I**: parsed off inbound write data, held per byte in `hni_data_buffer`, carried to and from AXI memory on the `WUSER`/`RUSER` sideband (`axi4_defines.svh` declares the layout — AXI4 has no poison bit) and sourced on the read back, which is section 9.5's (p.9-347, MUST) "the Poison value, once set, must be propagated along with the data". The other three still drop it — [#164](https://github.com/10x-Engineers/CHI-OpenNoC/issues/164) |
| Error propagation (`RespErr`) | 🟢 | 🟢 | 🟢 | 🟢 | the SN-F and HN-I latch `RRESP`/`BRESP` per entry and report them, all-or-none across the packets of one read message (section 9.4.1); the HN-F parses inbound `RespErr` on both RX channels and passes it back, keeping `DERR` and `NDERR` distinct (section 9.1, section 9.2) |
| `CCID` / `TraceTag` on data responses | 🟢 | 🟢 | 🟢 | 🟢 | all four nodes drive both from the request they answer |
| Snoop/completion serialisation | — | — | — | 🟢 | a coherent read's `CompData` is held until its snoops have responded (section 4.11.2) |
| `RetToSrc` fan-out (section 4.9) | — | — | — | 🟢 | the snoop flit is built once per fan-out; every re-drive clears `RetToSrc`, so only the first snoopee carries it |

¹ The RN-I has no `SACTIVE` ports at all, and Figure 15-1 (p.15-466) gives the
Chapter 15 pair to an RN-F or RN-D — an I/O Requester is neither.
² `rtl/src/snf/` has no monitor, which section 6.2.4 permits — a System monitor "can be
placed at a PoS or at endpoint devices", and here it sits at the Home.
³ `hni_global_monitor.sv` arms on `ReadNoSnp(Excl)` and judges `WriteNoSnp*(Excl)`,
which is the whole of section 6.3's (p.6-286) RN-I → ICN(HN-I) pair; the monitor is reset
by another LP's write to the location (section 6.2.4 p.6-285). `Excl` on any other opcode
is the Requester's violation of section 13.10.27 (p.13-432) and is serviced as a plain
access, never answered `EXOK`.
⁴ `AxLOCK` is carried as `Excl` on the `ReadNoSnp` / `WriteNoSnpPtl` of an exclusive
access that one CHI transaction can carry: Non-cacheable, INCR (or single-beat
FIXED), a power-of-two total of at most 64 bytes at an address aligned to it
(section 6.3.3 p.6-291), with `Size` set to the burst's byte count so the read and write
are one section 6.3.3 pair. `RespErr` passes through as `RRESP`/`BRESP`, so `EXOK` is
`EXOKAY` and a failed exclusive is `OKAY`. A Cacheable, WRAP or 128-byte exclusive
is bridged as a plain access and answered `OKAY`, AXI4 A7.2.3's response from a
target without exclusive support. The bridge presents one Logical Processor
(`LPID=0`), so its AXI manager must hold one exclusive sequence in flight at a
time -- section 6.3.3 (p.6-291) forbids two from one LP -- which is AXI4 A7.2's own
read-then-write flow on a single ID.

### What the RN-I generates

The RN-I is an AXI4-to-CHI bridge, so the question is which CHI request an AXI
access becomes. `AxCACHE` names an AMBA AXI4 (IHI 0022) Table A4-5 memory type,
and each row of CHI E.b Table 2-11 carries that same memory type, so the mapping
is fixed by the two tables together.

| `AxCACHE` | AXI memory type | Read | Write |
| :--- | :--- | :--- | :--- |
| `[1] == 0` | Device | `ReadNoSnp` | `WriteNoSnpPtl` |
| `[1] == 1`, `[3:2] == 00` | Normal Non-cacheable | `ReadNoSnp` | `WriteNoSnpPtl` |
| `[1] == 1`, `[3:2] != 00` | Normal Cacheable | `ReadOnce` | `WriteUniquePtl` |

`rni_arctrl.sv`'s and `rni_awctrl.sv`'s `*_txreqflit_info_r.opcode`. `Order` is
EndpointOrder on the Device rows and Ordered Write Observation on a Normal
write; `EWA` comes from
`AxCACHE[0]`, `Allocate` from `AxCACHE[2]` (read) / `AxCACHE[3]` (write).

Only the **partial** write form is generated — the bridge's write path is
byte-enabled throughout — so `WriteNoSnpFull` and `WriteUniqueFull` never appear,
not even for a burst covering the whole line
([#172](https://github.com/10x-Engineers/CHI-OpenNoC/issues/172)).
It emits no CMO, no Atomic and no `ReadNoSnpSep`. `AxLOCK=1` sets `Excl` on the
two Non-cacheable rows, under the shape limits of footnote ⁴ above; a read is
otherwise always a 64-byte request, and only an exclusive one carries the burst's
own `Size`.

---

---

## Verification

Three layers, in increasing cost:

| Layer | What it proves | Runs where |
| :-- | :-- | :-- |
| `tools/lint.sh` | The design elaborates and contains no never-executing logic, inferred latches, or incomplete cases. | CI, every push and PR. Licence-free. |
| `rtl/tb/` | Directed behavioural benches: 136 recorded HN-F cases, an RN-I AXI bench, an SN-F bench, and a Chapter 14 link-activation conformance bench. | Locally, needs VCS or Xcelium. |
| **An external CHI VIP** | Conformance against the Issue E.b specification itself: every node driven as a DUT by an independent UVM verification IP whose checkers cite spec clauses, with a golden reference model behind them. | The 10xEngineers CHI VIP. This is where essentially every protocol defect in the fork log was found. |

The third layer is what the fork exists for. A design can lint clean and pass its
own directed benches while still violating the protocol in ways only an
independent oracle notices. Over 90 such defects have been found and fixed
here — a Completer that accepted a request and never answered it, a link that
granted credits before it was in RUN, an error status that never reached the
Requester — each one an issue on this repository naming the clause it violated.

---

## Repository layout

```
.
├── LICENSE                    Mulan PSL v2
├── README.md
├── .github/workflows/lint.yml Verilator lint gate (the only CI job)
├── doc/
│   └── hnf/                   HN-F design overview + datapath diagram (Chinese)
├── rtl/
│   ├── include/               Types, parameter macros and field definitions
│   │   ├── chie_pkg.sv            CHI E.b flit structs, opcode/Resp/Order enums
│   │   ├── chi_chan_if.sv         One channel's flit/FLITV/FLITPEND/LCRDV bundle
│   │   ├── opennoc_hnf_pkg.sv     HN-F's snoop routing envelope
│   │   ├── opennoc_rni_pkg.sv     RN-I's AXI4 channel structs + PCrdGrant/B-resp
│   │   ├── axi4_defines.svh       AXI4 field widths for HN-I and SN-F
│   │   └── {hnf,hni,rni,snf}_{param,defines}.svh
│   ├── misc/                  Shared modules: chi_link_handshake (Chapter 14 FSM),
│   │                          crosspoint channels, FIFO, arbiters, BIQ,
│   │                          assert_checker, chie_flit_rsvdc_check
│   ├── src/
│   │   ├── hnf/               HN-F  (24 files) — link, MSHR, cache pipeline, SRAMs
│   │   ├── hni/               HN-I  (10 files)
│   │   ├── rni/               RN-I  (14 files)
│   │   └── snf/               SN-F  (8 files)
│   ├── tb/                    Behavioural benches
│   ├── case/                  136 recorded HN-F stimulus/response cases
│   ├── Makefile               VCS compile/run flow
│   └── file_list_tb.f         Source manifest
└── tools/
    ├── lint.sh                Verilator structural lint (CI gate)
    ├── link_check.sh          Chapter 14 link-activation bench
    ├── mesh_generator/        Mesh fabric generator (Python + Jinja2)
    └── ring_generator/        Ring fabric generator
```

---

---

## Contributing

Issues and pull requests are welcome. Fixes are offered upstream to
[RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC); while upstream is
dormant they land here.

**Reporting a bug.** Open an issue with:

1. The node and the commit.
2. The CHI E.b clause you believe is violated — section number and page.
3. What was observed on the wire, ideally as a flit trace or waveform.

Issues are triaged against the spec, not against intuition. A report that names
the clause gets a much faster answer than one that does not, and several reports
filed against this fork have been closed as *not a defect* on exactly that basis.

---

## Licence

**Mulan Permissive Software License, Version 2 (Mulan PSL v2)** — see
[`LICENSE`](LICENSE) for the full text in Chinese and English.

Copyright of the original design rests with its authors as recorded in the
per-file headers.
