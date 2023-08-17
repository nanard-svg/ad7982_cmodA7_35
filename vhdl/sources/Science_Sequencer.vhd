
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.DORN_Package.all;
--use work.Package_AMBA.all;
--use work.Package_AXI.all;
--use work.Pack_FLASH_Mem_Ctrl.all;

entity Science_Sequencer is
    port(
        --------------------------------------------
        -- Clock and reset
        --------------------------------------------
        i_Rst_n                : in    std_logic;
        i_Clk                  : in    std_logic;
        --------------------------------------------
        -- TC decoder flags
        --------------------------------------------

        i_TC_Change_Param      : in    std_logic;
        i_TC_Target_Address_TC : in    std_logic_vector(7 downto 0);
        i_TC_Data_Write_TC     : in    std_logic_vector(15 downto 0);
        --------------------------------------------
        -- TM encoder
        --------------------------------------------

        o_Science_Available    : inout std_logic;
        o_FIFO_Science_Data    : out   std_logic_vector(23 downto 0);
        i_FIFO_Science_Rd_En   : in    std_logic;
        o_Reg_Rd_En            : out   std_logic;
        o_Reg_Wr_En            : out   std_logic;
        o_Reg_Data_Read        : out   std_logic_vector(15 downto 0);
        i_Target_Address_TM    : in    std_logic_vector(7 downto 0)
    );
end entity Science_Sequencer;

architecture RTL of Science_Sequencer is

    type state_type is (write_add_du1, data_du1, write_add_du2, data_du2, write_add_du3, data_du3, write_add_du4, data_du4,  
        write_add_du5, data_du5, write_add_du6, data_du6,write_add_du7, data_du7, write_add_du8, data_du8, break
    );
    signal state : state_type;

    signal unsigned_counter_science_available : unsigned(23 downto 0);

    signal we                              : STD_LOGIC;
    signal Reg_Data_Read                   : STD_LOGIC_VECTOR(15 downto 0);
    signal unsigned_o_FIFO_Science_Data    : unsigned(23 downto 0);
    signal Reg_Address                     : std_logic_vector(7 downto 0);
    signal i_TC_Change_Param_internal      : STD_LOGIC;
    signal i_TC_Target_Address_TC_internal : std_logic_vector(7 downto 0);
    signal i_TC_Data_Write_TC_RAM          : STD_LOGIC_VECTOR(15 downto 0);
    signal i_TC_Data_Write_TC_RAM_internal : STD_LOGIC_VECTOR(15 downto 0);

