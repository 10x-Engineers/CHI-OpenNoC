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
SRAMs, no timing constraints, no DFT). MTE is partial. Only
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
| **RN-F** | `rtl/src/rnf/rnf.sv` | AXI4 subordinate + policy/CMO/DVM ports | Coherent Requester, set-associative cache, snoop port, Chapter 15 SYSCO, DVM |
| **SN-F** | `rtl/src/snf/snf.sv` | AXI4 manager | Memory Subordinate |
| **MN** | `rtl/src/mn/mn.sv` | per-Requester SYSCO snoop enable/pending | Miscellaneous Node: completes every `DVMOp`, sends its `SnpDVMOp` pair to every other DVM-capable Requester in `MN_RN_NID_LIST_PARAM`, and completes a Sync only after the Non-syncs it held |
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
| `ReadNoSnpSep` | 🟢 | ⚪ | ⚪ received, 🟢 issued | Home-to-SN only, so received from an RN it stays ⚪. The HN-F issues it with `RespSepData` in place of DMT for an unordered read when `HNF_SEP_RESP_EN_PARAM` is set |
| `ReadOnce`, `ReadClean`, `ReadNotSharedDirty`, `ReadUnique` | — | 🟢 | 🟢 | |
| `ReadOnceCleanInvalid`, `ReadOnceMakeInvalid` | — | 🟢 | 🟢 | |
| `ReadShared` | — | 🟢 `CompData_SC` | 🟢 as `ReadNotSharedDirty` | |
| `ReadPreferUnique`, `MakeReadUnique` | — | 🟢 `CompData_UC` | 🟢 as `ReadUnique` | |
| `WriteNoSnpFull`, `WriteNoSnpPtl`, `WriteNoSnpZero` | 🟢 | 🟢 | 🟢 | |
| `WriteUniqueFull`, `WriteUniquePtl` | — | 🟢 | 🟢 | |
| `WriteUniqueZero` | 🟢 as `WriteNoSnpZero` ² | 🟢 | 🟢 | |
| `WriteBackFull`, `WriteCleanFull`, `WriteEvictFull` | — | 🟢 | 🟢 | |
| `WriteBackPtl`, `WriteEvictOrEvict` | — | 🟢 | 🟢 | |
| `WriteUnique*Stash`, `StashOnceShared`, `StashOnceUnique` | — | 🟢 hint ignored | 🟢 | |
| `StashOnceSep*` | — | 🟢 `CompStashDone` | 🟢 | ¹ |
| Combined Writes, `WriteNoSnp*` (6) | 🟢 | 🟢 | 🟢 | |
| Combined Writes, others (9) | 🟢 as the `WriteNoSnp` form ² | 🟢 | 🟢 | |
| `CleanShared`, `CleanInvalid`, `MakeInvalid`, `CleanSharedPersist`, `CleanSharedPersistSep` | 🟢 | 🟢 | 🟢 | |
| `CleanUnique`, `MakeUnique`, `Evict` | — | 🟢 | 🟢 | |
| Atomics (18) | 🟢 AXI read-modify-write | 🟢 Normal memory; Device NDERR ³ | 🟢 executed at the Home | |
| `DVMOp` | ⚪ | ⚪ | ⚪ | serviced by the MN (§1), the one Completer Table B-1 (p.B-493) names |
| `PrefetchTgt`, `PCrdReturn`, `ReqLCrdReturn` | ⬛ | ⬛ | ⬛ | |

¹ Table B-3 (p.B-495) lists only ICN(HN-F) as a source of `StashDone`/`CompStashDone` and of a Home's `TagMatch`, yet Table B-1 routes these requests to an HN-I, and Sections 2.3.4 (p.2-72) and 12.11.3 (p.12-387, MUST) still owe those responses. The HN-I sends them; the section text is taken to govern.

² Tables 4-14 (p.4-179) and 4-18 (p.4-182) give a Home only `WriteNoSnp{Full,Ptl,Zero}` and the six `WriteNoSnp` Combined Writes to send an SN-F. A Subordinate has no coherence to preserve, so the SN-F services the other ten as their `WriteNoSnp` equivalents, `RespErr` OK: `WriteUniqueZero` as `WriteNoSnpZero`, `WriteUnique{Full,Ptl}CleanSh[PerSep]` as `WriteNoSnp{Full,Ptl}CleanSh[PerSep]`, and `WriteBackFull*` / `WriteCleanFull*` as `WriteNoSnpFull` plus the same CMO leg, completed `CompDBIDResp` as Table 4-39 gives a CopyBack. Built with `DISPLAY_FATAL`, the SN-F still stops on any write outside the two tables (`SNF_OFF_TABLE_WRITE`), since only a misbehaving Home sends one.

