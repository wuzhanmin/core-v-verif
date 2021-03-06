//
// Copyright 2020 OpenHW Group
// Copyright 2020 Datum Technologies
// 
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     https://solderpad.org/licenses/
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


`ifndef __UVMT_CV32_TB_SV__
`define __UVMT_CV32_TB_SV__


/**
 * Module encapsulating the CV32 DUT wrapper, and associated SV interfaces.
 * Also provide UVM environment entry and exit points.
 */
module uvmt_cv32_tb;

   import uvm_pkg::*;
   import uvmt_cv32_pkg::*;
   import uvme_cv32_pkg::*;
   
   // Envrionment configuration and context
   uvme_cv32_cfg_c    top_env_config;
   uvme_cv32_cntxt_c  top_env_cntxt;

   // Capture regs for test status from Virtual Peripheral in dut_wrap.mem_i
   reg        tp;
   reg        tf;
   reg        evalid;
   reg [31:0] evalue;

   // DUT Wrapper Interfaces
   uvmt_cv32_clk_gen_if         clk_gen_if();         // Clock & Reset
   uvmt_cv32_vp_status_if       vp_status_if();       // Status information generated by the Virtual Peripherals in the DUT WRAPPER memory.
   uvmt_cv32_core_cntrl_if      core_cntrl_if();      // Static and quasi-static core control inputs.
   uvmt_cv32_core_status_if     core_status_if();     // Core status outputs.
   uvmt_cv32_core_interrupts_if core_interrupts_if(); // Interrupt I/O from Core
   
  /**
   * DUT WRAPPER instance:
   * This is an update of the riscv_wrapper.sv from PULP-Platform RI5CY project with
   * a few mods to bring unused ports from the CORE to this level using SV interfaces.
   */
   uvmt_cv32_dut_wrap  #(
                         .INSTR_RDATA_WIDTH ( 128),
                         .RAM_ADDR_WIDTH    (  20),
                         .PULP_SECURE       (   1)
                        )
                        dut_wrap (.*);
   
   
   /**
    * Test bench entry point.
    */
   initial begin : test_bench_entry_point

     // Specify time format for simulation (units_number, precision_number, suffix_string, minimum_field_width)
     $timeformat(-9, 3, " ns", 8);

     // Create and randomzie top-level configuration object (context is optionally created in the env).
     top_env_config = uvme_cv32_cfg_c::type_id::create("top_env_config");
     if (!top_env_config.randomize()) begin
       `uvm_error("uvmt_cv32_tb", "Failed to randomize top-level configuration object" )
     end

     // For now - this will prevent the ENV build phase from doing anything...
     top_env_config.enabled   = 0;
     top_env_config.is_active = UVM_PASSIVE;

     // Add environment configuration and context to uvm_config_db
     uvm_config_db #(uvme_cv32_cfg_c  )::set(null, "*", "config", top_env_config);
     uvm_config_db #(uvme_cv32_cntxt_c)::set(null, "*", "cntxt",  top_env_cntxt);
      
     // Add interfaces handles to uvm_config_db
     uvm_config_db#(virtual uvmt_cv32_clk_gen_if        )::set(null, "*", "clk_gen_vif",         clk_gen_if);
     uvm_config_db#(virtual uvmt_cv32_vp_status_if      )::set(null, "*", "vp_status_vif",       vp_status_if);
     uvm_config_db#(virtual uvmt_cv32_core_cntrl_if     )::set(null, "*", "core_cntrl_vif",      core_cntrl_if);
     uvm_config_db#(virtual uvmt_cv32_core_status_if    )::set(null, "*", "core_status_vif",     core_status_if);
     uvm_config_db#(virtual uvmt_cv32_core_interrupts_if)::set(null, "*", "core_interrupts_vif", core_interrupts_if);
     //uvm_config_db#(mm_ram)::set("uvmt_cv32_tb.dut_wrap.*", "ram_i", "ram_i",          ram_i);
      
     // Run test
     uvm_top.enable_print_topology = 1;
     uvm_top.finish_on_completion  = 1;
     uvm_top.run_test();
   end : test_bench_entry_point
   
   // Capture the test status and exit pulse flags
   always @(posedge clk_gen_if.core_clock) begin
     if (!clk_gen_if.core_reset_n) begin
       tp     <= 1'b0;
       tf     <= 1'b0;
       evalid <= 1'b0;
       evalue <= 32'h00000000;
     end
     else begin
      if (vp_status_if.tests_failed) tf     <= 1'b1;
      if (vp_status_if.tests_passed) tp     <= 1'b1;
      if (vp_status_if.exit_valid)   evalid <= 1'b1;
      if (vp_status_if.exit_valid)   evalue <= vp_status_if.exit_value;
     end
   end
   
   /**
    * End-of-test summary printout.
    */
   final begin: end_of_test
      string             summary_string;
      uvm_report_server  rs;
      int                err_count;
      int                warning_count;
      int                fatal_count;
      static bit         sim_finished = 0;
      
      static string  red   = "\033[31m\033[1m";
      static string  green = "\033[32m\033[1m";
      static string  reset = "\033[0m";
      
      rs            = uvm_top.get_report_server();
      err_count     = rs.get_severity_count(UVM_ERROR);
      warning_count = rs.get_severity_count(UVM_WARNING);
      fatal_count   = rs.get_severity_count(UVM_FATAL);
      
      void'(uvm_config_db#(bit)::get(null, "", "sim_finished", sim_finished));

      $display("\n%m: *** Test Summary ***\n");
      
      if (sim_finished && (err_count == 0) && (fatal_count == 0)) begin
         $display("    PPPPPPP    AAAAAA    SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    PP    PP  AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP    PP  AA    AA  SS        SS        EE        DD    DD    ");
         $display("    PPPPPPP   AAAAAAAA   SSSSSS    SSSSSS   EEEEE     DD    DD    ");
         $display("    PP        AA    AA        SS        SS  EE        DD    DD    ");
         $display("    PP        AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP        AA    AA   SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    ----------------------------------------------------------");
         if (warning_count == 0) begin
           $display("                        SIMULATION PASSED                     ");
         end
         else begin
           $display("                 SIMULATION PASSED with WARNINGS              ");
         end
         $display("    ----------------------------------------------------------");
      end
      else begin
         $display("    FFFFFFFF   AAAAAA   IIIIII  LL        EEEEEEEE  DDDDDDD       ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FFFFF     AAAAAAAA    II    LL        EEEEE     DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA  IIIIII  LLLLLLLL  EEEEEEEE  DDDDDDD       ");
         
         if (sim_finished == 0) begin
            $display("    --------------------------------------------------------");
            $display("                   SIMULATION FAILED - ABORTED              ");
            $display("    --------------------------------------------------------");
         end
         else begin
            $display("    --------------------------------------------------------");
            $display("                       SIMULATION FAILED                    ");
            $display("    --------------------------------------------------------");
         end
      end
   end
   
endmodule : uvmt_cv32_tb


`endif // __UVMT_CV32_TB_SV__
