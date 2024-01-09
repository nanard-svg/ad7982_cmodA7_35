library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Fast_to_Slow_CDC is
    port(
        --global
        i_reset    : in  std_logic;
        i_clk_fast : in  std_logic;
        i_clk_slow : in  std_logic;
        --ready
        i_ready    : in  std_logic;
        o_ready    : out std_logic;
        --data science
        i_data     : in  std_logic_vector(15 downto 0);
        o_data     : out std_logic_vector(15 downto 0)
    );
end entity Fast_to_Slow_CDC;

architecture RTL of Fast_to_Slow_CDC is

    --meta
    signal ready_1 : std_logic;
    signal ready_2 : std_logic;
    --cdc
    signal ready_3 : std_logic;
    signal ready_4 : std_logic;

begin
------------------------------------------------------------------------------------------
--
-- Detect fast ready with clock pin
--
------------------------------------------------------------------------------------------
    label_cdc_first : process(i_ready, ready_4) is
    begin
        if ready_4 = '1' then
            --  meta
            ready_1 <= '0';
        elsif rising_edge(i_ready) then
            ready_1 <= '1';
        end if;
    end process;

    label_cdc : process(i_clk_slow, ready_4) is
    begin
        if ready_4 = '1' then

            --  meta
            ready_2 <= '0';
            ready_3 <= '0';
            ready_4 <= '0';


        elsif rising_edge(i_clk_slow) then

            ready_2 <= ready_1;
            ready_3 <= ready_2;
            ready_4 <= ready_3;

        end if;
    end process;

    --ready_out <= ready_3 and not ready_4;
    --o_ready   <= ready_out;

    process(i_clk_slow, i_reset) is
    begin
        if i_reset = '1' then
            o_data  <= (others => '0');
            o_ready <= '0';
        elsif rising_edge(i_clk_slow) then

            if ready_3 = '1' and ready_4 = '0' then
                o_data  <= i_data;
                o_ready <= '1';
            else
                o_ready <= '0';
            end if;

        end if;
    end process;

--------------------------------------------------------------------------------------------------------------

    --    label_cdc : process(i_clk_slow, i_reset) is
    --    begin
    --        if i_reset = '1' then
    --            --  meta
    --            ready_1 <= '0';
    --            ready_2 <= '0';
    --            --  cdc
    --            ready_3 <= '0';
    --            o_ready <= '0';
    --
    --            data_1 <= (others => '0');
    --            o_data <= (others => '0');
    --
    --        elsif rising_edge(i_clk_slow) then
    --
    --            --  meta ready
    --            ready_1 <= i_ready;
    --            ready_2 <= ready_1;
    --
    --            --  cdc ready
    --            ready_3 <= ready_2;
    --
    --            o_ready <= ready_2 and not ready_3;
    --
    --            --  meta data science
    --            data_1 <= i_data;
    --            o_data <= data_1;
    --
    --        end if;
    --    end process;

end architecture RTL;
