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
    parameter int unsigned APB_ADDR_WIDTH = 12,
    parameter int unsigned NR_FLLS        = 3
);

    logic clk, rst_n;
    APB_BUS apb();
    FLL_BUS fll_intf[2:0]();

    apb_fll_if #(
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .NR_FLLS        ( 3              )
    ) i_apb_fll_if (
        .clk_i    ( clk_i    ),
        .rst_ni   ( rst_ni   ),
        .apb      ( apb      ),
        .fll_intf ( fll_intf )
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