// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
//
// Description: Self-checking testbench for apb_to_fll.
//   Uses NumFLLs=3 so that:
//     - FLL0/1/2 are individually addressable (paddr[5:4] = 2'b00/01/10)
//     - The pseudo-FLL lock address is 2'b11 (fll_sel == '1)
//   Test cases:
//     1. FLL0 write/read-back (all 4 registers)
//     2. FLL1 write/read-back (verifies FLL selection via paddr[5:4])
//     3. Lock read            (verifies pseudo-FLL path; all FLLs must be locked)
//     4. Back-to-back writes  (FLL2, no extra idle cycles between transactions)

module apb_fll_tb;

    `include "apb/typedef.svh"

    import apb_fll_pkg::*;

    // --------------------------------------------------------------------------
    // Parameters
    // --------------------------------------------------------------------------
    localparam int unsigned APBAddrWidth = 12;
    localparam int unsigned NumFLLs      = 3;
    localparam realtime ClkPeriod  = 10;

    // FLL mock lock delay; must be < 256.  Tests 1+2 consume >> 64 cycles, so
    // the FLLs will have locked long before Test 3 runs.
    localparam int unsigned LockAfter   = 32;

    // Base addresses per FLL  (paddr[5:4] selects FLL, idx_width(3)=2 bits)
    localparam logic [APBAddrWidth-1:0] FLL0_BASE  = 12'h000; // paddr[5:4]=2'b00
    localparam logic [APBAddrWidth-1:0] FLL1_BASE  = 12'h010; // paddr[5:4]=2'b01
    localparam logic [APBAddrWidth-1:0] FLL2_BASE  = 12'h020; // paddr[5:4]=2'b10
    localparam logic [APBAddrWidth-1:0] LOCK_ADDR  = 12'h030; // paddr[5:4]=2'b11 → read_lock

    // --------------------------------------------------------------------------
    // Type definitions
    // --------------------------------------------------------------------------
    `APB_TYPEDEF_ALL(apb, logic [APBAddrWidth-1:0], logic [31:0], logic [3:0])

    // --------------------------------------------------------------------------
    // Signals
    // --------------------------------------------------------------------------
    logic clk, rst_n;

    apb_req_t  apb_req;
    apb_resp_t apb_rsp;

    apb_fll_pkg::fll_req_t [NumFLLs-1:0] fll_req;
    apb_fll_pkg::fll_rsp_t [NumFLLs-1:0] fll_rsp;

    // --------------------------------------------------------------------------
    // DUT
    // --------------------------------------------------------------------------
    apb_to_fll #(
        .APBAddrWidth (APBAddrWidth),
        .NumFLLs      (NumFLLs),
        .apb_req_t    (apb_req_t),
        .apb_resp_t   (apb_resp_t)
    ) i_dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .apb_req_i (apb_req),
        .apb_rsp_o (apb_rsp),
        .fll_req_o (fll_req),
        .fll_rsp_i (fll_rsp)
    );

    // --------------------------------------------------------------------------
    // FLL mock instances
    // --------------------------------------------------------------------------
    for (genvar i = 0; i < NumFLLs; i++) begin : gen_fll
        fll_model #(
            .LockAfterCycles (LockAfter)
        ) i_fll (
            .clk_i  (clk),
            .rst_ni (rst_n),
            .req_i  (fll_req[i]),
            .rsp_o  (fll_rsp[i])
        );
    end

    // --------------------------------------------------------------------------
    // Clock generation
    // --------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(ClkPeriod/2) clk = ~clk;
    end

    // --------------------------------------------------------------------------
    // APB driver tasks
    // --------------------------------------------------------------------------

    // Two-phase APB write:
    //   Cycle 0 (after @posedge): SETUP  — psel=1, penable=0
    //   Cycle 1 (after @posedge): ACCESS — psel=1, penable=1
    //   Wait for pready; then deassert.
    task automatic apb_write(
        input logic [APBAddrWidth-1:0] addr,
        input logic [31:0]             data
    );
        @(posedge clk);
        apb_req.paddr   = addr;
        apb_req.pprot   = '0;
        apb_req.psel    = 1'b1;
        apb_req.penable = 1'b0;
        apb_req.pwrite  = 1'b1;
        apb_req.pwdata  = data;
        apb_req.pstrb   = 4'hF;

        @(posedge clk);
        apb_req.penable = 1'b1;

        do @(posedge clk); while (!apb_rsp.pready);

        apb_req.psel    = 1'b0;
        apb_req.penable = 1'b0;
    endtask

    // Two-phase APB read; returns prdata via `data`.
    task automatic apb_read(
        input  logic [APBAddrWidth-1:0] addr,
        output logic [31:0]             data
    );
        @(posedge clk);
        apb_req.paddr   = addr;
        apb_req.pprot   = '0;
        apb_req.psel    = 1'b1;
        apb_req.penable = 1'b0;
        apb_req.pwrite  = 1'b0;
        apb_req.pwdata  = '0;
        apb_req.pstrb   = 4'hF;

        @(posedge clk);
        apb_req.penable = 1'b1;

        do @(posedge clk); while (!apb_rsp.pready);

        data            = apb_rsp.prdata;
        apb_req.psel    = 1'b0;
        apb_req.penable = 1'b0;
    endtask

    // --------------------------------------------------------------------------
    // Test stimulus and self-checking
    // --------------------------------------------------------------------------
    initial begin : tb_main
        int fail_cnt;
        logic [31:0] rdata;
        fail_cnt = 0;

        // Initialise APB bus to idle
        apb_req = '0;

        // Reset sequence
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 1: FLL0 — write all 4 registers then read back
        // ------------------------------------------------------------------
        $display("[TB] Test 1: FLL0 write/read-back");

        apb_write(FLL0_BASE | STATUS_BASE_ADDR, 32'hDEAD_0000);
        apb_write(FLL0_BASE | CONFIG1_BASE_ADDR, 32'hDEAD_0001);
        apb_write(FLL0_BASE | CONFIG2_BASE_ADDR, 32'hDEAD_0002);
        apb_write(FLL0_BASE | INTEGRATOR_BASE_ADDR, 32'hDEAD_0003);

        apb_read(FLL0_BASE | STATUS_BASE_ADDR, rdata);
        if (rdata !== 32'hDEAD_0000) begin
            $error("[TB] Test 1 FAIL: FLL0 reg0 got 0x%08X, exp 0xDEAD0000", rdata);
            fail_cnt++;
        end

        apb_read(FLL0_BASE | CONFIG1_BASE_ADDR, rdata);
        if (rdata !== 32'hDEAD_0001) begin
            $error("[TB] Test 1 FAIL: FLL0 reg1 got 0x%08X, exp 0xDEAD0001", rdata);
            fail_cnt++;
        end

        apb_read(FLL0_BASE | CONFIG2_BASE_ADDR, rdata);
        if (rdata !== 32'hDEAD_0002) begin
            $error("[TB] Test 1 FAIL: FLL0 reg2 got 0x%08X, exp 0xDEAD0002", rdata);
            fail_cnt++;
        end

        apb_read(FLL0_BASE | INTEGRATOR_BASE_ADDR, rdata);
        if (rdata !== 32'hDEAD_0003) begin
            $error("[TB] Test 1 FAIL: FLL0 reg3 got 0x%08X, exp 0xDEAD0003", rdata);
            fail_cnt++;
        end

        if (fail_cnt == 0) $display("[TB] Test 1 PASSED");

        // ------------------------------------------------------------------
        // Test 2: FLL1 — verifies that paddr[5:4] correctly selects FLL1
        // ------------------------------------------------------------------
        $display("[TB] Test 2: FLL1 write/read-back (FLL selection check)");

        apb_write(FLL1_BASE | STATUS_BASE_ADDR, 32'hCAFE_0000);
        apb_write(FLL1_BASE | CONFIG1_BASE_ADDR, 32'hCAFE_0001);
        apb_write(FLL1_BASE | CONFIG2_BASE_ADDR, 32'hCAFE_0002);
        apb_write(FLL1_BASE | INTEGRATOR_BASE_ADDR, 32'hCAFE_0003);

        apb_read(FLL1_BASE | STATUS_BASE_ADDR, rdata);
        if (rdata !== 32'hCAFE_0000) begin
            $error("[TB] Test 2 FAIL: FLL1 reg0 got 0x%08X, exp 0xCAFE0000", rdata);
            fail_cnt++;
        end

        apb_read(FLL1_BASE | CONFIG1_BASE_ADDR, rdata);
        if (rdata !== 32'hCAFE_0001) begin
            $error("[TB] Test 2 FAIL: FLL1 reg1 got 0x%08X, exp 0xCAFE0001", rdata);
            fail_cnt++;
        end

        apb_read(FLL1_BASE | CONFIG2_BASE_ADDR, rdata);
        if (rdata !== 32'hCAFE_0002) begin
            $error("[TB] Test 2 FAIL: FLL1 reg2 got 0x%08X, exp 0xCAFE0002", rdata);
            fail_cnt++;
        end

        apb_read(FLL1_BASE | INTEGRATOR_BASE_ADDR, rdata);
        if (rdata !== 32'hCAFE_0003) begin
            $error("[TB] Test 2 FAIL: FLL1 reg3 got 0x%08X, exp 0xCAFE0003", rdata);
            fail_cnt++;
        end

        // Also verify FLL0 registers are unchanged (FLL selection isolation check)
        apb_read(FLL0_BASE | STATUS_BASE_ADDR, rdata);
        if (rdata !== 32'hDEAD_0000) begin
            $error("[TB] Test 2 FAIL: FLL0 reg0 corrupted by FLL1 write! got 0x%08X", rdata);
            fail_cnt++;
        end

        if (fail_cnt == 0) $display("[TB] Test 2 PASSED");

        // ------------------------------------------------------------------
        // Test 3: Lock read via pseudo-FLL address
        //   By now Tests 1+2 have consumed many cycles; all FLLs are locked.
        //   pready must be asserted immediately (no CVP handshake).
        // ------------------------------------------------------------------
        $display("[TB] Test 3: Lock read via pseudo-FLL address (0x%03X)", LOCK_ADDR);

        apb_read(LOCK_ADDR, rdata);

        // prdata[NumFLLs-1:0] holds the lock status of each FLL
        if (rdata[NumFLLs-1:0] !== {NumFLLs{1'b1}}) begin
            $error("[TB] Test 3 FAIL: lock bits got 0x%0X, exp 0x%0X",
                   rdata[NumFLLs-1:0], {NumFLLs{1'b1}});
            fail_cnt++;
        end else begin
            $display("[TB] Test 3 PASSED (lock=0x%0X)", rdata[NumFLLs-1:0]);
        end

        // ------------------------------------------------------------------
        // Test 4: Back-to-back writes on FLL2 (no extra idle gaps)
        // ------------------------------------------------------------------
        $display("[TB] Test 4: FLL2 back-to-back writes then read-back");

        // Writes issued immediately one after another
        apb_write(FLL2_BASE | STATUS_BASE_ADDR, 32'hBEEF_0000);
        apb_write(FLL2_BASE | CONFIG1_BASE_ADDR, 32'hBEEF_0001);
        apb_write(FLL2_BASE | CONFIG2_BASE_ADDR, 32'hBEEF_0002);
        apb_write(FLL2_BASE | INTEGRATOR_BASE_ADDR, 32'hBEEF_0003);

        apb_read(FLL2_BASE | STATUS_BASE_ADDR, rdata);
        if (rdata !== 32'hBEEF_0000) begin
            $error("[TB] Test 4 FAIL: FLL2 reg0 got 0x%08X, exp 0xBEEF0000", rdata);
            fail_cnt++;
        end

        apb_read(FLL2_BASE | CONFIG1_BASE_ADDR, rdata);
        if (rdata !== 32'hBEEF_0001) begin
            $error("[TB] Test 4 FAIL: FLL2 reg1 got 0x%08X, exp 0xBEEF0001", rdata);
            fail_cnt++;
        end

        apb_read(FLL2_BASE | CONFIG2_BASE_ADDR, rdata);
        if (rdata !== 32'hBEEF_0002) begin
            $error("[TB] Test 4 FAIL: FLL2 reg2 got 0x%08X, exp 0xBEEF0002", rdata);
            fail_cnt++;
        end

        apb_read(FLL2_BASE | INTEGRATOR_BASE_ADDR, rdata);
        if (rdata !== 32'hBEEF_0003) begin
            $error("[TB] Test 4 FAIL: FLL2 reg3 got 0x%08X, exp 0xBEEF0003", rdata);
            fail_cnt++;
        end

        if (fail_cnt == 0) $display("[TB] Test 4 PASSED");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        repeat (4) @(posedge clk);
        if (fail_cnt == 0) begin
            $display("[TB] All tests PASSED.");
        end else begin
            $error("[TB] %0d test(s) FAILED.", fail_cnt);
        end
        $finish;
    end

    // Watchdog: abort if simulation hangs
    initial begin
        #100us;
        $error("[TB] TIMEOUT: simulation did not complete within 100 us.");
        $finish;
    end

endmodule
