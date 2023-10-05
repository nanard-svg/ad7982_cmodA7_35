library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Rx_fe is
    port(
        --global
        clk        : in     std_logic;
        rst        : in     std_logic;
        --adc
        o_sck      : out    std_logic;
        o_cnv      : out    std_logic;
        i_sdo      : in     std_logic;
        --out adc driver
        o_data_rx  : buffer std_logic_vector(17 downto 0);
        o_ready_rx : buffer std_logic
    );
end entity Rx_fe;

architecture RTL of Rx_fe is

    type state_type is (reset_state, conversion_state, acquisition_state, end_state);
    signal state : state_type;

    signal count        : unsigned(9 downto 0);
    signal o_cnv_signal : std_logic;
    signal enable_sck   : std_logic;

begin

    process(clk, rst) is
    begin
        if rst = '1' then

            state        <= reset_state;
            o_cnv_signal <= '0';
            count        <= (others => '0');
            enable_sck   <= '0';
            o_ready_rx   <= '0';

        elsif falling_edge(clk) then
            case state is

                when reset_state =>

                    state <= conversion_state;

                    o_cnv_signal <= '0';
                    count        <= (others => '0');

                when conversion_state =>

                    o_cnv_signal <= '1';
                    enable_sck   <= '0';
                    count        <= count + 1;

                    if To_integer(count) = 46 then -- 700 = 15ns(66MHz)*46
                        o_cnv_signal <= '0';
                        enable_sck   <= '1';
                        count        <= (others => '0');
                        state        <= acquisition_state;
                    end if;

                when acquisition_state =>

                    o_cnv_signal <= '0';
                    count        <= count + 1;

                    if To_integer(count) = 17 then --360= 20ns * 18
                        o_cnv_signal <= '1'; --set SDO to 'Z'
                        enable_sck   <= '0';
                        o_ready_rx   <= '1';
                        count        <= (others => '0');
                        state        <= end_state;
                    end if;

                when end_state =>

                    o_cnv_signal <= '0';
                    o_ready_rx   <= '0';
                    state        <= conversion_state;

            end case;

        end if;
    end process;

    o_cnv <= o_cnv_signal;
    o_sck <= clk when (o_cnv_signal = '0' and enable_sck = '1') else '0';

    process(clk, rst) is
    begin
        if rst = '1' then
            o_data_rx <= (others => '0');

        elsif falling_edge(clk) then

            if (o_cnv_signal = '0' and enable_sck = '1') then
                o_data_rx <= o_data_rx(16 downto 0) & i_sdo;
            else
                if o_ready_rx = '1' then
                    o_data_rx <= (others => '0'); -- flush o_data_rx
                end if;
            end if;

        end if;
    end process;

end architecture RTL;