³ The HN-I performs an Atomic to Normal memory as an AXI read-modify-write, the AXI ID held until the write is acknowledged (section 16.3.2, p.16-479: "at a point ... where the transaction is visible to all other agents"). A Device Atomic "must be passed to the appropriate endpoint Subordinate", and an AXI4 endpoint takes none, so it is answered NDERR with the transaction structure intact (section 9.4.4).

Decode sites: `snf_mshr.sv` / `hni_mshr.sv` `rxreq_*_s0`; HN-F `opennoc_hnf_pkg.sv`
`hnf_serviced_as()`, then the `op_*` chain in `hnf_mshr_ctl.sv`.

### Snoops (HN-F)

| Snoop | | Issue |
| :--- | :---: | :--- |
| `SnpOnce`, `SnpClean`, `SnpShared`, `SnpNotSharedDirty`, `SnpUnique`, `SnpPreferUnique` | 🟢 | |
| `SnpCleanShared`, `SnpCleanInvalid`, `SnpMakeInvalid` | 🟢 | |
| `SnpOnceFwd`, `SnpCleanFwd`, `SnpNotSharedDirtyFwd`, `SnpSharedFwd`, `SnpUniqueFwd`, `SnpPreferUniqueFwd` (DCT) | 🟢 | only to a Requester set in `RNF_DCT_LIST_PARAM`; `SnpSharedFwd` for a `ReadShared`, whose Snoopee may forward `SD_PD` |
| `SnpStashUnique`, `SnpStashShared`, `SnpUniqueStash`, `SnpMakeInvalidStash` | 🟢 | only to a target set in `RNF_STASH_LIST_PARAM` |
| `SnpQuery` | 🟢 | from the `SNPQ_*` port when `HNF_SNPQUERY_EN_PARAM` is set, which reports the Snoopee's state |
| `SnpDVMOp` | — | sent by the MN (Table B-2 p.B-494) |
| All snoop responses, incl. `SnpRespDataPtl` | 🟢 | |

Every snoop but `SnpQuery` is sent with `DoNotGoToSD = 1`; section 13.10.34 makes it zero there.

### Features

| Feature | SN-F | HN-I | RN-I | RN-F | HN-F | Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| Link activation (Ch. 14) | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| `TXSACTIVE` / `RXSACTIVE` (section 14.7) | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| Retry / P-Credits | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| QoS | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 2 classes SN-F/HN-I, 4 HN-F; RN-F carries `AxQOS` |
| DMT / DWT | 🟢 | — | — | — | 🟢 | |
| DCT | — | — | — | 🟢 | 🟢 | RN-F as a DCT target: forwards CompData to the Requester |
| Snoop filter, L3 | — | — | — | — | 🟢 | |
| Snoop handling | — | — | — | 🟢 | — | Forwarding snoops per Tables 4-51..4-56, Stash snoops with a Data Pull per Tables 4-46..4-48; a `SnpDVMOp` pair with one `SnpResp_I` once both parts are in |
| Exclusives | — | 🟢 | 🟢 | 🟢 | 🟢 | RN-I / RN-F: `AxID < 256` only |
| CMOs | 🟢 | 🟢 | — | 🟢 | 🟢 | |
| Combined Writes | 🟢 | 🟢 | — | 🟢 | 🟢 | SN-F ² |
| Write Zero | 🟢 | 🟢 | — | 🟢 | 🟢 | SN-F ² |
| Atomics | 🟢 | 🟢 | — | 🟢 | 🟢 | SN-F declares `Atomic_Transactions` (section 16.3.3) for its whole space; HN-I `Atomic_Transactions` True ³; RN-F executes near in its cache or sends far, `BROADCASTATOMIC` suppresses |
| Stash | — | 🟢 | — | 🟢 | 🟢 | HN-I completes without stashing; RN-F is a source and a Data Pull target |
| DVM | — | — | — | 🟢 | — | serviced by the MN (below); the RN-F issues `DVMOp` from its DVM port and answers `SnpDVMOp` |
| System coherency (Ch. 15) | — | — | — | 🟢 | 🟢 | one SYSCO pair per RN-F; the HN-F's `SYSCOACK` also waits on `SYSCO_SNP_PEND`, another node's snoop to that RN-F |
| MTE / `TagOp` | 🟡 | 🟡 | 🟡 | 🟢 | 🟡 | HN-I holds no tags: reads answer `Invalid`, a Match is answered `TagMatch` Fail ¹; RN-F caches tags per line and matches a cached store itself, with `BROADCASTMTE` |
| MPAM | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | when `CHIE_MPAM_PRESENT` is defined |
| RSVDC | 🟡 | 🟡 | 🟡 | 🟡 | 🟢 | HN-F propagates REQ, drops DAT |
| DataCheck | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | sourced, odd parity; **bit i covers byte lane i** |
| Poison | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | over AXI via `WUSER`/`RUSER` |
| `RespErr` propagation | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| `Data_Width` 128 / 512 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | every node packetises by `Data_Width` |

