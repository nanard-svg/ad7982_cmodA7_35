library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.DORN_Package.all;

entity Science_Sequencer_complexe is
    port(
        --------------------------------------------
        -- Clock and reset
        --------------------------------------------
        i_Rst_n              : in    std_logic;
        i_Clk                : in    std_logic;
        --------------------------------------------
        -- Command Flags
        --------------------------------------------

        --i_Write_FLASH_FIFO   : in  std_logic;
        --i_Start_Erasing      : in  std_logic;
        --------------------------------------------
        -- FIFO DUMP interface with FLASH
        --------------------------------------------
        --i_FLASH_Settings_TC : in  FLASH_Settings_type; -- Record (CTYPE, BLK, PAGE, CA, NBDATA)
        --o_FIFO_DUMP_Wr_En   : out std_logic;
        o_Science_Available  : inout std_logic;
        i_FIFO_DUMP_Rd_En    : in    std_logic;
        o_FIFO_Science_Data  : out   std_logic_vector(23 downto 0);
        i_FIFO_Science_Rd_En : in    std_logic;
        --o_FIFO_DUMP_Empty   : out std_logic;
        o_FIFO_DUMP_Half     : out   std_logic;
        o_FIFO_DUMP_Data     : out   std_logic_vector(23 downto 0);
        -- Time codes

        o_FLASH_AXI_Start    : out   std_logic;
        o_FLASH_AXI_Busy     : out   std_logic;
        o_Reg_Rd_En          : inout std_logic;
        o_Reg_Wr_En          : out   std_logic;
        o_Reg_Adr            : out   std_logic_vector(7 downto 0);
        o_Reg_Data_Read      : out   std_logic_vector(15 downto 0);
        i_Change_Param       : in    std_logic;
        i_Read_Param         : in    std_logic;
        i_UART_TC_ID         : in    std_logic_vector(7 downto 0);
        i_Target_Address_TC  : in    std_logic_vector(7 downto 0);
        i_Data_Write_TC      : in    std_logic_vector(15 downto 0);
        i_Target_Address_TM  : in    std_logic_vector(7 downto 0)
    );
end entity Science_Sequencer_complexe;

architecture RTL of Science_Sequencer_complexe is

    type state_type_kh is (start_tag, Housekeeping, Modes, Heater_conf, header_page_encoding, add_page_encoding, data_page_encoding);
    signal state         : state_type_kh;
    signal old_state     : state_type_kh;
    signal KH_Byte_index : integer range 0 to 21; --22 * 3 bytes = 66bytes
    signal Page_index    : integer range 0 to 1024;

    signal Reg_Data_Read  : std_logic_vector(15 downto 0);
    signal Target_Address : STD_LOGIC_VECTOR(7 downto 0);
    signal we             : STD_LOGIC;

    signal unsigned_o_FIFO_Science_Data        : unsigned(23 downto 0);
    signal unsigned_ADR_pckt                   : unsigned(23 downto 0);
    signal unsigned_counter                    : unsigned(11 downto 0);
    signal unsigned_o_FIFO_Science_Data_old    : unsigned(23 downto 0);
    signal unsigned_o_FIFO_Science_Data_hk_old : unsigned(23 downto 0);
