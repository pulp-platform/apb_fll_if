// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
//
// Description: Open-source FLL mock model for simulation.
//   Implements the CVP (Clock-Valid-Phase) 4-wire handshake protocol and
//   stores register state to enable self-checking read-back in testbenches.
//
// Protocol:
//   - CFGREQ is propagated through a chain of 4 flip-flops; CFGACK is the
//     output of the last (4th) flip-flop, i.e. ack = req delayed by 4 cycles.
//   - Configuration data is latched into the selected register on the 3rd
//     rising edge after CFGREQ is asserted (req_sr[2] in this model).
//   - Master deasserts req upon seeing ack (after external synchronization).
//   - ack follows req low with the same 4-cycle chain delay.
//
// Register map (addr[1:0]):
//   0 - status     (read-only from HW; writable via CVP for testing)
//   1 - config1
//   2 - config2
//   3 - integrator
//
// Note: wrn=0 means write, wrn=1 means read (inverted from the field name,
//       matching the DUT's assignment: wrn = ~apb_req_i.pwrite).

module fll_model #(
    // Number of clock cycles after reset before lock is asserted.
    // Must be < 256 with the 8-bit counter used here.
    parameter int unsigned LockAfterCycles = 32
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  apb_fll_pkg::fll_req_t req_i,
    output apb_fll_pkg::fll_rsp_t rsp_o
);

    `include "common_cells/registers.svh"

    // Internal register file: 4 x 32-bit
    logic [3:0][31:0] regs_q, regs_d;

    // 8-bit lock counter (supports up to 255 cycles)
    logic [7:0] lock_cnt_q, lock_cnt_d;

    // 4-stage shift register modelling the CVP flip-flop chain.
    // req_sr_q[0] = req delayed 1 cycle, ..., req_sr_q[3] = req delayed 4 cycles.
    logic [3:0] req_sr_q;

    // Address latched while req is active; held afterwards for rdata output.
    logic [1:0] addr_q;

    always_comb begin
        regs_d     = regs_q;
        lock_cnt_d = lock_cnt_q;

        // Lock counter
        if (lock_cnt_q < 8'(LockAfterCycles)) begin
            lock_cnt_d = lock_cnt_q + 8'h1;
        end

        // Write: data latched on 3rd rising edge after req (req_sr_q[2]).
        // wrn is stable (DUT drives wrn=1 when req=0), so checking req_i.wrn
        // here is safe because req is still high when req_sr_q[2] first fires.
        if (req_sr_q[2] && !req_i.wrn) begin
            regs_d[req_i.addr] = req_i.wdata;
        end
    end

    assign rsp_o.rdata = regs_q[addr_q];
    assign rsp_o.lock  = (lock_cnt_q >= 8'(LockAfterCycles));
    assign rsp_o.ack   = req_sr_q[3];  // 4th flip-flop in the CVP chain

    `FF(regs_q, regs_d, '0)
    `FF(req_sr_q, {req_sr_q[2:0], req_i.req}, '0)
    `FFL(addr_q, req_i.addr, req_i.req, '0)
    `FF(lock_cnt_q, lock_cnt_d, '0)

endmodule
