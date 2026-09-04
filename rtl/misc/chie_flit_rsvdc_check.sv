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

// chie_pkg's REQ and DAT layouts carry no RSVDC field: SS16.1 makes its width
// IMPLEMENTATION DEFINED and every node here declares it zero. A build that
// widens it would otherwise get a flit whose fields all sit at the wrong
// offsets, with nothing to say so -- the widths are parameters, and a struct
// cannot grow a field from one.
module chie_flit_rsvdc_check #(
    parameter REQ_RSVDC_WIDTH = 0,
    parameter DAT_RSVDC_WIDTH = 0
    ) ();

    initial begin
        if (REQ_RSVDC_WIDTH != 0 || DAT_RSVDC_WIDTH != 0)
            $fatal(1, "%m: chie_pkg's flit layout has no RSVDC field, but this build declares REQ_RSVDC_WIDTH=%0d DAT_RSVDC_WIDTH=%0d. Add the field to chie_pkg::req_flit_s/dat_flit_s before widening it.",
                   REQ_RSVDC_WIDTH, DAT_RSVDC_WIDTH);
    end

endmodule
