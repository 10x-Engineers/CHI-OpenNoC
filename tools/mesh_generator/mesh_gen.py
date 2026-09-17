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
# Generate OpenNoC Mesh

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
    Y: int
    P0: PortEnum
    P1: PortEnum
    def __init__(self, name:str = "XP", obj:dict = None):
        self.name = name
        self.X = obj["X"]
        self.Y = obj["Y"]
        self.P0 = PortEnum(obj["P0"])
        self.P1 = PortEnum(obj["P1"])

x_max = 1
y_max = 1
mesh_cfg = []
def main():
    global mesh_cfg
    parser = argparse.ArgumentParser(description="Generate OpenNoC Mesh Wrapper")
    parser.add_argument('-f', '--file',  type=str, help="mesh configure file")
    parser.add_argument('-o', '--out-dir', type=str, default=".",
                        help="directory the generated files are written to")
    args = parser.parse_args()

    if args.file is None:
        parser.print_help()
        exit(-1)

    with open(args.file, 'r') as mesh_cfg_file:
        cfg_data = json.load(mesh_cfg_file)
        verify_cfg(cfg_data)
        if (x_max + 1) * (y_max + 1) != len(cfg_data):
            print("Found Error Configuration")
            exit(-1)
        print(mesh_cfg)
        generate(x_max, y_max, mesh_cfg, args.out_dir)

def verify_cfg(cfg_data):
    global x_max
    global y_max
    global mesh_cfg
    for key in cfg_data:
        xp = cfg_data[key]
        if xp["X"] > x_max:
            x_max = xp["X"]
        if xp["Y"] > y_max:
            y_max = xp["Y"]
        route_node = CrossPoint(key, xp)
        mesh_cfg.append(route_node)

# NodeIDs are LSB-anchored {X, Y, port}, the fields chi_xp_channel's route_xy reads.
def mesh_nid(node, port):
    return (node.X << 4) | (node.Y << 1) | port

def generate(x_max : int = 1, y_max : int = 1, cfg : list = None, out_dir : str = "."):
    size = "{0}x{1}".format(x_max + 1, y_max + 1)
    module = "mesh_wrapper_" + size
    env = make_env(HERE / "template")
    render(env, "mesh_wrapper.j2", Path(out_dir) / (module + ".sv"),
           xmax = x_max, ymax = y_max, module = module, nodes = cfg)
    render_system(env, module, "mesh_system_" + size, node_ports(cfg, mesh_nid), out_dir)

if __name__ == "__main__":
    main()
