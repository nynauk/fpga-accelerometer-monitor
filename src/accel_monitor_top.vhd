----------------------------------------------------------------------------------
-- Module: accel_monitor_top
-- Description: Top-level module for the Accelerometer-based Monitor.
--              Stage 1: When SW15 is ON, displays the 12-bit signed value
--                       set by switches SW11-SW0 on the 7-segment display.
--              Stage 2a: When SW15 is OFF, reads acceleration from ADXL362
--                        sensor (averaged over 32 samples). SW14:SW13 select
--                        which axis to display: "00"=X, "01"=Y, "10"=Z.
--              Stage 2b: RGB LED colour depends on board orientation
--                        (average X, Y, Z acceleration values).
--              Stage 2c: When SW14:SW13 = "11", displays X_acc in mg
--                        (range +/-2g, 1mg/LSB at 12-bit, 2g range).
--
--              Target: XC7A100T-1CSG324C (Nexys A7)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity accel_monitor_top is
generic (
    SYSCLK_FREQUENCY_HZ : integer := 100000000;
    SCLK_FREQUENCY_HZ   : integer := 1000000;
    NUM_READS_AVG        : integer := 32;
    UPDATE_FREQUENCY_HZ  : integer := 100
);
port (
    -- System
    CLK100MHZ : in  STD_LOGIC;
    RESET     : in  STD_LOGIC;  -- active high reset (BTNC)

    -- Switches
    SW        : in  STD_LOGIC_VECTOR (15 downto 0);

    -- 7-Segment Display
    SEG       : out STD_LOGIC_VECTOR (6 downto 0);
    AN        : out STD_LOGIC_VECTOR (7 downto 0);

    -- SPI Interface to Accelerometer
    ACL_SCLK  : out STD_LOGIC;
    ACL_MOSI  : out STD_LOGIC;
    ACL_MISO  : in  STD_LOGIC;
    ACL_CSN   : out STD_LOGIC;

    -- Normal User LEDs
    LED       : out STD_LOGIC_VECTOR (15 downto 0);

    -- RGB LEDs (accent LEDs on Nexys A7)
    LED16_R   : out STD_LOGIC;
    LED16_G   : out STD_LOGIC;
    LED16_B   : out STD_LOGIC;
    LED17_R   : out STD_LOGIC;
    LED17_G   : out STD_LOGIC;
    LED17_B   : out STD_LOGIC
);
end accel_monitor_top;

architecture structural of accel_monitor_top is

    -- Component declarations
    component ACC_XYZ is
    generic (
        SYSCLK_FREQUENCY_HZ : integer := 100000000;
        SCLK_FREQUENCY_HZ   : integer := 1000000;
        NUM_READS_AVG        : integer := 16;
        UPDATE_FREQUENCY_HZ  : integer := 100
    );
    port (
        SYSCLK      : in  STD_LOGIC;
        RESET       : in  STD_LOGIC;
        SCLK        : out STD_LOGIC;
        MOSI        : out STD_LOGIC;
        MISO        : in  STD_LOGIC;
        SS          : out STD_LOGIC;
        ACCEL_X_OUT : out STD_LOGIC_VECTOR (11 downto 0);
        ACCEL_Y_OUT : out STD_LOGIC_VECTOR (11 downto 0);
        ACCEL_Z_OUT : out STD_LOGIC_VECTOR (11 downto 0);
        ACCEL_TMP_OUT : out STD_LOGIC_VECTOR (11 downto 0)
    );
    end component;

    component display is
    generic (
        SYSCLK_FREQUENCY_HZ : integer := 100000000
    );
    port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        data_in  : in  STD_LOGIC_VECTOR (11 downto 0);
        seg      : out STD_LOGIC_VECTOR (6 downto 0);
        an       : out STD_LOGIC_VECTOR (7 downto 0)
    );
    end component;

    -- Internal signals
    signal accel_x     : STD_LOGIC_VECTOR (11 downto 0);
    signal accel_y     : STD_LOGIC_VECTOR (11 downto 0);
    signal accel_z     : STD_LOGIC_VECTOR (11 downto 0);
    signal accel_tmp   : STD_LOGIC_VECTOR (11 downto 0);

    signal data_to_display : STD_LOGIC_VECTOR (11 downto 0);
    signal sw_data         : STD_LOGIC_VECTOR (11 downto 0);
    signal accel_sel       : STD_LOGIC_VECTOR (1 downto 0);

    -- For mg conversion: ADXL362 at 2g range, 12-bit output
    -- Sensitivity = 1 mg/LSB (per ADXL362 datasheet at 2g range)
    -- So the raw 12-bit value IS already in mg
    signal accel_x_mg  : STD_LOGIC_VECTOR (11 downto 0);

    -- RGB LED signals
    signal x_val_signed : signed(11 downto 0);
    signal y_val_signed : signed(11 downto 0);
    signal z_val_signed : signed(11 downto 0);

