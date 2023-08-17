
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Tx is
    generic(
        -- Configuration
        G_PARITY_POLARITY : std_logic := '1'      -- RS-422 protocol partity bit, 0: Even, 1: Odd
    );
    port(
        -- Reset and Clock
        i_Rst_n        : in  std_logic;
        i_Clk          : in  std_logic;
        i_Baud_Cnt_Max : in  std_logic_vector(7 downto 0);
        -- Commands
        o_Start_Bit    : out std_logic;
        o_Next_Bit     : out std_logic;
        i_Send_Data    : in  std_logic;
        i_Tx_Din       : in  std_logic_vector(7 downto 0);
        o_Tx_Busy      : out std_logic;
        -- Serial link
        o_RS422_Tx     : out std_logic
    );
end entity UART_Tx;

architecture RTL of UART_Tx is

    signal Start_Bit  : std_logic;
    signal Next_Bit   : std_logic;
    signal Freq_Count : unsigned(7 downto 0);

    type state_type is (S_UART_Idle, S_UART_Start, S_UART_Send_Data, S_UART_Parity, S_UART_Stop);
    signal state : state_type;

    signal ShiftReg   : std_logic_vector(7 downto 0);
    signal CalcParity : std_logic;
    signal Bit_cnt    : integer range 0 to 8;     -- 8 bit data

begin

    p_Next_Bit_Gen : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            Next_Bit   <= '0';
            Freq_Count <= (others => '0');
        elsif rising_edge(i_Clk) then
            if Freq_Count >= unsigned(i_Baud_Cnt_Max) then
                Next_Bit   <= '1';
                Freq_Count <= (others => '0');
            else
                Next_Bit   <= '0';
                Freq_Count <= Freq_Count + 1;
            end if;

            if Start_Bit = '1' then               -- Resynchronize at every new byte
                Next_Bit   <= '0';
                Freq_Count <= (others => '0');
            end if;
        end if;
    end process p_Next_Bit_Gen;

    o_Start_Bit <= Start_Bit;
    o_Next_Bit  <= Next_Bit;

    --------------------------------------------------------

    -- Transmission process state machine
    -- UART Protocol, LSB first
    -- Start = '0' | #0 | #1 | #2 | #3 | #4 | #5 | #6 | #7 | Parity | Stop = '1'

    p_Tx_FSM : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            o_Tx_Busy  <= '0';
            o_RS422_Tx <= '1';

            Start_Bit  <= '0';
            ShiftReg   <= X"00";
            CalcParity <= '0';
            Bit_cnt    <= 0;
            state      <= S_UART_Idle;
        elsif rising_edge(i_Clk) then
            -- FSM
            case state is
                when S_UART_Idle =>
                    o_RS422_Tx <= '1';            -- Idle at '1'
                    ShiftReg   <= i_Tx_Din;       -- Load buffer to serialize
                    Bit_cnt    <= 0;
                    CalcParity <= '0';

                    if i_Send_Data = '1' then
                        Start_Bit <= '1';         -- Resynchronize at every new byte
                        o_Tx_Busy <= '1';
                        state     <= S_UART_Start;
                    end if;
                --------------------------------------------------------
                when S_UART_Start =>
                    Start_Bit <= '0';
                    if Next_Bit = '1' then
                        o_RS422_Tx <= '0';        -- Start = '0'
                        state      <= S_UART_Send_Data;
                    end if;
                --------------------------------------------------------
                when S_UART_Send_Data =>
                    if Next_Bit = '1' then
                        o_RS422_Tx <= ShiftReg(0);
                        ShiftReg   <= '0' & ShiftReg(7 downto 1); -- LSB first
                        CalcParity <= CalcParity xor ShiftReg(0);
                        Bit_cnt    <= Bit_cnt + 1;

                        if Bit_cnt >= 7 then
                            state <= S_UART_Parity;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_UART_Parity =>
                    if Next_Bit = '1' then
                        o_RS422_Tx <= CalcParity xor G_PARITY_POLARITY;
                        state      <= S_UART_Stop;
                    end if;
                --------------------------------------------------------
                when S_UART_Stop =>
                    if Next_Bit = '1' then
                        o_Tx_Busy  <= '0';
                        o_RS422_Tx <= '1';        -- Stop = '1'
                        state      <= S_UART_Idle;
                    end if;
                --------------------------------------------------------
                when others =>
                    o_Tx_Busy  <= '0';
                    o_RS422_Tx <= '1';
                    state      <= S_UART_Idle;
            end case;
        end if;
    end process p_Tx_FSM;

end architecture RTL;