begin

    o_FIFO_Science_Data <= std_logic_vector(unsigned_o_FIFO_Science_Data);

    --------------------------------------------------
    -- 
    --------------------------------------------------
    process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then

            unsigned_o_FIFO_Science_Data       <= x"000102";
            unsigned_counter_science_available <= (others => '0');
            o_Science_Available                <= '1';

        elsif rising_edge(i_Clk) then

            if o_Science_Available = '0' then --o_Science_Available = '1'

                if i_FIFO_Science_Rd_En = '1' then

                    unsigned_o_FIFO_Science_Data <= (unsigned_o_FIFO_Science_Data(23 downto 16) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data(15 downto 8) + to_unsigned(3, 8)) & (unsigned_o_FIFO_Science_Data(7 downto 0) + to_unsigned(3, 8));

                    unsigned_counter_science_available <= unsigned_counter_science_available + 1;

                    if unsigned_counter_science_available = to_unsigned(289, 24) then
                        o_Science_Available                <= '1';
                        unsigned_counter_science_available <= (others => '0');
                    end if;

                end if;

            else                        --o_Science_Available = '0'

                unsigned_counter_science_available <= unsigned_counter_science_available + 1;

                if unsigned_counter_science_available = to_unsigned(16000000, 24) then
                    o_Science_Available                <= '0';
                    unsigned_counter_science_available <= (others => '0');
                end if;

            end if;

        end if;
    end process;

    --------------------------------------------------
    -- mem reg
    --------------------------------------------------

    label_mem_reg : entity work.mem_reg
        port map(
            a   => Reg_Address,
            d   => i_TC_Data_Write_TC_RAM,
            clk => i_Clk,
            we  => we,
            spo => Reg_Data_Read
        );

    i_TC_Data_Write_TC_RAM <= i_TC_Data_Write_TC when i_TC_Change_Param_internal = '0' else i_TC_Data_Write_TC_RAM_internal;
    --------------------------------------------------
    -- write reg
    --------------------------------------------------
    process(i_Rst_n, i_Clk)
    begin
        if i_Rst_n = '0' then
            we          <= '0';
            Reg_Address <= X"00";

        elsif rising_edge(i_Clk) then

            if i_TC_Change_Param = '1' then
                Reg_Address <= i_TC_Target_Address_TC;
            else    
                if i_TC_Change_Param_internal = '1' then
                    Reg_Address <= i_TC_Target_Address_TC_internal;
                else
                    Reg_Address <= i_Target_Address_TM;
                end if;
            end if;

            we <= i_TC_Change_Param or i_TC_Change_Param_internal;
            
            if i_TC_Target_Address_TC = X"21" and i_TC_Data_Write_TC /= X"0578" and i_TC_Data_Write_TC /= X"0000" then
                we <= '0';
            end if;

        end if;
    end process;

    o_Reg_Data_Read <= Reg_Data_Read;
    o_Reg_Rd_En     <= '1';
    o_Reg_Wr_En     <= '0';

    --------------------------------------------------
    -- FSM write RAM HKs
    --------------------------------------------------

    p_Tx_FSM : process(i_Rst_n, i_Clk) is
    begin
        if i_Rst_n = '0' then

            state                           <= write_add_du1;
            i_TC_Change_Param_internal      <= '0';
            i_TC_Target_Address_TC_internal <= X"00";
            i_TC_Data_Write_TC_RAM_internal <= x"0000";
        elsif rising_edge(i_Clk) then
            -- FSM
            case state is
                
                when write_add_du1 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du1;
                    i_TC_Target_Address_TC_internal <= x"F8";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                when data_du1 =>
                    state                           <= write_add_du2;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0AD7"; 
                    
                when write_add_du2 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du2;
                    i_TC_Target_Address_TC_internal <= x"F9";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                when data_du2 =>
                    state                           <= write_add_du3;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0AC7"; 
                        
                when write_add_du3 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du3;
                    i_TC_Target_Address_TC_internal <= x"FA";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                when data_du3 =>
                    state                           <= write_add_du4;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0AB7";
                    
                when write_add_du4 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du4;
                    i_TC_Target_Address_TC_internal <= x"FB";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when data_du4 =>
                    state                           <= write_add_du5;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0AA7";      

                when write_add_du5 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du5;
                    i_TC_Target_Address_TC_internal <= x"FC";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when data_du5 =>
                    state                           <= write_add_du6;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0A97"; 
                    
                when write_add_du6 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du6;
                    i_TC_Target_Address_TC_internal <= x"FD";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when data_du6 =>
                    state                           <= write_add_du7;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0A87";   
                    
                when write_add_du7 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du7;
                    i_TC_Target_Address_TC_internal <= x"FE";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when data_du7 =>
                    state                           <= write_add_du8;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0A77";                                    
 
                 when write_add_du8 =>
                    i_TC_Change_Param_internal      <= '1';
                    state                           <= data_du8;
                    i_TC_Target_Address_TC_internal <= x"FF";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when data_du8 =>
                    state                           <= break;
                    i_TC_Change_Param_internal      <= '1';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0A67"; 
                    
                                       
                --------------------------------------------------------
                when break =>
                    state                           <= break;
                    i_TC_Change_Param_internal      <= '0';
                    i_TC_Target_Address_TC_internal <= X"00";
                    i_TC_Data_Write_TC_RAM_internal <= x"0000";
                    
                when others =>

            end case;
        end if;
    end process p_Tx_FSM;

end architecture RTL;
