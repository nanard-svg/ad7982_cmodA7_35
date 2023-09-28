----------------------------------------------------------------------------
--	ad7982_cmodA7_35.vhd -- 3Utransat UART Demonstration Project
----------------------------------------------------------------------------
-- Author:  Bernard BERTRND
--          Copyright 2023 IRAP, Inc.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

Library UNISIM;
use UNISIM.vcomponents.all;
--The IEEE.std_logic_unsigned contains definitions that allow 
--std_logic_vector types to be used with the + operator to instantiate a 
--counter.

use work.UT_Package.all;

--use IEEE.std_logic_unsigned.all;

entity ad7982_cmodA7_35 is
    Port(
        BTN        : in  STD_LOGIC_VECTOR(1 downto 0);
        CLK        : in  STD_LOGIC;
        --led
        LED        : out STD_LOGIC_VECTOR(1 downto 0);
        --RS422
        i_RS422_Rx : in  STD_LOGIC;
        o_RS422_Tx : out STD_LOGIC;
        --RGB
        RGB0_Red   : out STD_LOGIC;
        RGB0_Green : out STD_LOGIC;
        RGB0_Blue  : out STD_LOGIC;
        --adc
        o_sck      : out std_logic;
        o_cnv      : out std_logic;
        i_sdo      : in  std_logic
    );
end ad7982_cmodA7_35;

architecture Behavioral of ad7982_cmodA7_35 is

    component debouncer
        Generic(
            DEBNC_CLOCKS : integer;
            PORT_WIDTH   : integer);
        Port(
            SIGNAL_I : in  std_logic_vector(1 downto 0);
            CLK_I    : in  std_logic;
            SIGNAL_O : out std_logic_vector(1 downto 0)
        );
    end component;

    component RGB_controller
        Port(
            GCLK        : in  std_logic;
            RGB_LED_1_O : out std_logic_vector(2 downto 0);
            RGB_LED_2_O : out std_logic_vector(2 downto 0)
        );
    end component;

    component clk_wiz_0_gpio
        port(
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic
        );
    end component;

    --Debounced btn signals used to prevent single button presses
    --from being interpreted as multiple button presses.

    --clock signal
    signal CLK25 : std_logic;

    --signal clkRst : std_logic;

    signal i_Rst_n : std_logic;

    signal UART_Rx_Ready : std_logic;
    ----------------------------------------------------------------------------------
    -- TM Commands flags
    ----------------------------------------------------------------------------------

    signal UART_Rx_Dout : std_logic_vector(7 downto 0);

    ----------------------------------------------------------------------------------
    -- DORN Internal Registers
    ----------------------------------------------------------------------------------   

    ----------------------------------------------------------------------------------
    -- UART RS-422
    ----------------------------------------------------------------------------------

    signal UART_Tx_Busy      : std_logic;
    signal UART_Tx_Send_Data : std_logic;
    signal UART_Tx_Din       : std_logic_vector(7 downto 0);
    signal Baud_Cnt_Offset   : signed(5 downto 0);

    signal rst      : std_logic;
    signal CLK66    : STD_LOGIC;
    --fifo in
    signal din      : STD_LOGIC_VECTOR(15 downto 0);
    signal wr_en    : STD_LOGIC;
    signal full     : STD_LOGIC;
    --fifo out
    signal rd_en    : std_logic;
    signal dout     : std_logic_vector(15 downto 0);
    signal empty    : std_logic;
    signal valid    : std_logic;
    signal data_rx  : std_logic_vector(17 downto 0);
    signal ready_rx : std_logic;

