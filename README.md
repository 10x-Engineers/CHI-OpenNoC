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
the default parameters are regularly exercised. Known defects are in the
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
| ⚪ | Not implemented; error-completed (NDERR, section 9.1) with the transaction structure intact |
| 🔴 | Not implemented |
| ⬛ | No response, by the spec |
| — | Not applicable to this node (a request that arrives anyway is error-completed) |

### Request opcodes (Completers)

| Request | SN-F | HN-I | HN-F |
| :--- | :---: | :---: | :---: |
| `ReadNoSnp` | 🟢 | 🟢 | 🟢 |
| `ReadNoSnpSep` | 🟢 | ⚪ | ⚪ |
| `ReadOnce`, `ReadClean`, `ReadNotSharedDirty`, `ReadUnique` | — | 🟢 | 🟢 |
| `ReadOnceCleanInvalid`, `ReadOnceMakeInvalid` | — | ⚪ | 🟢 |
| `ReadShared` | — | ⚪ | 🟢 as `ReadNotSharedDirty` |
| `ReadPreferUnique`, `MakeReadUnique` | — | ⚪ | 🟢 as `ReadUnique` |
| `WriteNoSnpFull`, `WriteNoSnpPtl`, `WriteNoSnpZero` | 🟢 | 🟢 | 🟢 |
| `WriteUniqueFull`, `WriteUniquePtl` | — | 🟢 | 🟢 |
| `WriteUniqueZero` | ⚪ | ⚪ | 🟢 |
| `WriteBackFull`, `WriteCleanFull`, `WriteEvictFull` | — | 🟢 | 🟢 |
| `WriteBackPtl`, `WriteEvictOrEvict` | — | ⚪ | 🟢 |
| `WriteUnique*Stash`, `StashOnce*` | — | ⚪ | 🟢 |
| Combined Writes, `WriteNoSnp*` (6) | 🟢 | 🟢 | 🟢 |
| Combined Writes, others (9) | ⚪ | ⚪ | 🟢 |
| `CleanShared`, `CleanInvalid`, `MakeInvalid`, `CleanSharedPersist`, `CleanSharedPersistSep` | 🟢 | 🟢 | 🟢 |
| `CleanUnique`, `MakeUnique`, `Evict` | — | ⚪ | 🟢 |
| Atomics (18) | ⚪ | ⚪ | 🟢 executed at the Home |
| `DVMOp` | ⚪ | ⚪ | ⚪ |
| `PrefetchTgt`, `PCrdReturn`, `ReqLCrdReturn` | ⬛ | ⬛ | ⬛ |

Decode sites: `snf_mshr.sv` / `hni_mshr.sv` `rxreq_*_s0`; HN-F `opennoc_hnf_pkg.sv`
`hnf_serviced_as()`, then the `op_*` chain in `hnf_mshr_ctl.sv`.

### Snoops (HN-F)

| Snoop | |
| :--- | :---: |
| `SnpOnce`, `SnpClean`, `SnpShared`, `SnpNotSharedDirty`, `SnpUnique`, `SnpPreferUnique` | 🟢 |
| `SnpCleanShared`, `SnpCleanInvalid`, `SnpMakeInvalid` | 🟢 |
| `SnpOnceFwd`, `SnpCleanFwd`, `SnpNotSharedDirtyFwd`, `SnpUniqueFwd`, `SnpPreferUniqueFwd` (DCT) | 🟢 |
| `SnpStashUnique`, `SnpStashShared`, `SnpUniqueStash`, `SnpMakeInvalidStash` | 🟢 |
| `SnpSharedFwd`, `SnpQuery` | not generated (permitted) |
| `SnpDVMOp` | 🔴 |
| All snoop responses, incl. `SnpRespDataPtl` | 🟢 |

Every snoop is sent with `DoNotGoToSD = 1`.

### Features