The MN (§1) implements Chapter 14 link activation and `TXSACTIVE`, Retry / P-Credits -- a
Sync and a Non-sync are credited apart (`PCrdType` 1 / 0), so Syncs never hold the entry
section 8.1.3 (p.8-307) reserves for a Non-sync -- and every `Data_Width`. It forwards a
DVM_v8.4 payload unexamined, sends no early Comp, carries the DVMOp's QoS without classes,
and consolidates a DERR write or a snoop error into the Comp (section 9.4.5). It snoops a
Requester only while that Requester's `SYSCO_SNP_EN` (its `SYSCOREQ`) is HIGH, and holds
`SYSCO_SNP_PEND` HIGH while a `SnpDVMOp` to it is unanswered, for whoever owns its `SYSCOACK` --
the HN-F's `SYSCO_SNP_PEND` input, in the same Requester order.

### RN-F interface declarations (section 16.1)

| Property | Value | Issue |
| :-- | :-- | :-- |
| `Atomic_Transactions` | True | |
| `Cache_Stash_Transactions` | True | |
| `Direct_Cache_Transfer`, `Enhanced_Features`, `CleanSharedPersistSep_Request` | True | |
| `DVM_Support` | `DVM_v8.4`: no TLB, branch predictor or instruction cache, so every pair is answered on arrival of both parts; two `SnpDVMOp`s accepted at once | |
| `CCF_Wrap_Order` | False | |
| `Data_Poison` | True | |
| `Data_Check` / `Check_Type` | `Odd_Parity` / `Odd_Parity_Byte_Data` | |
| `MPAM_Support` | `MPAM_9_1` with `CHIE_MPAM_PRESENT`, else False | |
| `Req_Addr_Width` / `NodeID_Width` / `Data_Width` | 44 / 7 / 256 (128 and 512 build too) | |

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
| `AxCACHE` | Device (`[1]=0`), Normal Non-cacheable (`[1]=1`, `[3:2]=00`) | `ReadNoSnp` of the beat, `WriteNoSnp{Full,Ptl,Zero}` of the bytes written; the cache is bypassed. Device is `Order = 0b11`, `AxCACHE[0]` is EWA (Table 2-11). `AxLOCK` sets `Excl` |
| `ARCOH` | `SHARED`, `CLEAN`, `PREFER_UNIQUE`, `UNIQUE`, `ONCE`, `ONCE_CLEAN_INV`, `ONCE_MAKE_INV`, `NOT_SHARED_DIRTY` | `ReadShared`, `ReadClean`, `ReadPreferUnique`, `ReadUnique`, `ReadOnce*`, `ReadNotSharedDirty` |
| `ARORD` (with `ARCOH`) | `0`, `1` | `1`: a `ReadOnce*` miss carries Request Order (`Order = 0b10`, Table 4-1) and completes on its `ReadReceipt` ([#360](https://github.com/10x-Engineers/CHI-OpenNoC/issues/360)) |
| `AWCOH` | `CACHED`, `READ_UNIQUE`, `IMMEDIATE`, `IMMEDIATE_CLSH`, `PARTIAL`, `IMMEDIATE_PERSEP`, `IMMEDIATE_STASH` | `CleanUnique`, `MakeReadUnique`, `MakeUnique`, `ReadUnique`, `WriteUnique{Full,Ptl,Zero}` and their `CleanSh`, `CleanShPerSep` and `Stash` forms; on a Device/Non-cacheable write, `WriteNoSnp{Full,Ptl}CleanSh{,PerSep}` |
| `STASHNID`, `STASHNIDVALID` (with `AWVALID` or `CMVALID`) | NodeID | The Stash target of a `*Stash` write or `StashOnce*` |
| `AWATOP`, `AWATM` (with `AWVALID`) | AXI5 `AWATOP`; `NEAR`, `FAR`, `FAR_SNOOPME` | `NEAR`: the store's own acquire, then the operation in the cache. `FAR`: a Dirty line written back or a Clean one dropped, then `Atomic*` with `SnoopMe = 0`. `FAR_SNOOPME`: `Atomic*` with `SnoopMe = 1`. The original value returns on `BATDATA` with `BVALID`. With `BROADCASTATOMIC` low a far request executes near, and a Device/Non-cacheable one is refused `SLVERR` |
| `ARUSER`/`AWUSER` `TagOp` (MTE, with `BROADCASTMTE`) | `ARUSER` non-zero; `AWUSER` `Update`, `Match` | Every allocating read carries `Transfer`, and a read's tags return on `RUSER`. A line held without the tags an access needs is written back or dropped and read again, a whole-line store by `ReadUnique` with `Fetch`; a whole-line store writing every tag is `MakeUnique` with `Update`. `WriteUnique*` and a far `Atomic*` carry the core's `Update` or `Match`, and a CopyBack returns Dirty tags `Update`, Clean ones `Transfer`. `BUSER` is the verdict of a cached store's own match or of the Completer's `TagMatch`. A Combined `WriteUnique` asked either, or a far `Atomic` asked `Update`, is refused `SLVERR` (Table 12-2) |
| `DVMADDR`, `DVMDATA`, `DVMDOMAIN` (on `DVMVALID`) | Table 8-8's (p.8-317) `Req.Addr` and 8-byte write data, Table 8-10's (p.8-321) domain | `DVMOp` to `MN_NID_PARAM`, run while no other request is outstanding; `DVMDONE` with the Comp's `RespErr` on `DVMRESP` |
| `CMOP` (on `CMVALID`) | `EVICT_*`, `CLEAN`, `CLEAN_SHARED`, `CLEAN_SHARED_EVICT`, `CLEAN_INVALID`, `MAKE_INVALID`, `CLEAN_SHARED_PERSIST`, `CLEAN_SHARED_PERSIST_SEP`, `CLEAN_SHARED_PERSIST_SEP_EVICT` | `Evict`, `WriteBack{Full,Ptl}`, `WriteEvictFull`, `WriteEvictOrEvict`, `WriteCleanFull`, `CleanShared`, `CleanInvalid`, `MakeInvalid`, `CleanSharedPersist`, `CleanSharedPersistSep`, `WriteBackFullCleanSh`, `WriteBackFullCleanInv`, `WriteCleanFullCleanSh`, `WriteBackFullCleanShPerSep`, `WriteCleanFullCleanShPerSep`; `STASH_ONCE_SHARED`, `STASH_ONCE_UNIQUE` give `StashOnceShared`, `StashOnceUnique` |

Encodings are in `rnf_defines.svh`; all-zero selectors give a plain cache. Every request carries the
access's `AxQOS`. The HN-F sends a `ReadReceipt` for every ordered `ReadNoSnp` and `ReadOnce*`.

As a Stash target the RN-F answers a Stash snoop with a Data Pull where Tables 4-46..4-48 permit one and the
line has a way it can take without a write-back, and allocates the line the pull returns. While a
`DVMOp` is outstanding it answers without a Data Pull.

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
SIM=verilator ./tools/home_check.sh    # directed HN-F / HN-I / MN benches (DVMOp, Stash targets)

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
also writes a populated `mesh_system_*.sv` / `ring_system_*.sv` with an `rnf` on each one, and sets
each one's bit of `RNF_DCT_LIST` and `RNF_STASH_LIST` in its package, since the `rnf` declares
`Direct_Cache_Transfer` and `Cache_Stash_Transactions`. The JSON schema is in `tools/mesh_generator/README.md`.

---

## 5. Configuration

Parameters come from `rtl/include/*_param.svh` macros (`` `HNF_PARAM ``, `` `HNF_PARAM_INST ``, …)
and are overridden at instantiation.

### The parameters that matter

| Parameter | Default | Notes |
| :-- | --: | :-- |
| `CHIE_REQ_ADDR_WIDTH_PARAM` | 44 | 44..52 build; only 44 exercised |
| `CHIE_NID_WIDTH_PARAM` | 7 | 7..11 build; only 7 exercised |
| `CHIE_DATA_WIDTH_PARAM` | 256 | 128 / 256 / 512 on every node |
| `AXI4_AXDATA_WIDTH_PARAM` | 128 | HN-I / RN-I / SN-F |
| `AXI4_PA_WIDTH_PARAM` | 44 (RN-I), 32 (HN-I, SN-F) | |
| `HNF_MSHR_RNF_NUM_PARAM`, `RNF_NID_LIST_PARAM` | 4, `{48,16,40,8}` | Coherent Requesters served by the HN-F |
| `RNF_DCT_LIST_PARAM` | all False | Per-Requester `Direct_Cache_Transfer` (section 16.1) |
| `RNF_STASH_LIST_PARAM` | all False | Per-Requester: receives Stash snoops (section 9.4.6) |
| `HNF_L3_CACHE_SIZE_PARAM` / `HNF_L3_WAY_NUM_PARAM` | 4096 KB / 16 | 64 B lines |
| `HNF_SF_ENTRIES_NUM_PARAM` / `HNF_SF_WAY_NUM_PARAM` | 131072 / 16 | |
| `HNF_SNPQUERY_EN_PARAM` | 0 | 1: `SNPQ_REQ_*` sends a `SnpQuery` for one line to one `RNF_NID_LIST_PARAM` entry and `SNPQ_RSP_*` reports its state, or `SENT=0` where that interface is out of the coherency domain |
| `HNF_SEP_RESP_EN_PARAM` | 0 | 1: an unordered read eligible for DMT is answered `RespSepData` by the HN-F and `DataSepResp` by the SN-F (`ReadNoSnpSep`, section 2.3.1 flow 4) |
| `RNF_CACHE_SETS_PARAM` / `RNF_CACHE_WAYS_PARAM` | 16 / 2 | |
| `RNF_NID_PARAM` / `HNF_NID_PARAM` / `MN_NID_PARAM` | 8 / 0 / 4 | `MN_NID_PARAM`: where the RN-F sends its `DVMOp`s |
| `RNF_EXCL_LP_NUM_PARAM` | 4 | One monitor per LP |
| `*_MSHR_ENTRIES_NUM_PARAM` | 32 | Multiple of 16 on the HN-F |
| `HNF_BIQ_ENTRIES_NUM_PARAM` | 8 | Power of two |
| `RNF_LCRD_NUM_PARAM`, `XP_LCRD_NUM_PARAM` | 15 | Max 15 (section 14.2.1) |
| `MN_NID_PARAM` | 4 | The MN's NodeID |
| `MN_RN_NUM_PARAM`, `MN_RN_NID_LIST_PARAM` | 4, `{48,16,40,8}` | Every DVM-capable RN-F / RN-D: the Requesters the MN serves and snoops |
| `MN_ENTRIES_NUM_PARAM` | 4 | DVMOps in flight, at least 2: Syncs may hold all but one (section 8.1.3) |
| `MN_RN_SNPDVM_NUM_PARAM` | 2 | `SnpDVMOp`s each Requester accepts at once, at least 2 (section 8.1.3); one place is kept for a Sync |
| `CHIE_REQ_RSVDC_WIDTH` / `CHIE_DAT_RSVDC_WIDTH` / `CHIE_MPAM_PRESENT` | undefined | `` `define ``s; defining one adds the field |

Derived widths (`CHIE_{BE,POISON,DATACHECK}_WIDTH_PARAM`, `*_MSHR_*_WIDTH_PARAM`) follow their source
parameter. If you override one to a value that disagrees, elaboration refuses it.

---

## 6. Repository layout

```
rtl/
├── include/     chie_pkg.sv (flits, enums), per-node param/define headers
├── misc/        link handshake, crosspoint channels, FIFOs, arbiters, checkers
├── src/         hnf/ hni/ rni/ rnf/ snf/ mn/
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
