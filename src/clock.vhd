----------------------------------------------------------------------------------
-- Module: clock
-- Description: Clock divider module that generates a tick signal for the
--              7-segment display scanning. The refresh rate is 4ms total for
--              all digits. With 5 active digits, each digit gets ~800us.
--              At 100MHz system clock and 1.25kHz scan: 100MHz / 1250 = 80000 counts per tick.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock is
generic (
    SYSCLK_FREQUENCY_HZ : integer := 100000000;
    SCAN_FREQUENCY_HZ   : integer := 1250  -- 5 digits at 4ms total = 1.25kHz scan rate
);
port (
    clk      : in  STD_LOGIC;
    reset    : in  STD_LOGIC;
    clk_out  : out STD_LOGIC
);
end clock;

architecture behavioral of clock is
    constant DIV_RATE : integer := (SYSCLK_FREQUENCY_HZ / SCAN_FREQUENCY_HZ) - 1;
    signal cnt : integer range 0 to DIV_RATE := 0;
    signal tick : STD_LOGIC := '0';
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= 0;
                tick <= '0';
            elsif cnt = DIV_RATE then
                cnt <= 0;
                tick <= '1';
            else
                cnt <= cnt + 1;
                tick <= '0';
            end if;
        end if;
    end process;

    clk_out <= tick;

end behavioral;
