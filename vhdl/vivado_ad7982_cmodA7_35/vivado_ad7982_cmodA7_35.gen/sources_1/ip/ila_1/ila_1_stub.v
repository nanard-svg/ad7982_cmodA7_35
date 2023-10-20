// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
// Date        : Tue Oct 17 17:35:22 2023
// Host        : DESKTOP-3HC2UMC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/3UT/ad7982_cmodA7_35/vhdl/vivado_ad7982_cmodA7_35/vivado_ad7982_cmodA7_35.gen/sources_1/ip/ila_1/ila_1_stub.v
// Design      : ila_1
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "ila,Vivado 2022.2" *)
module ila_1(clk, probe0, probe1)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[7:0],probe1[1:0]" */;
  input clk;
  input [7:0]probe0;
  input [1:0]probe1;
endmodule
