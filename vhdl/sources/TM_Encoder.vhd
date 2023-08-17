
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.DORN_Package.all;

entity TM_Encoder is
    port(
        -- Reset and Clock
        i_Rst_n                : in  std_logic;
        i_Clk                  : in  std_logic;
        -- UART interface
        i_UART_Tx_Busy         : in  std_logic;
        o_UART_Tx_Send_Data    : out std_logic;
        o_UART_Tx_Din          : out std_logic_vector(7 downto 0);
        -- TC Decoder
        i_TC_ID                : in  std_logic_vector(7 downto 0);
        i_Error_TC_ID          : in  std_logic;
        i_Science_Available    : in  std_logic;
        i_Error_Timeout_TC     : in  std_logic;
        i_Error_Parity         : in  std_logic;
        i_Error_Checksum       : in  std_logic;
        i_Error_Frame          : in  std_logic;
        -- TC flags
        i_Start_Sc_Acq         : in  std_logic;
        i_Reset_Sc_Acq         : in  std_logic;
        i_Power_OFF            : in  std_logic;
        i_HK_Request           : in  std_logic;
        i_SC_Request           : in  std_logic;
        i_Get_Status           : in  std_logic;
        i_Set_Time             : in  std_logic;
        -- Read / Write registers
        i_Change_Param         : in  std_logic;
        i_Read_Param           : in  std_logic;
        o_Read_Reg_Status      : out std_logic;
        o_Target_Address_TM    : out std_logic_vector(7 downto 0);
        -- DORN Internal Registers
        i_Reg_Rd_En            : in  std_logic;
        i_Reg_Wr_En            : in  std_logic;
        i_Reg_Data_Read        : in  std_logic_vector(15 downto 0);
        -- Status fields
        i_Status_Version       : in  std_logic_vector(7 downto 0);
        i_Status_Mode          : in  std_logic_vector(3 downto 0);
        i_Status_Heater_Config : in  HV_Heater_Config_type;
        i_Status_HV_FE_On_Off  : in  std_logic_vector(7 downto 0);
        i_Debug_DU_ADC_Select  : in  std_logic_vector(7 downto 0);
        i_Debug_Pins_Select    : in  std_logic_vector(3 downto 0);
        i_HK_Period_ms         : in  std_logic_vector(15 downto 0);
        i_Enable_Science       : in  std_logic;
        i_Spectra_Counter      : in  std_logic_vector(11 downto 0);
        i_Time_Code_Coarse     : in  std_logic_vector(31 downto 0);
        -- Data fields for SC_PCKT
        o_FIFO_Science_Rd_En   : out std_logic;
        i_FIFO_Science_Data    : in  std_logic_vector(23 downto 0);
        -- Execution Fields
        o_Sending_Header       : out std_logic;
        o_Sending_Payload      : out std_logic;
        o_Erase_Events_Cnt     : out std_logic;
        o_DU_Polling_Select    : out std_logic_vector(2 downto 0)
    );
end entity TM_Encoder;

