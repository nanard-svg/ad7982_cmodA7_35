
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Rx is
    generic(
        -- Configuration
        G_PARITY_POLARITY : std_logic := '1'      -- RS-422 protocol partity bit, 0: Even, 1: Odd
    );
    port(
        -- Reset and Clock
        i_Rst_n        : in  std_logic;
        i_Clk          : in  std_logic;
        i_Baud_Cnt_Max : in  std_logic_vector(7 downto 0);
        -- Status
        o_Start_Bit    : out std_logic;
        o_Next_Bit     : out std_logic;
        o_Parity_Error : out std_logic;
        o_Frame_Error  : out std_logic;
        -- Data
        o_Rx_Ready     : out std_logic;
        o_Rx_Dout      : out std_logic_vector(7 downto 0);
        -- Serial link
        i_RS422_Rx     : in  std_logic
    );
end entity UART_Rx;

architecture RTL of UART_Rx is

    -- Metastability
    signal Rx_r0 : std_logic;
    signal Rx_r1 : std_logic;
    signal Rx_r2 : std_logic;

    signal Start_Bit  : std_logic;
    signal Next_Bit   : std_logic;
    signal Freq_Count : unsigned(7 downto 0);

    type state_type is (S_UART_Idle, S_UART_Receive_Data, S_UART_Parity, S_UART_Stop);
    signal state : state_type;

    signal ShiftReg   : std_logic_vector(8 downto 0);
    signal CalcParity : std_logic;
    signal Bit_cnt    : integer range 0 to 9;     -- 8 bit data + parity
    signal Rx_Busy    : std_logic;

begin
    -- On clock falling edge, trigger receiving a new word from input signal if there is no reception running
    o_Start_Bit <= Start_Bit;
    o_Next_Bit  <= Next_Bit;

    p_Rx_Buffer : process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then
            Start_Bit <= '0';
            Rx_r0     <= '1';
            Rx_r1     <= '1';
            Rx_r2     <= '1';
        elsif rising_edge(i_Clk) then
            -- Rx_r0 is METASTABLE, Rx_r1 and Rx_r2 are STABLE
            Rx_r0 <= i_RS422_Rx;
            Rx_r1 <= Rx_r0;
            Rx_r2 <= Rx_r1;

            if Rx_r2 = '1' and Rx_r1 = '0' and Rx_Busy = '0' then -- Falling edge, start = '0'
                Start_Bit <= '1';
            else
                Start_Bit <= '0';
            end if;
        end if;
    end process p_Rx_Buffer;

    --------------------------------------------------------

    p_Next_Bit_Gen : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            Next_Bit   <= '0';
            Freq_Count <= (others => '0');
        elsif rising_edge(i_Clk) then
            if Start_Bit = '1' and Rx_Busy = '0' then
                Next_Bit   <= '0';
                Freq_Count <= "0" & unsigned(i_Baud_Cnt_Max(7 downto 1)); -- Center at half period
            else
                if Freq_Count >= unsigned(i_Baud_Cnt_Max) then
                    Next_Bit   <= '1';
                    Freq_Count <= (others => '0');
                else
                    Next_Bit   <= '0';
                    Freq_Count <= Freq_Count + 1;
                end if;
            end if;
        end if;
    end process p_Next_Bit_Gen;

    --------------------------------------------------------

    -- Reception process state machine
    -- UART Protocol, LSB first
    -- Start = '0' | #0 | #1 | #2 | #3 | #4 | #5 | #6 | #7 | Parity | Stop = '1'

    p_Rx_FSM : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            o_Rx_Ready     <= '0';
            o_Rx_Dout      <= X"00";
            o_Parity_Error <= '0';
            o_Frame_Error  <= '0';

            ShiftReg   <= (others => '0');
            CalcParity <= '0';
            Bit_cnt    <= 0;
            Rx_Busy    <= '0';
            state      <= S_UART_Idle;
        elsif rising_edge(i_Clk) then
            -- FSM
            case state is
                when S_UART_Idle =>
                    o_Rx_Ready     <= '0';
                    o_Parity_Error <= '0';
                    o_Frame_Error  <= '0';
                    Rx_Busy        <= '0';
                    ShiftReg       <= (others => '0');
                    CalcParity     <= '0';
                    Bit_cnt        <= 0;

                    if Start_Bit = '1' then
                        Rx_Busy <= '1';
                        state   <= S_UART_Receive_Data;
                    end if;
                --------------------------------------------------------
                when S_UART_Receive_Data =>
                    if Next_Bit = '1' then
                        ShiftReg   <= Rx_r1 & ShiftReg(8 downto 1); -- LSB first
                        CalcParity <= CalcParity xor Rx_r1;
                        Bit_cnt    <= Bit_cnt + 1;

                        if Bit_cnt >= 8 then
                            state <= S_UART_Parity;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_UART_Parity =>
                    if Next_Bit = '1' then
                        CalcParity <= CalcParity xor Rx_r1 xor G_PARITY_POLARITY;
                        state      <= S_UART_Stop;
                    end if;
                --------------------------------------------------------
                when S_UART_Stop =>
                    if Next_Bit = '1' then
                        o_Parity_Error <= CalcParity;
                        o_Frame_Error  <= not Rx_r1; -- Stop = '1'
                        o_Rx_Dout      <= ShiftReg(8 downto 1); -- Discard polarity
                        o_Rx_Ready     <= '1';
                        state          <= S_UART_Idle;
                    end if;
                --------------------------------------------------------
                when others =>
                    o_Rx_Ready     <= '0';
                    o_Parity_Error <= '1';
                    o_Frame_Error  <= '1';
                    state          <= S_UART_Idle;
            end case;
        end if;
    end process p_Rx_FSM;

end architecture RTL;
