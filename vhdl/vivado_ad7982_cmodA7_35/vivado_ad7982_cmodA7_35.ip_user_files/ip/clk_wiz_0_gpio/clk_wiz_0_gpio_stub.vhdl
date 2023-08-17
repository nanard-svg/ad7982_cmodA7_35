-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
-- Date        : Thu Aug 17 15:28:03 2023
-- Host        : DESKTOP-BSP8Q2B running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/3u/ad7982_cmodA7_35/vhdl/vivado_ad7982_cmodA7_35/vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio_stub.vhdl
-- Design      : clk_wiz_0_gpio
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a35tcpg236-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_wiz_0_gpio is
  Port ( 
    clk_out1 : out STD_LOGIC;
    reset : in STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end clk_wiz_0_gpio;

architecture stub of clk_wiz_0_gpio is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_out1,reset,clk_in1";
begin
end;
