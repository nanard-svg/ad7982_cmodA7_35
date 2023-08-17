
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package UT_Package is

    ------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Clocks period constants
    ------------------------------------------------------------------------------------------------------------------------------------------------------

    -- Target baudrate = 115.2kBit/s
    -- Theoretical baud count max = 10e9 / 40ns / 115200 = 217 ticks => 0 to Max_Ticks - 1
    -- Adapated offset are defined in their respective top level entity
    -- With NX_OSC,  25MHz period is 42.43 ns for DevKit or EM => 204.58 ticks, offset = -13
    -- With NX_OSC,  25MHz period is 41.29 ns for FM           => 210.20 ticks, offset = -8
    -- With NX_OSC,  25MHz period is 43.97 ns for FS           => 197.42 ticks, offset = -21

    -- With EXT_OSC, 25MHz period is 40.00 ns for FM           => 217.014 ticks, offset = -1

    constant C_SYSTEM_PERIOD_NS      : integer range 0 to 63     := 40; -- MAIN_CLOCK frequency in [nanosecond] from WFG at 25 MHz
    constant C_UART_BAUDRATE         : integer range 0 to 131071 := 115200;
    constant C_UART_BAUDRATE_CNT_MAX : integer range 0 to 255    := 1_000_000_000 / C_SYSTEM_PERIOD_NS / C_UART_BAUDRATE;
    constant C_UART_PARITY_POLARITY  : std_logic                 := '1'; -- Odd polarity

end package UT_Package;