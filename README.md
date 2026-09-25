# CHI-OpenNoC

An open-source **AMBA CHI Issue E.b** interconnect in synthesisable SystemVerilog.

[![Lint](https://github.com/10x-Engineers/CHI-OpenNoC/actions/workflows/lint.yml/badge.svg)](https://github.com/10x-Engineers/CHI-OpenNoC/actions/workflows/lint.yml)
[![Licence: Mulan PSL v2](https://img.shields.io/badge/licence-Mulan%20PSL%20v2-blue.svg)](LICENSE)
[![Spec: CHI E.b](https://img.shields.io/badge/spec-AMBA%20CHI%20Issue%20E.b-informational.svg)](https://developer.arm.com/documentation/ihi0050/latest/)

```
        RN-I  ──AXI4──┐                                    ┌── AXI4──  memory
   (AXI manager)      │                                    │
                      ├─ CHI ─┤ crosspoint ├─ CHI ─┤  HN-F ─┴─ CHI ─┤  SN-F
        RN-F  ────────┘        (mesh / ring)          HN-I ───AXI4──┘
   (AXI subordinate)
```

A fork of [RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC) (taken at `4f57dda`,
2025-06-25), maintained here. Original copyright headers are kept.

**Status:** simulation-verified, not silicon-proven or synthesis-hardened (behavioural
SRAMs, no timing constraints, no DFT). DVM is not implemented and MTE is partial. Only
the default parameters are regularly exercised. Every non-🟢 cell in [§2](#2-chi-support)
links its tracking issue; known defects are in the
[issue tracker](https://github.com/10x-Engineers/CHI-OpenNoC/issues).

## Contents

1. [Nodes](#1-nodes)
2. [CHI support](#2-chi-support)
3. [Quick start](#3-quick-start)
4. [Building a system](#4-building-a-system)
5. [Configuration](#5-configuration)
6. [Repository layout](#6-repository-layout)
7. [Contributing](#7-contributing)
8. [Licence](#8-licence)

---

## 1. Nodes

Each node is a standalone module; there is no SoC wrapper.

| Node | Top module | Other port | Role |
| :-- | :-- | :-- | :-- |
| **HN-F** | `rtl/src/hnf/hnf.sv` | — | Coherent Home: PoC/PoS, L3, snoop filter, exclusive monitor, downstream REQ to an SN-F |
| **HN-I** | `rtl/src/hni/hni.sv` | AXI4 manager | Non-coherent I/O Home, 16-region address decode |
| **RN-I** | `rtl/src/rni/rni.sv` | AXI4 subordinate | AXI4 → CHI bridge, bursts split at 64 B / 4 KB |
| **RN-F** | `rtl/src/rnf/rnf.sv` | AXI4 subordinate + policy/CMO ports | Coherent Requester, set-associative cache, snoop port, Chapter 15 SYSCO |
| **SN-F** | `rtl/src/snf/snf.sv` | AXI4 manager | Memory Subordinate |
| **Crosspoint** | `rtl/misc/chi_xp_channel.sv`, `chi_ring_channel.sv` | — | One CHI channel per instance; four make a mesh/ring node |

---

## 2. CHI support

| | |
| :---: | :--- |
| 🟢 | Serviced |
| 🟡 | Partial |
| ⚪ | Not implemented; error-completed (NDERR, section 9.1) with the transaction structure intact. Conformant |
| ⬜ | Not implemented; optional and legally absent (a section 16.1 declaration or a MAY) |
| 🔴 | Not conformant today, open bug |
| ⬛ | No response, by the spec |
| — | Not a target of this node / not applicable |

The **Issue** column tracks the work to reach 🟢.

### Request opcodes (Completers)

| Request | SN-F | HN-I | HN-F | Issue |
| :--- | :---: | :---: | :---: | :--- |
| `ReadNoSnp` | 🟢 | 🟢 | 🟢 | |
| `ReadNoSnpSep` | 🟢 | ⚪ | ⚪ | Home-to-SN only: received from an RN it stays ⚪; HN-F issuing it [#332](https://github.com/10x-Engineers/CHI-OpenNoC/issues/332) |
| `ReadOnce`, `ReadClean`, `ReadNotSharedDirty`, `ReadUnique` | — | 🟢 | 🟢 | |
| `ReadOnceCleanInvalid`, `ReadOnceMakeInvalid` | — | ⚪ | 🟢 | [#329](https://github.com/10x-Engineers/CHI-OpenNoC/issues/329) |
| `ReadShared` | — | ⚪ | 🟢 as `ReadNotSharedDirty` | [#329](https://github.com/10x-Engineers/CHI-OpenNoC/issues/329) |
| `ReadPreferUnique`, `MakeReadUnique` | — | ⚪ | 🟢 as `ReadUnique` | [#329](https://github.com/10x-Engineers/CHI-OpenNoC/issues/329) |
| `WriteNoSnpFull`, `WriteNoSnpPtl`, `WriteNoSnpZero` | 🟢 | 🟢 | 🟢 | |
| `WriteUniqueFull`, `WriteUniquePtl` | — | 🟢 | 🟢 | |
| `WriteUniqueZero` | 🟢 as `WriteNoSnpZero` ² | ⚪ | 🟢 | HN-I [#330](https://github.com/10x-Engineers/CHI-OpenNoC/issues/330) |
| `WriteBackFull`, `WriteCleanFull`, `WriteEvictFull` | — | 🟢 | 🟢 | |
| `WriteBackPtl`, `WriteEvictOrEvict` | — | ⚪ | 🟢 | [#330](https://github.com/10x-Engineers/CHI-OpenNoC/issues/330) |
| `WriteUnique*Stash`, `StashOnceShared`, `StashOnceUnique` | — | 🟢 hint ignored | 🟢 | |
| `StashOnceSep*` | — | 🟢 `CompStashDone` | 🟢 | ¹ |
| Combined Writes, `WriteNoSnp*` (6) | 🟢 | 🟢 | 🟢 | |
| Combined Writes, others (9) | 🟢 as the `WriteNoSnp` form ² | ⚪ | 🟢 | HN-I [#331](https://github.com/10x-Engineers/CHI-OpenNoC/issues/331) |
| `CleanShared`, `CleanInvalid`, `MakeInvalid`, `CleanSharedPersist`, `CleanSharedPersistSep` | 🟢 | 🟢 | 🟢 | |
| `CleanUnique`, `MakeUnique`, `Evict` | — | ⚪ | 🟢 | [#330](https://github.com/10x-Engineers/CHI-OpenNoC/issues/330) |
| Atomics (18) | 🟢 AXI read-modify-write | ⚪ | 🟢 executed at the Home | HN-I [#322](https://github.com/10x-Engineers/CHI-OpenNoC/issues/322) |
| `DVMOp` | ⚪ | ⚪ | ⚪ | serviced only by an MN [#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321) |
| `PrefetchTgt`, `PCrdReturn`, `ReqLCrdReturn` | ⬛ | ⬛ | ⬛ | |

¹ Table B-3 (p.B-495) lists only ICN(HN-F) as a source of `StashDone`/`CompStashDone` and of a Home's `TagMatch`, yet Table B-1 routes these requests to an HN-I, and Sections 2.3.4 (p.2-72) and 12.11.3 (p.12-387, MUST) still owe those responses. The HN-I sends them; the section text is taken to govern.

² Tables 4-14 (p.4-179) and 4-18 (p.4-182) give a Home only `WriteNoSnp{Full,Ptl,Zero}` and the six `WriteNoSnp` Combined Writes to send an SN-F. A Subordinate has no coherence to preserve, so the SN-F services the other ten as their `WriteNoSnp` equivalents, `RespErr` OK: `WriteUniqueZero` as `WriteNoSnpZero`, `WriteUnique{Full,Ptl}CleanSh[PerSep]` as `WriteNoSnp{Full,Ptl}CleanSh[PerSep]`, and `WriteBackFull*` / `WriteCleanFull*` as `WriteNoSnpFull` plus the same CMO leg, completed `CompDBIDResp` as Table 4-39 gives a CopyBack. Built with `DISPLAY_FATAL`, the SN-F still stops on any write outside the two tables (`SNF_OFF_TABLE_WRITE`), since only a misbehaving Home sends one.

Decode sites: `snf_mshr.sv` / `hni_mshr.sv` `rxreq_*_s0`; HN-F `opennoc_hnf_pkg.sv`
`hnf_serviced_as()`, then the `op_*` chain in `hnf_mshr_ctl.sv`.

### Snoops (HN-F)

| Snoop | | Issue |
| :--- | :---: | :--- |
| `SnpOnce`, `SnpClean`, `SnpShared`, `SnpNotSharedDirty`, `SnpUnique`, `SnpPreferUnique` | 🟢 | |
| `SnpCleanShared`, `SnpCleanInvalid`, `SnpMakeInvalid` | 🟢 | |
| `SnpOnceFwd`, `SnpCleanFwd`, `SnpNotSharedDirtyFwd`, `SnpUniqueFwd`, `SnpPreferUniqueFwd` (DCT) | 🟢 | only to a Requester set in `RNF_DCT_LIST_PARAM` |
| `SnpStashUnique`, `SnpStashShared`, `SnpUniqueStash`, `SnpMakeInvalidStash` | 🟢 | only to a target set in `RNF_STASH_LIST_PARAM` |
| `SnpSharedFwd`, `SnpQuery` | ⬜ | [#334](https://github.com/10x-Engineers/CHI-OpenNoC/issues/334) |
| `SnpDVMOp` | ⬜ | MN only [#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321) |
| All snoop responses, incl. `SnpRespDataPtl` | 🟢 | |

Every snoop is sent with `DoNotGoToSD = 1`.

### Features

| Feature | SN-F | HN-I | RN-I | RN-F | HN-F | Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| Link activation (Ch. 14) | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| `TXSACTIVE` / `RXSACTIVE` (section 14.7) | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| Retry / P-Credits | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| QoS | 🟢 | 🟢 | 🟢 | ⬜ | 🟢 | 2 classes SN-F/HN-I, 4 HN-F; RN-F issues QoS 0 [#328](https://github.com/10x-Engineers/CHI-OpenNoC/issues/328) |
| DMT / DWT | 🟢 | — | — | — | 🟢 | |
| DCT | — | — | — | ⬜ | 🟢 | RN-F as a DCT target [#323](https://github.com/10x-Engineers/CHI-OpenNoC/issues/323) |
| Snoop filter, L3 | — | — | — | — | 🟢 | |
| Snoop handling | — | — | — | 🟢 | — | Fwd/Stash snoops answered as their Non-forwarding twin; `SnpDVMOp` needs DVM [#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321) |
| Exclusives | — | 🟢 | 🟢 | 🟢 | 🟢 | RN-I / RN-F: `AxID < 256` only |
| CMOs | 🟢 | 🟢 | — | 🟡 | 🟢 | RN-F: no persistent CMOs [#323](https://github.com/10x-Engineers/CHI-OpenNoC/issues/323) |
| Combined Writes | 🟢 | 🟡 | — | 🟡 | 🟢 | SN-F ², HN-I [#331](https://github.com/10x-Engineers/CHI-OpenNoC/issues/331), RN-F [#323](https://github.com/10x-Engineers/CHI-OpenNoC/issues/323) |
| Write Zero | 🟢 | 🟢 | — | 🟡 | 🟢 | SN-F ², RN-F `WriteNoSnpZero` [#328](https://github.com/10x-Engineers/CHI-OpenNoC/issues/328) |
| Atomics | 🟢 | ⚪ | — | ⬜ | 🟢 | SN-F declares `Atomic_Transactions` (section 16.3.3) for its whole space; HN-I [#322](https://github.com/10x-Engineers/CHI-OpenNoC/issues/322), RN-F [#324](https://github.com/10x-Engineers/CHI-OpenNoC/issues/324) |
| Stash | — | 🟢 | — | ⬜ | 🟢 | HN-I completes without stashing; RN-F [#325](https://github.com/10x-Engineers/CHI-OpenNoC/issues/325) |
| DVM | — | — | — | ⬜ | — | needs an MN [#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321) |
| System coherency (Ch. 15) | — | — | — | 🟢 | 🟢 | one SYSCO pair per RN-F |
| MTE / `TagOp` | 🟡 | 🟡 | 🟡 | ⬜ | 🟡 | HN-I holds no tags: reads answer `Invalid`, a Match is answered `TagMatch` Fail ¹; RN-F [#326](https://github.com/10x-Engineers/CHI-OpenNoC/issues/326) |
| MPAM | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | when `CHIE_MPAM_PRESENT` is defined |
| RSVDC | 🟡 | 🟡 | 🟡 | 🟡 | 🟢 | HN-F propagates REQ, drops DAT |
| DataCheck | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | sourced, odd parity; **bit i covers byte lane i** |
| Poison | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | over AXI via `WUSER`/`RUSER` |
| `RespErr` propagation | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| `Data_Width` 128 / 512 | 🟢 | ⬜ | ⬜ | ⬜ | ⬜ | SN-F packetises by `Data_Width`; the other nodes are 256 only, so a whole system is too [#327](https://github.com/10x-Engineers/CHI-OpenNoC/issues/327) |

### RN-F interface declarations (section 16.1)

| Property | Value | Issue |
| :-- | :-- | :-- |
| `Atomic_Transactions` | False | [#324](https://github.com/10x-Engineers/CHI-OpenNoC/issues/324) |
| `Cache_Stash_Transactions` | False | [#325](https://github.com/10x-Engineers/CHI-OpenNoC/issues/325) |
| `Direct_Cache_Transfer`, `Enhanced_Features`, `CleanSharedPersistSep_Request` | False | [#323](https://github.com/10x-Engineers/CHI-OpenNoC/issues/323) |
| `DVM_Support` | False | [#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321) |
| `CCF_Wrap_Order` | False | |
| `Data_Poison` | True | |
| `Data_Check` / `Check_Type` | `Odd_Parity` / `Odd_Parity_Byte_Data` | |
| `MPAM_Support` | `MPAM_9_1` with `CHIE_MPAM_PRESENT`, else False | |
| `Req_Addr_Width` / `NodeID_Width` / `Data_Width` | 44 / 7 / 256 | [#327](https://github.com/10x-Engineers/CHI-OpenNoC/issues/327) |

### What the RN-I generates

| `AxCACHE` | Read | Write |
| :--- | :--- | :--- |
| Device (`[1]=0`) | `ReadNoSnp` | `WriteNoSnpFull` / `WriteNoSnpPtl` |
| Normal Non-cacheable (`[1]=1`, `[3:2]=00`) | `ReadNoSnp` | `WriteNoSnpFull` / `WriteNoSnpPtl` |
| Normal Cacheable (`[1]=1`, `[3:2]!=00`) | `ReadOnce` | `WriteUniqueFull` / `WriteUniquePtl` |

- `Full` is used only for a whole 64-byte line with every byte enable set.
- `AxLOCK` becomes `Excl` only for `AxID < 256` (it must fit in `LPID`) on the Non-cacheable rows.
  Other exclusives are bridged as plain accesses and answered `OKAY`.
- MTE crosses on `AxUSER` (`TagOp`, `TagGroupID`), `W/RUSER` (`Tag`, `TU`) and `BUSER`
  (`[0]` TagMatch received, `[1]` pass). Only Normal WriteBack (Cacheable) accesses carry a `TagOp`
  (section 12.1); any other, or one the chosen opcode cannot carry, goes out as `Invalid`.
- Also sends `PCrdReturn` for unused P-Credits. Issues no CMO, Atomic or `ReadNoSnpSep`.

### What the RN-F generates

| Selector | Values | Requests |
| :--- | :--- | :--- |
| `ARCOH` | `SHARED`, `CLEAN`, `PREFER_UNIQUE`, `UNIQUE`, `ONCE`, `ONCE_CLEAN_INV`, `ONCE_MAKE_INV` | `ReadShared`, `ReadClean`, `ReadPreferUnique`, `ReadUnique`, `ReadOnce*` |
| `ARORD` (with `ARCOH`) | `0`, `1` | `1`: a `ReadOnce*` miss carries Request Order (`Order = 0b10`, Table 4-1) and completes on its `ReadReceipt` ([#360](https://github.com/10x-Engineers/CHI-OpenNoC/issues/360)) |
| `AWCOH` | `CACHED`, `READ_UNIQUE`, `IMMEDIATE`, `IMMEDIATE_CLSH`, `PARTIAL` | `CleanUnique`, `MakeReadUnique`, `MakeUnique`, `ReadUnique`, `WriteUnique{Full,Ptl,Zero}` and their `CleanSh` forms |
| `CMOP` (on `CMVALID`) | `EVICT_*`, `CLEAN`, `CLEAN_SHARED`, `CLEAN_SHARED_EVICT`, `CLEAN_INVALID`, `MAKE_INVALID` | `Evict`, `WriteBack{Full,Ptl}`, `WriteEvictFull`, `WriteEvictOrEvict`, `WriteCleanFull`, `CleanShared`, `CleanInvalid`, `MakeInvalid`, `WriteBackFullCleanSh`, `WriteBackFullCleanInv`, `WriteCleanFullCleanSh` |

Encodings are in `rnf_defines.svh`; all-zero selectors give a plain cache. The HN-F sends a
`ReadReceipt` for an ordered `ReadOnce` only, so set `ARORD` with `ARCOH = ONCE` alone for now. The RN-F issues
no `ReadNotSharedDirty`, `CleanSharedPersist*` ([#323](https://github.com/10x-Engineers/CHI-OpenNoC/issues/323)), Stash ([#325](https://github.com/10x-Engineers/CHI-OpenNoC/issues/325)), Atomic ([#324](https://github.com/10x-Engineers/CHI-OpenNoC/issues/324)),
`DVMOp` ([#321](https://github.com/10x-Engineers/CHI-OpenNoC/issues/321)) or Non-snoopable request ([#328](https://github.com/10x-Engineers/CHI-OpenNoC/issues/328)).

---

## 3. Quick start

| Tool | For |
| :-- | :-- |
| Verilator ≥ 5.0, pyslang | `tools/lint.sh` (CI) |
| Verilator ≥ 5.050, GCC ≥ 10 | licence-free simulation (`SIM=verilator`) |
| Xcelium or VCS | the same benches under a commercial simulator |
| Python 3 + `jinja2` | mesh/ring generators |

```bash
./tools/lint.sh                        # lint all nodes and generated fabrics
./tools/lint.sh hnf snf                # lint selected nodes

SIM=verilator ./tools/link_check.sh    # Chapter 14 link bench (default: Xcelium; SIM=vcs)
SIM=verilator ./tools/home_check.sh    # directed HN-F / HN-I benches (DVMOp, Stash targets)

cd rtl
make com sim SIM=verilator             # 136-case HN-F regression (default: VCS)
TOP_TB=tb_rni make com sim             # RN-I bench
```

---

## 4. Building a system

```bash
(cd tools/mesh_generator && ./mesh_gen.py -f mesh_2x2.json)   # run from the generator's own dir
(cd tools/ring_generator && ./ring_gen.py -f ring_8.json)
```

Each run writes `mesh_wrapper_{X}x{Y}.sv` / `ring_wrapper_{N}.sv`. If the config has `RNF` ports, it
also writes a populated `mesh_system_*.sv` / `ring_system_*.sv` with an `rnf` on each one. The JSON
schema is in `tools/mesh_generator/README.md`.

---

## 5. Configuration

Parameters come from `rtl/include/*_param.svh` macros (`` `HNF_PARAM ``, `` `HNF_PARAM_INST ``, …)
and are overridden at instantiation.

### The parameters that matter

| Parameter | Default | Notes |
| :-- | --: | :-- |
| `CHIE_REQ_ADDR_WIDTH_PARAM` | 44 | 44..52 build; only 44 exercised |
| `CHIE_NID_WIDTH_PARAM` | 7 | 7..11 build; only 7 exercised |
| `CHIE_DATA_WIDTH_PARAM` | 256 | 128 / 256 / 512 on the SN-F; every other node refuses anything but 256 [#327](https://github.com/10x-Engineers/CHI-OpenNoC/issues/327) |
| `AXI4_AXDATA_WIDTH_PARAM` | 128 | HN-I / RN-I / SN-F |
| `AXI4_PA_WIDTH_PARAM` | 44 (RN-I), 32 (HN-I, SN-F) | |
| `HNF_MSHR_RNF_NUM_PARAM`, `RNF_NID_LIST_PARAM` | 4, `{48,16,40,8}` | Coherent Requesters served by the HN-F |
| `RNF_DCT_LIST_PARAM` | all False | Per-Requester `Direct_Cache_Transfer` (section 16.1) |
| `RNF_STASH_LIST_PARAM` | all False | Per-Requester: receives Stash snoops (section 9.4.6) |
| `HNF_L3_CACHE_SIZE_PARAM` / `HNF_L3_WAY_NUM_PARAM` | 4096 KB / 16 | 64 B lines |
| `HNF_SF_ENTRIES_NUM_PARAM` / `HNF_SF_WAY_NUM_PARAM` | 131072 / 16 | |
| `RNF_CACHE_SETS_PARAM` / `RNF_CACHE_WAYS_PARAM` | 16 / 2 | |
| `RNF_NID_PARAM` / `HNF_NID_PARAM` | 8 / 0 | |
| `RNF_EXCL_LP_NUM_PARAM` | 4 | One monitor per LP |
| `*_MSHR_ENTRIES_NUM_PARAM` | 32 | Multiple of 16 on the HN-F |
| `HNF_BIQ_ENTRIES_NUM_PARAM` | 8 | Power of two |
| `RNF_LCRD_NUM_PARAM`, `XP_LCRD_NUM_PARAM` | 15 | Max 15 (section 14.2.1) |
| `CHIE_REQ_RSVDC_WIDTH` / `CHIE_DAT_RSVDC_WIDTH` / `CHIE_MPAM_PRESENT` | undefined | `` `define ``s; defining one adds the field |

Derived widths (`CHIE_{BE,POISON,DATACHECK}_WIDTH_PARAM`, `*_MSHR_*_WIDTH_PARAM`) follow their source
parameter. If you override one to a value that disagrees, elaboration refuses it.

---

## 6. Repository layout

```
rtl/
├── include/     chie_pkg.sv (flits, enums), per-node param/define headers
├── misc/        link handshake, crosspoint channels, FIFOs, arbiters, checkers
├── src/         hnf/ hni/ rni/ rnf/ snf/
├── tb/          behavioural benches
├── case/        136 HN-F stimulus/response cases
└── Makefile
tools/           lint.sh, check_select_bounds.py, link_check.sh, home_check.sh, mesh/ring generators
doc/hnf/         HN-F design overview (Chinese)
```

---

## 7. Contributing

Issues and PRs are welcome. When you report a bug, include:

1. The node and the commit.
2. The CHI E.b clause you believe is violated (section and page).
3. A flit trace or waveform.

---

## 8. Licence

[Mulan PSL v2](LICENSE). Copyright of the original design rests with the authors named in each file's header.