begin

    -- Accelerometer controller instantiation (Stage 2a)
    ACCEL_CTRL: ACC_XYZ
    generic map (
        SYSCLK_FREQUENCY_HZ => SYSCLK_FREQUENCY_HZ,
        SCLK_FREQUENCY_HZ   => SCLK_FREQUENCY_HZ,
        NUM_READS_AVG        => NUM_READS_AVG,
        UPDATE_FREQUENCY_HZ  => UPDATE_FREQUENCY_HZ
    )
    port map (
        SYSCLK      => CLK100MHZ,
        RESET       => RESET,
        SCLK        => ACL_SCLK,
        MOSI        => ACL_MOSI,
        MISO        => ACL_MISO,
        SS          => ACL_CSN,
        ACCEL_X_OUT => accel_x,
        ACCEL_Y_OUT => accel_y,
        ACCEL_Z_OUT => accel_z,
        ACCEL_TMP_OUT => accel_tmp
    );

    -- Mirror switches to user LEDs
    LED <= SW;

    -- Stage 1a: Switch input selection
    sw_data <= SW(11 downto 0);
    accel_sel <= SW(14 downto 13);

    -- Stage 2c: X acceleration in mg
    -- At 2g range, ADXL362 sensitivity is 1 mg/LSB
    -- The raw 12-bit signed value is already in mg
    accel_x_mg <= accel_x;

    -- Data source selection (Stage 1a + Stage 2a + Stage 2c)
    -- SW15 = '1': display switch value
    -- SW15 = '0': display accelerometer value based on SW14:SW13
    process (SW, sw_data, accel_x, accel_y, accel_z, accel_x_mg, accel_sel)
    begin
        if SW(15) = '1' then
            -- Stage 1a: Display switch value
            data_to_display <= sw_data;
        else
            -- Stage 2a: Display accelerometer value
            case accel_sel is
                when "00"   => data_to_display <= accel_x;     -- X axis
                when "01"   => data_to_display <= accel_y;     -- Y axis
                when "10"   => data_to_display <= accel_z;     -- Z axis
                when "11"   => data_to_display <= accel_x_mg;  -- X in mg (Stage 2c)
                when others => data_to_display <= accel_x;
            end case;
        end if;
    end process;

    -- Display module instantiation (Stage 1e)
    DISP: display
    generic map (
        SYSCLK_FREQUENCY_HZ => SYSCLK_FREQUENCY_HZ
    )
    port map (
        clk     => CLK100MHZ,
        reset   => RESET,
        data_in => data_to_display,
        seg     => SEG,
        an      => AN
    );

    -- Stage 2b: RGB LED colour based on board orientation
    x_val_signed <= signed(accel_x);
    y_val_signed <= signed(accel_y);
    z_val_signed <= signed(accel_z);

    -- Stage 2b: RGB LED orientation using LED16 only
    -- LED16_R: X axis tilt detected (tilted left or right)
    -- LED16_G: board flat face-up (Z acceleration near +1g)
    -- LED16_B: Y axis tilt detected (tilted forward or backward)
    -- Colour mixing gives intuitive feedback:
    --   Green        = flat
    --   Red          = tilted left/right
    --   Blue         = tilted forward/backward
    --   Yellow (R+G) = slight X tilt while mostly flat
    --   Cyan (G+B)   = slight Y tilt while mostly flat
    --   Purple (R+B) = tilted diagonally
    --   Off          = upside down
    process (x_val_signed, y_val_signed, z_val_signed)
    begin
        -- Red: X axis tilt
        if x_val_signed > 100 or x_val_signed < -100 then
            LED16_R <= '1';
        else
            LED16_R <= '0';
        end if;

        -- Green: board flat face-up (Z near +1g, threshold 800)
        if z_val_signed > 800 then
            LED16_G <= '1';
        else
            LED16_G <= '0';
        end if;

        -- Blue: Y axis tilt
        if y_val_signed > 100 or y_val_signed < -100 then
            LED16_B <= '1';
        else
            LED16_B <= '0';
        end if;
    end process;

    -- LED17 not used for orientation, drive off
    LED17_R <= '0';
    LED17_G <= '0';
    LED17_B <= '0';

end structural;
