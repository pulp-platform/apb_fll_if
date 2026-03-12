// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>

package apb_fll_pkg;

  localparam int unsigned STATUS_BASE_ADDR = 32'h0;
  localparam int unsigned CONFIG1_BASE_ADDR = 32'h4;
  localparam int unsigned CONFIG2_BASE_ADDR = 32'h8;
  localparam int unsigned INTEGRATOR_BASE_ADDR = 32'hC;

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
