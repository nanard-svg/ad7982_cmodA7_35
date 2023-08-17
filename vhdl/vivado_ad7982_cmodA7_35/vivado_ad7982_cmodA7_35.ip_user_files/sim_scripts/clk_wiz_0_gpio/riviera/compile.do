vlib work
vlib riviera

vlib riviera/xpm
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -sv2k12 "+incdir+../../../ipstatic" \
"C:/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -93  \
"C:/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic" \
"../../../../vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio_clk_wiz.v" \
"../../../../vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio.v" \

vlog -work xil_defaultlib \
"glbl.v"

