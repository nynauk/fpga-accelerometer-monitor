----------------------------------------------------------------------------------
-- Testbench: bin2BCD_tb
-- Description: Comprehensive testbench for the bin2BCD module.
--              Tests positive values, negative values, zero, boundary values,
--              and all-ones input. Uses assert/report for automated verification.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.textio.ALL;
use IEEE.std_logic_textio.ALL;

entity bin2BCD_tb is
end bin2BCD_tb;

architecture testbench of bin2BCD_tb is

    -- Component declaration
    component bin2BCD is
    port (
        bin_in    : in  STD_LOGIC_VECTOR (11 downto 0);
        sign_out  : out STD_LOGIC;
        thousands : out STD_LOGIC_VECTOR (3 downto 0);
        hundreds  : out STD_LOGIC_VECTOR (3 downto 0);
        tens      : out STD_LOGIC_VECTOR (3 downto 0);
        unit      : out STD_LOGIC_VECTOR (3 downto 0)
    );
    end component;

    -- Testbench signals
    signal bin_in_tb    : STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    signal sign_out_tb  : STD_LOGIC;
    signal thousands_tb : STD_LOGIC_VECTOR (3 downto 0);
    signal hundreds_tb  : STD_LOGIC_VECTOR (3 downto 0);
    signal tens_tb      : STD_LOGIC_VECTOR (3 downto 0);
    signal unit_tb      : STD_LOGIC_VECTOR (3 downto 0);

    -- Error counter
    signal error_count  : integer := 0;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: bin2BCD
    port map (
        bin_in    => bin_in_tb,
        sign_out  => sign_out_tb,
        thousands => thousands_tb,
        hundreds  => hundreds_tb,
        tens      => tens_tb,
        unit      => unit_tb
    );

    -- Stimulus and verification process
    stim_proc: process
        variable s : line;
        variable abs_val      : integer;
        variable exp_sign     : STD_LOGIC;
        variable exp_thou     : integer;
        variable exp_hund     : integer;
        variable exp_tens     : integer;
        variable exp_unit     : integer;
        variable actual_thou  : integer;
        variable actual_hund  : integer;
        variable actual_tens  : integer;
        variable actual_unit  : integer;
        variable test_val     : integer;
        variable err_cnt      : integer := 0;
    begin
        write(s, string'("=== bin2BCD Testbench Start ==="));
        writeline(output, s);

        -- Test a comprehensive set of values
        -- Positive values: 0, 1, 9, 10, 99, 100, 999, 1000, 2047
        -- Negative values: -1, -9, -10, -99, -100, -999, -1000, -2048
        -- Boundary values and specific patterns

        -- Loop through selected test values
        for i in 0 to 19 loop
            case i is
                when 0  => test_val := 0;
                when 1  => test_val := 1;
                when 2  => test_val := 9;
                when 3  => test_val := 10;
                when 4  => test_val := 99;
                when 5  => test_val := 100;
                when 6  => test_val := 123;
                when 7  => test_val := 456;
                when 8  => test_val := 999;
                when 9  => test_val := 1000;
                when 10 => test_val := 2047;
                when 11 => test_val := -1;
                when 12 => test_val := -9;
                when 13 => test_val := -10;
                when 14 => test_val := -99;
                when 15 => test_val := -100;
                when 16 => test_val := -123;
                when 17 => test_val := -999;
                when 18 => test_val := -1000;
                when 19 => test_val := -2048;
                when others => test_val := 0;
            end case;

            -- Apply input
            bin_in_tb <= STD_LOGIC_VECTOR(to_signed(test_val, 12));
            wait for 10 ns;

            -- Calculate expected values
            if test_val < 0 then
                exp_sign := '1';
                abs_val := -test_val;
            else
                exp_sign := '0';
                abs_val := test_val;
            end if;

            exp_thou := abs_val / 1000;
            exp_hund := (abs_val mod 1000) / 100;
            exp_tens := (abs_val mod 100) / 10;
            exp_unit := abs_val mod 10;

            -- Read actual values
            actual_thou := to_integer(unsigned(thousands_tb));
            actual_hund := to_integer(unsigned(hundreds_tb));
            actual_tens := to_integer(unsigned(tens_tb));
            actual_unit := to_integer(unsigned(unit_tb));

            -- Verify sign
            assert (sign_out_tb = exp_sign)
                report "SIGN ERROR at value " & integer'image(test_val) &
                       ": expected " & STD_LOGIC'image(exp_sign) &
                       " got " & STD_LOGIC'image(sign_out_tb)
                severity ERROR;

            -- Verify BCD digits
            if (actual_thou /= exp_thou) or (actual_hund /= exp_hund) or
               (actual_tens /= exp_tens) or (actual_unit /= exp_unit) then
                err_cnt := err_cnt + 1;
                write(s, string'("FAIL: input = "));
                write(s, test_val);
                write(s, string'(" expected = "));
                write(s, exp_thou);
                write(s, exp_hund);
                write(s, exp_tens);
                write(s, exp_unit);
                write(s, string'(" got = "));
                write(s, actual_thou);
                write(s, actual_hund);
                write(s, actual_tens);
                write(s, actual_unit);
                writeline(output, s);
            else
                write(s, string'("PASS: input = "));
                write(s, test_val);
                write(s, string'(" -> "));
                if exp_sign = '1' then
                    write(s, string'("-"));
                end if;
                write(s, exp_thou);
                write(s, exp_hund);
                write(s, exp_tens);
                write(s, exp_unit);
                writeline(output, s);
            end if;
        end loop;

        -- Additional exhaustive test: sweep through a range of values
        write(s, string'("=== Exhaustive sweep from -2048 to 2047 ==="));
        writeline(output, s);

        for val in -2048 to 2047 loop
            bin_in_tb <= STD_LOGIC_VECTOR(to_signed(val, 12));
            wait for 5 ns;

            if val < 0 then
                abs_val := -val;
            else
                abs_val := val;
            end if;

            exp_thou := abs_val / 1000;
            exp_hund := (abs_val mod 1000) / 100;
            exp_tens := (abs_val mod 100) / 10;
            exp_unit := abs_val mod 10;

            actual_thou := to_integer(unsigned(thousands_tb));
            actual_hund := to_integer(unsigned(hundreds_tb));
            actual_tens := to_integer(unsigned(tens_tb));
            actual_unit := to_integer(unsigned(unit_tb));

            if (actual_thou /= exp_thou) or (actual_hund /= exp_hund) or
               (actual_tens /= exp_tens) or (actual_unit /= exp_unit) then
                err_cnt := err_cnt + 1;
                assert false
                    report "FAIL at value " & integer'image(val)
                    severity ERROR;
            end if;
        end loop;

        -- Summary
        write(s, string'("=== bin2BCD Testbench Complete ==="));
        writeline(output, s);

        if err_cnt = 0 then
            write(s, string'("ALL TESTS PASSED - No errors found"));
            writeline(output, s);
            assert false
                report "Simulation complete: ALL TESTS PASSED"
                severity NOTE;
        else
            write(s, string'("TESTS FAILED - Error count: "));
            write(s, err_cnt);
            writeline(output, s);
            assert false
                report "Simulation complete: ERRORS FOUND"
                severity FAILURE;
        end if;

        wait;
    end process stim_proc;

end testbench;
