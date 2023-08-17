onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+clk_wiz_0_gpio  -L xpm -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.clk_wiz_0_gpio xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure

do {clk_wiz_0_gpio.udo}

run 1000ns

endsim

quit -force
