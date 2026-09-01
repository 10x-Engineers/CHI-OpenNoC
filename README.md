# 1 Introduction to OpenNoC

OpenNoC is a bus implemented against the AMBA CHI protocol, issue 0050E.b, used to
connect multiple cores, memory controllers and peripherals. It currently implements
HNF, HNI, RNI, SNF and XP; this repository contains the HNF, HNI, RNI, SNF and SXP
sources together with some testbenches.

> **About this fork.** This is 10xEngineers' fork of
> [RV-BOSC/OpenNoC](https://github.com/RV-BOSC/OpenNoC). Upstream has had no commit
> since 2025-06-25, so protocol fixes found while verifying against the 10xEngineers
> CHI VIP land here. See [Section 4](#4-changes-in-this-fork).

# 2 Directory layout
```
.
├── doc                       // design documents
│   ├── hnf                   // hnf design overview
├── README.md                 // README
├── rtl
│   ├── include               // header files, including macro definitions
│   ├── misc                  // shared Verilog modules (FIFOs, poll helpers,
│   │                         //   XP/ring channel, chi_link_handshake)
│   ├── src                   // component RTL
│   │   ├── hnf               // HN-F Component code
│   │   ├── hni               // HN-I Component code
│   │   ├── rni               // RN-I Component code
│   │   └── snf               // SN-F Component code
│   │── tb                    // test top (incl. tb_hnf_link.sv, the Chapter 14
│   │                         //   check run by tools/link_check.sh)
│   │── case                  // test case
│   │── Makefile              // compile script
│   └── file_list_tb.f        // list of all src and header files
└── tools
    ├── lint.sh               // Verilator structural lint, licence-free (CI)
    ├── link_check.sh         // Chapter 14 link-activation bench (needs a simulator)
    ├── mesh_generator        //Mesh topology router configure tool
    └── ring_generator        //Ring topology router configure tool

```
# 3 Usage
  Please read the following notes to make sure everything is used correctly.
## 3.1 Parameter configuration
  The parameters of each component are described below. You can set them as needed when instantiating the corresponding module.
### 3.1.1 SXP parameter configuration

At present the SXP treats REQ, RSP, DAT and SNP identically. A CHI SNP message has
no TgtID field, so the SXP appends a TgtID field of fixed 7-bit length after the
standard SNP message and uses it for routing. The SXP only routes on TgtID; it does
not modify the flit in any way, including SNP messages.

The SXP code provides the function of a single channel only:
`rtl/misc/chi_xp_channel.v`. How these are assembled into a complete SXP is left to
the user. When using it, configure `FLIT_WIDTH` and `FLIT_TGT_OFFSET` according to
the channel type (`FLIT_TGT_OFFSET` currently only needs configuring for the SNP
channel; the default of 4 is fine for the others).

The NodeID width and the routing fields inside it are parameters, so a crosspoint
elaborates consistently with the HNF/HNI/SNF/RNI around it:

|    Parameter          |         Description                                            | Default |
| :-------------------: | :------------------------------------------------------------: | :-----: |
| CHIE_NID_WIDTH_PARAM  | NodeID width. The CHI E.b protocol requires this to be in the range 7-11 | 7 |
| XP_XID_WIDTH          | Width of the X field inside the NodeID                          | 3 |
| XP_YID_WIDTH          | Width of the Y field inside the NodeID                          | 3 |

The NodeID routing fields are LSB-anchored: **bit 0** is the local port (P0/P1),
then `XP_YID_WIDTH` bits of Y, then `XP_XID_WIDTH` bits of X. Bits above those are
unused by the route decode. `port + Y + X` must fit inside `CHIE_NID_WIDTH_PARAM`,
which the module checks at elaboration. `chi_ring_channel.v` takes
`CHIE_NID_WIDTH_PARAM` the same way and keeps its own `ROUTER_NODE_NUM`-derived
X field.

### 3.1.2 HNF parameter configuration
The HNF parameters are listed below. They can be changed as needed in the contents of the `HNF_PARAM` macro in `rtl/include/hnf_param.v`. Apart from the parameters described below, please leave the other parameters under the `HNF_PARAM` macro at their default values. Note in addition that the L3 CacheLineSize is fixed at 64 bytes.

|    Parameter                  |         Description                       | Default |
| :---------------------------: | :---------------------------------------: | :----: |
| CHIE_REQ_ADDR_WIDTH_PARAM   | Address width of the REQ message                          | 44     |
| CHIE_SNP_ADDR_WIDTH_PARAM   | Address width of the SNP message. The CHI E.b protocol requires this to be (CHIE_REQ_ADDR_WIDTH_PARAM-3) | 41      |
| CHIE_NID_WIDTH_PARAM        | The CHI E.b protocol requires this to be in the range 7-11             | 7       |
| CHIE_DATA_WIDTH_PARAM       | Data width of the CHI DAT channel (not currently configurable)        | 256     |
| CHIE_BE_WIDTH_PARAM         | BE width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/8)| 32      |
| CHIE_DATACHECK_WIDTH_PARAM  | DataCheck width of the CHI DAT channel; must match the data width (0 or CHIE_DATA_WIDTH_PARAM/8)| 32      |
| CHIE_POISON_WIDTH_PARAM     | Poison width of the CHI DAT channel; must match the data width (0 or CHIE_DATA_WIDTH_PARAM/64)| 4       |
| CHIE_REQ_RSVDC_WIDTH_PARAM  | User-defined width on the CHI REQ channel                        | 0       |
| CHIE_DAT_RSVDC_WIDTH_PARAM  | User-defined width on the CHI DAT channel                        | 0       |
| HNF_MSHR_RNF_NUM_PARAM      | Number of RNFs in the NoC                          | 4      |
| HNF_MSHR_RNI_NUM_PARAM      | Number of RNIs in the NoC                          | 0      |
| RNF_NID_LIST_PARAM          | List of RNF node IDs in the NoC                    | {7'd48,7'd16,7'd40,7'd8} |
| RNI_NID_LIST_PARAM          | List of RNI node IDs in the NoC                    | {7'd1} |
| HNF_NID_PARAM               | HNF nodeid                                | 0      |
| SNF_NID_PARAM               | SNF nodeid                               | 32      |
| XP_LCRD_NUM_PARAM           | Maximum L-Credit count for each HNF channel. The maximum value is 15 | 15     |
| HNF_SF_ENTRIES_NUM_PARAM    | Total number of Snoop Filter entries                  | 131072     |
| HNF_SF_WAY_NUM_PARAM        | Snoop Filter Way                            | 16      |
| HNF_MSHR_EXCL_RN_NUM_PARAM  | Number of data-tag entries in the Global Monitor module. The maximum depends on the number of RNs and the number of LPs each RN supports; 8 LPs are supported by default | 32      |
| HNF_MSHR_EXCL_RN_WIDTH_PARAM| Width of the data-tag entry count in the Global Monitor module; must match HNF_MSHR_EXCL_RN_NUM_PARAM | 5       |
| HNF_MSHR_ENTRIES_NUM_PARAM  | Number of entries supported in the processing queue                   | 32      |
| HNF_MSHR_ENTRIES_WIDTH_PARAM| Width of the processing-queue entry count; must match HNF_MSHR_ENTRIES_NUM_PARAM | 5       |
| HNF_L3_CACHE_SIZE_PARAM     | Total L3 Cache size, in KB                  | 4096  |
| HNF_L3_WAY_NUM_PARAM        | L3 Cache way                                | 16      |

### 3.1.3 RNI parameter configuration
The RNI parameters are listed below. They can be changed as needed in the contents of the `RNI_PARAM` macro in `rtl/include/rni_param.v`. Apart from the parameters described below, please leave the other parameters under the `RNI_PARAM` macro at their default values.

|    Parameter                  |         Description                       | Default |
| :---------------------------: | :---------------------------------------: | :----: |
| AXI4_PA_WIDTH_PARAM        | AXI4 address width                            | 44     |
| AXI4_AXDATA_WIDTH_PARAM    | AXI4 data width (not currently configurable)               | 128    |
| CHIE_NID_WIDTH_PARAM       | Width of the NODEID. The CHI E.b protocol requires this to be in the range 7-11 | 11     |
| CHIE_REQ_RSVDC_WIDTH_PARAM | User-defined width in the REQ message                    | 0      |
| CHIE_DAT_RSVDC_WIDTH_PARAM | User-defined width in the DAT message                    | 0      |
| CHIE_REQ_ADDR_WIDTH_PARAM  | Address width of the REQ message                          | 44     |
| CHIE_SNP_ADDR_WIDTH_PARAM  | Address width of the SNP message. The CHI E.b protocol requires this to be (CHIE_REQ_ADDR_WIDTH_PARAM-3) | 41     |
| CHIE_PA_WIDTH_PARAM        | Address width of the PA message                            | 44     |
| CHIE_DATA_WIDTH_PARAM      | Data width of the DAT message (not currently configurable)               | 256    |
| CHIE_BE_WIDTH_PARAM        | BE width of the DAT message; must match the data width (CHIE_DATA_WIDTH_PARAM/8) | 32     |
| CHIE_POISON_WIDTH_PARAM    | Poison width of the DAT message; must match the data width (0 or CHIE_DATA_WIDTH_PARAM/64) | 0      |
| CHIE_DATACHECK_WIDTH_PARAM | DataCheck width of the DAT message; must match the data width (0 or CHIE_DATA_WIDTH_PARAM/8) | 0      |
| RNI_NID_PARAM              | RNI nodeid                                | 6      |
| HNF_NID_PARAM              | HNF nodeid                                | 0      |

### 3.1.4 HNI parameter configuration

The HNI parameters are listed below. They can be specified as needed at instantiation.

|    Parameter                  |         Description                       | Default |
| :---------------------------: | :---------------------------------------: | :----: |
|   CHIE_REQ_ADDR_WIDTH_PARAM   | Address width of a request on the CHI REQ channel                 | 44  |
|   CHIE_NID_WIDTH_PARAM        | NodeID width of a request on the CHI REQ channel               | 7  |
|   CHIE_DATA_WIDTH_PARAM       | Data width of the CHI DAT channel (not currently configurable)     | 256 |
|   CHIE_BE_WIDTH_PARAM         | BE width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/8)| 32  |
|   CHIE_DATACHECK_WIDTH_PARAM  | DataCheck width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/8)| 32  |
|   CHIE_POISON_WIDTH_PARAM     | Poison width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/64)| 4 |
|   HNI_MSHR_RNF_NUM_PARAM      | Number of RNFs                                 | 4 |
|   AXI4_PA_WIDTH_PARAM         | Address width of the AXI channel                         | 32 |
|   AXI_AXDATA_WIDTH_PARAM      | Data width of the AXI channel (not currently configurable)         | 128 |
|   XP_LCRD_NUM_PARAM           | Total L-Credits for a single channel                        | 15 |
|   HNI_MSHR_EXCL_RN_NUM_PARAM  | Number of data-tag entries in the Global Monitor module. The maximum depends on the number of RNs and the number of LPs each RN supports; 8 LPs are supported by default | 32 |
|   HNI_MSHR_EXCL_RN_WIDTH_PARAM| Width of the data-tag entry count in the Global Monitor module; must match HNI_MSHR_EXCL_RN_NUM_PARAM | 5 |
|   HNI_MSHR_ENTRIES_NUM_PARAM  | Number of entries supported in the processing queue                   | 32 |
|   HNI_MSHR_ENTRIES_WIDTH_PARAM| Width of the processing-queue entry count; must match HNI_MSHR_ENTRIES_NUM_PARAM                  | 5 |
|   HNI_NODEID_PARAM            | NodeID of the HNI                               | 0 |
|   HNI_ADDR_REGION_NUM         | Number of AXI address regions, corresponding to the number of AXIDs         | 16 |
|   HNI_ADDR_REGION_LSB         | Base address of each AXI address region; must be an integer multiple of the address width | {44'hf000, 44'he000, 44'hd000, 44'hc000, 44'hb000, 44'ha000, 44'h9000, 44'h8000, 44'h7000, 44'h6000, 44'h5000, 44'h4000, 44'h3000, 44'h2000, 44'h1000, 44'h0000} |
|   HNI_ADDR_REGION_SIZE        | Width of each AXI address region; the minimum allowed is 12 (4KB)    | {12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12} |