architecture RTL of TM_Encoder is

    -- State Machine
    type state_type is (S_Idle, S_Write_SYNC_Byte_1, S_Write_SYNC_Byte_2, S_Write_SYNC_Byte_3, -- Synchronous Head
                        S_Write_Data_Frame_Type_Byte_4, S_Write_Payload, S_Write_Checksum_Byte_N, -- Payload
                        S_Wait_Header, S_Wait_ACK_PCKT, S_Wait_HK_PCKT, S_Wait_SC_PCKT, S_Wait_STS_PCKT); -- Wait states
    signal state : state_type;

    signal TM_Wait_index : unsigned(1 downto 0); -- Wait up to 4 clock cycles

    -- Common header:          5 bytes: 4 bytes SYNChronous head, Data frame type (ID)
    -- Acknowledge packet:     5 bytes: TC_Status, TC_ID, 2 bytes data, Checksum
    -- Housekeeping packet:   27 bytes: 6 bytes CCSDS Header, 20 bytes HK, Checksum
    -- Science data packet:  873 bytes: 2 bytes PSC + 870 bytes of science data compressed, Checksum
    -- Full status packet:   152 bytes: 152 bytes of Version, Mode, Heater cfg, ON_OFF, HV targets, HK, Enables, Counters, Time Code, Debug, Checksum

    constant C_TM_HK_PCKT_CCSDS_NUMBER    : integer range 0 to 15 := 4 + 6; -- Common header + CCSDS frame
    constant C_TM_HK_PCKT_MAX_BYTE_NUMBER : integer range 0 to 31 := C_TM_HK_PCKT_CCSDS_NUMBER + 20 + 1; -- 20 HK fields + Checksum

    constant C_TM_SC_PCKT_MAX_BYTE_NUMBER : integer range 0 to 1023 := 4 + 2 + 3 * C_TM_SC_PCKT_SIZE + 1; -- Common header + PSC + 3 * Science Data + Checksum

    constant C_TM_STATUS_HV_BYTE_NUMBER     : integer range 0 to 31  := 4 + 9 + 4 * 2; -- Common header + Version + Mode + Heater config + HV_FE_ON_OFF + HV_TARGETS
    constant C_TM_STATUS_HK_BYTE_NUMBER     : integer range 0 to 127 := C_TM_STATUS_HV_BYTE_NUMBER + 32 * 2; -- 32 HK encoded on 16-bit data
    constant C_TM_STATUS_DU_BYTE_NUMBER     : integer range 0 to 255 := C_TM_STATUS_HK_BYTE_NUMBER + 24 * 2; -- 16 Filters_THLD + 8 Thld_Sat encoded on 16-bit data
    constant C_TM_STATUS_MEMORY_BYTE_NUMBER : integer range 0 to 255 := C_TM_STATUS_DU_BYTE_NUMBER + 4 * 2; -- 4 Memory counters encoded on 16-bit data
    constant C_TM_STATUS_MAX_BYTE_NUMBER    : integer range 0 to 255 := C_TM_STATUS_MEMORY_BYTE_NUMBER + 14 + 1; -- Miscellaneous + Checksum

    -- Data frame type ID
    signal TM_ID     : std_logic_vector(7 downto 0);
    signal TC_Status : std_logic_vector(7 downto 0);

    -- Checksum: Sum all previous decoded bytes (7 bytes) but SYNC_HEAD (4 bytes)
    signal UART_Tx_Din : std_logic_vector(7 downto 0);
    signal Checksum    : unsigned(7 downto 0);

    -- Prepare data to send in TM
    signal TM_Byte_index    : integer range 0 to 4095; -- Must be equal to maximum size TM + 1
    signal HK_PSC           : std_logic_vector(13 downto 0); -- Housekeeping Packet Sequence Count: Chronological CCSDS number
    signal SC_PSC           : std_logic_vector(15 downto 0); -- Science Packet Sequence Count: Chronological number
    signal TM_Data_Select   : std_logic_vector(1 downto 0); -- Select between each byte of the 24-bit payload of Sience data
    signal TM_HV_Command_ID : unsigned(2 downto 0); -- 2 x 4 HV_Commands
    signal TM_HK_DU_ID      : unsigned(5 downto 0); -- 2 x 32 HK or 2 x 16 Filters_Thld or 2 x 8 Thld_Sat
    signal TM_MEMORY_ID     : unsigned(2 downto 0); -- 4 addresses for memory counters on 16-bits each

    constant TM_DATA_SELECT_23_to_16 : std_logic_vector(1 downto 0) := "00";
    constant TM_DATA_SELECT_15_to_8  : std_logic_vector(1 downto 0) := "01";
    constant TM_DATA_SELECT_7_to_0   : std_logic_vector(1 downto 0) := "10";

    signal Reg_Data_to_Send  : std_logic_vector(15 downto 0);
    signal FIFO_Science_Data : std_logic_vector(23 downto 0);

    -- Used for HK_PCKT
    signal Buffer_Data_Reg   : std_logic_vector(3 downto 0);
    signal DU_Polling_Select : unsigned(2 downto 0);
    signal Toggle_Heater_HK  : std_logic;

