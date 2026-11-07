----------------------------------------------------------------------------------
-- Module: DAnC (Digits' Anode Controller)
-- Description: Anode controller to select the active display digit on the
--              Nexys A7 7-segment display. Active low anodes.
--              Uses the rightmost 5 digits (AN0 to AN4) for:
--              count 0 = AN0 (units), 1 = AN1 (tens), 2 = AN2 (hundreds),
--              3 = AN3 (thousands), 4 = AN4 (sign).
--              AN5 to AN7 are always disabled (high).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DAnC is
port (
    sel    : in  STD_LOGIC_VECTOR (2 downto 0);
    an_out : out STD_LOGIC_VECTOR (7 downto 0)
);
end DAnC;

architecture dataflow of DAnC is
begin

    an_out <= "11111110" when sel = "000" else  -- AN0 active (units)
              "11111101" when sel = "001" else  -- AN1 active (tens)
              "11111011" when sel = "010" else  -- AN2 active (hundreds)
              "11110111" when sel = "011" else  -- AN3 active (thousands)
              "11101111" when sel = "100" else  -- AN4 active (sign)
              "11111111";                       -- all off

end dataflow;
