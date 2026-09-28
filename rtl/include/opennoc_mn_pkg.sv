/*
* Copyright (c) 2026 10xEngineers
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*/

`ifndef OPENNOC_MN_PKG_SV
`define OPENNOC_MN_PKG_SV

package opennoc_mn_pkg;

  typedef chie_pkg::snp_routed_s snp_routed_s;

  // Table 8-7 (p.8-315): the DVMOp type, which Table 8-8 (p.8-317) puts in Req.Addr[13:11].
  localparam logic [2:0] DVM_TYPE_PICI = 3'b010;
  localparam logic [2:0] DVM_TYPE_SYNC = 3'b100;

  function automatic logic dvm_is_sync(logic [chie_pkg::REQ_ADDR_WIDTH-1:0] addr);
    return addr[13:11] == DVM_TYPE_SYNC;
  endfunction

  typedef struct packed {
    logic [chie_pkg::SNP_ADDR_WIDTH-1:0] addr;
    logic [chie_pkg::NID_WIDTH-1:0]      fwdnid;
    logic [7:0]                          vmidext;
  } dvm_snp_part_s;

  // Table 8-8 (p.8-317/8-318): one SnpDVMOp packet of the pair a DVMOp's Req.Addr and
  // 8-byte write data become, Snp.Addr[0] naming the part. Table 8-9 (p.8-320) puts
  // Range and Num on FwdNID, zero elsewhere; VMID[15:8] rides Part 1's VMIDExt.
  // Snp.Addr[42:41] of Part 2 carry VA[51,49] but PA[47:46], so a PA operation (PICI)
  // is packed as one.
  // SPEC-AMBIGUITY: Table 8-8 names only VA bits in Part 1's Snp.Addr[42:38]; a PICI,
  // which carries no VA, sends them zero.
  function automatic dvm_snp_part_s dvm_snp_part(logic                                part2,
                                                 logic [chie_pkg::REQ_ADDR_WIDTH-1:0] req_addr,
                                                 logic [63:0]                         data);
    logic [48:0] a;
    logic        pa;
    a       = '0;
    pa      = (req_addr[13:11] == DVM_TYPE_PICI);
    a[0]    = part2;
    dvm_snp_part         = '0;
    if (!part2) begin
      a[37:1] = req_addr[40:4];
      if (!pa) begin
        a[40:38] = data[46:44];
        a[41]    = data[48];
        a[42]    = data[50];
      end
      dvm_snp_part.fwdnid  = chie_pkg::NID_WIDTH'(req_addr[41]);
      dvm_snp_part.vmidext = data[63:56];
    end
    else begin
      a[40:1] = data[43:4];
      if (pa) begin
        a[42:41] = data[45:44];
        a[45:43] = data[48:46];
        a[46]    = data[49];
      end
      else begin
        a[41] = data[47];
        a[42] = data[49];
      end
      dvm_snp_part.fwdnid = chie_pkg::NID_WIDTH'({req_addr[42], data[3:0]});
    end
    dvm_snp_part.addr = a[chie_pkg::SNP_ADDR_WIDTH-1:0];
  endfunction

endpackage

`endif
