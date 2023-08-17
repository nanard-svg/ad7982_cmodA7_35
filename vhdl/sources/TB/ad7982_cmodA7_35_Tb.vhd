
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity ad7982_cmodA7_35_Tb is
end entity ad7982_cmodA7_35_Tb;

architecture Simulation of ad7982_cmodA7_35_Tb is

    -----------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------
    constant C_DEBUG_PERIOD_NS       : integer range 0 to 63     := 10; -- Debugger CLOCK frequency in [nanosecond] from OpalKelly at 100 MHz
    constant C_SYSTEM_PERIOD_NS      : integer range 0 to 63     := 40; -- MAIN_CLOCK frequency in [nanosecond] from WFG at 25 MHz
    constant C_UART_BAUDRATE         : integer range 0 to 131071 := 115200;
    constant C_UART_BAUDRATE_CNT_MAX : integer range 0 to 255    := 1_000_000_000 / C_SYSTEM_PERIOD_NS / C_UART_BAUDRATE;
    constant C_UART_PARITY_POLARITY  : std_logic                 := '1'; -- Odd polarity

    constant C_Debugger_Clock_Period : time := C_DEBUG_PERIOD_NS * 1 ns; -- Freq = 100MHz
    constant C_Debugger_Phase_Shift  : time := 3 ns; -- Desynchronize tb_Debugger and Fusio to test Serial Link

    constant C_Lander_Clock_Period : time := C_SYSTEM_PERIOD_NS * 1 ns; -- Freq = 25MHz
    constant C_Lander_Phase_Shift  : time := 2 ns; -- Desynchronize tb_Lander and Fusio to test UART

    -- constant C_Ext_Oscillator_Period : time := 40 * 1 ns; -- Freq = 25MHz

    -----------------------------------------------------------------
    -- Test Bench: Reset and Clocks
    -----------------------------------------------------------------
    signal HW_RESET_n   : std_logic := '0';
    signal Lander_CLOCK : std_logic := '0';
    -- signal Ext_OSC_CLOCK : std_logic := '0';

    signal Board_Select    : std_logic;
    signal Baud_Cnt_Offset : signed(5 downto 0);
	
    -----------------------------------------------------------------
    -- UART RS-422
    -----------------------------------------------------------------
    signal DORN_RS422_Rx : std_logic;
    signal DORN_RS422_Tx : std_logic;

    signal i_Rst_n               : std_logic;
    signal clk12MHz_Clock_Period : time      := 83 ns;
    signal clk12MHz              : std_logic := '0';
    signal BTN                   : STD_LOGIC_VECTOR(1 downto 0);

begin

    ---------------------------------------------------------------------------------------------------------------------------------
    --
    -- Reset
    --
    ---------------------------------------------------------------------------------------------------------------------------------

    HW_RESET_n <= '0', '1' after 23 ns; -- Asynchronous hardware Reset_n, negative polarity
    i_Rst_n    <= '0', '1' after 20 ns;

    BTN(0) <= '1', '0' after 100 ns;
    BTN(1) <= '0';

    ---------------------------------------------------------------------------------------------------------------------------------
    --
    -- Clocks
    --
    ---------------------------------------------------------------------------------------------------------------------------------

    --------------------------------------------------------

    p_Gen_Lander_Clk : process                    -- 25 MHz
    begin
        Lander_CLOCK <= '0';
        wait until HW_RESET_n = '1';
        wait for C_Lander_Phase_Shift;

        while True loop
            Lander_CLOCK <= '1';
            wait for C_Lander_Clock_Period / 2;
            Lander_CLOCK <= '0';
            wait for C_Lander_Clock_Period / 2;
        end loop;
    end process p_Gen_Lander_Clk;

    ---------------------------------------------------------------------------------------------------------------------------------
    --
    -- Clocks
    --
    ---------------------------------------------------------------------------------------------------------------------------------

    Clk_cmod : process                  -- 100 MHz
    begin
        clk12MHz <= '0';
        wait until BTN(0) = '0';

        while True loop
            clk12MHz <= '1';
            wait for clk12MHz_Clock_Period / 2;
            clk12MHz <= '0';
            wait for clk12MHz_Clock_Period / 2;
        end loop;
    end process Clk_cmod;

    --------------------------------------------------------

    --    p_Gen_Ext_OSC_Clk : process                   -- 25 MHz
    --    begin
    --        wait until HW_RESET_n = '1';
    --        while True loop
    --            Ext_OSC_CLOCK <= '1';
    --            wait for C_Ext_Oscillator_Period / 2;
    --            Ext_OSC_CLOCK <= '0';
    --            wait for C_Ext_Oscillator_Period / 2;
    --        end loop;
    --    end process p_Gen_Ext_OSC_Clk;

    ---------------------------------------------------------------------------------------------------------------------------------
    --
    -- Lander
    --
    ---------------------------------------------------------------------------------------------------------------------------------

    Board_Select    <= '1';                       -- 0: FS, 1: FM
    Baud_Cnt_Offset <= to_signed(0 - 8, 6) when Board_Select = '1' else -- Used on DORN_FM (Weak Pullup)
                       to_signed(0 - 21, 6);      -- Used on DORN_FS (Pulldown)	
	
    inst_GSE : entity work.GSE
        generic map(
            G_SYSTEM_PERIOD_NS      => C_SYSTEM_PERIOD_NS,
            G_UART_BAUDRATE_CNT_MAX => C_UART_BAUDRATE_CNT_MAX,
            G_UART_PARITY_POLARITY  => C_UART_PARITY_POLARITY
        )
        port map(
            i_Rst_n           => HW_RESET_n,
            i_Clk             => Lander_CLOCK,
            i_Baud_Cnt_Offset => std_logic_vector(Baud_Cnt_Offset),
            i_Lander_UART_Rx  => DORN_RS422_Tx,
            o_Lander_UART_Tx  => DORN_RS422_Rx
        );

    ---------------------------------------------------------------------------------------------------------------------------------
    --
    -- A7 FPGA
    --
    ---------------------------------------------------------------------------------------------------------------------------------

    inst_CMOD : entity work.ad7982_cmodA7_35
        port map(
            BTN        => BTN,
            CLK        => clk12MHz,
            LED        => open,
            i_RS422_Rx => DORN_RS422_Rx,
            o_RS422_Tx => DORN_RS422_Tx,
            RGB0_Red   => open,
            RGB0_Green => open,
            RGB0_Blue  => open
            


        );

        --            clk12MHz   => clk12MHz,
        --            i_Rst_n    => i_Rst_n,
        --            i_RS422_Rx => DORN_RS422_Rx,
        --            o_RS422_Tx => DORN_RS422_Tx

end architecture Simulation;
