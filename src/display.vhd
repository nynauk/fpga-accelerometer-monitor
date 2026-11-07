----------------------------------------------------------------------------------
-- Module: display
-- Description: Top-level module for Stage 1. Instantiates all sub-modules
--              using structural design style to display a 12-bit signed
--              two's complement number on the 7-segment display.
--              SW15 selects between switch input (SW11-SW0) and accelerometer.
--              The system diagram:
--              switches/accel -> bin2BCD -> MUX -> bin2seg -> 7seg cathodes
--              clock -> counter -> DAnC -> 7seg anodes
--                                counter -> MUX (select)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity display is
generic (
    SYSCLK_FREQUENCY_HZ : integer := 100000000
);
port (
    clk       : in  STD_LOGIC;
    reset     : in  STD_LOGIC;
    data_in   : in  STD_LOGIC_VECTOR (11 downto 0);
    seg       : out STD_LOGIC_VECTOR (6 downto 0);
    an        : out STD_LOGIC_VECTOR (7 downto 0)
);
end display;

architecture structural of display is

    -- Component declarations
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

    component clock is
    generic (
        SYSCLK_FREQUENCY_HZ : integer := 100000000;
        SCAN_FREQUENCY_HZ   : integer := 5000
    );
    port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        clk_out  : out STD_LOGIC
    );
    end component;

    component counter is
    port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        enable   : in  STD_LOGIC;
        count    : out STD_LOGIC_VECTOR (2 downto 0)
    );
    end component;

    component mux is
    port (
        sel       : in  STD_LOGIC_VECTOR (2 downto 0);
        sign_in   : in  STD_LOGIC;
        thousands : in  STD_LOGIC_VECTOR (3 downto 0);
        hundreds  : in  STD_LOGIC_VECTOR (3 downto 0);
        tens      : in  STD_LOGIC_VECTOR (3 downto 0);
        unit      : in  STD_LOGIC_VECTOR (3 downto 0);
        bcd_out   : out STD_LOGIC_VECTOR (3 downto 0)
    );
    end component;

    component bin2seg is
    port (
        bcd_in  : in  STD_LOGIC_VECTOR (3 downto 0);
        seg_out : out STD_LOGIC_VECTOR (6 downto 0)
    );
    end component;

    component DAnC is
    port (
        sel    : in  STD_LOGIC_VECTOR (2 downto 0);
        an_out : out STD_LOGIC_VECTOR (7 downto 0)
    );
    end component;

    -- Internal signals
    signal sign_sig      : STD_LOGIC;
    signal thou_sig      : STD_LOGIC_VECTOR (3 downto 0);
    signal hund_sig      : STD_LOGIC_VECTOR (3 downto 0);
    signal tens_sig      : STD_LOGIC_VECTOR (3 downto 0);
    signal unit_sig      : STD_LOGIC_VECTOR (3 downto 0);
    signal scan_tick     : STD_LOGIC;
    signal cnt_sig       : STD_LOGIC_VECTOR (2 downto 0);
    signal mux_out_sig   : STD_LOGIC_VECTOR (3 downto 0);

begin

    -- Binary to BCD converter
    BCD_CONV: bin2BCD
    port map (
        bin_in    => data_in,
        sign_out  => sign_sig,
        thousands => thou_sig,
        hundreds  => hund_sig,
        tens      => tens_sig,
        unit      => unit_sig
    );

    -- Clock divider for scanning
    CLK_DIV: clock
    generic map (
        SYSCLK_FREQUENCY_HZ => SYSCLK_FREQUENCY_HZ,
        SCAN_FREQUENCY_HZ   => 5000
    )
    port map (
        clk     => clk,
        reset   => reset,
        clk_out => scan_tick
    );

    -- Digit selection counter
    DIGIT_CNT: counter
    port map (
        clk    => clk,
        reset  => reset,
        enable => scan_tick,
        count  => cnt_sig
    );

    -- BCD value multiplexer
    BCD_MUX: mux
    port map (
        sel       => cnt_sig,
        sign_in   => sign_sig,
        thousands => thou_sig,
        hundreds  => hund_sig,
        tens      => tens_sig,
        unit      => unit_sig,
        bcd_out   => mux_out_sig
    );

    -- BCD to 7-segment converter
    SEG_CONV: bin2seg
    port map (
        bcd_in  => mux_out_sig,
        seg_out => seg
    );

    -- Anode controller
    ANODE_CTRL: DAnC
    port map (
        sel    => cnt_sig,
        an_out => an
    );

end structural;
