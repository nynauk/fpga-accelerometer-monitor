----------------------------------------------------------------------------------
-- Module: bin2seg
-- Description: Converts a 4-bit BCD value to a 7-segment display representation.
--              Active low outputs (cathode active low on Nexys A7).
--              Segment mapping: seg(6)=CA, seg(5)=CB, seg(4)=CC,
--                               seg(3)=CD, seg(2)=CE, seg(1)=CF, seg(0)=CG
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bin2seg is
port (
    bcd_in  : in  STD_LOGIC_VECTOR (3 downto 0);
    seg_out : out STD_LOGIC_VECTOR (6 downto 0)
);
end bin2seg;

architecture dataflow of bin2seg is
begin
    with bcd_in select
        seg_out <= "0000001" when "0000",
                   "1001111" when "0001",
                   "0010010" when "0010",
                   "0000110" when "0011",
                   "1001100" when "0100",
                   "0100100" when "0101",
                   "0100000" when "0110",
                   "0001111" when "0111",
                   "0000000" when "1000",
                   "0000100" when "1001",
                   "1111110" when "1010",
                   "1111111" when "1111",
                   "1111111" when others;
end dataflow;