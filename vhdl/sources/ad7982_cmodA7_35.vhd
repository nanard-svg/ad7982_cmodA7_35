----------------------------------------------------------------------------
--	GPIO_Demo.vhd -- Nexys4DDR GPIO/UART Demonstration Project
----------------------------------------------------------------------------
-- Author:  Samuel Lowe Adapted from Sam Bobrowicz
--          Copyright 2013 Digilent, Inc.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	The GPIO/UART Demo project demonstrates a simple usage of the Nexys4DDR's 
--  GPIO and UART. The behavior is as follows:
--
--	      *The 16 User LEDs are tied to the 16 User Switches. While the center
--			 User button is pressed, the LEDs are instead tied to GND
--	      *The 7-Segment display counts from 0 to 9 on each of its 8
--        digits. This count is reset when the center button is pressed.
--        Also, single anodes of the 7-Segment display are blanked by
--	       holding BTNU, BTNL, BTND, or BTNR. Holding the center button 
--        blanks all the 7-Segment anodes.
--       *An introduction message is sent across the UART when the device
--        is finished being configured, and after the center User button
--        is pressed.
--       *A message is sent over UART whenever BTNU, BTNL, BTND, or BTNR is
--        pressed.
--       *The Tri-Color LEDs cycle through several colors in a ~4 second loop
--       *Data from the microphone is collected and transmitted over the mono
--        audio out port.
--       *Note that the center user button behaves as a user reset button
--        and is referred to as such in the code comments below
--        
--	All UART communication can be captured by attaching the UART port to a
-- computer running a Terminal program with 9600 Baud Rate, 8 data bits, no 
-- parity, and 1 stop bit.																
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Revision History:
--  08/08/2011(SamB): Created using Xilinx Tools 13.2
--  08/27/2013(MarshallW): Modified for the Nexys4 with Xilinx ISE 14.4\
--  		--added RGB and microphone
--  12/10/2014(SamB): Ported to Nexys4DDR and updated to Vivado 2014.4
--  05/24/2016(SamL): Ported to Cmod A7 and updated to Vivado 2015.4
--          --dimmed RGBLED and added clk_wiz_o
----------------------------------------------------------------------------

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
        LED        : out STD_LOGIC_VECTOR(1 downto 0);
        i_RS422_Rx : in  STD_LOGIC;
        o_RS422_Tx : out STD_LOGIC;
        RGB0_Red   : out STD_LOGIC;
        RGB0_Green : out STD_LOGIC;
        RGB0_Blue  : out STD_LOGIC
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
    signal CLK25   : std_logic;
    signal CLK25_i : std_logic;
    signal CLK100  : std_logic;

    signal unsigned_cnt_25mhz : unsigned(1 downto 0);

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
    signal UART_Tx_Din       : unsigned(7 downto 0);
    signal Baud_Cnt_Offset   : signed(5 downto 0);
    signal start_pattern     : std_logic;
    signal pattern           : unsigned(7 downto 0);
    signal UART_Tx_Din_std   : std_logic_vector(7 downto 0);
    signal not_send_data     : std_logic;

begin

    ----------------------------------------------------------
    ------                Clocking                  -------
    ----------------------------------------------------------

    inst_clk : clk_wiz_0_gpio
        port map(
            clk_in1  => CLK,
            clk_out1 => CLK25,
            reset    => '0'
        );

    --    --------------------------------------------------
    --    -- clock
    --    --------------------------------------------------
    --    process(i_Rst_n, CLK100)
    --    begin
    --        if i_Rst_n = '0' then
    --
    --            CLK25_i            <= '0';
    --            unsigned_cnt_25mhz <= (others => '0');
    --
    --        elsif rising_edge(CLK100) then
    --
    --            unsigned_cnt_25mhz <= unsigned_cnt_25mhz + to_unsigned(1, 2);
    --
    --            if unsigned_cnt_25mhz = to_unsigned(1, 2) then
    --
    --                CLK25_i            <= not CLK25_i;
    --                unsigned_cnt_25mhz <= (others => '0');
    --
    --            end if;
    --
    --        end if;
    --    end process;

    --    BUFG_inst : BUFG
    --        port map(
    --            O => CLK25,                 -- 1-bit output: Clock output
    --            I => CLK25_i                -- 1-bit input: Clock input
    --        );

    ----------------------------------------------------------
    ------                LED Control                  -------
    ----------------------------------------------------------

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
    Inst_btn_debounce : debouncer
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

    RGB_Core1 : RGB_controller
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
            i_Tx_Din          => UART_Tx_Din_std,
            o_Tx_Busy         => UART_Tx_Busy,
            -- RS-422
            i_RS422_Rx        => i_RS422_Rx,
            o_RS422_Tx        => o_RS422_Tx
        );

    --        --------------------------------------------------
    --        -- rx -> tx
    --        --------------------------------------------------
    --        process(i_Rst_n, CLK25)
    --        begin
    --            if i_Rst_n = '0' then
    --                UART_Tx_Din       <= (others => '0');
    --                UART_Tx_Send_Data <= '0';
    --            elsif rising_edge(CLK25) then
    --                if UART_Rx_Ready = '1' and UART_Tx_Busy = '0' then
    --                    UART_Tx_Din       <= UART_Rx_Dout;
    --                    UART_Tx_Send_Data <= '1';
    --                else
    --                    UART_Tx_Send_Data <= '0';
    --                end if;
    --            end if;
    --        end process;

    LED(0) <= BTN(0);
    LED(1) <= BTN(1);

    --        process(i_Rst_n, CLK25)
    --        begin
    --            if i_Rst_n = '0' then
    --                LED(0) <= '0';
    --                LED(1) <= '0';
    --            elsif rising_edge(CLK25) then
    --                LED(0) <= start_pattern;
    --                LED(1) <= UART_Tx_Send_Data;
    --            end if;
    --        end process;

    --------------------------------------------------
    -- ila
    --------------------------------------------------
    label_ila_1 : entity work.ila_1
        port map(
            clk    => CLK25,
            probe0 => UART_Rx_Dout,
            probe1 => '0' & UART_Rx_Ready
        );

    --------------------------------------------------
    -- detect start
    --------------------------------------------------
    process(i_Rst_n, CLK25)
    begin
        if i_Rst_n = '0' then
            start_pattern <= '0';
        elsif rising_edge(CLK25) then
            if UART_Rx_Ready = '1' and UART_Rx_Dout = x"53" then
                start_pattern <= '1';
            end if;
        end if;
    end process;

    --------------------------------------------------
    -- pattern
    --------------------------------------------------
    process(i_Rst_n, CLK25)
    begin
        if i_Rst_n = '0' then
            UART_Tx_Din       <= (others => '0');
            pattern           <= (others => '0');
            UART_Tx_Send_Data <= '0';
            not_send_data     <= '0';
        elsif rising_edge(CLK25) then
            if UART_Tx_Busy = '0' and start_pattern = '1' and not_send_data = '0' then
                UART_Tx_Din       <= UART_Tx_Din + To_unsigned(1, 8);
                UART_Tx_Send_Data <= '1';
                not_send_data     <= '1';
            else
                UART_Tx_Send_Data <= '0';
                if UART_Tx_Busy = '0' then
                    not_send_data <= '0';
                end if;
            end if;
        end if;
    end process;

    UART_Tx_Din_std <= std_logic_vector(UART_Tx_Din);

end Behavioral;
