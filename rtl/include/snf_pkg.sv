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

// SN-F local packed payloads. These are not CHI flits -- they are what the QoS
// block hands the TXRSP block through a width-parameterised sync_fifo -- but they
// were sliced by the same running-sum macros, with the same unchecked ranges.

`ifndef SNF_PKG_SV
`define SNF_PKG_SV

package snf_pkg;

  // What a retried request has to keep so its RetryAck can be built later
  // (SS2.11 p.2-145: the PCrdType granted must match the one retried under).
  typedef struct packed {
    logic [3:0]                     pcrdtype;
    logic                           trace;
    logic [3:0]                     qos;
    logic [11:0]                    txnid;
    logic [chie_pkg::NID_WIDTH-1:0] srcid;
  } retry_ackq_s;

  // A PCrdGrant binds to no transaction (SS2.6.5 p.2-112 sets its TxnID to zero),
  // so the queue carries only who to grant to and under which credit type.
  typedef struct packed {
    logic [3:0]                     pcrdtype;
    logic [3:0]                     qos;
    logic [chie_pkg::NID_WIDTH-1:0] srcid;
  } pcrdgrantq_s;

endpackage

`endif
