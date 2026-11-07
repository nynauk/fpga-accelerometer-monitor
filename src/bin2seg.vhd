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
    -- seg_out = "abcdefg" active low
    with bcd_in select
        seg_out <= "0000001" when "0000", -- 0
                   "1001111" when "0001", -- 1
                   "0010010" when "0010", -- 2
                   "0000110" when "0011", -- 3
                   "1001100" when "0100", -- 4
                   "0100100" when "0101", -- 5
                   "0100000" when "0110", -- 6
                   "0001111" when "0111", -- 7
                   "0000000" when "1000", -- 8
                   "0000100" when "1001", -- 9
                   "1111110" when others; -- dash (minus sign) for invalid/sign
end dataflow;
