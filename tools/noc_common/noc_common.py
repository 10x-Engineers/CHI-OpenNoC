# Copyright (c) 2026 10xEngineers
# OpenNoC is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
# See the Mulan PSL v2 for more details.
#
# What mesh_gen.py and ring_gen.py share: the node-port types, the CHI signal set
# each type brings to a crosspoint port, and the populated system -- the
# generated fabric with an rnf instance on every RNF port.

from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

COMMON_TEMPLATES = Path(__file__).resolve().parent / "template"


class PortEnum(Enum):
    NONE = "NONE"
    RNF = "RNF"
    RNI = "RNI"
    HNF = "HNF"
    HNI = "HNI"
    SNF = "SNF"
    MN = "MN"


def _channel(tx, ch, width):
    """One channel's four wires, in the fabric's direction: what a node transmits
    is an input here, and the L-Credit that paces it an output."""
    into, outof = ("input", "output") if tx else ("output", "input")
    side = "TX" if tx else "RX"
    return [(into, "", f"{side}{ch}FLITPEND"),
            (into, "", f"{side}{ch}FLITV"),
            (into, width, f"{side}{ch}FLIT"),
            (outof, "", f"{side}{ch}LCRDV")]


def chi_signals(kind):
    """The CHI signals a node of `kind` exchanges with its crosspoint port.

    Figure 13-5 (SS13.6.1 p.13-400) gives an RN-F an RX snoop channel and no RXREQ;
    Figure 13-8 (SS13.6.2 p.13-401) gives a Subordinate no RXRSP. A Home's TX snoop
    carries the routing TgtID beside the flit, which Table 13-8 does not define. An
    MN completes DVMOps and sources SnpDVMOps (Tables B-1/B-2), so it has neither
    TXREQ nor TXDAT, and its TX snoop is routed as a Home's is.
    """
    flit = "[{0}_FLIT_WIDTH-1:0]".format
    sigs = [("input", "", "TXSACTIVE"), ("output", "", "RXSACTIVE"),
            ("input", "", "TXLINKACTIVEREQ"), ("output", "", "TXLINKACTIVEACK"),
            ("output", "", "RXLINKACTIVEREQ"), ("input", "", "RXLINKACTIVEACK")]
    if kind in ("RNF", "RNI", "HNF"):
        sigs += _channel(True, "REQ", flit("REQ"))
    if kind in ("HNF", "HNI", "SNF", "MN"):
        sigs += _channel(False, "REQ", flit("REQ"))
    sigs += _channel(True, "RSP", flit("RSP"))
    if kind != "SNF":
        sigs += _channel(False, "RSP", flit("RSP"))
    if kind != "MN":
        sigs += _channel(True, "DAT", flit("DAT"))
    sigs += _channel(False, "DAT", flit("DAT"))
    if kind in ("HNF", "MN"):
        sigs += _channel(True, "SNP", "[SNP_FLIT_WIDTH+CHIE_NID_WIDTH_PARAM-1:0]")
    if kind == "RNF":
        sigs += _channel(False, "SNP", flit("SNP"))
    return sigs


@dataclass
class NodePort:
    name: str
    kind: str
    nid: int


def node_ports(nodes, nid_of):
    """Every connected crosspoint port in config order, with the NodeID the
    fabric routes to it by."""
    ports = []
    for node in nodes:
        for idx, p in enumerate(("P0", "P1")):
            kind = getattr(node, p).value
            if kind != "NONE":
                ports.append(NodePort(f"{node.name}_{p}", kind, nid_of(node, idx)))
    return ports


def make_env(template_dir):
    env = Environment(loader=FileSystemLoader([str(template_dir), str(COMMON_TEMPLATES)]))
    env.trim_blocks = True
    env.lstrip_blocks = True
    env.globals["chi_signals"] = chi_signals
    return env


def render(env, template, out, **kw):
    with open(out, "w", encoding="UTF-8") as f:
        f.write(env.get_template(template).render(**kw))
    print(f"Generate {Path(out).name}")


def render_system(env, wrapper, system, ports, out_dir):
    """The fabric populated with the RN-F: an rnf on every RNF port, every other
    port brought out unchanged. An RN-F addresses every request to its Home, so a
    config with RN-F ports needs exactly one HNF port to derive that Home from."""
    rnfs = [p for p in ports if p.kind == "RNF"]
    if not rnfs:
        return
    homes = [p for p in ports if p.kind == "HNF"]
    if len(homes) != 1:
        raise SystemExit(f"{system}: an RN-F's Home is derived from the config's one HNF "
                         f"port, and this config has {len(homes)}")
    render(env, "noc_system.j2", Path(out_dir) / f"{system}.sv",
           module=system, wrapper=wrapper, ports=ports, rnfs=rnfs, home=homes[0])
