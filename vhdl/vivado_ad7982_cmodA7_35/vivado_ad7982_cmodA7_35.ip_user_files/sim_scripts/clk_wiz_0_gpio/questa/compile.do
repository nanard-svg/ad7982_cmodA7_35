vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xpm
vlib questa_lib/msim/xil_defaultlib

vmap xpm questa_lib/msim/xpm
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../ipstatic" \
"C:/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm  -93  \
"C:/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../ipstatic" \
"../../../../vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio_clk_wiz.v" \
"../../../../vivado_ad7982_cmodA7_35.gen/sources_1/ip/clk_wiz_0_gpio/clk_wiz_0_gpio.v" \

vlog -work xil_defaultlib \
"glbl.v"

