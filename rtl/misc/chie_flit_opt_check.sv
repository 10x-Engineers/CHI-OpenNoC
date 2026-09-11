/*
* Copyright (c) 2024 Beijing Institute of Open Source Chip
* OpenNoC is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
* See the Mulan PSL v2 for more details.
*/

// A node's width parameter for an OPTIONAL flit field and chie_pkg's flit layout are
// two declarations of one thing, and a struct cannot grow a field from a parameter --
// the layout follows the `define. A node that disagrees would get a flit whose fields
// all sit at the wrong offsets, with nothing to say so, which is what this refuses.
//
// Section 13.10.56 (p.13-441) also fixes RSVDC's legal set: "the permitted field widths
// are 4-bit, 8-bit, 12-bit, 16-bit, 24-bit, and 32-bit". Zero is the absent field.
// Section 11.3 (p.11-365) gives MPAM only 0 or 11.
module chie_flit_opt_check #(
    parameter REQ_RSVDC_WIDTH = 0,
    parameter DAT_RSVDC_WIDTH = 0,
    parameter MPAM_WIDTH      = 0
    ) ();

    function automatic bit width_legal(int unsigned w);
        return (w == 0) || (w inside {4, 8, 12, 16, 24, 32});
    endfunction

    initial begin
        if (REQ_RSVDC_WIDTH != chie_pkg::REQ_RSVDC_WIDTH)
            $fatal(1, "%m: REQ_RSVDC_WIDTH=%0d but chie_pkg's req_flit_s carries %0d. The layout follows `CHIE_REQ_RSVDC_WIDTH; define it to match, or drop the parameter override.",
                   REQ_RSVDC_WIDTH, chie_pkg::REQ_RSVDC_WIDTH);
        if (DAT_RSVDC_WIDTH != chie_pkg::DAT_RSVDC_WIDTH)
            $fatal(1, "%m: DAT_RSVDC_WIDTH=%0d but chie_pkg's dat_flit_s carries %0d. The layout follows `CHIE_DAT_RSVDC_WIDTH; define it to match, or drop the parameter override.",
                   DAT_RSVDC_WIDTH, chie_pkg::DAT_RSVDC_WIDTH);
        if (!width_legal(REQ_RSVDC_WIDTH) || !width_legal(DAT_RSVDC_WIDTH))
            $fatal(1, "%m: REQ_RSVDC_WIDTH=%0d DAT_RSVDC_WIDTH=%0d -- section 13.10.56 (p.13-441) permits 4/8/12/16/24/32, or zero for an absent field.",
                   REQ_RSVDC_WIDTH, DAT_RSVDC_WIDTH);
        if (MPAM_WIDTH != chie_pkg::MPAM_WIDTH)
            $fatal(1, "%m: MPAM_WIDTH=%0d but chie_pkg's req_flit_s and snp_flit_s carry %0d. The layout follows `CHIE_MPAM_PRESENT; define it to match, or drop the parameter override.",
                   MPAM_WIDTH, chie_pkg::MPAM_WIDTH);
        if (!(MPAM_WIDTH inside {0, 11}))
            $fatal(1, "%m: MPAM_WIDTH=%0d -- section 11.3 (p.11-365) makes the field either 0 bits or 11 bits.",
                   MPAM_WIDTH);
    end

endmodule
