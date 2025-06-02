// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Florian Zaruba <zaruabf@iis.ee.ethz.ch>
/// Testbench for APB FLL Interface
module apb_fll_tb #(
    parameter int unsigned APBAddrWidth = 12,
    parameter int unsigned NumFLLs        = 3
);

    `include "apb/typedef.svh"
    `include "apb/assign.svh"

    `APB_TYPEDEF_ALL(apb, logic[APBAddrWidth-1:0], logic [31:0], logic [7:0])
    APB #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb();

    apb_req_t [NumFLLs-1:0] apb_req;
    apb_resp_t [NumFLLs-1:0] apb_rsp;

    `APB_ASSIGN_TO_REQ(apb_req, apb)
    `APB_ASSIGN_FROM_RESP(apb, apb_rsp)

    apb_fll_pkg::fll_req_t [NumFLLs-1:0] fll_req;
    apb_fll_pkg::fll_rsp_t [NumFLLs-1:0] fll_rsp;

    logic clk, rst_n;

    apb_to_fll #(
        .APBAddrWidth(APBAddrWidth),
        .NumFLLs     (NumFLLs),
        .apb_req_t   (apb_req_t),
        .apb_resp_t  (apb_resp_t)
    ) i_apb_to_fll (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .apb_req_i(apb_req),
        .apb_rsp_o(apb_rsp),
        .fll_req_o(fll_req),
        .fll_rsp_i(fll_rsp)
    );

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        repeat (8)
            #10ns clk = ~clk;

        rst_n = 1'b1;
        forever
            #10ns clk = ~clk;
    end

    program testbench();

    endprogram
endmodule