| Feature | SN-F | HN-I | RN-I | RN-F | HN-F | Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| Link activation (Ch. 14) | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| `TXSACTIVE` (section 14.7.4) | 🟢 | 🟢 | — | 🟢 | 🟢 | RN-I has no SACTIVE ports |
| Retry / P-Credits | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |
| QoS | 🟢 | 🟢 | 🟢 | — | 🟢 | 2 classes SN-F/HN-I, 4 HN-F; RN-F issues QoS 0 |
| DMT / DWT | 🟢 | — | — | — | 🟢 | |
| DCT | — | — | — | — | 🟢 | per-RN-F via `RNF_DCT_LIST_PARAM` |
| Snoop filter, L3 | — | — | — | — | 🟢 | |
| Exclusives | — | 🟢 | 🟢 | 🟢 | 🟢 | RN-I / RN-F: `AxID < 256` only |
| CMOs | 🟢 | 🟢 | — | 🟡 | 🟢 | RN-F: no persistent CMOs |
| Combined Writes | 🟡 | 🟡 | — | 🟡 | 🟢 | |
| Write Zero | 🟡 | 🟢 | — | 🟡 | 🟢 | |
| Atomics | ⚪ | ⚪ | — | — | 🟢 | |
| Stash | ⚪ | ⚪ | — | — | 🟢 | |
| System coherency (Ch. 15) | — | — | — | 🟢 | 🟢 | one SYSCO pair per RN-F |
| MTE / `TagOp` | 🟡 | 🟡 | 🟡 | — | 🟡 | tags over AXI `USER`; RN-F ties MTE fields to zero |
| MPAM | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | when `CHIE_MPAM_PRESENT` is defined |
| RSVDC | 🟡 | 🟡 | 🟡 | 🟡 | 🟢 | HN-F propagates REQ, drops DAT |
| DataCheck | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | sourced, odd parity; **bit i covers byte lane i** |
| Poison | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | over AXI via `WUSER`/`RUSER` |
| `RespErr` propagation | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | |

### RN-F interface declarations (section 16.1)

| Property | Value |
| :-- | :-- |
| `Atomic_Transactions`, `Cache_Stash_Transactions`, `Direct_Cache_Transfer` | False |
| `CleanSharedPersistSep_Request`, `CCF_Wrap_Order`, `Enhanced_Features`, `DVM_Support` | False |
| `Data_Poison` | True |
| `Data_Check` / `Check_Type` | `Odd_Parity` / `Odd_Parity_Byte_Data` |
| `MPAM_Support` | `MPAM_9_1` with `CHIE_MPAM_PRESENT`, else False |
| `Req_Addr_Width` / `NodeID_Width` / `Data_Width` | 44 / 7 / 256 |

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
  (`[0]` TagMatch received, `[1]` pass). A `TagOp` the chosen opcode cannot carry goes out as `Invalid`.
- Also sends `PCrdReturn` for unused P-Credits. Issues no CMO, Atomic or `ReadNoSnpSep`.

### What the RN-F generates

| Selector | Values | Requests |
| :--- | :--- | :--- |
| `ARCOH` | `SHARED`, `CLEAN`, `PREFER_UNIQUE`, `UNIQUE`, `ONCE`, `ONCE_CLEAN_INV`, `ONCE_MAKE_INV` | `ReadShared`, `ReadClean`, `ReadPreferUnique`, `ReadUnique`, `ReadOnce*` |
| `AWCOH` | `CACHED`, `READ_UNIQUE`, `IMMEDIATE`, `IMMEDIATE_CLSH`, `PARTIAL` | `CleanUnique`, `MakeReadUnique`, `MakeUnique`, `ReadUnique`, `WriteUnique{Full,Ptl,Zero}` and their `CleanSh` forms |
| `CMOP` (on `CMVALID`) | `EVICT_*`, `CLEAN`, `CLEAN_SHARED`, `CLEAN_SHARED_EVICT`, `CLEAN_INVALID`, `MAKE_INVALID` | `Evict`, `WriteBack{Full,Ptl}`, `WriteEvictFull`, `WriteEvictOrEvict`, `WriteCleanFull`, `CleanShared`, `CleanInvalid`, `MakeInvalid`, `WriteBackFullCleanSh`, `WriteBackFullCleanInv`, `WriteCleanFullCleanSh` |

Encodings are in `rnf_defines.svh`; all-zero selectors give a plain cache. The RN-F issues
no `ReadNotSharedDirty`, `CleanSharedPersist*`, Stash, Atomic, `DVMOp` or Non-snoopable request.

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
| `CHIE_DATA_WIDTH_PARAM` | 256 | **256 only**, other values are refused |
| `AXI4_AXDATA_WIDTH_PARAM` | 128 | HN-I / RN-I / SN-F |
| `AXI4_PA_WIDTH_PARAM` | 44 (RN-I), 32 (HN-I, SN-F) | |
| `HNF_MSHR_RNF_NUM_PARAM`, `RNF_NID_LIST_PARAM` | 4, `{48,16,40,8}` | Coherent Requesters served by the HN-F |
| `RNF_DCT_LIST_PARAM` | all True | Per-Requester `Direct_Cache_Transfer` |
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
tools/           lint.sh, check_select_bounds.py, link_check.sh, mesh/ring generators
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