begin

    ----------------------------------------------------------
    ------                Clocking                  -------
    ----------------------------------------------------------

    inst_clk : entity work.clk_wiz_0_gpio
        port map(
            clk_out1 => CLK25,
            clk_out2 => CLK66,
            reset    => '0',
            clk_in1  => CLK
        );

    ----------------------------------------------------------
    ------                LED Control                  -------
    ----------------------------------------------------------
    LED(0) <= BTN(0);
    LED(1) <= BTN(1);
    ----------------------------------------------------------
    ------                reset                          -------
    ----------------------------------------------------------    

    i_Rst_n <= not BTN(0);

    ----------------------------------------------------------
    ------              Button Control                 -------
    ----------------------------------------------------------
    --Buttons are debounced and their rising edges are detected
    --to trigger UART messages

    --Debounces btn signals 
    Inst_btn_debounce : entity work.debouncer
        generic map(
            DEBNC_CLOCKS => (2 ** 16),
            PORT_WIDTH   => 2)
        port map(
            SIGNAL_I => BTN,
            CLK_I    => CLK25,
            SIGNAL_O => open
        );

    ----------------------------------------------------------
    ------            RGB LED Control                  -------
    ----------------------------------------------------------

    RGB_Core1 : entity work.RGB_controller
        port map(
            GCLK           => CLK25,
            RGB_LED_1_O(0) => RGB0_Green,
            RGB_LED_1_O(1) => RGB0_Blue,
            RGB_LED_1_O(2) => RGB0_Red,
            RGB_LED_2_O    => open
        );

    -- Offset is board dependent, adapt it to internal oscillator frequency to adjust UART timing
    Baud_Cnt_Offset <= to_signed(0 - 8, 6); -- Used on DORN_FS (Pulldown)

    inst_UART_Module : entity work.UART_Module
        generic map(
            G_UART_BAUDRATE_CNT_MAX => C_UART_BAUDRATE_CNT_MAX,
            G_UART_PARITY_POLARITY  => C_UART_PARITY_POLARITY
        )
        port map(
            -- Reset and Clock
            i_Rst_n           => i_Rst_n,
            i_Clk             => CLK25,
            i_Baud_Cnt_Offset => std_logic_vector(Baud_Cnt_Offset),
            -- Rx
            o_Rx_Start_Bit    => open,
            o_Rx_Next_Bit     => open,
            o_Rx_Parity_Error => open,
            o_Rx_Frame_Error  => open,
            o_Rx_Ready        => UART_Rx_Ready,
            o_Rx_Dout         => UART_Rx_Dout,
            -- Tx
            o_Tx_Start_Bit    => open,
            o_Tx_Next_Bit     => open,
            i_Tx_Send_Data    => UART_Tx_Send_Data,
            i_Tx_Din          => UART_Tx_Din,
            o_Tx_Busy         => UART_Tx_Busy,
            -- RS-422
            i_RS422_Rx        => i_RS422_Rx,
            o_RS422_Tx        => o_RS422_Tx
        );

    --------------------------------------------------
    -- ila
    --------------------------------------------------
    label_ila_1 : entity work.ila_1
        port map(
            clk    => CLK25,
            probe0 => UART_Rx_Dout,
            probe1 => '0' & UART_Rx_Ready
        );

    rst <= not i_Rst_n;
    --------------------------------------------------
    -- fifo
    --------------------------------------------------

    inst_fifo : entity work.fifo
        port map(
            rst         => rst,
            wr_clk      => CLK66,
            rd_clk      => CLK25,
            din         => din,
            wr_en       => wr_en,
            rd_en       => rd_en,
            dout        => dout,
            full        => open,
            empty       => empty,
            valid       => valid,
            wr_rst_busy => open,
            rd_rst_busy => open
        );

    --------------------------------------------------
    -- fsm acq
    --------------------------------------------------
    inst_fsm_acq : entity work.fsm_acq
        port map(
            clk            => CLK66,
            rst            => rst,
            -- fifo
            o_din          => din,
            o_wr_en        => wr_en,
            -- ila
            i_UART_Rx_Dout => UART_Rx_Dout,
            -- adc interface
            i_data_rx      => data_rx,
            i_ready_rx     => ready_rx
        );

    --------------------------------------------------
    -- fsm tx
    --------------------------------------------------
    inst_fsm_tx : entity work.fsm_tx
        port map(
            clk                 => CLK25,
            rst                 => rst,
            o_rd_en             => rd_en,
            i_dout              => dout,
            i_empty             => empty,
            i_valid             => valid,
            o_UART_Tx_Din       => UART_Tx_Din,
            o_UART_Tx_Send_Data => UART_Tx_Send_Data,
            i_UART_Tx_Busy      => UART_Tx_Busy
        );

    --------------------------------------------------
    -- adc driver
    --------------------------------------------------
    inst_adc_driver_Rx_fe : entity work.Rx_fe
        port map(
            --global
            clk        => CLK66,
            rst        => rst,
            --adc
            o_sck      => o_sck,
            o_cnv      => o_cnv,
            i_sdo      => i_sdo,
            --out adc driver
            o_data_rx  => data_rx,
            o_ready_rx => ready_rx
        );

end Behavioral;
