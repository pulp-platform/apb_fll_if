// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module apb_fll_if
#(
    parameter APB_ADDR_WIDTH = 12
)
(
    input  logic                      HCLK,
    input  logic                      HRESETn,
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic               [31:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic               [31:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,

    output logic                      fll1_req_o,
    output logic                      fll1_wrn_o,
    output logic                [1:0] fll1_add_o,
    output logic               [31:0] fll1_data_o,
    input  logic                      fll1_ack_i,
    input  logic               [31:0] fll1_r_data_i,
    input  logic                      fll1_lock_i,
    output logic                      fll2_req_o,
    output logic                      fll2_wrn_o,
    output logic                [1:0] fll2_add_o,
    output logic               [31:0] fll2_data_o,
    input  logic                      fll2_ack_i,
    input  logic               [31:0] fll2_r_data_i,
    input  logic                      fll2_lock_i,
    output logic                      fll3_req_o,
    output logic                      fll3_wrn_o,
    output logic                [1:0] fll3_add_o,
    output logic               [31:0] fll3_data_o,
    input  logic                      fll3_ack_i,
    input  logic               [31:0] fll3_r_data_i,
    input  logic                      fll3_lock_i,
    output logic                      bbgen_req_o,
    output logic                      bbgen_wrn_o,
    output logic                      bbgen_sel_o,
    output logic               [31:0] bbgen_data_o,
    input  logic                      bbgen_ack_i,
    input  logic               [31:0] bbgen_r_data_i,
    input  logic                [3:0] bbgen_lock_i
);

    logic        s_fll1_rd_access;
    logic        s_fll1_wr_access;
    logic        s_fll2_rd_access;
    logic        s_fll2_wr_access;
    logic        s_fll3_rd_access;
    logic        s_fll3_wr_access;
    logic        s_bbgen_rd_access;
    logic        s_bbgen_wr_access;

    logic        s_read_ready;
    logic        s_write_ready;
    logic [31:0] s_read_data;

    logic        s_rvalid;

    logic        r_fll1_ack_sync0;
    logic        r_fll1_ack_sync;
    logic        r_fll2_ack_sync0;
    logic        r_fll2_ack_sync;
    logic        r_fll3_ack_sync0;
    logic        r_fll3_ack_sync;
    logic        r_bbgen_ack_sync0;
    logic        r_bbgen_ack_sync;

    logic        r_fll1_lock_sync0;
    logic        r_fll1_lock_sync;
    logic        r_fll2_lock_sync0;
    logic        r_fll2_lock_sync;
    logic        r_fll3_lock_sync0;
    logic        r_fll3_lock_sync;
    logic  [3:0] r_bbgen_lock_sync0;
    logic  [3:0] r_bbgen_lock_sync;

    logic        s_fll1_valid;
    logic        s_fll2_valid;
    logic        s_fll3_valid;
    logic        s_bbgen_valid;

    enum logic [4:0] { IDLE, CVP1_PHASE1, CVP1_PHASE2, CVP2_PHASE1, CVP2_PHASE2, CVP3_PHASE1, CVP3_PHASE2, BBGEN_PHASE1, BBGEN_PHASE2} state,state_next;

    always_ff @(posedge HCLK, negedge HRESETn)
    begin
        if (!HRESETn)
        begin
            r_fll1_ack_sync0  <= 1'b0;
            r_fll1_ack_sync   <= 1'b0;
            r_fll2_ack_sync0  <= 1'b0;
            r_fll2_ack_sync   <= 1'b0;
            r_fll3_ack_sync0  <= 1'b0;
            r_fll3_ack_sync   <= 1'b0;
            r_fll1_lock_sync0 <= 1'b0;
            r_fll1_lock_sync  <= 1'b0;
            r_fll2_lock_sync0 <= 1'b0;
            r_fll2_lock_sync  <= 1'b0;
            r_fll3_lock_sync0 <= 1'b0;
            r_fll3_lock_sync  <= 1'b0;
            r_bbgen_lock_sync0 <= 1'b0;
            r_bbgen_lock_sync  <= 1'b0;
            r_bbgen_ack_sync0 <= 1'b0;
            r_bbgen_ack_sync <= 1'b0;
            state           <= IDLE;
        end
        else
        begin
            r_fll1_ack_sync0  <= fll1_ack_i;
            r_fll1_ack_sync   <= r_fll1_ack_sync0;
            r_fll2_ack_sync0  <= fll2_ack_i;
            r_fll2_ack_sync   <= r_fll2_ack_sync0;
            r_fll3_ack_sync0  <= fll3_ack_i;
            r_fll3_ack_sync   <= r_fll3_ack_sync0;
            r_fll1_lock_sync0 <= fll1_lock_i;
            r_fll1_lock_sync  <= r_fll1_lock_sync0;
            r_fll2_lock_sync0 <= fll2_lock_i;
            r_fll2_lock_sync  <= r_fll2_lock_sync0;
            r_fll3_lock_sync0 <= fll3_lock_i;
            r_fll3_lock_sync  <= r_fll3_lock_sync0;
            r_bbgen_lock_sync0 <= bbgen_lock_i;
            r_bbgen_lock_sync  <= r_bbgen_lock_sync0;
            r_bbgen_ack_sync0 <= bbgen_ack_i;
            r_bbgen_ack_sync <= r_bbgen_ack_sync0;
            state           <= state_next;
        end
    end

    always_comb
    begin
        state_next    = IDLE;
        s_rvalid        = 1'b0;
        fll1_req_o      = 1'b0;
        fll2_req_o      = 1'b0;
        fll3_req_o      = 1'b0;
        bbgen_req_o     = 1'b0;
        s_fll1_valid    = 1'b0;
        s_fll2_valid    = 1'b0;
        s_fll3_valid    = 1'b0;
        s_bbgen_valid   = 1'b0;

        case(state)
        IDLE:
        begin
            if (s_fll2_rd_access || s_fll2_wr_access)
            begin
                s_fll2_valid = 1'b1;
                state_next = CVP2_PHASE1;
            end
            else if (s_fll1_rd_access || s_fll1_wr_access)
            begin
                s_fll1_valid = 1'b1;
                state_next = CVP1_PHASE1;
            end
            else if (s_fll3_rd_access || s_fll3_wr_access)
            begin
                s_fll3_valid = 1'b1;
                state_next = CVP3_PHASE1;
            end
            else if (s_bbgen_rd_access || s_bbgen_wr_access)
            begin
                s_bbgen_valid = 1'b1;
                state_next = BBGEN_PHASE1;
            end
        end

        CVP1_PHASE1:
        begin
            if (r_fll1_ack_sync)
            begin
                fll1_req_o   = 1'b0;
                s_fll1_valid = 1'b0;
                state_next = CVP1_PHASE2;
                s_rvalid = 1'b1;
            end
            else
            begin
                fll1_req_o   = 1'b1;
                s_fll1_valid = 1'b1;
                state_next = CVP1_PHASE1;
            end
        end

        CVP1_PHASE2:
        begin
            if (!r_fll1_ack_sync)
                state_next = IDLE;
            else
                state_next = CVP1_PHASE2;
        end

        CVP2_PHASE1:
        begin
            if (r_fll2_ack_sync)
            begin
                fll2_req_o   = 1'b0;
                s_fll2_valid = 1'b0;
                state_next = CVP2_PHASE2;
                s_rvalid     = 1'b1;
            end
            else
            begin
                fll2_req_o   = 1'b1;
                s_fll2_valid = 1'b1;
                state_next = CVP2_PHASE1;
            end
        end

        CVP2_PHASE2:
        begin
            if (!r_fll2_ack_sync)
                state_next = IDLE;
            else
                state_next = CVP2_PHASE2;
        end

        CVP3_PHASE1:
        begin
            if (r_fll3_ack_sync)
            begin
                fll3_req_o   = 1'b0;
                s_fll3_valid = 1'b0;
                state_next = CVP3_PHASE2;
                s_rvalid     = 1'b1;
            end
            else
            begin
                fll3_req_o   = 1'b1;
                s_fll3_valid = 1'b1;
                state_next = CVP3_PHASE1;
            end
        end

        CVP3_PHASE2:
        begin
            if (!r_fll3_ack_sync)
                state_next = IDLE;
            else
                state_next = CVP3_PHASE2;
        end

        BBGEN_PHASE1:
        begin
            if (r_bbgen_ack_sync)
            begin
                bbgen_req_o   = 1'b0;
                s_bbgen_valid = 1'b0;
                state_next = BBGEN_PHASE2;
                s_rvalid     = 1'b1;
            end
            else
            begin
                bbgen_req_o   = 1'b1;
                s_bbgen_valid = 1'b1;
                state_next = BBGEN_PHASE1;
            end
        end

        BBGEN_PHASE2:
        begin
            if (!r_bbgen_ack_sync)
                state_next = IDLE;
            else
                state_next = BBGEN_PHASE2;
        end

        endcase
    end

    // write logic
    always_comb
    begin
      // default assignments
      s_fll1_wr_access = 1'b0;
      s_fll2_wr_access = 1'b0;
      s_fll3_wr_access = 1'b0;
      s_bbgen_wr_access = 1'b0;

      s_write_ready    = 1'b0;

      if (PSEL && PENABLE && PWRITE) begin
        unique case (PADDR[6:2])
          // Direct access to FLL1
          5'b00000,
          5'b00001,
          5'b00010,
          5'b00011: begin
            s_fll1_wr_access = 1'b1;
            s_write_ready    = s_rvalid;
          end

          // Direct access to FLL2
          5'b00100,
          5'b00101,
          5'b00110,
          5'b00111: begin
            s_fll2_wr_access = 1'b1;
            s_write_ready    = s_rvalid;
          end

          // Direct access to FLL3
          5'b01000,
          5'b01001,
          5'b01010,
          5'b01011: begin
            s_fll3_wr_access = 1'b1;
            s_write_ready    = s_rvalid;
          end

          // Direct access to BBGENs
          5'b10000,
          5'b10001: begin
            s_bbgen_wr_access = 1'b1;
            s_write_ready    = s_rvalid;
          end

          // There are no additional registers to write
          default: begin
            s_write_ready = 1'b1;
          end
        endcase
      end
    end

    // read logic
    always_comb
    begin
      // default assignments
      s_fll1_rd_access = 1'b0;
      s_fll2_rd_access = 1'b0;
      s_fll3_rd_access = 1'b0;
      s_bbgen_rd_access = 1'b0;
      s_read_ready     = 1'b0;
      s_read_data      = '0;

      if (PSEL && PENABLE && (~PWRITE)) begin
        unique case (PADDR[6:2])
          // Direct FLL access to FLL1
          5'b00000,
          5'b00001,
          5'b00010,
          5'b00011: begin
            s_fll1_rd_access = 1'b1;
            s_read_data      = fll1_r_data_i;
            s_read_ready     = s_rvalid;
          end

          // Direct FLL access to FLL2
          5'b00100,
          5'b00101,
          5'b00110,
          5'b00111: begin
            s_fll2_rd_access = 1'b1;
            s_read_data      = fll2_r_data_i;
            s_read_ready     = s_rvalid;
          end

          // Direct FLL access to FLL3
          5'b01000,
          5'b01001,
          5'b01010,
          5'b01011: begin
            s_fll3_rd_access = 1'b1;
            s_read_data      = fll3_r_data_i;
            s_read_ready     = s_rvalid;
          end

          // Direct FLL access to BBGENs
          5'b10000,
          5'b10001: begin
            s_bbgen_rd_access = 1'b1;
            s_read_data      = bbgen_r_data_i;
            s_read_ready     = s_rvalid;
          end

          5'b10010: begin
            s_read_data[3:0] = r_bbgen_lock_sync;
            s_read_ready     = 1'b1;
          end

          5'b01111: begin
            s_read_data[2:0] = {r_fll3_lock_sync, r_fll2_lock_sync, r_fll1_lock_sync};
            s_read_ready     = 1'b1;
          end

          // There are no additional registers to read
          default: begin
            s_read_ready = 1'b1;
          end
        endcase
      end
    end


    assign fll1_wrn_o   = s_fll1_valid ? ~PWRITE    : 1'b1;
    assign fll1_add_o   = s_fll1_valid ? PADDR[3:2] : '0;
    assign fll1_data_o  = s_fll1_valid ? PWDATA     : '0;

    assign fll2_wrn_o   = s_fll2_valid ? ~PWRITE    : 1'b1;
    assign fll2_add_o   = s_fll2_valid ? PADDR[3:2] : '0;
    assign fll2_data_o  = s_fll2_valid ? PWDATA     : '0;

    assign fll3_wrn_o   = s_fll3_valid ? ~PWRITE    : 1'b1;
    assign fll3_add_o   = s_fll3_valid ? PADDR[3:2] : '0;
    assign fll3_data_o  = s_fll3_valid ? PWDATA     : '0;

    assign bbgen_wrn_o   = s_bbgen_valid ? ~PWRITE    : 1'b1;
    assign bbgen_sel_o   = s_bbgen_valid ? PADDR[2]   : '0;
    assign bbgen_data_o  = s_bbgen_valid ? PWDATA     : '0;

    assign PREADY     = PWRITE ? s_write_ready : s_read_ready;
    assign PRDATA     = s_read_data;
    assign PSLVERR    = 1'b0;

endmodule
