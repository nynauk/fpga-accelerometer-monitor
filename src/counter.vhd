----------------------------------------------------------------------------------
-- Module: counter
-- Description: Counter module for 7-segment display scanning.
--              Counts from 0 to 4 (5 digits: sign, thousands, hundreds, tens, units)
--              to alternatively select the active display digit.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter is
port (
    clk      : in  STD_LOGIC;
    reset    : in  STD_LOGIC;
    enable   : in  STD_LOGIC;
    count    : out STD_LOGIC_VECTOR (2 downto 0)
);
end counter;

architecture behavioral of counter is
    signal cnt_reg : unsigned(2 downto 0) := "000";
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt_reg <= "000";
            elsif enable = '1' then
                if cnt_reg = 4 then
                    cnt_reg <= "000";
                else
                    cnt_reg <= cnt_reg + 1;
                end if;
            end if;
        end if;
    end process;

    count <= STD_LOGIC_VECTOR(cnt_reg);

end behavioral;
