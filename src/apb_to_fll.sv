// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module apb_to_fll #(
    parameter int APBAddrWidth   = 12,
    parameter int unsigned NumFLLs = 1,
    parameter type apb_req_t = logic,
    parameter type apb_resp_t = logic
) (
    input  logic  clk_i,
    input  logic  rst_ni,
    // APB interface
    input  apb_req_t apb_req_i,
    output apb_resp_t apb_rsp_o,
    // FLL interface
    output apb_fll_pkg::fll_req_t [NumFLLs-1:0] fll_req_o,
    input  apb_fll_pkg::fll_rsp_t [NumFLLs-1:0] fll_rsp_i
);

    `include "common_cells/registers.svh"
    `include "common_cells/assertions.svh"

    logic fll_ready;

    logic [NumFLLs-1:0] fll_ack_q2, fll_ack_q;
    logic [NumFLLs-1:0] fll_lock_q2, fll_lock_q;
    logic [NumFLLs-1:0] fll_req;

    logic [1:0] fll_req_sel;
    logic [cf_math_pkg::idx_width(NumFLLs)-1:0] fll_sel;
    logic read_lock;

    // [1:0] is the byte offset
    // [3:2] is the FLL reg address
    // The MSBs is to select the FLL
    assign fll_req_sel = apb_req_i.paddr[3:2];
    assign fll_sel = apb_req_i.paddr[4+:cf_math_pkg::idx_width(NumFLLs)];
    // To read the lock signal, we can read the pseudo FLL at '1
    assign read_lock = (fll_sel == '1);

    enum logic [2:0] { IDLE, CVP_PHASE1, CVP_PHASE2 } state_q, state_d;

    always_comb begin
        state_d     = state_q;
        fll_ready   = 1'b0;
        fll_req     = '0;

        case (state_q)
            IDLE: begin
                if (apb_req_i.psel && apb_req_i.penable && !read_lock) begin
                    state_d = CVP_PHASE1;
                end
            end

            CVP_PHASE1: begin
                if (fll_ack_q2[fll_sel]) begin
                    fll_ready = 1'b1;
                    state_d = CVP_PHASE2;
                end else begin
                    fll_req[fll_sel] = 1'b1;
                end
            end

            CVP_PHASE2: begin
                if (!fll_ack_q2[fll_sel])
                    state_d = IDLE;
            end
        endcase
    end

    for (genvar i = 0; i < NumFLLs; i++) begin
        assign fll_req_o[i].req   = fll_req[i];
        assign fll_req_o[i].wrn   = fll_req_o[i].req ? ~apb_req_i.pwrite : 1'b1;
        assign fll_req_o[i].addr  = fll_req_o[i].req ? fll_req_sel : '0;
        assign fll_req_o[i].wdata = fll_req_o[i].req ? apb_req_i.pwdata  : '0;
    end

    // APB response logic
    assign apb_rsp_o.pready  = read_lock ? apb_req_i.psel && apb_req_i.penable : fll_ready;
    assign apb_rsp_o.prdata  = read_lock ? fll_lock_q2 : fll_rsp_i[fll_sel].rdata;
    assign apb_rsp_o.pslverr = 1'b0;

    for (genvar i = 0; i < NumFLLs; i++) begin
        `FF(fll_lock_q[i], fll_rsp_i[i].lock, '0)
        `FF(fll_lock_q2[i], fll_lock_q[i], '0)
        `FF(fll_ack_q[i], fll_rsp_i[i].ack, '0)
        `FF(fll_ack_q2[i], fll_ack_q[i], '0)
    end

    `FF(state_q, state_d, IDLE)

    // Assert that the APB address width is appropriate for the number of FLLs
    // `NumFLL+1` because we have a pseudo FLL at address '1 to read the lock signal
    `ASSERT_INIT(APBAddrWidthCheck, APBAddrWidth-4 >= $clog2(NumFLLs+1), "[APB FLL IF] You have more FLLs than bits to address")

endmodule