### 3.1.5 SNF parameter configuration

The SNF parameters are listed below. They can be specified as needed at instantiation.

|    Parameter                  |         Description                       | Default |
| :---------------------------: | :---------------------------------------: | :----: |
| CHIE_REQ_ADDR_WIDTH_PARAM    | Address width of a request on the CHI REQ channel                                        | 44   |
| CHIE_NID_WIDTH_PARAM         | NodeID width of a request on the CHI REQ channel                                      | 7    |
| CHIE_DATA_WIDTH_PARAM        | Data width of the CHI DAT channel (not currently configurable)                                   | 256  |
| CHIE_BE_WIDTH_PARAM          | BE width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/8)        | 32   |
| CHIE_DATACHECK_WIDTH_PARAM   | DataCheck width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/8) | 32   |
| CHIE_POISON_WIDTH_PARAM      | Poison width of the CHI DAT channel; must match the data width (CHIE_DATA_WIDTH_PARAM/64)   | 4    |
| CHIE_REQ_RSVDC_WIDTH_PARAM   | User-defined width on the CHI REQ channel                                        | 0    |
| CHIE_DAT_RSVDC_WIDTH_PARAM   | User-defined width on the CHI DAT channel                                        | 0    |
| SNF_MSHR_HNF_NUM_PARAM       | Number of HNFs                                                          | 4    |
| XP_LCRD_NUM_PARAM            | Maximum number of L-Credits for a single channel                                           | 15   |
| SNF_MSHR_ENTRIES_NUM_PARAM   | Number of entries supported in the processing queue                                          | 32   |
| SNF_NID_PARAM                | NodeID of the SNF                                                      | 7'd3 |
| AXI4_AXDATA_WIDTH_PARAM      | Data width of the AXI channel; can be configured as 128/256                                | 128  |
| AXI4_PA_WIDTH_PARAM          | Address width of the AXI channel                                                | 32   |
| SNF_MSHR_ENTRIES_WIDTH_PARAM | Width of the processing-queue entry count; must match SNF_MSHR_ENTRIES_NUM_PARAM  | 5    |

