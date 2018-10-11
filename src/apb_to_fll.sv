// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module apb_to_fll #(
    parameter int APB_ADDR_WIDTH   = 12,
    parameter int unsigned NR_FLLS = 1
)(
    input  logic  clk_i,
    input  logic  rst_ni,
    APB_BUS.in    apb,

    FLL_BUS.out   fll_intf [NR_FLLS-1:0]

);

    logic [NR_FLLS-1:0] fll_rd_access;
    logic [NR_FLLS-1:0] fll_wr_access;

    logic        read_ready;
    logic        write_ready;
    logic [31:0] read_data;

    logic        rvalid;

    logic [NR_FLLS-1:0] fll_ack_sync0;
    logic [NR_FLLS-1:0] fll_ack_sync;

    logic [NR_FLLS-1:0] fll_lock_sync0;
    logic [NR_FLLS-1:0] fll_lock_sync;

    logic [NR_FLLS-1:0] fll_valid;

    logic [NR_FLLS-1:0] fll_intf_req;
    logic [NR_FLLS-1:0] fll_intf_ack;
    logic [NR_FLLS-1:0] fll_intf_lock;
    logic [NR_FLLS-1:0][31:0] fll_intf_rdata;

    // unpack interface
    for (genvar i = 0; i < NR_FLLS; i++) begin
        assign fll_intf_ack[i]   = fll_intf[i].ack;
        assign fll_intf_lock[i]  = fll_intf[i].lock;
        assign fll_intf[i].req   = fll_intf_req[i];
        assign fll_intf_rdata[i] = fll_intf[i].rdata;
    end

    enum logic [2:0] { IDLE, CVP_PHASE1, CVP_PHASE2 } state_q, state_d;

    logic [$clog2(NR_FLLS)-1:0] fll_select_d, fll_select_q;

    always_comb begin
        state_d      = state_q;
        fll_select_d = fll_select_q;
        rvalid       = 1'b0;
        fll_valid    = '0;

        fll_intf_req = '0;

        case (state_q)
            IDLE: begin
                // select the corresponding fll
                for (int unsigned i = 0; i < NR_FLLS; i++) begin
                    if (fll_rd_access[i] || fll_wr_access[i]) begin
                        fll_select_d = i;
                        state_d = CVP_PHASE1;
                        break;
                    end
                end
            end

            CVP_PHASE1: begin
                if (fll_ack_sync[fll_select_q]) begin
                    rvalid  = 1'b1;
                    state_d = CVP_PHASE2;
                end else begin
                    fll_intf_req[fll_select_q] = 1'b1;
                    fll_valid[fll_select_q]    = 1'b1;
                end
            end

            CVP_PHASE2: begin
                if (!fll_ack_sync[fll_select_q])
                    state_d = IDLE;
            end
        endcase
    end

    always_comb begin
        // default assignments
        fll_rd_access = '0;
        read_ready    = 1'b0;
        read_data     = '0;

        fll_wr_access = '0;
        write_ready   = 1'b0;

        // read logic
        if (apb.psel && apb.penable && (~apb.pwrite)) begin
            // lock signal
            if (apb.paddr[APB_ADDR_WIDTH-1:2] == '1) begin
                read_data  = fll_intf_lock;
                read_ready = 1'b1;
            // FLL registers
            end else begin
                fll_rd_access[apb.paddr[4+$clog2(NR_FLLS):4]] = 1'b1;
                read_data  = fll_intf_rdata[apb.paddr[4+$clog2(NR_FLLS):4]];
                read_ready = rvalid;
            end
        end

        // write logic
        if (apb.psel && apb.penable && apb.pwrite) begin
            fll_wr_access[apb.paddr[4+$clog2(NR_FLLS):4]] = 1'b1;
            write_ready                               = rvalid;
        end
    end

    for (genvar i = 0; i < NR_FLLS; i++) begin
        assign fll_intf[i].wrn   = fll_valid[i] ? ~apb.pwrite    : 1'b1;
        assign fll_intf[i].addr  = fll_valid[i] ? apb.paddr[3:2] : '0;
        assign fll_intf[i].wdata = fll_valid[i] ? apb.pwdata     : '0;
    end

    // additional APB signaling
    assign apb.pready  = apb.pwrite ? write_ready : read_ready;
    assign apb.prdata  = read_data;
    assign apb.pslverr = 1'b0;

    `ifndef SYNTHESIS
    `ifndef VERILATOR
    initial begin
        assert($clog2(APB_ADDR_WIDTH-2) < NR_FLLS + 1) else $error("[APB FLL IF] You have more FLLs than bits to address");
    end
    `endif
    `endif

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            fll_ack_sync0  <= '0;
            fll_ack_sync   <= '0;

            fll_lock_sync0 <= '0;
            fll_lock_sync  <= '0;

            state_q        <= IDLE;
            fll_select_q   <= '0;
        end else begin
            fll_ack_sync0  <= fll_intf_ack;
            fll_lock_sync0 <= fll_intf_lock;

            fll_lock_sync  <= fll_lock_sync0;
            fll_ack_sync   <= fll_ack_sync0;

            state_q        <= state_d;
            fll_select_q   <= fll_select_d;
        end
    end
endmodule
