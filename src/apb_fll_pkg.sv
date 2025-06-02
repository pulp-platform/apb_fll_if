// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

package apb_fll_pkg;

  typedef struct packed {
    logic        req;    // request
    logic        wrn;    // write not read
    logic [1:0]  addr;   // address
    logic [31:0] wdata;  // write data
  } fll_req_t;

  typedef struct packed {
    logic        ack;    // acknowledge
    logic [31:0] rdata;  // read data
    logic        lock;   // lock
  } fll_rsp_t;

endpackage
