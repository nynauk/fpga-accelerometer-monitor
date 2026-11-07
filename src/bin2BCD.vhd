----------------------------------------------------------------------------------
-- Module: bin2BCD
-- Description: Converts a 12-bit signed two's complement binary number to BCD.
--              Uses the Double Dabble (shift-and-add-3) algorithm.
--              Outputs: sign bit, thousands (4-bit), hundreds (4-bit),
--                       tens (4-bit), unit (4-bit).
--              The 12-bit signed input range is -2048 to +2047.
--              After taking absolute value, max is 2048, so 4 BCD digits needed.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin2BCD is
port (
    bin_in    : in  STD_LOGIC_VECTOR (11 downto 0);
    sign_out  : out STD_LOGIC;
    thousands : out STD_LOGIC_VECTOR (3 downto 0);
    hundreds  : out STD_LOGIC_VECTOR (3 downto 0);
    tens      : out STD_LOGIC_VECTOR (3 downto 0);
    unit      : out STD_LOGIC_VECTOR (3 downto 0)
);
end bin2BCD;

architecture behavioral of bin2BCD is
begin

    process (bin_in)
        variable bin_temp  : unsigned(11 downto 0);
        variable bcd_thou  : unsigned(3 downto 0);
        variable bcd_hund  : unsigned(3 downto 0);
        variable bcd_tens  : unsigned(3 downto 0);
        variable bcd_unit  : unsigned(3 downto 0);
        variable is_neg    : STD_LOGIC;
    begin
        -- Step 1: Check if MSB == '1' (negative value)
        if bin_in(11) = '1' then
            is_neg := '1';
        else
            is_neg := '0';
        end if;

        -- Step 2: Store the sign
        sign_out <= is_neg;

        -- Step 3: If negative, invert all bits and add '1' (two's complement)
        if is_neg = '1' then
            bin_temp := unsigned(not bin_in) + 1;
        else
            bin_temp := unsigned(bin_in);
        end if;

        -- Step 4: Initialize the BCD columns to 0
        bcd_thou := "0000";
        bcd_hund := "0000";
        bcd_tens := "0000";
        bcd_unit := "0000";

        -- Steps 5-7: Double Dabble algorithm for 12 bits
        for i in 0 to 11 loop
            -- Step 5: Check if any column is greater than 4, if so add 3
            if bcd_thou > 4 then
                bcd_thou := bcd_thou + 3;
            end if;
            if bcd_hund > 4 then
                bcd_hund := bcd_hund + 3;
            end if;
            if bcd_tens > 4 then
                bcd_tens := bcd_tens + 3;
            end if;
            if bcd_unit > 4 then
                bcd_unit := bcd_unit + 3;
            end if;

            -- Step 6: Shift all bits to the left 1 position
            bcd_thou := bcd_thou(2 downto 0) & bcd_hund(3);
            bcd_hund := bcd_hund(2 downto 0) & bcd_tens(3);
            bcd_tens := bcd_tens(2 downto 0) & bcd_unit(3);
            bcd_unit := bcd_unit(2 downto 0) & bin_temp(11);
            bin_temp := bin_temp(10 downto 0) & '0';
        end loop;

        -- Step 7: Output the BCD values
        thousands <= STD_LOGIC_VECTOR(bcd_thou);
        hundreds  <= STD_LOGIC_VECTOR(bcd_hund);
        tens      <= STD_LOGIC_VECTOR(bcd_tens);
        unit      <= STD_LOGIC_VECTOR(bcd_unit);
    end process;

end behavioral;
