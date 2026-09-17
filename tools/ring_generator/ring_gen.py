#!/usr/bin/env python3
# Copyright (c) 2024 Beijing Institute of Open Source Chip
# OpenNoC is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
# See the Mulan PSL v2 for more details.
#
# Author:
#    Jianxing Wang <wangjianxing@bosc.ac.cn>
#
# Generate OpenNoC Ring

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "noc_common"))
from noc_common import PortEnum, make_env, node_ports, render, render_system

@dataclass
class CrossPoint:
    name: str
    X: int
    P0: PortEnum
    P1: PortEnum
    def __init__(self, name:str = "XP", obj:dict = None):
        self.name = name
        self.X = obj["X"]
        self.P0 = PortEnum(obj["P0"])
        self.P1 = PortEnum(obj["P1"])

x_max = 1
ring_cfg = []
def main():
    global ring_cfg
    parser = argparse.ArgumentParser(description="Generate OpenNoC Ring Wrapper")
    parser.add_argument('-f', '--file',  type=str, help="ring configure file")
    parser.add_argument('-o', '--out-dir', type=str, default=".",
                        help="directory the generated files are written to")
    args = parser.parse_args()

    if args.file is None:
        parser.print_help()
        exit(-1)

    with open(args.file, 'r') as ring_cfg_file:
        cfg_data = json.load(ring_cfg_file)
        verify_cfg(cfg_data)
        if (x_max + 1) != len(cfg_data):
            print("Found Error Configuration")
            exit(-1)
        print(ring_cfg)
        generate(x_max, ring_cfg, args.out_dir)

def verify_cfg(cfg_data):
    global x_max
    global ring_cfg
    for key in cfg_data:
        xp = cfg_data[key]
        if xp["X"] > x_max:
            x_max = xp["X"]
        route_node = CrossPoint(key, xp)
        ring_cfg.append(route_node)

# NodeIDs are LSB-anchored {X, port}, the fields chi_ring_channel's route_x reads.
def ring_nid(node, port):
    return (node.X << 1) | port

def generate(x_max : int = 1, cfg : list = None, out_dir : str = "."):
    module = "ring_wrapper_{0}".format(x_max + 1)
    env = make_env(HERE / "template")
    render(env, "ring_wrapper.j2", Path(out_dir) / (module + ".sv"),
           xmax = x_max, module = module, nodes = cfg)
    render_system(env, module, "ring_system_{0}".format(x_max + 1),
                  node_ports(cfg, ring_nid), out_dir)

if __name__ == "__main__":
    main()