begin

    process(i_Clk, i_Rst_n) is
    begin
        if i_Rst_n = '0' then

            state                               <= start_tag;
            unsigned_counter                    <= (others => '0');
            unsigned_o_FIFO_Science_Data        <= (others => '0');
            unsigned_o_FIFO_Science_Data_old    <= x"000102";
            unsigned_o_FIFO_Science_Data_hk_old <= (others => '0');

            --realy use?
            o_FIFO_DUMP_Half <= '0';

            o_FLASH_AXI_Start <= '0';
            o_FLASH_AXI_Busy  <= '0';
            KH_Byte_index     <= 0;
            Page_index        <= 0;
            unsigned_ADR_pckt <= (others => '0');

        elsif rising_edge(i_Clk) then

            case state is
                ---------------------------------------------------------------------------------------------------------------
                when start_tag =>

                    if Page_index = 1023 then
                        old_state                           <= start_tag;
                        state                               <= header_page_encoding;
                        Page_index                          <= 0;
                        unsigned_o_FIFO_Science_Data        <= 0x"ABCD" & 0x"00";
                        unsigned_o_FIFO_Science_Data_hk_old <= unsigned_o_FIFO_Science_Data_old;

                    else

                        unsigned_o_FIFO_Science_Data <= 0x"AA" & 0x"0" & unsigned_counter;
                        if i_FIFO_Science_Rd_En = '1' then
                            state            <= Housekeeping;
                            KH_Byte_index    <= KH_Byte_index + 1;
                            Page_index       <= Page_index + 1;
                            unsigned_counter <= unsigned_counter + to_unsigned(1, 12);

                            unsigned_o_FIFO_Science_Data     <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            unsigned_o_FIFO_Science_Data_old <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                        end if;

                    end if;

                when Housekeeping =>

                    if Page_index = 1023 then
                        old_state                           <= Housekeeping;
                        state                               <= header_page_encoding;
                        Page_index                          <= 0;
                        unsigned_o_FIFO_Science_Data        <= 0x"ABCD" & 0x"00";
                        unsigned_o_FIFO_Science_Data_hk_old <= unsigned_o_FIFO_Science_Data_old;

                    else

                        if i_FIFO_Science_Rd_En = '1' then

                            unsigned_o_FIFO_Science_Data     <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            unsigned_o_FIFO_Science_Data_old <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));

                            KH_Byte_index <= KH_Byte_index + 1;
                            Page_index    <= Page_index + 1;

                            if KH_Byte_index = 16 then
                                state <= Modes;
                            end if;

                        end if;
                    end if;

                when Modes =>

                    if Page_index = 1023 then
                        old_state                           <= Modes;
                        state                               <= header_page_encoding;
                        Page_index                          <= 0;
                        unsigned_o_FIFO_Science_Data        <= 0x"ABCD" & 0x"00";
                        unsigned_o_FIFO_Science_Data_hk_old <= unsigned_o_FIFO_Science_Data_old;

                    else

                        if i_FIFO_Science_Rd_En = '1' then
                            unsigned_o_FIFO_Science_Data <= 0x"00" & 0x"00" & 0x"00";
                            state                        <= Heater_conf;
                            KH_Byte_index                <= KH_Byte_index + 1;
                            Page_index                   <= Page_index + 1;
                        end if;

                    end if;

                when Heater_conf =>

                    if Page_index = 1023 then
                        old_state                           <= Heater_conf;
                        state                               <= header_page_encoding;
                        Page_index                          <= 0;
                        unsigned_o_FIFO_Science_Data        <= 0x"ABCD" & 0x"00";
                        unsigned_o_FIFO_Science_Data_hk_old <= unsigned_o_FIFO_Science_Data_old;

                    else

                        if i_FIFO_Science_Rd_En = '1' then
                            unsigned_o_FIFO_Science_Data <= 0x"00" & 0x"00" & 0x"00";
                            state                        <= Heater_conf;
                            KH_Byte_index                <= KH_Byte_index + 1;
                            Page_index                   <= Page_index + 1;

                            if KH_Byte_index = 21 then
                                state         <= start_tag;
                                KH_Byte_index <= 0;
                            end if;
                        end if;

                    end if;
                ----------------------------------------------------------------------------------------------------------------
                when header_page_encoding =>

                        if i_FIFO_Science_Rd_En = '1' then
                            unsigned_o_FIFO_Science_Data <= unsigned_ADR_pckt;
                            unsigned_ADR_pckt            <= unsigned_ADR_pckt + 1;
                            state                        <= add_page_encoding;
                            Page_index                   <= Page_index + 1;

                        end if;
                   
                when add_page_encoding =>

                        if i_FIFO_Science_Rd_En = '1' then

                            state                            <= data_page_encoding;
                            unsigned_o_FIFO_Science_Data     <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            unsigned_o_FIFO_Science_Data_old <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            Page_index                   <= Page_index + 1;
    

                        end if;

                    

                when data_page_encoding =>
  
                    if Page_index = 1023 then

                        state                            <= old_state;
                        Page_index                       <= 0;
                        unsigned_o_FIFO_Science_Data     <= 0x"ABCD" & 0x"00";
                        unsigned_o_FIFO_Science_Data_old <= unsigned_o_FIFO_Science_Data_hk_old;

                    else

                        if i_FIFO_Science_Rd_En = '1' then

                            state                            <= data_page_encoding;
                            unsigned_o_FIFO_Science_Data     <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            unsigned_o_FIFO_Science_Data_old <= (unsigned_o_FIFO_Science_Data_old(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data_old(7 downto 0) + to_unsigned(3, 8));
                            Page_index                   <= Page_index + 1;
    

                        end if;

                    end if;                    
                    
            end case;

        end if;
    end process;

    o_FIFO_Science_Data <= std_logic_vector(unsigned_o_FIFO_Science_Data);
    o_Science_Available <= '1';

    --------------------------------------------------
    -- mem reg
    --------------------------------------------------

    label_mem_reg : entity work.mem_reg
        port map(
            a   => Target_Address,
            d   => i_Data_Write_TC,
            clk => i_Clk,
            we  => we,
            spo => Reg_Data_Read
        );

    --------------------------------------------------
    -- write reg
    --------------------------------------------------
    process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then
            we <= '0';
        elsif rising_edge(i_Clk) then
            we <= '0';
            if i_Change_Param = '1' then
                we <= '1';
            end if;
        end if;
    end process;

    process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then
            o_Reg_Data_Read <= (others => '0');
            o_Reg_Wr_En     <= '0';
            o_Reg_Adr       <= (others => '0');
        elsif rising_edge(i_Clk) then
            o_Reg_Wr_En <= '0';
            if i_Read_Param = '1' or o_Reg_Rd_En = '1' then
                o_Reg_Data_Read <= Reg_Data_Read;
                o_Reg_Wr_En     <= '1';
            else
                o_Reg_Wr_En <= '0';
            end if;
        end if;
    end process;

    Target_Address <= i_Target_Address_TC when ((i_UART_TC_ID = C_TC_CHANGE_PARAM) or (i_UART_TC_ID = C_TC_READ_PARAM)) else i_Target_Address_TM;

    process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then
            o_Reg_Rd_En <= '0';
        elsif rising_edge(i_Clk) then
            if i_UART_TC_ID = C_TC_GET_STATUS then
                o_Reg_Rd_En <= '1';
            else
                o_Reg_Rd_En <= '0';
            end if;
        end if;
    end process;

end architecture RTL;
