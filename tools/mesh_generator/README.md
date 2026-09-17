# Mesh Generator
Mesh Generator 主要可以根据用户自定义配置完成 Mesh XP 的自动连接工作, 用户只需要根据配置正确将 CHI 节点连接到 Mesh XP 上就可以工作.

# 使用说明
配置 mesh_xxx.json, 要求 Mesh 是一个矩形, 里面每个XP节点都必须配置. 下面以工具中的 mesh_2x2.json 为例:
```
{
    "XP0_0": {         //XP的名字,可以根据拓扑自定义,符合 verilog 实例名称就可以
        "X": 0,        //XP的X坐标,目前是支持3bit,即0-7
        "Y": 0,        //XP的Y坐标,目前是支持3bit,即0-7
        "P0": "RNF",   //P0的类型,目前支持 RNF, RNI, HNF, HNI, SNF, 当端口没有连接时,请配置为 NONE
        "P1": "NONE"
    },
    "XP1_0": {
        "X": 1,
        "Y": 0,
        "P0": "HNF",
        "P1": "NONE"
    },
    "XP0_1": {
        "X": 0,
        "Y": 1,
        "P0": "HNI",
        "P1": "NONE"
    },
    "XP1_1": {
        "X": 1,
        "Y": 1,
        "P0": "NONE",
        "P1": "NONE"
    }
}

```
根据配置生成 Mesh 网络:
```shell
./mesh_gen.py -f xxx.json
...
Generate Mesh Wrapper mesh_wrapper_xxx.sv
```
请将以下文件放入目标工程下: `mesh_wrapper_xxx.sv, chi_xp_node.sv, chi_xp_channel.sv`

# Populated system (RN-F)

When the config has any `RNF` port, the generator also emits `mesh_system_<X>x<Y>.sv`
(`ring_gen.py` emits `ring_system_<N>.sv` the same way): the fabric with an `rnf`
instance on every RNF port. Every other port is brought out under the wrapper's own
names, for the integrator to connect its HN-F, SN-F, HN-I or RN-I.

- **NodeIDs are derived, not typed.** The fabric routes on LSB-anchored fields --
  `{X, Y, port}` for a mesh (`X<<4 | Y<<1 | port`), `{X, port}` for a ring -- so the
  generated `<system>_pkg` carries one `<XP>_<P>_NID` per connected port plus
  `RNF_NUM` and `RNF_NID_LIST`, in the layout the HN-F's `RNF_NID_LIST_PARAM`
  expects. Parameterise every node from that package.
- **Each RN-F's Home** is the config's one HNF port; a config with RNF ports and
  zero or several HNF ports is refused. `<XP>_<P>_HNF_NID` overrides it.
- **Chapter 15 is not carried by the fabric.** `SYSCOREQ`/`SYSCOACK` are a direct
  pair between a Requester and the interconnect (CHI E.b SS15.1 p.15-466), so each
  RN-F's pair leaves the system as `<XP>_<P>_SYSCOREQ`/`_SYSCOACK`, with
  `_COHERENCY_EN` (its own decision to enter coherency) and its AXI4 core port.

```shell
./mesh_gen.py -f mesh_2x2.json [-o <dir>]
Generate mesh_wrapper_2x2.sv
Generate mesh_system_2x2.sv
```
Compile `mesh_system_*.sv` after `mesh_wrapper_*.sv`, `chi_xp_node.sv`,
`rtl/misc/chi_xp_channel.sv` and the RN-F sources (`rtl/src/rnf/*.sv`, plus
`chi_lcrd_hdlr.sv`, `chi_link_handshake.sv`, `sync_fifo.sv` and `assert_checker.sv`
from `rtl/misc/`). `tools/lint.sh` holds both checked-in configs' systems at zero
warnings at NodeID_Width 7 and 11.
