library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_acq is
    port(
        --global
        clk            : in  std_logic;
        rst            : in  std_logic;
        --fifo
        o_din          : out std_logic_vector(15 downto 0);
        o_wr_en        : out std_logic;
        --rx uart
        i_UART_Rx_Dout : in  std_logic_vector(7 downto 0);
        --adc
        --out adc driver
        i_data_rx      : in  std_logic_vector(15 downto 0);
        i_ready_rx     : in  std_logic
    );
end entity fsm_acq;

architecture RTL of fsm_acq is

    type state_type is (wait_start, write_fifo, wait_delay);
    signal state                : state_type;
    signal i_UART_Rx_Dout_ff0   : std_logic_vector(7 downto 0);
    signal i_UART_Rx_Dout_ff1   : std_logic_vector(7 downto 0);
    signal pattern_data         : std_logic_vector(15 downto 0);

    signal pattern_data_counter : unsigned(15 downto 0);
    signal compter_delay        : unsigned(15 downto 0);
    signal i_UART_Rx_Dout_ff2   : std_logic_vector(7 downto 0);

begin

    process(clk, rst) is
    begin
        if rst = '1' then
            state <= wait_start;

            o_wr_en              <= '0';
            pattern_data         <= (others => '0');
            compter_delay        <= (others => '0');
            i_UART_Rx_Dout_ff0   <= x"30";
            i_UART_Rx_Dout_ff1   <= x"30";
            i_UART_Rx_Dout_ff2   <= x"30";
            pattern_data_counter <= (others => '0');
            

        elsif rising_edge(clk) then

            i_UART_Rx_Dout_ff0 <= i_UART_Rx_Dout;
            i_UART_Rx_Dout_ff1 <= i_UART_Rx_Dout_ff0;
            i_UART_Rx_Dout_ff2 <= i_UART_Rx_Dout_ff1;

            o_wr_en <= '0';

            case state is

                when wait_start =>

                    if i_UART_Rx_Dout_ff1 = x"53" and i_UART_Rx_Dout_ff2 = x"30" then
                        state <= write_fifo;
                    end if;

                when write_fifo =>

                    if i_ready_rx = '1' then
                        pattern_data   <= i_data_rx;
                        

                        pattern_data_counter <= pattern_data_counter + 1;
                        o_wr_en              <= '1';
                        state                <= wait_delay;
                    end if;

                when wait_delay =>

                    if To_integer(pattern_data_counter) = 65500 then
                        state                <= wait_start;
                        pattern_data_counter <= (others => '0');
                        compter_delay        <= (others => '0');
                    else
                        state <= write_fifo;
                    end if;

            end case;

        end if;
    end process;

    o_din <= pattern_data;

end architecture RTL;