begin

    p_Input_Data_Identification : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then
            Reg_Data_to_Send  <= (others => '0');
            FIFO_Science_Data <= (others => '0');
        elsif rising_edge(i_Clk) then
            -- Reg Adr and Data to send are available on the bus only during few clock cycles
            if i_Reg_Rd_En = '1' or i_Reg_Wr_En = '1' then
                Reg_Data_to_Send <= i_Reg_Data_Read;
            end if;

            -- Buffer from FIFO_Science and FIFO_DUMP to ease timings
            FIFO_Science_Data <= i_FIFO_Science_Data;
        end if;
    end process p_Input_Data_Identification;

    -----------------------------------------------------------------------------------------------------------------------------------------------------

    -- Use an internal register to simplify checksum calculation
    o_UART_Tx_Din <= UART_Tx_Din;

    p_Encoder_FSM : process(i_Clk, i_Rst_n) is
    begin
        if i_Rst_n = '0' then
            UART_Tx_Din         <= (others => '0');
            o_UART_Tx_Send_Data <= '0';

            o_FIFO_Science_Rd_En <= '0';
            o_Read_Reg_Status    <= '0';
            o_Target_Address_TM  <= (others => '0');

            o_Sending_Header    <= '0';
            o_Sending_Payload   <= '0';
            o_Erase_Events_Cnt  <= '0';
            o_DU_Polling_Select <= (others => '0');

            TM_ID             <= (others => '0');
            TC_Status         <= (others => '0');
            Checksum          <= (others => '0');
            HK_PSC            <= (others => '0');
            SC_PSC            <= (others => '0');
            TM_Byte_index     <= 0;
            TM_Data_Select    <= TM_DATA_SELECT_23_to_16;
            TM_Wait_index     <= (others => '0');
            TM_HV_Command_ID  <= (others => '0');
            TM_HK_DU_ID       <= (others => '0');
            TM_MEMORY_ID      <= (others => '0');
            Buffer_Data_Reg   <= (others => '0');
            DU_Polling_Select <= (others => '0');
            Toggle_Heater_HK  <= '0';

            state <= S_Idle;
        elsif rising_edge(i_Clk) then
            -- Default values to avoid maintaining flags
            o_UART_Tx_Send_Data  <= '0';
            o_FIFO_Science_Rd_En <= '0';
            o_Erase_Events_Cnt   <= '0';
            -- FSM
            case state is
                when S_Idle =>
                    o_Read_Reg_Status   <= '0';
                    o_Target_Address_TM <= (others => '0');

                    o_Sending_Header  <= '0';
                    o_Sending_Payload <= '0';

                    UART_Tx_Din      <= X"00";
                    TM_Byte_index    <= 0;
                    TM_Data_Select   <= TM_DATA_SELECT_23_to_16;
                    TM_Wait_index    <= (others => '0');
                    TM_HV_Command_ID <= (others => '0');
                    TM_HK_DU_ID      <= (others => '0');
                    TM_MEMORY_ID     <= (others => '0');

                    --------------------------------------------------------
                    -- TM_ID Type Identification
                    --------------------------------------------------------
                    -- Check TC_ID if no error
                    if i_TC_ID = C_TC_START_SC_ACQ or i_TC_ID = C_TC_RESET_SC_ACQ or i_TC_ID = C_TC_POWER_OFF or i_TC_ID = C_TC_CHANGE_PARAM or i_TC_ID = C_TC_READ_PARAM or i_TC_ID = C_TC_SET_TIME then
                        TM_ID <= C_TM_ACK_PCKT;
                    elsif i_TC_ID = C_TC_HK_REQUEST then
                        TM_ID <= C_TM_HK_PCKT;
                    elsif i_TC_ID = C_TC_SC_REQUEST then
                        if i_Science_Available = '0' then -- Negative polarity
                            TM_ID <= C_TM_SC_PCKT;
                        else            -- Return ACK if no science available
                            TM_ID <= C_TM_ACK_PCKT;
                        end if;
                    elsif i_TC_ID = C_TC_GET_STATUS then
                        TM_ID <= C_TM_STS_PCKT;
                    else                -- No new TC or bad TC_ID detected
                        TM_ID <= C_TM_ACK_PCKT;
                    end if;

                    -- Overwrite TM_ID if error is detected in TC_ID
                    if i_Error_TC_ID or i_Error_Timeout_TC or i_Error_Parity or i_Error_Checksum or i_Error_Frame then
                        TM_ID <= C_TM_ACK_PCKT;
                    end if;

                    --------------------------------------------------------
                    -- Check for start TM encoding
                    --------------------------------------------------------
                    if i_UART_Tx_Busy = '0' then
                        -- Check for errors or normal ACK operations
                        if i_Error_TC_ID or i_Error_Timeout_TC or i_Error_Parity or i_Error_Checksum or i_Error_Frame or -- Errors
                            i_Start_Sc_Acq or i_Reset_Sc_Acq or i_Power_OFF or -- Mode changes
                            i_HK_Request or i_SC_Request or i_Get_Status or -- Custom size
                            i_Set_Time or i_Change_Param or i_Read_Param then -- Configuration
                            o_Sending_Header    <= '1'; -- Start of SYNChronous Head
                            o_UART_Tx_Send_Data <= '1';
                            UART_Tx_Din         <= C_SYNC_HEAD_0;
                            Checksum            <= (others => '0'); -- Init checksum
                            state               <= S_Wait_Header;
                        end if;

                        -- Define TC_STATUS
                        TC_Status(C_TC_STATUS_ERROR_FRAME_adr)      <= i_Error_Frame;
                        TC_Status(C_TC_STATUS_ERROR_CHECKSUM_adr)   <= i_Error_Checksum;
                        TC_Status(C_TC_STATUS_ERROR_PARITY_adr)     <= i_Error_Parity;
                        TC_Status(C_TC_STATUS_ERROR_TIMEOUT_TC_adr) <= i_Error_Timeout_TC;
                        TC_Status(C_TC_STATUS_SC_Available_adr)     <= i_Science_Available;
                        TC_Status(C_TC_STATUS_ERROR_TC_ID_adr)      <= i_Error_TC_ID;
                        TC_Status(C_TC_STATUS_Spare_bit_1_adr)      <= '0'; -- Not used
                        TC_Status(C_TC_STATUS_Spare_bit_0_adr)      <= '0'; -- Not used
                    end if;
                --------------------------------------------------------
                when S_Write_SYNC_Byte_1 =>
                    if i_UART_Tx_Busy = '0' then
                        o_UART_Tx_Send_Data <= '1';
                        UART_Tx_Din         <= C_SYNC_HEAD_1;
                        state               <= S_Wait_Header;
                    end if;
                --------------------------------------------------------
                when S_Write_SYNC_Byte_2 =>
                    if i_UART_Tx_Busy = '0' then
                        o_UART_Tx_Send_Data <= '1';
                        UART_Tx_Din         <= C_SYNC_HEAD_2;
                        state               <= S_Wait_Header;
                    end if;
                --------------------------------------------------------
                when S_Write_SYNC_Byte_3 =>
                    if i_UART_Tx_Busy = '0' then
                        o_UART_Tx_Send_Data <= '1';
                        UART_Tx_Din         <= C_SYNC_HEAD_3;
                        state               <= S_Wait_Header;
                    end if;
                --------------------------------------------------------
                when S_Write_Data_Frame_Type_Byte_4 =>
                    if i_UART_Tx_Busy = '0' then
                        o_UART_Tx_Send_Data <= '1';
                        UART_Tx_Din         <= TM_ID;
                        state               <= S_Wait_Header;
                    end if;
                --------------------------------------------------------
                when S_Write_Payload =>
                    if i_UART_Tx_Busy = '0' then
                        o_Sending_Header <= '0'; -- End of header, start of payload
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        -- Acknowledge Packet, 10 bytes in TM
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        if TM_ID = C_TM_ACK_PCKT then
                            o_Sending_Payload   <= '1';
                            o_UART_Tx_Send_Data <= '1';
                            state               <= S_Wait_ACK_PCKT;

                            case TM_Byte_index is
                                when 5 =>
                                    UART_Tx_Din <= TC_Status; -- TC_Status is defined when TM_ID is affected
                                    --------------------------------------------------------
                                when 6 =>
                                    UART_Tx_Din <= i_TC_ID;
                                --------------------------------------------------------
                                when 7 =>
                                    if i_TC_ID = C_TC_READ_PARAM then
                                        UART_Tx_Din <= Reg_Data_to_Send(15 downto 8); -- 8 bits
                                    else -- Spare in public answers
                                        UART_Tx_Din <= X"00";
                                    end if;
                                --------------------------------------------------------
                                when 8 =>
                                    if i_TC_ID = C_TC_READ_PARAM then
                                        UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- 8 bits
                                    else -- Spare in public answers
                                        UART_Tx_Din <= X"00";
                                    end if;
                                --------------------------------------------------------
                                when 9 =>
                                    UART_Tx_Din <= std_logic_vector(Checksum);
                                --------------------------------------------------------
                                when others =>
                                    UART_Tx_Din <= C_UART_ERROR;
                                    state       <= S_Idle;
                            end case;
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        -- HK Engineering Packet, 32 bytes in TM, Structure of HK fields : 12 + 12 + 12 + 12 + 12 + 12 + 8 + 16 + 16 + 16 + 16 + 16 bits = total 20 bytes
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        elsif TM_ID = C_TM_HK_PCKT then
                            o_Sending_Payload   <= '1';
                            o_UART_Tx_Send_Data <= '1';
                            state               <= S_Wait_HK_PCKT;

                            case TM_Byte_index is
                                when 5 => -- Version Number ("000") + TM_Type ("0") + no Secondary Header ("0") + E_PDU_APID_MSB
                                    UART_Tx_Din <= "00000" & C_E_PDU_APID(10 downto 8); -- 5 + 3 bits
                                    --------------------------------------------------------
                                when 6 => -- E-PDU_APID_LSB
                                    UART_Tx_Din <= C_E_PDU_APID(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 7 => -- Sequence flags (ungrouped packet) + Packet Sequence Count MSB
                                    UART_Tx_Din <= "11" & HK_PSC(13 downto 8); -- 2 + 6 bits
                                    --------------------------------------------------------
                                when 8 => -- Packet Sequence Count LSB
                                    UART_Tx_Din <= HK_PSC(7 downto 0); -- 8 bits
                                    HK_PSC      <= std_logic_vector(unsigned(HK_PSC) + 1); -- Increment Packet Sequence Count for next TC_HK_REQUEST
                                    --------------------------------------------------------
                                when 9 => -- Payload Data length MSB
                                    UART_Tx_Din <= C_HK_PCKT_PDL(15 downto 8);
                                --------------------------------------------------------
                                when 10 => -- Payload Data length LSB
                                    UART_Tx_Din <= C_HK_PCKT_PDL(7 downto 0);
                                --------------------------------------------------------
                                when 11 =>
                                    UART_Tx_Din <= x"B0"; -- TEMP RT Fusio = 30.07°C 
                                    --Buffer_Data_Reg <= Reg_Data_to_Send(3 downto 0); -- Save 4 LSB for next UART byte
                                    --------------------------------------------------------
                                when 12 =>
                                    UART_Tx_Din <= x"6" & x"B";
                                --------------------------------------------------------
                                when 13 =>
                                    UART_Tx_Din <= x"63"; -- TEMP CV = 40.06°C
                                    --------------------------------------------------------
                                when 14 =>
                                    if Toggle_Heater_HK = '0' then
                                        UART_Tx_Din <= x"89"; -- TEMP_HEATER_1 = 21°C
                                    else
                                        UART_Tx_Din <= x"8A"; -- TEMP_HEATER_2 = 22°C
                                    end if;
                                --------------------------------------------------------
                                when 15 =>
                                    if Toggle_Heater_HK = '0' then
                                        UART_Tx_Din <= x"0" & Reg_Data_to_Send(11 downto 8);
                                    else
                                        UART_Tx_Din <= x"7" & Reg_Data_to_Send(11 downto 8);
                                    end if;
                                --------------------------------------------------------
                                when 16 =>
                                    UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- Write 8 LSB
                                    --------------------------------------------------------
                                when 17 =>
                                    UART_Tx_Din <= x"7B"; -- IPRIM AOP = 366.31mA
                                    --Buffer_Data_Reg <= Reg_Data_to_Send(3 downto 0); -- Save 4 LSB for next UART byte
                                    --------------------------------------------------------
                                when 18 =>
                                    UART_Tx_Din <= x"2" & x"0";
                                --------------------------------------------------------
                                when 19 =>
                                    UART_Tx_Din <= x"BA"; -- P7V_HV_CURRENT = 149.89mA
                                    --------------------------------------------------------
                                when 20 =>
                                    if i_Status_Mode = C_MODE_STANDBY then
                                        UART_Tx_Din(7) <= '0'; -- Standby bit
                                    else
                                        UART_Tx_Din(7) <= '1'; -- Running bit
                                    end if;
                                    UART_Tx_Din(6) <= DU_Polling_Select(2);
                                    UART_Tx_Din(5) <= DU_Polling_Select(1);
                                    UART_Tx_Din(4) <= DU_Polling_Select(0);
                                    UART_Tx_Din(3) <= i_Enable_Science;
                                    UART_Tx_Din(2) <= i_Science_Available;
                                    UART_Tx_Din(1) <= Toggle_Heater_HK;
                                    UART_Tx_Din(0) <= i_Status_Heater_Config.ON_n_OFF; -- Negative polarity

                                    Toggle_Heater_HK <= not Toggle_Heater_HK; -- Toggle between Sensor #1 and Sensor #2
                                    --------------------------------------------------------
                                when 21 =>
                                    UART_Tx_Din <= x"99"; -- MSB
                                    --------------------------------------------------------
                                when 22 =>
                                    UART_Tx_Din <= x"88"; -- LSB
                                    --------------------------------------------------------
                                when 23 =>
                                    UART_Tx_Din <= Reg_Data_to_Send(15 downto 8); -- MSB
                                    --------------------------------------------------------
                                when 24 =>
                                    UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- LSB
                                    --------------------------------------------------------
                                when 25 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(31 downto 24); -- 8 bits
                                    --------------------------------------------------------
                                when 26 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(23 downto 16); -- 8 bits
                                    --------------------------------------------------------
                                when 27 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(15 downto 8); -- 8 bits
                                    --------------------------------------------------------
                                when 28 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 29 =>
                                    UART_Tx_Din <= x"77";
                                --------------------------------------------------------
                                when 30 =>
                                    UART_Tx_Din <= x"66";
                                --------------------------------------------------------
                                when C_TM_HK_PCKT_MAX_BYTE_NUMBER =>
                                    UART_Tx_Din         <= std_logic_vector(Checksum);
                                    o_Erase_Events_Cnt  <= '1';
                                    o_DU_Polling_Select <= std_logic_vector(DU_Polling_Select);
                                    DU_Polling_Select   <= DU_Polling_Select + 1; -- Increase polling after each HK_Request
                                    --------------------------------------------------------
                                when others =>
                                    UART_Tx_Din <= C_UART_ERROR;
                                    state       <= S_Idle;
                            end case;
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        -- Science Data Packet, 878 bytes in TM
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        elsif TM_ID = C_TM_SC_PCKT then
                            o_Sending_Payload   <= '1';
                            o_UART_Tx_Send_Data <= '1';
                            state               <= S_Wait_SC_PCKT;

                            case TM_Byte_index is
                                when 5 =>
                                    UART_Tx_Din <= SC_PSC(15 downto 8); -- 8 bits
                                    --------------------------------------------------------
                                when 6 =>
                                    UART_Tx_Din <= SC_PSC(7 downto 0); -- 8 bits
                                    SC_PSC      <= std_logic_vector(unsigned(SC_PSC) + 1); -- Increment Packet Sequence Count for next TC_SC_REQUEST with science
                                    --------------------------------------------------------
                                when 7 to C_TM_SC_PCKT_MAX_BYTE_NUMBER - 1 =>
                                    -- Choose data part to send on Tx_Data
                                    if TM_Data_Select = TM_DATA_SELECT_23_to_16 then
                                        UART_Tx_Din    <= FIFO_Science_Data(23 downto 16);
                                        TM_Data_Select <= TM_DATA_SELECT_15_to_8;
                                    elsif TM_Data_Select = TM_DATA_SELECT_15_to_8 then
                                        UART_Tx_Din    <= FIFO_Science_Data(15 downto 8);
                                        TM_Data_Select <= TM_DATA_SELECT_7_to_0;
                                    elsif TM_Data_Select = TM_DATA_SELECT_7_to_0 then
                                        o_FIFO_Science_Rd_En <= '1'; -- Request new data from FIFO_Science
                                        UART_Tx_Din          <= FIFO_Science_Data(7 downto 0);
                                        TM_Data_Select       <= TM_DATA_SELECT_23_to_16;
                                    else -- Should never happen
                                        UART_Tx_Din    <= C_UART_ERROR;
                                        TM_Data_Select <= TM_DATA_SELECT_23_to_16;
                                    end if;
                                --------------------------------------------------------
                                when C_TM_SC_PCKT_MAX_BYTE_NUMBER =>
                                    UART_Tx_Din <= std_logic_vector(Checksum);
                                --------------------------------------------------------
                                when others =>
                                    UART_Tx_Din <= C_UART_ERROR;
                                    state       <= S_Idle;
                            end case;
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        -- Full Status Packet, 157 bytes in TM
                        ------------------------------------------------------------------------------------------------------------------------------------------------------
                        elsif TM_ID = C_TM_STS_PCKT then
                            o_Sending_Payload   <= '1';
                            o_UART_Tx_Send_Data <= '1';
                            state               <= S_Wait_STS_PCKT;

                            case TM_Byte_index is
                                --------------------------------------------------------
                                when 5 =>
                                    UART_Tx_Din <= i_Status_Version;
                                --------------------------------------------------------
                                when 6 =>
                                    UART_Tx_Din <= i_Status_Mode & i_Status_Heater_Config.ON_n_OFF & i_Status_Heater_Config.Mode; -- 4 + 1 + 3 bits
                                    --------------------------------------------------------
                                when 7 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.Command(11 downto 4); -- 8 bits
                                    --------------------------------------------------------
                                when 8 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.Command(3 downto 0) & i_Status_Heater_Config.Hyst_Width(11 downto 8); -- 4 + 4 bits
                                    --------------------------------------------------------
                                when 9 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.Hyst_Width(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 10 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.Setpoint(11 downto 4); -- 8 bits
                                    --------------------------------------------------------
                                when 11 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.Setpoint(3 downto 0) & i_Status_Heater_Config.DAC_ON_Value(11 downto 8); -- 4 + 4 bits
                                    --------------------------------------------------------
                                when 12 =>
                                    UART_Tx_Din <= i_Status_Heater_Config.DAC_ON_Value(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 13 =>
                                    UART_Tx_Din <= i_Status_HV_FE_On_Off;
                                --------------------------------------------------------
                                when 14 to C_TM_STATUS_HV_BYTE_NUMBER => -- 2 x 4 HV_TARGETS to send
                                    if TM_HV_Command_ID(0) = '0' then -- MSB
                                        UART_Tx_Din <= X"0" & Reg_Data_to_Send(11 downto 8); -- 4 (Spare) + 4 bits
                                    else -- LSB
                                        UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- 8 bits
                                    end if;

                                    TM_HV_Command_ID <= TM_HV_Command_ID + 1;
                                --------------------------------------------------------
                                when C_TM_STATUS_HV_BYTE_NUMBER + 1 to C_TM_STATUS_DU_BYTE_NUMBER => -- 2 x 32 HK + 2 x 16 Filters_Thld_Low + 16 Thld_Sat
                                    if TM_HK_DU_ID(0) = '0' then -- MSB
                                        UART_Tx_Din <= Reg_Data_to_Send(15 downto 8); -- 8 bits
                                    else -- LSB
                                        UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- 8 bits
                                    end if;

                                    TM_HK_DU_ID <= TM_HK_DU_ID + 1;
                                --------------------------------------------------------
                                when C_TM_STATUS_DU_BYTE_NUMBER + 1 to C_TM_STATUS_MEMORY_BYTE_NUMBER =>
                                    if TM_MEMORY_ID(0) = '0' then -- MSB
                                        UART_Tx_Din <= Reg_Data_to_Send(15 downto 8); -- 8 bits
                                    else -- LSB
                                        UART_Tx_Din <= Reg_Data_to_Send(7 downto 0); -- 8 bits
                                    end if;

                                    TM_MEMORY_ID <= TM_MEMORY_ID + 1;
                                --------------------------------------------------------
                                when 142 =>
                                    UART_Tx_Din <= i_Debug_DU_ADC_Select; -- 8 bits
                                    --------------------------------------------------------
                                when 143 =>
                                    UART_Tx_Din <= i_HK_Period_ms(15 downto 8); -- 8 bits
                                    --------------------------------------------------------
                                when 144 =>
                                    UART_Tx_Din <= i_HK_Period_ms(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 145 =>
                                    UART_Tx_Din <= i_Enable_Science & i_Science_Available & "00" & i_Spectra_Counter(11 downto 8); -- 2 + 2 (Spare) + 4 bits
                                    --------------------------------------------------------
                                when 146 =>
                                    UART_Tx_Din <= i_Spectra_Counter(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 147 =>
                                    UART_Tx_Din <= X"0" & i_Debug_Pins_Select; -- 4 (spare) + 4 bits
                                    --------------------------------------------------------
                                when 148 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(31 downto 24); -- 8 bits
                                    --------------------------------------------------------
                                when 149 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(23 downto 16); -- 8 bits
                                    --------------------------------------------------------
                                when 150 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(15 downto 8); -- 8 bits
                                    --------------------------------------------------------
                                when 151 =>
                                    UART_Tx_Din <= i_Time_Code_Coarse(7 downto 0); -- 8 bits
                                    --------------------------------------------------------
                                when 152 =>
                                    UART_Tx_Din <= X"44"; -- ASCII letter D
                                    --------------------------------------------------------
                                when 153 =>
                                    UART_Tx_Din <= X"4F"; -- ASCII letter O
                                    --------------------------------------------------------
                                when 154 =>
                                    UART_Tx_Din <= X"52"; -- ASCII letter R
                                    --------------------------------------------------------
                                when 155 =>
                                    UART_Tx_Din <= X"4E"; -- ASCII letter N
                                    --------------------------------------------------------
                                when C_TM_STATUS_MAX_BYTE_NUMBER =>
                                    UART_Tx_Din <= std_logic_vector(Checksum);
                                --------------------------------------------------------
                                when others =>
                                    UART_Tx_Din <= C_UART_ERROR;
                            end case;
                        end if;
                    end if;
                ------------------------------------------------------------------------------------------------------------------------------------------------------------
                when S_Write_Checksum_Byte_N =>
                    if i_UART_Tx_Busy = '0' then
                        TM_Byte_index <= 0;
                        state         <= S_Idle;
                    end if;
                ------------------------------------------------------------------------------------------------------------------------------------------------------------
                when S_Wait_Header =>
                    TM_Wait_index <= TM_Wait_index + 1;
                    if TM_Wait_index = "11" then -- Wait for 4 clock ticks to ensure Tx is Busy
                        case TM_Byte_index is -- Index is not udpated yet when checked
                            when 0 => state <= S_Write_SYNC_Byte_1;
                            when 1 => state <= S_Write_SYNC_Byte_2;
                            when 2 => state <= S_Write_SYNC_Byte_3;
                            when 3 => state <= S_Write_Data_Frame_Type_Byte_4;
                            when 4 => state    <= S_Write_Payload;
                                Checksum <= Checksum + unsigned(UART_Tx_Din);
                            when others => state <= S_Idle;
                        end case;

                        -- Exclude SYNC_HEAD bytes from Checksum
                        TM_Wait_index <= (others => '0');
                        TM_Byte_index <= TM_Byte_index + 1;
                    end if;
                ------------------------------------------------------------------------------------------------------------------------------------------------------------
                when S_Wait_ACK_PCKT =>
                    TM_Wait_index <= TM_Wait_index + 1;
                    if TM_Wait_index = "11" then -- Wait for 4 clock ticks to ensure Tx is Busy
                        case TM_Byte_index is -- Index is not udpated yet when checked
                            when 5 to 8 => state <= S_Write_Payload; -- Until last byte
                            when 9      => state <= S_Write_Checksum_Byte_N; -- Last byte
                            when others => state <= S_Idle;
                        end case;

                        Checksum      <= Checksum + unsigned(UART_Tx_Din);
                        TM_Wait_index <= (others => '0');
                        TM_Byte_index <= TM_Byte_index + 1;
                    end if;
                ------------------------------------------------------------------------------------------------------------------------------------------------------------
                when S_Wait_HK_PCKT =>
                    TM_Wait_index <= TM_Wait_index + 1;
                    if TM_Wait_index = "11" then -- Wait for 4 clock ticks to ensure Tx is Busy
                        o_Read_Reg_Status <= '1'; -- -- Request new data from DORN Registers
                        state             <= S_Write_Payload; -- Default transition if not last byte nor error

                        case TM_Byte_index is -- Index is not udpated yet when checked, use previous index
                            when 5 to 9 => -- Do not update address, no registers read
                            when 10 => o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_TEMP_FUSIO_RT;
                            when 11 => o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_TEMP_CV_LVPS;
                            when 12 =>  -- Do not update address, LSB
                            when 13 =>
                                if Toggle_Heater_HK = '0' then
                                    o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_TEMP_HEATER_1;
                                else    -- Default display
                                    o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_TEMP_HEATER_2;
                                end if;
                            when 14 => o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_DU_TEMP_adr & std_logic_vector(DU_Polling_Select);
                            when 15 =>  -- Do not update address, LSB
                            when 16 => o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_IPRIM_AOP;
                            when 17 => o_Target_Address_TM <= C_START_REG_HK_VALUES & C_HK_ID_P7V_HV_CURRENT;
                            when 18 =>  -- Do not update address, LSB
                            when 19 =>  -- Do not update address, Status and ID
                            when 20 => o_Target_Address_TM <= C_START_REG_SDRAM_AREA_COUNTS & C_SDRAM_P12_MAPS_COUNT_adr;
                            when 21 =>  -- Do not update address, LSB
                            when 22 => o_Target_Address_TM <= C_START_REG_SDRAM_AREA_COUNTS & C_SDRAM_SPECTRA_COUNT_adr;
                            when 23 =>  -- Do not update address, LSB
                            when 24 => o_Target_Address_TM <= C_START_REG_EVENTS_COUNT_ALPHA_1 & std_logic_vector(DU_Polling_Select);
                            when 25 =>  -- Do not update address, LSB
                            when 26 => o_Target_Address_TM <= C_START_REG_EVENTS_COUNT_ALPHA_2 & std_logic_vector(DU_Polling_Select);
                            when 27 =>  -- Do not update address, LSB
                            when 28 => o_Target_Address_TM <= C_START_REG_EVENTS_COUNT_PROTON & std_logic_vector(DU_Polling_Select);
                            when 29 =>  -- Do not update address, LSB
                            when 30 =>  -- Do not update address, Checksum
                            when C_TM_HK_PCKT_MAX_BYTE_NUMBER => state <= S_Write_Checksum_Byte_N; -- Last byte
                            when others                       => state <= S_Idle;
                        end case;

                        Checksum      <= Checksum + unsigned(UART_Tx_Din);
                        TM_Wait_index <= (others => '0');
                        TM_Byte_index <= TM_Byte_index + 1;
                    end if;
                ------------------------------------------------------------------------------------------------------------------------------------------------------------
                when S_Wait_SC_PCKT =>
                    TM_Wait_index <= TM_Wait_index + 1;
                    if TM_Wait_index = "11" then -- Wait for 4 clock ticks to ensure Tx is Busy
                        case TM_Byte_index is -- Index is not udpated yet when checked
                            when 5 to C_TM_SC_PCKT_MAX_BYTE_NUMBER - 1 => state <= S_Write_Payload; -- Until last byte
                            when C_TM_SC_PCKT_MAX_BYTE_NUMBER          => state <= S_Write_Checksum_Byte_N; -- Last byte
                            when others                                => state <= S_Idle;
                        end case;

                        Checksum      <= Checksum + unsigned(UART_Tx_Din);
                        TM_Wait_index <= (others => '0');
                        TM_Byte_index <= TM_Byte_index + 1;
                    end if;
                --------------------------------------------------------
                when S_Wait_STS_PCKT =>
                    TM_Wait_index <= TM_Wait_index + 1;
                    if TM_Wait_index = "11" then -- Wait for 4 clock ticks to ensure Tx is Busy
                        o_Read_Reg_Status <= '1'; -- -- Request new data from DORN Registers
                        state             <= S_Write_Payload; -- Default transition if not last byte nor error

                        case TM_Byte_index is -- Index is not udpated yet when checked
                            when 5 to C_TM_STATUS_HV_BYTE_NUMBER - 1 =>
                                o_Target_Address_TM <= C_START_REG_HEATER_HV_FE & "10" & (std_logic_vector(TM_HV_Command_ID(2 downto 1))); -- 4 + 4 bits, X"0" addresses, index 8 to 11
                                --------------------------------------------------------
                            when C_TM_STATUS_HV_BYTE_NUMBER to C_TM_STATUS_HK_BYTE_NUMBER - 1 =>
                                -- Update new data from DORN Registers only every 2 TM bytes
                                o_Target_Address_TM <= C_START_REG_HK_VALUES & (std_logic_vector(TM_HK_DU_ID(5 downto 1))); -- 3 + 5 bits, X"E" and X"F" addresses
                                --------------------------------------------------------
                            when C_TM_STATUS_HK_BYTE_NUMBER to C_TM_STATUS_DU_BYTE_NUMBER - 1 =>
                                -- Update new data from DORN Registers only every 2 TM bytes
                                o_Target_Address_TM <= C_START_REG_Front_Filter_Thld(4 downto 2) & (std_logic_vector(TM_HK_DU_ID(5 downto 1))); -- 3 + 5 bits, X"2" and X"3" addresses
                                --------------------------------------------------------
                            when C_TM_STATUS_DU_BYTE_NUMBER to C_TM_STATUS_MEMORY_BYTE_NUMBER - 1 =>
                                o_Target_Address_TM <= C_START_REG_SDRAM_AREA_COUNTS & "0" & std_logic_vector(TM_MEMORY_ID(2 downto 1)); -- 5 + 1 + 2 bits, X"2" addresses, index 0 to 7
                                --------------------------------------------------------
                            when C_TM_STATUS_MEMORY_BYTE_NUMBER to C_TM_STATUS_MAX_BYTE_NUMBER - 1 => -- Until last byte
                                -- No address read
                                --------------------------------------------------------
                            when C_TM_STATUS_MAX_BYTE_NUMBER => -- Last byte
                                state <= S_Write_Checksum_Byte_N;
                            --------------------------------------------------------
                            when others => state <= S_Idle;
                        end case;

                        Checksum      <= Checksum + unsigned(UART_Tx_Din);
                        TM_Wait_index <= (others => '0');
                        TM_Byte_index <= TM_Byte_index + 1;
                    end if;
                --------------------------------------------------------
                when others =>
                    state <= S_Idle;
            end case;
        end if;
    end process p_Encoder_FSM;

end architecture RTL;
