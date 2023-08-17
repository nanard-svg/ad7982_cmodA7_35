
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.DORN_Package.all;

entity TC_Decoder is
    port(
        -- Reset and Clock
        i_Rst_n                : in  std_logic;
        i_Clk                  : in  std_logic;
        -- UART interface
        i_UART_Rx_Ready        : in  std_logic;
        i_UART_Rx_Data         : in  std_logic_vector(7 downto 0);
        i_UART_Rx_Parity_Error : in  std_logic;
        i_UART_Rx_Frame_Error  : in  std_logic;
        -- TM_Encoder flags
        i_Sending_Header       : in  std_logic;
        i_Sending_Payload      : in  std_logic;
        -- Packet settings
        o_TC_ID                : out std_logic_vector(7 downto 0);
        o_Error_TC_ID          : out std_logic;
        o_Error_Timeout_TC     : out std_logic;
        o_Error_Parity         : out std_logic;
        o_Error_Checksum       : out std_logic;
        o_Error_Frame          : out std_logic;
        -- Commands
        o_Start_SC_ACQ         : out std_logic;
        o_Reset_SC_ACQ         : out std_logic;
        o_Power_OFF            : out std_logic;
        o_HK_Request           : out std_logic;
        o_SC_Request           : out std_logic;
        o_Get_Status           : out std_logic;
        -- Time codes
        o_Set_Time             : out std_logic;
        o_Time_Code_Fine       : out std_logic_vector(15 downto 0);
        o_Time_Code_Coarse     : out std_logic_vector(31 downto 0);
        -- Read / Write registers
        o_Change_Param         : out std_logic;
        o_Read_Param           : out std_logic;
        o_Target_Address_TC    : out std_logic_vector(7 downto 0);
        o_Data_Write_TC        : out std_logic_vector(15 downto 0)
    );
end entity TC_Decoder;

architecture RTL of TC_Decoder is

    -- State Machine, Unable to decode input frame of size other than 12 bytes (5 bytes Header + 6 bytes Payload + Checksum)
    type state_type is (S_Idle, S_Read_SYNC_Byte_1, S_Read_SYNC_Byte_2, S_Read_SYNC_Byte_3, S_Read_ID_Byte_4,
                        S_Read_Byte_5, S_Read_Byte_6, S_Read_Byte_7, S_Read_Byte_8, S_Read_Byte_9,
                        S_Read_Byte_10, S_Read_Checksum_Byte_11, S_Execute_TC, S_Wait_for_TM);
    signal state         : state_type;
    signal TC_Wait_index : unsigned(2 downto 0);  -- Wait up to 8 clock cycles

    -- Timeout error counter, LSB = t_Clk = 40ns, 10ms = 250 000 ticks, fits on 18 bits
    signal Timeout_TC_cnt  : unsigned(17 downto 0);
    constant C_TIMEOUT_MAX : unsigned(17 downto 0) := to_unsigned(250_000, 18); -- 10 ms

    -- Instruction type ID
    signal TC_ID : std_logic_vector(7 downto 0);

    -- Payload: 6 bytes
    signal Byte5  : std_logic_vector(7 downto 0);
    signal Byte6  : std_logic_vector(7 downto 0);
    signal Byte7  : std_logic_vector(7 downto 0);
    signal Byte8  : std_logic_vector(7 downto 0);
    signal Byte9  : std_logic_vector(7 downto 0);
    signal Byte10 : std_logic_vector(7 downto 0);

    -- Checksum: Sum all previous decoded bytes (7 bytes) but SYNC_HEAD (4 bytes)
    signal Checksum : unsigned(7 downto 0);

    signal Toggle_Part_SET_TIME : std_logic;
    signal Buffer_SET_TIME      : std_logic_vector(15 downto 0);

