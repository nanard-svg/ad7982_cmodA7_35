library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_tx is
    port(
        --  global
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        --  fifo
        o_rd_en             : out std_logic;
        i_dout              : in  std_logic_vector(15 downto 0);
        i_empty             : in  std_logic;
        i_valid             : in  std_logic;
        --  tx
        o_UART_Tx_Din       : out std_logic_vector(7 downto 0);
        o_UART_Tx_Send_Data : out std_logic;
        i_UART_Tx_Busy      : in  std_logic
    );
end entity fsm_tx;

architecture RTL of fsm_tx is

    type state_type is (wait_fifo_lsb, valid_fifo_lsb, write_tx_lsb,one_cycle,write_tx_msb);
    signal state : state_type := wait_fifo_lsb;

begin

    process(clk, rst) is
    begin
        if rst = '1' then
            state   <= wait_fifo_lsb;
            o_rd_en <= '0';

            o_UART_Tx_Din <= (others => '0');
        elsif rising_edge(clk) then

            o_UART_Tx_Send_Data <= '0';
            o_rd_en             <= '0';

            case state is

                when wait_fifo_lsb =>

                    if i_empty = '0' then
                        state   <= valid_fifo_lsb;
                        o_rd_en <= '1';
                    end if;

                when valid_fifo_lsb =>

                    if i_valid = '1' then

                        state <= write_tx_lsb;

                        o_UART_Tx_Din <= i_dout(7 downto 0);

                    end if;

                when write_tx_lsb =>

                    if i_UART_Tx_Busy = '0' then
                        o_UART_Tx_Send_Data <= '1';
                        state               <= one_cycle;
                    end if;
                    
                when one_cycle  =>
                    
                    o_UART_Tx_Din       <= i_dout(15 downto 8);
                    state               <= write_tx_msb;

                when write_tx_msb =>

                    if i_UART_Tx_Busy = '0' then

                        o_UART_Tx_Send_Data <= '1';   
                        state               <= wait_fifo_lsb;
                        
                    end if;

            end case;
        end if;

    end process;

end architecture RTL;
