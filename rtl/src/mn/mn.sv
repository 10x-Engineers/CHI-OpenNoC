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

`include "mn_defines.svh"
`include "mn_param.svh"
`include "param_check.svh"

// Miscellaneous Node (SS1.3 p.1-22): the Completer of every DVMOp (Table B-1 p.B-493)
// and the source of every SnpDVMOp (Table B-2 p.B-494). It forwards each DVM payload
// unexamined, so the system it serves declares DVM_v8.4 (SS16.1.1 p.16-473) at every
// MN_RN_NID_LIST_PARAM Requester and nothing needs suppressing.
module mn `MN_PARAM
    (
    input  wire                         CLK,
    input  wire                         RST,

    output wire                         TXLINKACTIVEREQ,
    input  wire                         TXLINKACTIVEACK,
    input  wire                         RXLINKACTIVEREQ,
    output wire                         RXLINKACTIVEACK,
    output wire                         TXSACTIVE,
    input  wire                         RXSACTIVE,

    input  wire                         RXREQFLITV,
    input  chie_pkg::req_flit_s         RXREQFLIT,
    input  wire                         RXREQFLITPEND,
    output wire                         RXREQLCRDV,

    input  wire                         RXRSPFLITV,
    input  chie_pkg::rsp_flit_s         RXRSPFLIT,
    input  wire                         RXRSPFLITPEND,
    output wire                         RXRSPLCRDV,

    input  wire                         RXDATFLITV,
    input  chie_pkg::dat_flit_s         RXDATFLIT,
    input  wire                         RXDATFLITPEND,
    output wire                         RXDATLCRDV,

    output wire                         TXRSPFLITV,
    output chie_pkg::rsp_flit_s         TXRSPFLIT,
    output wire                         TXRSPFLITPEND,
    input  wire                         TXRSPLCRDV,

    output wire                         TXSNPFLITV,
    output opennoc_mn_pkg::snp_routed_s TXSNPFLIT,
    output wire                         TXSNPFLITPEND,
    input  wire                         TXSNPLCRDV,

    // Chapter 15 is kept by whoever owns each Requester's SYSCOREQ/SYSCOACK pair.
    // SYSCO_SNP_EN[i] is SYSCOREQ of MN_RN_NID_LIST_PARAM entry i: Table 15-1
    // (p.15-468, MUST) lets the interconnect send it new snoops only while HIGH.
    // SYSCO_SNP_PEND[i] is HIGH while a SnpDVMOp to it is unanswered, which SS15.2.2
    // (p.15-468, MUST) holds SYSCOACK HIGH for.
    input  wire [MN_RN_NUM_PARAM-1:0]   SYSCO_SNP_EN,
    output wire [MN_RN_NUM_PARAM-1:0]   SYSCO_SNP_PEND
    );

    wire                         prot_rxreqflitv, prot_rxrspflitv, prot_rxdatflitv;
    chie_pkg::req_flit_s         prot_rxreqflit;
    chie_pkg::rsp_flit_s         prot_rxrspflit;
    chie_pkg::dat_flit_s         prot_rxdatflit;
    wire [1:0]                   prot_req_free;
    wire                         prot_txrspflitv, prot_txrspflit_sent;
    chie_pkg::rsp_flit_s         prot_txrspflit;
    wire                         prot_txsnpflitv, prot_txsnpflit_sent;
    opennoc_mn_pkg::snp_routed_s prot_txsnpflit;
    wire                         prot_txflitv;
    wire                         ctl_busy;

    // SS14.7.2 (p.14-460, MUST): TXSACTIVE covers every transaction in progress and
    // the flit that finishes one.
    assign TXSACTIVE = (ctl_busy | prot_txflitv) & ~RST;

    mn_link_ctl `MN_PARAM_INST u_mn_link_ctl (
        .clk_i                 (CLK                 ),
        .rst_i                 (RST                 ),
        .TXLINKACTIVEREQ       (TXLINKACTIVEREQ     ),
        .TXLINKACTIVEACK       (TXLINKACTIVEACK     ),
        .RXLINKACTIVEREQ       (RXLINKACTIVEREQ     ),
        .RXLINKACTIVEACK       (RXLINKACTIVEACK     ),
        .TXRSPFLITPEND         (TXRSPFLITPEND       ),
        .TXRSPFLITV            (TXRSPFLITV          ),
        .TXRSPFLIT             (TXRSPFLIT           ),
        .TXRSPLCRDV            (TXRSPLCRDV          ),
        .TXSNPFLITPEND         (TXSNPFLITPEND       ),
        .TXSNPFLITV            (TXSNPFLITV          ),
        .TXSNPFLIT             (TXSNPFLIT           ),
        .TXSNPLCRDV            (TXSNPLCRDV          ),
        .RXREQFLITPEND         (RXREQFLITPEND       ),
        .RXREQFLITV            (RXREQFLITV          ),
        .RXREQFLIT             (RXREQFLIT           ),
        .RXREQLCRDV            (RXREQLCRDV          ),
        .RXRSPFLITPEND         (RXRSPFLITPEND       ),
        .RXRSPFLITV            (RXRSPFLITV          ),
        .RXRSPFLIT             (RXRSPFLIT           ),
        .RXRSPLCRDV            (RXRSPLCRDV          ),
        .RXDATFLITPEND         (RXDATFLITPEND       ),
        .RXDATFLITV            (RXDATFLITV          ),
        .RXDATFLIT             (RXDATFLIT           ),
        .RXDATLCRDV            (RXDATLCRDV          ),
        .prot_txrspflit_i      (prot_txrspflit      ),
        .prot_txrspflitv_i     (prot_txrspflitv     ),
        .prot_txrspflit_sent_o (prot_txrspflit_sent ),
        .prot_txsnpflit_i      (prot_txsnpflit      ),
        .prot_txsnpflitv_i     (prot_txsnpflitv     ),
        .prot_txsnpflit_sent_o (prot_txsnpflit_sent ),
        .prot_rxreqflitv_o     (prot_rxreqflitv     ),
        .prot_rxreqflit_o      (prot_rxreqflit      ),
        .prot_rxrspflitv_o     (prot_rxrspflitv     ),
        .prot_rxrspflit_o      (prot_rxrspflit      ),
        .prot_rxdatflitv_o     (prot_rxdatflitv     ),
        .prot_rxdatflit_o      (prot_rxdatflit      ),
        .prot_req_free_i       (prot_req_free       ),
        .prot_txflitv_o        (prot_txflitv        )
    );

    mn_ctl `MN_PARAM_INST u_mn_ctl (
        .clk_i            (CLK                 ),
        .rst_i            (RST                 ),
        .rxreqflitv_i     (prot_rxreqflitv     ),
        .rxreqflit_i      (prot_rxreqflit      ),
        .rxrspflitv_i     (prot_rxrspflitv     ),
        .rxrspflit_i      (prot_rxrspflit      ),
        .rxdatflitv_i     (prot_rxdatflitv     ),
        .rxdatflit_i      (prot_rxdatflit      ),
        .req_free_o       (prot_req_free       ),
        .txrspflitv_o     (prot_txrspflitv     ),
        .txrspflit_o      (prot_txrspflit      ),
        .txrspflit_sent_i (prot_txrspflit_sent ),
        .txsnpflitv_o     (prot_txsnpflitv     ),
        .txsnpflit_o      (prot_txsnpflit      ),
        .txsnpflit_sent_i (prot_txsnpflit_sent ),
        .sysco_snp_en_i   (SYSCO_SNP_EN        ),
        .sysco_snp_pend_o (SYSCO_SNP_PEND      ),
        .busy_o           (ctl_busy            )
    );

    `CHECK_DERIVED_WIDTH(mn, MN_ENTRIES_NUM_PARAM, MN_ENTRIES_WIDTH_PARAM, entries)

    // The Sync class may hold every entry but one (SS8.1.3 p.8-307, MUST), and a
    // snoopee takes at least two SnpDVMOps (SS8.1.3 p.8-308, MUST).
    if (MN_ENTRIES_NUM_PARAM < 2)
        $fatal(1, "mn: MN_ENTRIES_NUM_PARAM=%0d; one entry is reserved for a Non-sync DVMOp, so at least two are needed.",
               MN_ENTRIES_NUM_PARAM);
    if (MN_RN_SNPDVM_NUM_PARAM < 2)
        $fatal(1, "mn: MN_RN_SNPDVM_NUM_PARAM=%0d; every RN-F and RN-D accepts at least two SnpDVMOps.",
               MN_RN_SNPDVM_NUM_PARAM);

    chie_flit_opt_check #(
        .REQ_RSVDC_WIDTH (CHIE_REQ_RSVDC_WIDTH_PARAM),
        .DAT_RSVDC_WIDTH (CHIE_DAT_RSVDC_WIDTH_PARAM),
        .MPAM_WIDTH      (CHIE_MPAM_WIDTH_PARAM     )
    ) u_chie_flit_opt_check ();

endmodule
