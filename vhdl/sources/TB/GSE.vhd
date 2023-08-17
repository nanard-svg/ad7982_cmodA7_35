
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom packages
use std.textio.all;                               -- basic I/O

entity GSE is
    generic(
        G_SYSTEM_PERIOD_NS      : integer range 0 to 63  := 40; -- MAIN_CLOCK frequency in [nanosecond] from WFG at 25 MHz
        G_UART_BAUDRATE_CNT_MAX : integer range 0 to 255 := 217; -- Adapt range to maximum value
        G_UART_PARITY_POLARITY  : std_logic              := '1' -- Odd polarity
    );
    port(
        -- Reset and Clock
        i_Rst_n           : in  std_logic;
        i_Clk             : in  std_logic;
        i_Baud_Cnt_Offset : in  std_logic_vector(5 downto 0);
        -- Lander_UART
        i_Lander_UART_Rx  : in  std_logic;
        o_Lander_UART_Tx  : out std_logic
    );
end GSE;

architecture Simulation of GSE is

    -----------------------------------------------------------------
    -- Lander UART Signals
    -----------------------------------------------------------------

    signal Lander_UART_Rx_Ready_Old : std_logic;
    signal Lander_UART_Rx_Ready_New : std_logic;
    signal Lander_UART_Rx_Dout      : std_logic_vector(7 downto 0);

    signal Lander_UART_Tx_Start_Bit : std_logic;
    signal Lander_UART_Tx_Send_Data : std_logic;
    signal Lander_UART_Tx_Din       : std_logic_vector(7 downto 0);
    signal Lander_UART_Tx_Busy      : std_logic;

    -----------------------------------------------------------------
    -- Lander UART FSM
    -----------------------------------------------------------------

    type Tx_state_type is (S_Tx_Idle, S_Tx_Read, S_Tx_Busy, S_Tx_Wait, S_Tx_Time_To_Wait);
    signal Lander_Tx_State : Tx_state_type;

    constant C_Time_To_Wait_Coeff  : integer := 1000 / G_SYSTEM_PERIOD_NS;
    signal Lander_Time_To_Wait_cnt : natural;

begin

    -----------------------------------------------------------------
    --
    -- Receiver Manager
    --
    -----------------------------------------------------------------

    p_Lander_Rx_FSM : process(i_Rst_n, i_Clk)
        file VEC_FILE     : text open write_mode is "downlink_flash.byte"; -- Adapt file name
        variable VEC_LINE : line;
    begin
        if i_Rst_n = '0' then
            Lander_UART_Rx_Ready_Old <= '0';
        elsif rising_edge(i_Clk) then
            -- Edge detection
            Lander_UART_Rx_Ready_Old <= Lander_UART_Rx_Ready_New;

            if Lander_UART_Rx_Ready_Old = '0' and Lander_UART_Rx_Ready_New = '1' then -- Rising edge
                HWRITE(VEC_LINE, Lander_UART_Rx_Dout);
                writeline(VEC_FILE, VEC_LINE);
            end if;
        end if;
    end process p_Lander_Rx_FSM;

    -----------------------------------------------------------------
    --
    -- Transmitter Manager
    --
    -----------------------------------------------------------------

    p_Lander_Tx_FSM : process(i_Rst_n, i_Clk)
        file VEC_FILE         : text open read_mode is "Test_Flash.byte"; -- Adapt file name
        variable VEC_LINE     : line;
        variable VEC_VAR      : std_logic_vector(7 downto 0) := (others => '0');
        variable Time_To_Wait : integer;
    begin
        if i_Rst_n = '0' then
            Lander_Time_To_Wait_cnt  <= 0;
            Lander_UART_Tx_Send_Data <= '0';
            Lander_UART_Tx_Din       <= (others => '0');
            Lander_Tx_State          <= S_Tx_Idle;
        elsif rising_edge(i_Clk) then
            -- FSM
            case Lander_Tx_State is
                when S_Tx_Idle =>
                    Lander_Time_To_Wait_cnt  <= 0;
                    Lander_UART_Tx_Send_Data <= '0';

                    if endfile(VEC_FILE) then
                        Lander_Tx_State <= S_Tx_Idle;
                    else
                        readline(VEC_FILE, VEC_LINE);
                        read(VEC_LINE, Time_To_Wait);
                        Time_To_Wait       := Time_To_Wait * C_Time_To_Wait_Coeff; -- Process number of Periods => Wished Time in [us]
                        HREAD(VEC_LINE, VEC_VAR);
                        Lander_UART_Tx_Din <= VEC_VAR;

                        Lander_Tx_State <= S_Tx_Time_To_Wait;

                        if Time_To_Wait = 0 then
                            Lander_Tx_State <= S_Tx_Read;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_Tx_Time_To_Wait =>         -- Wait for xx s before sending the byte
                    if Lander_Time_To_Wait_cnt >= Time_To_Wait then
                        Lander_Time_To_Wait_cnt <= 0;
                        Lander_Tx_State         <= S_Tx_Read;
                    else
                        Lander_Time_To_Wait_cnt <= Lander_Time_To_Wait_cnt + 1;
                    end if;
                --------------------------------------------------------
                when S_Tx_Read =>
                    Lander_UART_Tx_Send_Data <= '1';
                    Lander_Tx_State          <= S_Tx_Wait;
                --------------------------------------------------------
                when S_Tx_Wait =>
                    if Lander_UART_Tx_Start_Bit = '1' then -- Make sure not to exit state before UART has started operations
                        Lander_Tx_State <= S_Tx_Busy;
                    end if;
                --------------------------------------------------------
                when S_Tx_Busy =>
                    Lander_UART_Tx_Send_Data <= '0';
                    if Lander_UART_Tx_Busy = '0' then
                        Lander_Tx_State <= S_Tx_Idle;
                    end if;
                --------------------------------------------------------
                when others =>
                    Lander_Tx_State <= S_Tx_Idle;
            end case;
        end if;
    end process p_Lander_Tx_FSM;

    -----------------------------------------------------------------
    --
    -- Simulation Lander: UART Instantiation
    --
    -----------------------------------------------------------------

    inst_GSE_UART : entity work.UART_Module
        generic map(
            G_UART_BAUDRATE_CNT_MAX => G_UART_BAUDRATE_CNT_MAX,
            G_UART_PARITY_POLARITY  => G_UART_PARITY_POLARITY
        )
        port map(
            i_Rst_n           => i_Rst_n,
            i_Clk             => i_Clk,
            i_Baud_Cnt_Offset => i_Baud_Cnt_Offset,
            --
            o_Rx_Start_Bit    => open,
            o_Rx_Next_Bit     => open,
            o_Rx_Parity_Error => open,
            o_Rx_Frame_Error  => open,
            o_Rx_Ready        => Lander_UART_Rx_Ready_New,
            o_Rx_Dout         => Lander_UART_Rx_Dout,
            --
            o_Tx_Start_Bit    => Lander_UART_Tx_Start_Bit,
            o_Tx_Next_Bit     => open,
            i_Tx_Send_Data    => Lander_UART_Tx_Send_Data,
            i_Tx_Din          => Lander_UART_Tx_Din,
            o_Tx_Busy         => Lander_UART_Tx_Busy,
            --
            i_RS422_Rx        => i_Lander_UART_Rx,
            o_RS422_Tx        => o_Lander_UART_Tx
        );

end Simulation;
