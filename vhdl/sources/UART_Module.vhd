
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Module is
    generic(
        G_UART_BAUDRATE_CNT_MAX : integer range 0 to 255 := 217; -- Adapt range to maximum value
        G_UART_PARITY_POLARITY  : std_logic              := '1' -- RS-422 protocol partity bit, 0: Even, 1: Odd
    );
    port(
        -- Reset and Clock
        i_Rst_n           : in  std_logic;
        i_Clk             : in  std_logic;
        i_Baud_Cnt_Offset : in  std_logic_vector(5 downto 0);
        -- Rx
        o_Rx_Start_Bit    : out std_logic;
        o_Rx_Next_Bit     : out std_logic;
        o_Rx_Parity_Error : out std_logic;
        o_Rx_Frame_Error  : out std_logic;
        o_Rx_Ready        : out std_logic;
        o_Rx_Dout         : out std_logic_vector(7 downto 0);
        -- Tx
        o_Tx_Start_Bit    : out std_logic;
        o_Tx_Next_Bit     : out std_logic;
        i_Tx_Send_Data    : in  std_logic;
        i_Tx_Din          : in  std_logic_vector(7 downto 0);
        o_Tx_Busy         : out std_logic;
        -- RS-422
        i_RS422_Rx        : in  std_logic;
        o_RS422_Tx        : out std_logic
    );
end entity UART_Module;

architecture RTL of UART_Module is

    signal Baud_Cnt_Max : signed(7 downto 0);     -- Must be always positive, signed type to add signed offset

begin
    -----------------------------------------------------------------
    --
    -- Configuration
    --
    -----------------------------------------------------------------

    Baud_Cnt_Max <= G_UART_BAUDRATE_CNT_MAX + resize(signed(i_Baud_Cnt_Offset), 8);

    -----------------------------------------------------------------
    --
    -- Rx : Receiver
    --
    -----------------------------------------------------------------

    inst_UART_Rx : entity work.UART_Rx
        generic map(
            G_PARITY_POLARITY => G_UART_PARITY_POLARITY
        )
        port map(
            i_Rst_n        => i_Rst_n,
            i_Clk          => i_Clk,
            i_Baud_Cnt_Max => std_logic_vector(Baud_Cnt_Max),
            --
            o_Start_Bit    => o_Rx_Start_Bit,
            o_Next_Bit     => o_Rx_Next_Bit,
            o_Parity_Error => o_Rx_Parity_Error,
            o_Frame_Error  => o_Rx_Frame_Error,
            o_Rx_Ready     => o_Rx_Ready,
            o_Rx_Dout      => o_Rx_Dout,
            --
            i_RS422_Rx     => i_RS422_Rx
        );

    -----------------------------------------------------------------
    --
    -- Tx : Transmitter
    --
    -----------------------------------------------------------------

    inst_UART_Tx : entity work.UART_Tx
        generic map(
            G_PARITY_POLARITY => G_UART_PARITY_POLARITY
        )
        port map(
            i_Rst_n        => i_Rst_n,
            i_Clk          => i_Clk,
            i_Baud_Cnt_Max => std_logic_vector(Baud_Cnt_Max),
            --
            o_Start_Bit    => o_Tx_Start_Bit,
            o_Next_Bit     => o_Tx_Next_Bit,
            i_Send_Data    => i_Tx_Send_Data,
            i_Tx_Din       => i_Tx_Din,
            o_Tx_Busy      => o_Tx_Busy,
            --
            o_RS422_Tx     => o_RS422_Tx
        );

end architecture RTL;