## 3.2 RTL compilation
`tools/lint.sh` is the licence-free gate CI runs (`.github/workflows/lint.yml`):
Verilator 5.0 or later elaborates every node standalone and fails on any `%Error`
or on `%Warning-ALWNEVER`.

`tools/link_check.sh` runs `rtl/tb/tb_hnf_link.sv`, the Chapter 14
link-activation check for `hnf.v`, under `xrun` (or `SIM=vcs`). It is not in CI
because it needs a licensed simulator: Verilator 5.048 segfaults constructing the
HN-F model, inside `VL_MURMUR64_HASH` in `ctor_var_reset`, before any Verilog runs.

The repo's own simulation flow needs VCS:

1. `make com` compiles every file listed in file_list.
2. `make sim` runs the testcases.
3. `make run_dve` opens the waveform viewer.
4. `make clean` removes every file produced by compilation and simulation.

# 4 Changes in this fork

Found by driving the RTL with the 10xEngineers CHI VIP. Filed as issues on this
fork rather than upstream, which has had no commit since 2025-06-25; the upstream
issue and PR backlog is ported here too.

| Change | Rule |
| :--- | :--- |
| `snf.v` — every request outside `{ReadNoSnp, WriteNoSnpFull, WriteNoSnpPtl}` was accepted, spent its L-Credit, took an MSHR entry and was never answered. `snf_mshr.v` now classifies every inbound request and owns a response programme for each class ([#1](https://github.com/10x-Engineers/CHI-OpenNoC/issues/1)) | CHI E.b §4.5.1, §9.3, §9.9.1 |
| `snf.v` — `ReadNoSnpSep` implemented: `DataSepResp` in place of `CompData`, and the `ReadReceipt` an `Order != 0b00` read is owed whether or not the data goes back direct | CHI E.b §4.5.1, §2.8.5 |
| `snf.v` — `CleanShared` / `CleanInvalid` / `MakeInvalid` / `CleanSharedPersist` complete with `Comp`, and `CleanSharedPersistSep` with the folded `CompPersist`; a CMO at a Subordinate holding no cached copy alters no data | CHI E.b §2.3.9, §2.3.5 |
| `snf.v` — everything the SN-F cannot execute (Atomics, `WriteNoSnpZero`, the Combined Writes, any unrecognised opcode) is completed with a Non-data Error in the shape its own table gives it, and `PrefetchTgt` / `PCrdReturn` free their entry with no response at all ([#36](https://github.com/10x-Engineers/CHI-OpenNoC/issues/36), [#37](https://github.com/10x-Engineers/CHI-OpenNoC/issues/37)) | CHI E.b §9.1, §9.4.4, §16.3.3, §2.3.6 |
| `hnf.v` — the HN-F had no `LINKACTIVE`/`SACTIVE` ports at all and granted RX L-Credits out of reset. It now carries the same six-signal interface as its siblings, drives `chi_link_handshake`, gates every RX credit grant on RUN, blocks TX flits outside RUN and returns its TX L-Credits while deactivating. `rtl/tb/tb_hnf_link.sv` + `tools/link_check.sh` are the check ([#3](https://github.com/10x-Engineers/CHI-OpenNoC/issues/3)) | CHI E.b Tables 14-2/14-3, §14.7.2 |
| `rni_link_handshake.v` → `rtl/misc/chi_link_handshake.v` — the link-activation FSM was RN-I-local and is now the shared module every node uses | — |
| `chi_xp_channel.v`, `chi_ring_channel.v` — the NodeID width was a hard-coded `localparam 7` and the XY decode sliced literal `[6:4]`/`[3:1]`, so a system elaborated at width 11 mis-routed every TgtID. Both take `CHIE_NID_WIDTH_PARAM`, and the mesh/ring generators pass it through ([#4](https://github.com/10x-Engineers/CHI-OpenNoC/issues/4)) | CHI E.b §16.1 |
| `snf.v` — `TXLINKACTIVEREQ` was tied to `1'b1`, so it was asserted throughout reset, and the Transmit link could never leave ACTIVATE for DEACTIVATE/STOP | CHI E.b §14.1.3, §14.5 |
| `snf.v` — `RXLINKACTIVEACK` reset synchronously, so it still drove its old value on the first cycle of reset. Both signals now reset asynchronously | CHI E.b §14.1.3 |
| `snf_data_buffer.v` — RSVDC, DataCheck and Poison were assigned in `always @*` blocks whose right-hand sides were constants, so the inferred sensitivity list was empty and the blocks never executed | — |
| `hnf_link_txdat_wrap.v`, `hni_data_buffer.v` — the same never-executing `always @*` construct, still present after the `snf` fix. `tools/lint.sh` now gates the class ([#2](https://github.com/10x-Engineers/CHI-OpenNoC/issues/2)) | — |
| `hni.v` — the HN-I hand-rolled its link activation (`RXLINKACTIVEACK` a one-cycle delay of `RXLINKACTIVEREQ`, `TXLINKACTIVEREQ` tied high out of reset) and granted RX L-Credits unconditionally from `hni_rxcrd_enable = 1'b1`. It now drives the shared `chi_link_handshake`, gates every RX grant on RUN, blocks TX flits outside RUN and returns its TX L-Credits while deactivating — the same treatment `hnf.v` got in [#3](https://github.com/10x-Engineers/CHI-OpenNoC/issues/3) ([#42](https://github.com/10x-Engineers/CHI-OpenNoC/issues/42)) | CHI E.b Tables 14-2/14-3 |
| `hni.v` — `TXSACTIVE` was `TXLINKACTIVEREQ & TXLINKACTIVEACK & ~RST`, which §14.7.4 forbids as a derivation ("SACTIVE signaling is orthogonal to the LINKACTIVE states") and which defeats its power-management purpose. It now tracks outstanding Protocol-layer work, as `snf.v` does since [#23](https://github.com/10x-Engineers/CHI-OpenNoC/issues/23) ([#42](https://github.com/10x-Engineers/CHI-OpenNoC/issues/42)) | CHI E.b §14.7.2, §14.7.4 |
| `rni_arctrl.v`, `rni_awctrl.v` — the bridge pinned `ReadOnce` / `WriteUniquePtl` with `Device=0, Cacheable=1, SnpAttr=Snoopable` for every access, ignoring `ARCACHE`/`AWCACHE`. Each row of Table 2-11 names a memory type, so a Device or Non-cacheable AXI access now maps to the row that names it — `ReadNoSnp` / `WriteNoSnpPtl`, Non-snoopable, Allocate 0, EWA from `AxCACHE[0]`, EndpointOrder on the Device rows ([#20](https://github.com/10x-Engineers/CHI-OpenNoC/issues/20), [#21](https://github.com/10x-Engineers/CHI-OpenNoC/issues/21)) | CHI E.b Table 2-11 p.2-129, Table 2-13 p.2-132 |
| `rni_awctrl.v` — a `DBIDRespOrd` was not recognised as the write's buffer grant, so an ordered write from a Home that answers with it never sent its data. Table B-3 lists it among the responses an RN-I receives ([#43](https://github.com/10x-Engineers/CHI-OpenNoC/issues/43)) | CHI E.b Table B-3 p.B-495, §2.8.5 |
| `rni_link_ctl.v` — the `txlink_run` output `chi_link_handshake` gained in [#3](https://github.com/10x-Engineers/CHI-OpenNoC/issues/3) was left unconnected while the RN-I re-derived the same term locally | — |
