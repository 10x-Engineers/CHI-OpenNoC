# CHI-OpenNoC

An open-source **AMBA CHI (Issue E.b)** interconnect, in synthesisable Verilog.

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
| **Language** | Verilog-2001 for the design; SystemVerilog for the benches and two helpers |
| **Nodes** | HN-F (coherent Home + L3 + snoop filter), HN-I (I/O Home), RN-I (AXI4→CHI bridge), SN-F (CHI→AXI4 memory Subordinate), mesh/ring crosspoints |
| **Dependencies** | none — all memories are inferred arrays; no technology cells, no third-party IP |
| **Licence** | Mulan PSL v2 |

> **This is 10xEngineers' fork of [RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC).**
> Upstream has had no commit since 2025-06-25. Protocol fixes found by driving the
> design with a CHI verification IP land here, and upstream's issue backlog is
> mirrored here too. See [Provenance](#provenance).

---

## Status

**Simulation-proven, not silicon-proven.** Read this section before you plan
anything around it.

| | |
| :-- | :-- |
| ✅ **Elaborates clean** | Verilator ≥ 5.0 lints all four nodes with zero errors and zero `ALWNEVER`/`COMBDLY`/`LATCH`/`CASEINCOMPLETE` warnings, gated in CI on every push and PR. |
| ✅ **Protocol-verified against a CHI VIP** | Every node has been driven by an independent Issue-E.b verification IP with an [AMBA CHI Issue E.b PDF] as its oracle. Roughly 60 protocol defects have been found and fixed this way; see [Verification](#verification). |
| ⚠️ **Not synthesis-hardened** | SRAMs are behavioural arrays with an `FPGA_MEMORY` swap-in hook. No timing constraints, no lint against a synthesis ruleset, no power intent, no DFT. |
| ⚠️ **Feature-incomplete against the spec** | Atomics, Stash, MTE, MPAM and DVM are not implemented. The [support matrix](#chi-feature-support) says exactly what is and is not, per node, with the decode site for each claim. |
| ⚠️ **Parameter space is narrow** | The defaults are the only combination that is regularly exercised. See [Configuration](#configuration) for the specific ones that are load-bearing. |

The [open issue tracker](https://github.com/10x-Engineers/CHI-OpenNoC/issues) is
the authoritative list of known defects. Nothing is hidden behind a "known
limitations" paragraph that nobody updates.

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

## CHI feature support

Every claim below is read from the decode site in the RTL and cites it, so it can
be checked against the source rather than taken on trust — and so that changing
one of those sites is visibly a change to this table.

| Status | Meaning |
| :---: | :--- |
| 🟢 | **Serviced** — decoded into real behaviour and completed. |
| 🟡 | **Partial** — some of the family is serviced, the rest is not. |
| ⚪ | **Error-completed** — not implemented, but answered conformantly: a Non-data Error per CHI E.b §9.1, with §9.4.4's transaction structure kept intact, so the grant, the write data and the read data still happen. A Requester sees a clean failure, not a hang. |
| 🔴 | **Not implemented, and not answered** — the request is accepted onto the link and nothing comes back. |
| ⬛ | **Correctly given no response** — §4.5.1's own two exceptions (`PrefetchTgt`, `PCrdReturn`), and Link-layer credit return, which is not a transaction. |
| — | Not applicable to that node's role. |

### Summary

| Node | Requests serviced | Everything else |
| :--- | ---: | :--- |
| **SN-F** | 16 | ⚪ NDERR catch-all — `snf_mshr.sv:389` |
| **HN-I** | 24 | ⚪ NDERR catch-all, shaped per request class — `hni_mshr.sv:515` |
| **HN-F** | 18, plus 7 snoops and their 4 forwarding forms | ⚪ NDERR catch-all — `hnf_mshr_ctl.sv:3126`, `:3308` |
| **RN-I** | generates 4 | it is a Requester — see [What the RN-I generates](#what-the-rn-i-generates) |

All three Completers now answer everything they do not implement. The HN-F count
includes `SnoopFilterEvict`, whose encoding its internal back-invalidate shares
(`hnf_defines.svh:184`).

### Request opcodes

| Request | SN-F | HN-I | HN-F |
| :--- | :---: | :---: | :---: |
| `ReadNoSnp` | 🟢 | 🟢 | 🟢 |
| `ReadNoSnpSep` | 🟢 | ⚪ | 🔴 [#65](https://github.com/10x-Engineers/CHI-OpenNoC/issues/65) |
| `ReadOnce` | — | 🟢 | 🟢 |
| `ReadOnceCleanInvalid`, `ReadOnceMakeInvalid` | — | ⚪ | 🔴 [#65](https://github.com/10x-Engineers/CHI-OpenNoC/issues/65) |
| `ReadClean`, `ReadNotSharedDirty`, `ReadUnique` | — | 🟢 | 🟢 |
| `ReadShared`, `ReadPreferUnique`, `MakeReadUnique` | — | ⚪ | 🔴 [#65](https://github.com/10x-Engineers/CHI-OpenNoC/issues/65) |
| `WriteNoSnpFull`, `WriteNoSnpPtl` | 🟢 | 🟢 | 🟢 |
| `WriteNoSnpZero` | 🟢 | 🟢 | 🔴 [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) |
| `WriteUniqueFull`, `WriteUniquePtl` | — | 🟢 | 🟢 |
| `WriteUniqueZero` | ⚪ | ⚪ | 🔴 [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) |
| `WriteBackFull`, `WriteCleanFull`, `WriteEvictFull` | — | 🟢 | 🟢 |
| `WriteBackPtl`, `WriteEvictOrEvict` | — | ⚪ | 🔴 [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) |
| `WriteUniqueFullStash`, `WriteUniquePtlStash` | — | ⚪ | 🔴 [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) |
| `StashOnceShared`, `StashOnceUnique`, `StashOnceSepShared`, `StashOnceSepUnique` | — | ⚪ | 🔴 [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) |
| `WriteNoSnp*` Combined Writes (6) | 🟢 | 🟢 | 🔴 [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) |
| `WriteUnique*` / `WriteBack*` / `WriteClean*` Combined Writes (9) | ⚪ | ⚪ | 🔴 [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) |
| `CleanShared`, `CleanInvalid` | 🟢 | 🟢 | 🟢 |
| `MakeInvalid` | 🟢 | 🟢 | 🔴 [#67](https://github.com/10x-Engineers/CHI-OpenNoC/issues/67) |
| `CleanSharedPersist`, `CleanSharedPersistSep` | 🟢 | 🟢 | 🔴 [#67](https://github.com/10x-Engineers/CHI-OpenNoC/issues/67) |
| `CleanUnique`, `MakeUnique`, `Evict` | — | ⚪ | 🟢 |
| Atomics — `AtomicStore`, `AtomicLoad`, `AtomicSwap`, `AtomicCompare` | ⚪ | ⚪ | 🔴 [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) |
| `SnoopFilterEvict` | ⚪ | ⚪ | 🟢 |
| `DVMOp` | ⚪ | ⚪ | 🔴 [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) |
| `PrefetchTgt`, `PCrdReturn` | ⬛ | ⬛ | ⬛ |
| `ReqLCrdReturn` | ⬛ | ⬛ | 🔴 [#53](https://github.com/10x-Engineers/CHI-OpenNoC/issues/53) |

Decode sites: `snf_mshr.sv:353-394`, `hni_mshr.sv:454-543`, and for the HN-F the
`op_*` chain at `hnf_mshr_ctl.sv:779-1122`.

### Snoops — HN-F only

An SN-F and an HN-I hold no cached copy and are no Point of Coherency (§1.6), so
neither issues a snoop and neither has a SNP port.

| Snoop | | Where |
| :--- | :---: | :--- |
| `SnpOnce`, `SnpClean`, `SnpNotSharedDirty`, `SnpUnique` | 🟢 | `hnf_mshr_ctl.sv:1963-1986` |
| `SnpCleanShared`, `SnpCleanInvalid`, `SnpMakeInvalid` | 🟢 | the CMO- and back-invalidate-driven snoops |
| `SnpOnceFwd`, `SnpCleanFwd`, `SnpNotSharedDirtyFwd`, `SnpUniqueFwd` | 🟢 | the base opcode `+16`, elected on a snoop-direct L3 miss for a non-Exclusive allocating read (`hnf_mshr_ctl.sv:1149`) |
| `SnpShared`, `SnpSharedFwd`, `SnpPreferUnique*`, `SnpStash*`, `SnpQuery`, `SnpDVMOp` | 🔴 | never generated — [#67](https://github.com/10x-Engineers/CHI-OpenNoC/issues/67) |
| Responses decoded: `SnpResp`, `SnpRespData`, `SnpRespFwded`, `SnpRespDataFwded` | 🟢 | `hnf_mshr_ctl.sv:1299-1300`, `:1319-1320` |
| `SnpRespDataPtl` | 🔴 | neither whitelisted (`hnf_link_rxdat_parse.sv:167`) nor decoded — [#67](https://github.com/10x-Engineers/CHI-OpenNoC/issues/67) |

### Features

| Feature | SN-F | HN-I | RN-I | HN-F | Where |
| :--- | :---: | :---: | :---: | :---: | :--- |
| Chapter 14 link activation | 🟢 | 🟢 | 🟢 | 🟢 | the shared `chi_link_handshake` on the HN-F, HN-I and RN-I; the SN-F drives its own FSM, which waits out §14.6.3's input race and gates every Protocol flit on its own TXLINK state |
| `TXSACTIVE` per §14.7.4 | 🟢 | 🟢 | —¹ | 🟢 | tracks outstanding Protocol-layer work on all three nodes that have the port |
| Retry (`RetryAck` / `PCrdGrant`) | 🟢 | 🟢 | 🟡 | 🟢 | each node's `*_qos.sv`; the RN-I stores `PCrdType` and re-sends with `AllowRetry=0` but never sends `PCrdReturn` |
| QoS | 🟢 | 🟢 | 🟢 | 🟢 | 2 classes at the SN-F/HN-I (`snf_qos.sv:232`, `hni_qos.sv:220`), 4 at the HN-F (`hnf_mshr_qos.sv:327-336`); the RN-I passes `AxQOS` through |
| DMT | 🟢 | — | — | 🟢 | `snf_mshr.sv:346` (`ReturnNID != SrcID`), `hnf_mshr_ctl.sv:2848` |
| DWT | 🟢 | — | — | 🟢 | `hnf_mshr_bypass.sv:396`, `hnf_mshr_ctl.sv:2857`. Always elected, not a parameter |
| DCT (forwarding snoops) | — | — | — | 🟢 | `hnf_mshr_ctl.sv:1149` |
| Snoop filter | — | — | — | 🟢 | `hnf_sf_sram.sv` |
| L3 / system cache | — | — | — | 🟢 | `hnf_data_sram.sv`, `hnf_tag_sram.sv`, `hnf_lru_sram.sv` |
| Exclusives | —² | 🟡³ | 🔴⁴ | 🟢 | `hnf_mshr_global_monitor.sv`: Excl `ReadNoSnp`/`ReadNotSharedDirty`/`ReadClean` load, `WriteNoSnp*`/`CleanUnique` store |
| CMOs | 🟢 | 🟢 | — | 🟡 | all five at the SN-F and HN-I; the HN-F decodes `CleanShared` and `CleanInvalid` only |
| Combined Writes | 🟡 | 🟡 | — | 🔴 | the six `WriteNoSnp` forms are serviced; the rest are error-completed |
| Write Zero | 🟡 | 🟡 | — | 🔴 | `WriteNoSnpZero` is serviced; `WriteUniqueZero` is error-completed |
| Atomics | ⚪ | ⚪ | — | 🔴 | §16.1 leaves `Atomic_Transactions` False when undeclared, and §16.3.3 then makes the error response the correct answer |
| Stash | ⚪ | ⚪ | — | 🔴 | |
| MTE / `TagOp` | 🔴 | 🔴 | 🔴 | 🔴 | every `TagOp` field is tied to zero |
| MPAM | 🔴 | 🔴 | 🔴 | 🔴 | absent from `chie_defines.svh`'s flit widths — the field is not in the layout |
| RSVDC / DataCheck / Poison | 🔴 | 🔴 | 🔴 | 🔴 | the field is in the flit layout, but no node sources or parses one — [#69](https://github.com/10x-Engineers/CHI-OpenNoC/issues/69) |
| Error propagation (`RespErr`) | 🟢 | 🟢 | 🟢 | 🟢 | the SN-F and HN-I latch `RRESP`/`BRESP` per entry and report them, all-or-none across the packets of one read message (§9.4.1); the HN-F parses inbound `RespErr` on both RX channels and passes it back, keeping `DERR` and `NDERR` distinct (§9.1, §9.2) |
| `CCID` / `TraceTag` on data responses | 🟢 | 🟢 | 🟢 | 🟢 | all four nodes drive both from the request they answer |
| Snoop/completion serialisation | — | — | — | 🟢 | a coherent read's `CompData` is held until its snoops have responded (§4.11.2) |
| `RetToSrc` fan-out (§4.9) | — | — | — | 🟢 | the snoop flit is built once per fan-out; every re-drive clears `RetToSrc`, so only the first snoopee carries it |

¹ The RN-I has no `SACTIVE` ports at all.
² `rtl/src/snf/` has no monitor, which §6.2.4 permits — a System monitor "can be
placed at a PoS or at endpoint devices", and here it sits at the Home.
³ `hni_global_monitor.sv:80` arms on `ReadNoSnp` only, so an Exclusive `ReadClean`
is serviced as a plain read and registers nothing.
⁴ `rni_awlink.sv:110` decodes `AxLOCK` into a signal with no readers; `Excl` is
never set on a request.

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

`rni_arctrl.sv:698`, `rni_awctrl.sv:944`. `Order` is EndpointOrder on the Device
rows and Ordered Write Observation on a Normal write; `EWA` comes from
`AxCACHE[0]`, `Allocate` from `AxCACHE[2]` (read) / `AxCACHE[3]` (write).

Only the **partial** write form is generated — the bridge's write path is
byte-enabled throughout — so `WriteNoSnpFull` and `WriteUniqueFull` never appear.
It emits no CMO, no Atomic and no `ReadNoSnpSep`.

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
| `CHIE_NID_WIDTH_PARAM` | 7 (**11** on RN-I) | NodeID width. §16.1 allows 7..11; only the crosspoint range-checks it. |
| `CHIE_DATA_WIDTH_PARAM` | 256 | CHI data width. **Not currently configurable** — 256 is the only value exercised. |
| `CHIE_BE_WIDTH_PARAM` | 32 | Must equal `CHIE_DATA_WIDTH_PARAM/8`. |
| `CHIE_POISON_WIDTH_PARAM` | 4 (**0** on RN-I) | Must equal `CHIE_DATA_WIDTH_PARAM/64`. |
| `CHIE_DATACHECK_WIDTH_PARAM` | 32 (**0** on RN-I) | Must equal `CHIE_DATA_WIDTH_PARAM/8`. |
| `AXI4_AXDATA_WIDTH_PARAM` | 128 | AXI data width on HN-I / RN-I / SN-F. |
| `AXI4_PA_WIDTH_PARAM` | 44 on RN-I, **32** on HN-I and SN-F | AXI address width. |
| `HNF_MSHR_RNF_NUM_PARAM` + `RNF_NID_LIST_PARAM` | 4, `{48,16,40,8}` | How many coherent Requesters the Home serves, and their NodeIDs. |
| `HNF_L3_CACHE_SIZE_PARAM` / `HNF_L3_WAY_NUM_PARAM` | 4096 KB / 16 | L3 geometry. Line size is fixed at 64 B. |
| `HNF_SF_ENTRIES_NUM_PARAM` / `HNF_SF_WAY_NUM_PARAM` | 131072 / 16 | Snoop filter geometry. |
| `*_MSHR_ENTRIES_NUM_PARAM` | 32 | Outstanding transactions per node. |
| `XP_LCRD_NUM_PARAM` | 15 | Maximum outstanding L-Credits per channel. §14.2.1 caps this at 15; the counters are 4 bits wide, so a larger value will not fit. |

### Sharp edges

These are real, and none of them is checked at elaboration:

- **The RN-I's CHI defaults deliberately differ** from the other three nodes —
  NodeID width 11 vs 7, Poison and DataCheck 0 vs 4/32. A system built from
  every node's defaults does **not** have consistent link widths. Set them
  explicitly.
- **`*_MSHR_ENTRIES_WIDTH_PARAM` must be kept equal to `$clog2` of its
  `_NUM_PARAM` by hand.** Nothing checks it.
- **The HN-F's QoS pool sizes are baked into a `HNF_MSHR_ENTRIES_NUM_PARAM == 32`
  ternary** (`hnf_defines.svh:153-157`), so any value other than 32 silently gets
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

## Verification

Three layers, in increasing cost:

| Layer | What it proves | Runs where |
| :-- | :-- | :-- |
| `tools/lint.sh` | The design elaborates and contains no never-executing logic, inferred latches, or incomplete cases. | CI, every push and PR. Licence-free. |
| `rtl/tb/` | Directed behavioural benches: 136 recorded HN-F cases, an RN-I AXI bench, an SN-F bench, and a Chapter 14 link-activation conformance bench. | Locally, needs VCS or Xcelium. |
| **An external CHI VIP** | Conformance against the Issue E.b specification itself: every node driven as a DUT by an independent UVM verification IP whose checkers cite spec clauses, with a golden reference model behind them. | The 10xEngineers CHI VIP. This is where essentially every protocol defect in the fork log was found. |

The third layer is what the fork exists for. A design can lint clean and pass its
own directed benches while still violating the protocol in ways only an
independent oracle notices — the fixes below are almost all of that kind: a
Completer that accepted a request and never answered it, a link that granted
credits before it was in RUN, an error status that never reached the Requester.

### Reporting a bug

Open an issue with:

1. The node and the commit.
2. The CHI E.b clause you believe is violated — section number and page.
3. What was observed on the wire, ideally as a flit trace or waveform.

Issues are triaged against the spec, not against intuition. A report that names
the clause gets a much faster answer than one that does not, and several reports
filed against this fork have been closed as *not a defect* on exactly that basis.

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
│   ├── include/               Parameter macros and field/opcode definitions
│   │   ├── chie_defines.svh       CHI E.b flit layouts and opcode constants
│   │   ├── axi4_defines.svh       AXI4 channel field definitions
│   │   └── {hnf,hni,rni,snf}_{param,defines}.v
│   ├── misc/                  Shared modules: chi_link_handshake (Chapter 14 FSM),
│   │                          crosspoint channels, FIFO, arbiters, BIQ
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

## Known limitations

Beyond the 🔴 and ⚪ cells in the support matrix, these are the open defects. The
[issue tracker](https://github.com/10x-Engineers/CHI-OpenNoC/issues) is
authoritative; this table is a snapshot.

| Issue | Node | What |
| :--- | :--- | :--- |
| [#102](https://github.com/10x-Engineers/CHI-OpenNoC/issues/102) | HN-F | a `WriteUnique` completed OK is later read back as zeros from the L3 |
| [#94](https://github.com/10x-Engineers/CHI-OpenNoC/issues/94) | HN-F | a read answered from memory after its forwarding snoop was already answered `SnpRespFwded`, so the Requester gets a stale line |
| [#87](https://github.com/10x-Engineers/CHI-OpenNoC/issues/87) | HN-I | the write completion ignores EWA — `CompDBIDResp` is sent at allocation whether or not §2.9.3 permits it |
| [#83](https://github.com/10x-Engineers/CHI-OpenNoC/issues/83) | HN-F | the four TX channels still spend an L-Credit in the cycle it arrives (§14.2.1) |
| [#81](https://github.com/10x-Engineers/CHI-OpenNoC/issues/81) | HN-F, SN-F | a `RetryAck` queued when the TXLINK leaves RUN deadlocks the RX deactivation |
| [#80](https://github.com/10x-Engineers/CHI-OpenNoC/issues/80) | HN-F | link flits reach the Protocol layer on RXRSP and RXDAT too, not only RXREQ |
| [#53](https://github.com/10x-Engineers/CHI-OpenNoC/issues/53) | HN-F | a `ReqLCrdReturn` is admitted as a request and takes the static MSHR allocation path |
| [#47](https://github.com/10x-Engineers/CHI-OpenNoC/issues/47) | RN-I | Device reads assert EndpointOrder with no `ReadReceipt` / `RespSepData` issue gate |
| [#23](https://github.com/10x-Engineers/CHI-OpenNoC/issues/23) | SN-F | `TXRSPFLITV` asserted while `TXSACTIVE` was low (§14.7.2) |
| [#15](https://github.com/10x-Engineers/CHI-OpenNoC/issues/15) | HN-F | an L3 eviction's downstream write and a same-line bypass write are not serialised against each other (§2.8.1) |
| [#65](https://github.com/10x-Engineers/CHI-OpenNoC/issues/65) [#66](https://github.com/10x-Engineers/CHI-OpenNoC/issues/66) [#67](https://github.com/10x-Engineers/CHI-OpenNoC/issues/67) [#68](https://github.com/10x-Engineers/CHI-OpenNoC/issues/68) [#69](https://github.com/10x-Engineers/CHI-OpenNoC/issues/69) | — | the opcode and feature gaps the 🔴 / ⚪ cells above stand for, grouped by family |

Two more that are not issues but are worth knowing:

- The crosspoint is not linted by CI, and `rtl/misc/chi_xp_channel.sv` is not in
  `file_list_tb.f`.
- `doc/` covers the HN-F only, and is in Chinese. There is no HN-I, RN-I, SN-F or
  crosspoint design document.

## Provenance

This repository is a fork of [RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC),
taken at `4f57dda` (upstream tip, 2025-06-25). Upstream is the work of the
**Beijing Institute of Open Source Chip** — the design and its copyright headers
are theirs, and the fork keeps them.

The fork adds protocol conformance fixes found by driving each node with the
10xEngineers CHI verification IP. As of this commit that is 21 commits covering
64 closed issues across all four nodes: the SN-F's and HN-I's and HN-F's
missing catch-all completions, Chapter 14 link activation on the HN-F and HN-I,
the RN-I's `AxCACHE`→memory-type mapping, error-status propagation on every node,
`WriteDataCancel` attribution, snoop/completion serialisation, and a parameterised
crosspoint NodeID width. Each one is an issue on this repository with the clause
it violated.

Fixes are offered upstream; while upstream is dormant they land here.

## Licence

**Mulan Permissive Software License, Version 2 (Mulan PSL v2)** — see
[`LICENSE`](LICENSE) for the full text in Chinese and English.

Copyright of the original design rests with its authors as recorded in the
per-file headers.
