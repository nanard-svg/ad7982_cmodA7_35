library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Fast_to_Slow_CDC_lite is
    port(
        --global
        i_reset    : in  std_logic;
        i_clk_fast : in  std_logic;
        i_clk_slow : in  std_logic;
        --ready
        i_ready    : in  std_logic;
        o_ready    : out std_logic;
        --data science
        i_data     : in  signed(15 downto 0);
        o_data     : out signed(15 downto 0)
    );
end entity Fast_to_Slow_CDC_lite;

architecture RTL of Fast_to_Slow_CDC_lite is

    --meta
    signal ready_1 : std_logic;
    signal ready_2 : std_logic;
    --cdc

    signal ready_fast : std_logic;

    signal count : unsigned(1 downto 0);

begin

    -----------------------------------------------------------
    -- Extend ready
    -----------------------------------------------------------

    process(i_clk_fast, i_reset) is
    begin
        if i_reset = '1' then
            count      <= (others => '0');
            ready_fast <= '0';
        elsif rising_edge(i_clk_fast) then

            if i_ready = '1' or ready_fast = '1' then
                count      <= count + 1;
                ready_fast <= '1';
                if To_integer(count) = 3 then
                    count      <= (others => '0');
                    ready_fast <= '0';
                end if;
            end if;

        end if;
    end process;

    -----------------------------------------------------------
    -- meta on slow clock
    -----------------------------------------------------------

    process(i_clk_slow, i_reset) is
    begin
        if i_reset = '1' then
            ready_1 <= '0';
            ready_2 <= '0';
            o_ready <= '0';
            o_data  <= (others => '0');
        elsif rising_edge(i_clk_slow) then

            ready_1 <= ready_fast;
            ready_2 <= ready_1;
            o_ready <= ready_2;

            if ready_2 = '1' then
                o_data <= i_data;
            end if;

        end if;

    end process;

end architecture RTL;
