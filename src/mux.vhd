----------------------------------------------------------------------------------
-- Module: mux
-- Description: Multiplexer to select the BCD value to be displayed on the
--              7-segment display. Selects one of 5 digits based on the counter:
--              0 = unit, 1 = tens, 2 = hundreds, 3 = thousands, 4 = sign
--              For the sign digit, outputs "1010" to trigger dash on bin2seg.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux is
port (
    sel       : in  STD_LOGIC_VECTOR (2 downto 0);
    sign_in   : in  STD_LOGIC;
    thousands : in  STD_LOGIC_VECTOR (3 downto 0);
    hundreds  : in  STD_LOGIC_VECTOR (3 downto 0);
    tens      : in  STD_LOGIC_VECTOR (3 downto 0);
    unit      : in  STD_LOGIC_VECTOR (3 downto 0);
    bcd_out   : out STD_LOGIC_VECTOR (3 downto 0)
);
end mux;

architecture dataflow of mux is
begin

    bcd_out <= unit      when sel = "000" else
               tens      when sel = "001" else
               hundreds  when sel = "010" else
               thousands when sel = "011" else
               "1010"    when sel = "100" and sign_in = '1' else  -- dash for negative
               "1111"    when sel = "100" and sign_in = '0' else  -- blank for positive
               "1111";   -- blank default

end dataflow;
