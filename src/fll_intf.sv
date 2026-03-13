// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

/// Interface for FLL controll
interface FLL_BUS (
    input logic clk_i
);
    logic        req;
    logic        wrn;
    logic [1:0]  addr;
    logic [31:0] wdata;
    logic        ack;
    logic [31:0] rdata;
    logic        lock;

    modport out (
        output req, wrn, addr, wdata,
        input ack, rdata, lock
    );

    modport in (
        input req, wrn, addr, wdata,
        output ack, rdata, lock
    );

endinterface