begin

    p_Decoder_FSM : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            Timeout_TC_cnt <= (others => '0');
            TC_ID          <= (others => '0');
            Checksum       <= (others => '0');

            Byte5  <= X"00";
            Byte6  <= X"00";
            Byte7  <= X"00";
            Byte8  <= X"00";
            Byte9  <= X"00";
            Byte10 <= X"00";

            Toggle_Part_SET_TIME <= '0';
            Buffer_SET_TIME      <= (others => '0');

            o_TC_ID            <= (others => '0');
            o_Error_TC_ID      <= '0';
            o_Error_Timeout_TC <= '0';
            o_Error_Parity     <= '0';
            o_Error_Checksum   <= '0';
            o_Error_Frame      <= '0';

            o_Start_SC_ACQ <= '0';
            o_Reset_SC_ACQ <= '0';
            o_Power_OFF    <= '0';
            o_HK_Request   <= '0';
            o_SC_Request   <= '0';
            o_Get_Status   <= '0';

            o_Set_Time         <= '0';
            o_Time_Code_Fine   <= (others => '0');
            o_Time_Code_Coarse <= (others => '0');

            o_Change_Param      <= '0';
            o_Read_Param        <= '0';
            o_Target_Address_TC <= (others => '0');
            o_Data_Write_TC     <= (others => '0');

            TC_Wait_index <= (others => '0');
            state         <= S_Idle;
        elsif rising_edge(i_Clk) then
            -- Check for timeout between each TC bytes or incomplete byte sequence
            if i_UART_Rx_Ready = '0' then
                if Timeout_TC_cnt < C_TIMEOUT_MAX then
                    Timeout_TC_cnt <= Timeout_TC_cnt + 1;
                else
                    o_Error_Timeout_TC <= '1';
                    state              <= S_Wait_for_TM;
                end if;
            end if;
            -- FSM
            case state is
                when S_Idle =>
                    o_Error_TC_ID      <= '0';
                    o_Error_Parity     <= '0';
                    o_Error_Timeout_TC <= '0';
                    o_Error_Checksum   <= '0';
                    o_Error_Frame      <= '0';

                    o_Start_SC_ACQ <= '0';
                    o_Reset_SC_ACQ <= '0';
                    o_Power_OFF    <= '0';
                    o_HK_Request   <= '0';
                    o_SC_Request   <= '0';
                    o_Get_Status   <= '0';
                    o_Set_Time     <= '0';

                    o_Change_Param      <= '0';
                    o_Read_Param        <= '0';
                    o_Target_Address_TC <= (others => '0'); -- Reset Address when no Write/Read register TC
                    o_Data_Write_TC     <= (others => '0'); -- Reset Data_Write when no Write register TC

                    Timeout_TC_cnt <= (others => '0'); -- No timeout during Idle state

                    -- Do no treat a new telecommand before the end of the previous telemetry
                    if i_Sending_Header = '0' and i_Sending_Payload = '0' then
                        if i_UART_Rx_Ready = '1' and i_UART_Rx_Data = C_SYNC_HEAD_0 then -- Discard every byte if different
                            TC_ID    <= (others => '0');
                            Checksum <= (others => '0'); -- Init checksum

                            Byte5  <= X"00";
                            Byte6  <= X"00";
                            Byte7  <= X"00";
                            Byte8  <= X"00";
                            Byte9  <= X"00";
                            Byte10 <= X"00";
                            
                            Buffer_SET_TIME     <= (others => '0');
                            Toggle_Part_SET_TIME <= '0'; -- Reset and wait for another TC SET_TIME

                            o_TC_ID <= C_UART_DEFAULT; -- Reset ID to make sure it is changed after each TC

                            TC_Wait_index <= (others => '0');
                            state         <= S_Read_SYNC_Byte_1;
                        end if;
                    end if;

                    -- Execute the second part of the SET_TIME
                    if Toggle_Part_SET_TIME = '1' then
                        state <= S_Execute_TC;
                    end if;
                --------------------------------------------------------
                when S_Read_SYNC_Byte_1 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        if i_UART_Rx_Data = C_SYNC_HEAD_1 then
                            state <= S_Read_SYNC_Byte_2;
                        else
                            o_Error_Frame <= '1';
                            state         <= S_Wait_for_TM;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_Read_SYNC_Byte_2 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        if i_UART_Rx_Data = C_SYNC_HEAD_2 then
                            state <= S_Read_SYNC_Byte_3;
                        else
                            o_Error_Frame <= '1';
                            state         <= S_Wait_for_TM;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_Read_SYNC_Byte_3 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        if i_UART_Rx_Data = C_SYNC_HEAD_3 then
                            state <= S_Read_ID_Byte_4;
                        else
                            o_Error_Frame <= '1';
                            state         <= S_Wait_for_TM;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_Read_ID_Byte_4 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        o_TC_ID        <= i_UART_Rx_Data;
                        TC_ID          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_5;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_5 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte5          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_6;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_6 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte6          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_7;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_7 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte7          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_8;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_8 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte8          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_9;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_9 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte9          <= i_UART_Rx_Data;
                        state          <= S_Read_Byte_10;
                    end if;
                --------------------------------------------------------
                when S_Read_Byte_10 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        Checksum       <= Checksum + unsigned(i_UART_Rx_Data);
                        Byte10         <= i_UART_Rx_Data;
                        state          <= S_Read_Checksum_Byte_11;
                    end if;
                --------------------------------------------------------
                when S_Read_Checksum_Byte_11 =>
                    -- New byte is received
                    if i_UART_Rx_Ready = '1' then
                        Timeout_TC_cnt <= (others => '0'); -- Reset between each byte
                        if i_UART_Rx_Data = std_logic_vector(Checksum) then
                            state <= S_Execute_TC;
                        else
                            o_Error_Checksum <= '1';
                            state            <= S_Wait_for_TM;
                        end if;
                    end if;
                --------------------------------------------------------
                when S_Execute_TC =>
                    case TC_ID is
                        when C_TC_START_SC_ACQ => o_Start_SC_ACQ <= '1';
                        when C_TC_POWER_OFF    => o_Power_OFF <= '1';
                        when C_TC_RESET_SC_ACQ => o_Reset_SC_ACQ <= '1';
                        when C_TC_HK_REQUEST   => o_HK_Request <= '1';
                        when C_TC_SC_REQUEST   => o_SC_Request <= '1';
                        when C_TC_GET_STATUS   => o_Get_Status <= '1';
                        ----------------------------------------------------------------------------------
                        when C_TC_SET_TIME =>
                            o_Set_Time         <= '1';
                            o_Time_Code_Fine   <= Byte5 & Byte6;
                            o_Time_Code_Coarse <= Byte7 & Byte8 & Byte9 & Byte10;

                            if Toggle_Part_SET_TIME = '0' then
                                o_Change_Param      <= '1';
                                o_Target_Address_TC <= X"30";
                                o_Data_Write_TC     <= Byte7 & Byte8;
                                Buffer_SET_TIME     <= Byte9 & Byte10;
                                Toggle_Part_SET_TIME <= '1'; -- Start another execute state after the resolution of the TM
                            else
                                o_Change_Param      <= '1';
                                o_Target_Address_TC <= X"38";
                                o_Data_Write_TC     <= Buffer_SET_TIME;
                                Buffer_SET_TIME     <= (others => '0');
                                Toggle_Part_SET_TIME <= '0'; -- Reset and wait for another TC SET_TIME
                            end if;
                        ----------------------------------------------------------------------------------
                        when C_TC_CHANGE_PARAM =>
                            o_Change_Param      <= '1';
                            o_Target_Address_TC <= Byte6;
                            o_Data_Write_TC     <= Byte7 & Byte8;
                        ----------------------------------------------------------------------------------
                        when C_TC_READ_PARAM =>
                            o_Read_Param        <= '1';
                            o_Target_Address_TC <= Byte6;
                        ----------------------------------------------------------------------------------
                        when others =>
                            o_Error_TC_ID <= '1';
                    end case;

                    state <= S_Wait_for_TM;
                ----------------------------------------------------------------------------------
                when S_Wait_for_TM =>             -- Dead time before executing new TC to ensure the previous flags are correctly treated
                    o_Start_SC_ACQ <= '0';
                    o_Reset_SC_ACQ <= '0';
                    o_Power_OFF    <= '0';
                    o_HK_Request   <= '0';
                    o_SC_Request   <= '0';
                    o_Get_Status   <= '0';
                    o_Set_Time     <= '0';

                    TC_Wait_index <= TC_Wait_index + 1;
                    if TC_Wait_index = "111" then
                        -- Reset flags one clock tick earlier than Adr/Data to make sure they are not erased
                        o_Change_Param <= '0';
                        o_Read_Param   <= '0';
                        state          <= S_Idle;
                    end if;
                ----------------------------------------------------------------------------------
                when others =>
                    state <= S_Idle;
            end case;
            -- Management of communication error in UART protocol
            if i_UART_Rx_Parity_Error = '1' or i_UART_Rx_Frame_Error = '1' then
                o_Error_Parity <= '1';
                state          <= S_Wait_for_TM;
            end if;
        end if;
    end process p_Decoder_FSM;

end architecture RTL;
