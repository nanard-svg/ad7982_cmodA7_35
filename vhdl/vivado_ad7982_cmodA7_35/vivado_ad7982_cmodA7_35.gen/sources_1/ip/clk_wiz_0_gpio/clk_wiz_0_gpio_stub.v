// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
// Date        : Tue Oct 17 17:34:21 2023
// Host        : DESKTOP-3HC2UMC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/3UT/ad7982_cmodA7_35/vhdl/vivado_ad7982_cmodA7_35/vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio_stub.v
// Design      : clk_wiz_0_gpio
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_wiz_0_gpio(clk_out1, clk_out2, reset, clk_in1)
/* synthesis syn_black_box black_box_pad_pin="clk_out1,clk_out2,reset,clk_in1" */;
  output clk_out1;
  output clk_out2;
  input reset;
  input clk_in1;
endmodule
