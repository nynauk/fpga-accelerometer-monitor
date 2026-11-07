----------------------------------------------------------------------------------
-- Description: 
--       This module represents the controller for the Nexys4 onboard ADXL362 Accelerometer device.
--    The module uses the SPI Interface component to communicate with the ADXL362.
--    At initialization time, the module resets the ADXL362, then configures its internal registers.
--       After configuring its internal registers, the acceleration will be read on the three axes followed 
--    by the temperature data: A set of 8 data bytes are read: XDATA_L, XDATA_H, YDATA_L, YDATA_H, ZDATA_L,
--    ZDATA_H, TEMP_L and TEMP_H, see the ADXL362 datasheet for details.
--       Reading is done continuously and an average is made from a number of reads. The number of reads 
--    for which average is made should be a power of two and is determined by the NUM_READS_AVG parameter,
--    by default 16. The UPDATE_FREQUENCY_HZ parameter sets a counter to a period of 1/UPDATE_FREQUENCY_HZ.
--    The state machine will wait for this period of time before starting a number of NUM_READS_AVG times 
--    data read procedure.
--       Before reading a set of data, the state machine reads and checks the status register to see when
--    new data is available at the ADXL362. Therefore the real sample time depends on the ADXL362 sample 
--    frequency, set in the Filter Control Register, address 0x2C, in this project set by default to 200Hz.
--
--       The module consists of three state machines, named by the signals holding the states:
--       - SPI Send/Receive Control State Machine: StC_Spi_SendRec. This state machine creates a handshake transaction
--    with the SPI Interface component, using the Start and Done signals to:
--             - Send the number of bytes specified by the Cnt_Bytes_Sent counter (3 when configuring an ADXL362 internal
--          register, 2 when sending a Read Command). The bytes to be sent through the SPI interface are taken from the 
--          command register, Cmd_Reg.
--             - Receive the number of bytes specified by the Cnt_Bytes_Rec counter (8 when reading acceleration and 
--          temperature data, 1 when reading the status register), when reading is required (SPI_RnW = 1).
--          The acceleration and temperature data is stored in the data register, Data_Reg
--
--       - SPI Transaction State machine, StC_Spi_Trans. This state machine controls the previously described SPI 
--    Send/Receive Control State Machine, using handshake with the the StartSpiSendRec (write) and SPI_SendRec_Done (read)
--    signals:
--            - Prepares and loads the command register, Cmd_Reg with the appropiate command string (configure a specific 
--          register, read data or read status)
--            - Loads Cnt_Bytes_Sent and Cnt_Bytes_Rec with the number of bytes to be sent and/or received
--            - Activates StartSpiSendRec to start the SPI Send/Receive Control State Machine and wait for its answer 
--          by reading the SPI_SendRec_Done signal
--
--          Note that between each SPI transaction (Register write or Register read) the SS signal has to be deactivated
--          for at least 10nS before a new command is issued
--
--       - ADXL 362 Control State Machine, StC_Adxl_Ctrl. This state machine controls the previously described SPI 
--    Transaction State machine, also by using handshake with the StartSpiTr (write) and SPI_Trans_Done (read) signals:
--            1. First, Cmd_Reg will be loaded with the reset command from the Cmd_Reg_Data ROM and the state machine starts 
--          the SPI Transaction State Machine to send the reset command to the ADXL362 accelerometer
--            2. The state machine waits for a period of time and then sends the remaining configuration register data from 
--          Cmd_Reg_Data to the ADXL362 accelerometer
--            3. After configuring ADXL362, the state machine waits for a period of time equal to 1/UPDATE_FREQUENCY_HZ 
--          before starts reading
--            4. After the period of time elapsed the state machine reads the status register and, when there is new data available, reads the 
--          reads the X, Y and Z acceleration data, followed by temperature data.
--               A number of reads equal to NUM_READS_AVG is performed, i.e. Step 4 is repeated NUM_READS_AVG times.
--            5. The data read is averaged in the ACCEL_X_SUM, ACCEL_Y_SUM, ACCEL_Z_SUM and ACCEL_TMP_SUM registers. The
--          NUM_READS_AVG is power of 2 in order to make averaging easier by removing the least significant bits. After 
--          a number of reads equal to NUM_READS_AVG is done, the state machine updates the output data, ACCEL_X, ACCEL_Y,
--          ACCEL_Z and ACCEL_TMP, stored in 12-bit two's complement format and signals to the output by activating for one
--          clock period the Data_Ready signal.
--               After that the state machine proceeds to Step 3, in an infinite loop. The state machine restarts from Step 1 only
--          when the FPGA is reconfigured or the Reset signal is activated.
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity ADXL362Ctrl is
generic 
(
   SYSCLK_FREQUENCY_HZ : integer := 100000000;
   SCLK_FREQUENCY_HZ   : integer := 1000000;
   NUM_READS_AVG       : integer := 16;
   UPDATE_FREQUENCY_HZ : integer := 1000
);
port
(
   SYSCLK     : in STD_LOGIC;
   RESET      : in STD_LOGIC;
   ACCEL_X    : out STD_LOGIC_VECTOR (11 downto 0);
   ACCEL_Y    : out STD_LOGIC_VECTOR (11 downto 0);
   ACCEL_Z    : out STD_LOGIC_VECTOR (11 downto 0);
   ACCEL_TMP  : out STD_LOGIC_VECTOR (11 downto 0);
   Data_Ready : out STD_LOGIC;
   SCLK       : out STD_LOGIC;
   MOSI       : out STD_LOGIC;
   MISO       : in STD_LOGIC;
   SS         : out STD_LOGIC
);
end ADXL362Ctrl;

architecture Behavioral of ADXL362Ctrl is

component SPI_If is
generic 
(
   SYSCLK_FREQUENCY_HZ : integer:= 100000000;
   SCLK_FREQUENCY_HZ : integer:= 1000000
);
port
(
 SYSCLK     : in STD_LOGIC;
 RESET      : in STD_LOGIC;
 Din        : in STD_LOGIC_VECTOR (7 downto 0);
 Dout       : out STD_LOGIC_VECTOR (7 downto 0);
 Start      : in STD_LOGIC;
 Done       : out STD_LOGIC;
 HOLD_SS   : in STD_LOGIC;
 SCLK       : out STD_LOGIC;
 MOSI       : out STD_LOGIC;
 MISO       : in STD_LOGIC;
 SS         : out STD_LOGIC
);
end component;

constant UPDATE_DIV_RATE : integer := (SYSCLK_FREQUENCY_HZ / UPDATE_FREQUENCY_HZ);
constant SYS_CLK_PERIOD_PS : integer := ((1000000000 / SYSCLK_FREQUENCY_HZ) * 1000);
constant READ_CMD : STD_LOGIC_VECTOR (7 downto 0) := X"0B";
constant WRITE_CMD : STD_LOGIC_VECTOR (7 downto 0) := X"0A";
constant READ_STARTING_ADDR : STD_LOGIC_VECTOR (7 downto 0):= X"0E";
constant STATUS_REG_ADDR : STD_LOGIC_VECTOR (7 downto 0):= X"0B";
constant NUMBYTES_CMD_CONFIG_REG : integer := 3;
constant NUMBYTES_CMD_READ : integer := 2;
constant NUMBYTES_READ_DATA : integer := 8;
constant NUMBYTES_READ_STATUS : integer := 1;
constant NUM_COMMAND_VEC : integer := 4;
constant NUM_READS : natural := NUM_READS_AVG;
constant NUM_READS_BITS : natural := natural(ceil(log(real(NUM_READS), 2.0)));
constant SS_INACTIVE_PERIOD_NS : integer := 10000;
constant SS_INACTIVE_CLOCKS   : integer := (SS_INACTIVE_PERIOD_NS/(SYS_CLK_PERIOD_PS/1000));

attribute FSM_ENCODING : string;

signal Start      :  STD_LOGIC;
signal Done       :  STD_LOGIC;
signal HOLD_SS    :  STD_LOGIC;

type rom_type is array (0 to ((2* NUM_COMMAND_VEC)-1)) of STD_LOGIC_VECTOR (7 downto 0);

constant Cmd_Reg_Data : rom_type := ( X"1F", X"52",
                                      X"1F", X"00",
                                      X"2D", X"02",
                                      X"2C", X"14"
                                     );

signal Cmd_Reg_Data_Addr: integer range 0 to (NUM_COMMAND_VEC - 1) := 0;
signal EN_Advance_Cmd_Reg_Addr:  STD_LOGIC := '0';
signal Advance_Cmd_Reg_Addr:  STD_LOGIC := '0';
signal Cmd_Reg_Addr_Done : STD_LOGIC := '0';

type command_reg_type is array (0 to 2) of STD_LOGIC_VECTOR (7 downto 0);
signal Cmd_Reg: command_reg_type := (X"00", X"00", WRITE_CMD);

signal Load_Cmd_Reg : STD_LOGIC := '0';
signal Shift_Cmd_Reg : STD_LOGIC := '0';
signal Cnt_Bytes_Sent : integer range 0 to 3 :=0;
signal Load_Cnt_Bytes_Sent : STD_LOGIC := '0';
signal Reset_Cnt_Bytes : STD_LOGIC := '0';

type data_reg_type is array (0 to (NUMBYTES_READ_DATA - 1)) of STD_LOGIC_VECTOR (7 downto 0);
signal Data_Reg: data_reg_type := (others => X"00");

signal EN_Shift_Data_Reg : STD_LOGIC := '0';
signal Shift_Data_Reg : STD_LOGIC := '0';
signal Cnt_Bytes_Rec : integer range 0 to NUMBYTES_READ_DATA - 1 := 0;
signal Load_Cnt_Bytes_Rec : STD_LOGIC := '0';

signal D_Send   : STD_LOGIC_VECTOR (7 downto 0) := X"00";
signal D_Rec   : STD_LOGIC_VECTOR (7 downto 0) := X"00";

signal StartSpiSendRec  : STD_LOGIC := '0';
signal SPI_RnW  : STD_LOGIC := '0';
signal SPI_WR_Done   : STD_LOGIC := '0';
signal SPI_RD_Done   : STD_LOGIC := '0';
signal SPI_SendRec_Done  : STD_LOGIC := '0';

constant stSpiSendRecIdle     : STD_LOGIC_VECTOR (6 downto 0) := "0000000";
constant stSpiPrepareCmd      : STD_LOGIC_VECTOR (6 downto 0) := "1000001";
constant stSpiSendStartW      : STD_LOGIC_VECTOR (6 downto 0) := "0001011";
constant stSpiWaitOnDoneW     : STD_LOGIC_VECTOR (6 downto 0) := "0000111";
constant stSpiSendStartR      : STD_LOGIC_VECTOR (6 downto 0) := "0001110";
constant stSpiWaitOnDoneR     : STD_LOGIC_VECTOR (6 downto 0) := "0100100";
constant stSpiSendRecDone     : STD_LOGIC_VECTOR (6 downto 0) := "0010101";

signal StC_Spi_SendRec, StN_Spi_SendRec   :  STD_LOGIC_VECTOR (6 downto 0) := stSpiSendRecIdle;
attribute FSM_ENCODING of StC_Spi_SendRec: signal is "USER";

signal Cnt_SS_Inactive : integer range 0 to (SS_INACTIVE_CLOCKS -1) := 0;
signal Reset_Cnt_SS_Inactive : STD_LOGIC := '0';
signal Cnt_SS_Inactive_done : STD_LOGIC := '0';

signal SPI_Trans_Done   : STD_LOGIC := '0';
signal StartSpiTr  : STD_LOGIC := '0';

constant stSpiTransIdle       : STD_LOGIC_VECTOR (9 downto 0) := "0000000000";
constant stSpiPrepAndSendCmd  : STD_LOGIC_VECTOR (9 downto 0) := "1111100001";
constant stSpiWaitonDoneSR    : STD_LOGIC_VECTOR (9 downto 0) := "0000110011";
constant stSpiWaitForSsInact  : STD_LOGIC_VECTOR (9 downto 0) := "0000000010";
constant stSpiTransDone       : STD_LOGIC_VECTOR (9 downto 0) := "0000001110";

signal StC_Spi_Trans, StN_Spi_Trans : STD_LOGIC_VECTOR (9 downto 0) := stSpiTransIdle;
attribute FSM_ENCODING of StC_Spi_Trans: signal is "USER";

signal Sample_Rate_Div        : integer range 0 to (UPDATE_DIV_RATE - 1) := 0;
signal Reset_Sample_Rate_Div  : STD_LOGIC := '0';
signal Sample_Rate_Tick       : STD_LOGIC := '0';

signal Cnt_Num_Reads : integer range 0 to (NUM_READS - 1) := 0;
signal CE_Cnt_Num_Reads : STD_LOGIC := '0';
signal Reset_Cnt_Num_Reads : STD_LOGIC := '0';
signal Cnt_Num_Reads_Done : STD_LOGIC := '0';

signal ACCEL_X_SUM   : STD_LOGIC_VECTOR ((11 + (NUM_READS_BITS)) downto 0) := (others => '0');
signal ACCEL_Y_SUM   : STD_LOGIC_VECTOR ((11 + (NUM_READS_BITS)) downto 0) := (others => '0');
signal ACCEL_Z_SUM   : STD_LOGIC_VECTOR ((11 + (NUM_READS_BITS)) downto 0) := (others => '0');
signal ACCEL_TMP_SUM : STD_LOGIC_VECTOR ((11 + (NUM_READS_BITS)) downto 0) := (others => '0');
signal Enable_Sum : STD_LOGIC := '0';
signal Data_Ready_1 : STD_LOGIC := '0';
signal Adxl_Data_Ready : STD_LOGIC := '0';
signal Adxl_Conf_Err : STD_LOGIC := '0';

constant stAdxlCtrlIdle            : STD_LOGIC_VECTOR (11 downto 0) := "100100000000";
constant stAdxlSendResetCmd        : STD_LOGIC_VECTOR (11 downto 0) := "011001000001";
constant stAdxlWaitResetDone       : STD_LOGIC_VECTOR (11 downto 0) := "010000000011";
constant stAdxlConf_Remaining      : STD_LOGIC_VECTOR (11 downto 0) := "011001000010";
constant stAdxlWaitSampleRateTick  : STD_LOGIC_VECTOR (11 downto 0) := "000100000110";
constant stAdxlRead_Status         : STD_LOGIC_VECTOR (11 downto 0) := "011001000111";
constant stAdxlRead_Data           : STD_LOGIC_VECTOR (11 downto 0) := "011000000101";
constant stAdxlFormatandSum        : STD_LOGIC_VECTOR (11 downto 0) := "000010101101";
constant stAdxlRead_Done           : STD_LOGIC_VECTOR (11 downto 0) := "000001011111";

signal StC_Adxl_Ctrl, StN_Adxl_Ctrl : STD_LOGIC_VECTOR (11 downto 0) := stAdxlCtrlIdle;
attribute FSM_ENCODING of StC_Adxl_Ctrl: signal is "USER";

begin

SPI_Interface: SPI_If
generic map 
(
   SYSCLK_FREQUENCY_HZ => SYSCLK_FREQUENCY_HZ,
   SCLK_FREQUENCY_HZ => SCLK_FREQUENCY_HZ
)
port map
(
 SYSCLK => SYSCLK,  
 RESET  => RESET,
 Din    => D_Send,
 Dout   => D_Rec,
 Start  => Start,
 Done   => Done,
 HOLD_SS => HOLD_SS,
 SCLK  => SCLK,
 MOSI  => MOSI,
 MISO  => MISO,
 SS    => SS
);

Shift_Cmd_Reg     <= StC_Spi_SendRec(6);
EN_Shift_Data_Reg <= StC_Spi_SendRec(5);
SPI_SendRec_Done  <= StC_Spi_SendRec(4);
Start             <= StC_Spi_SendRec(3);

Load_D_Send: process (SYSCLK, RESET, Cmd_Reg, Shift_Cmd_Reg)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if RESET = '1' then
         D_Send <= X"00";
      elsif Shift_Cmd_Reg = '1' then
         D_Send <= Cmd_Reg (2);
      end if;
   end if;
end process Load_D_Send;

Load_Cmd_Reg          <= StC_Spi_Trans(9);
Load_Cnt_Bytes_Sent   <= StC_Spi_Trans(8);
Load_Cnt_Bytes_Rec    <= StC_Spi_Trans(7);
StartSpiSendRec       <= StC_Spi_Trans(6);
HOLD_SS               <= StC_Spi_Trans(5);
Reset_Cnt_SS_Inactive <= StC_Spi_Trans(4);
SPI_Trans_Done        <= StC_Spi_Trans(3);

Reset_Cnt_Bytes         <= StC_Adxl_Ctrl(11);
EN_Advance_Cmd_Reg_Addr <= StC_Adxl_Ctrl(10);
StartSpiTr              <= StC_Adxl_Ctrl(9);
Reset_Cnt_Num_Reads     <= StC_Adxl_Ctrl(8);
CE_Cnt_Num_Reads        <= StC_Adxl_Ctrl(7);
Reset_Sample_Rate_Div   <= StC_Adxl_Ctrl(6);
Enable_Sum              <= StC_Adxl_Ctrl(5);
Data_Ready_1            <= StC_Adxl_Ctrl(4);

Load_Shift_Cmd_Reg: process (SYSCLK, Cmd_Reg, Cmd_Reg_Data_Addr, StC_Adxl_Ctrl, Load_Cmd_Reg, Shift_Cmd_Reg)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Load_Cmd_Reg = '1' then
         if       (StC_Adxl_Ctrl = stAdxlSendResetCmd) 
               or (StC_Adxl_Ctrl = stAdxlConf_Remaining) then
                  Cmd_Reg(2) <= WRITE_CMD;
                  Cmd_Reg(1) <= Cmd_Reg_Data (2 * Cmd_Reg_Data_Addr);
                  Cmd_Reg(0) <= Cmd_Reg_Data ((2 * Cmd_Reg_Data_Addr) + 1);
         elsif    (StC_Adxl_Ctrl = stAdxlRead_Status) then
                  Cmd_Reg(2) <= READ_CMD;
                  Cmd_Reg(1) <= STATUS_REG_ADDR;
                  Cmd_Reg(0) <= X"00";
         elsif (StC_Adxl_Ctrl = stAdxlRead_Data) then
                  Cmd_Reg(2) <= READ_CMD;
                  Cmd_Reg(1) <= READ_STARTING_ADDR;
                  Cmd_Reg(0) <= X"00";
         end if;
      elsif Shift_Cmd_Reg = '1' then
                  Cmd_Reg(2) <= Cmd_Reg(1);
                  Cmd_Reg(1) <= Cmd_Reg(0);
                  Cmd_Reg(0) <= X"00";
      end if;
   end if;
end process Load_Shift_Cmd_Reg;

Advance_Cmd_Reg_Addr <= EN_Advance_Cmd_Reg_Addr AND SPI_Trans_Done;

Count_Addr: process (SYSCLK, RESET, Cmd_Reg_Data_Addr, StC_Adxl_Ctrl, Advance_Cmd_Reg_Addr)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if RESET = '1'  or StC_Adxl_Ctrl = stAdxlCtrlIdle then
         Cmd_Reg_Data_Addr <= 0;
      elsif Advance_Cmd_Reg_Addr = '1' then
         if Cmd_Reg_Data_Addr =  (NUM_COMMAND_VEC - 1) then
            Cmd_Reg_Data_Addr <= 0;
         else
            Cmd_Reg_Data_Addr <= Cmd_Reg_Data_Addr + 1;
         end if;
      end if;
   end if;
end process Count_Addr;

Cmd_Reg_Addr_Done <= '1' when Cmd_Reg_Data_Addr = (NUM_COMMAND_VEC - 1) else '0';

Shift_Data_Reg <= EN_Shift_Data_Reg AND Done;

Read_Data: process (SYSCLK, Shift_Data_Reg, D_Rec, Data_Reg)
variable i: integer range 0 to 6 := 0;
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Shift_Data_Reg = '1' then                     
         for i in 0 to 6 loop
            Data_Reg(i+1) <= Data_Reg(i);
         end loop;
            Data_Reg(0) <= D_Rec;
      end if;
   end if;
end process Read_Data;

Count_Bytes_Send: process (SYSCLK, Reset_Cnt_Bytes, Load_Cnt_Bytes_Sent, Shift_Cmd_Reg, Cnt_Bytes_Sent)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Reset_Cnt_Bytes = '1' then
          Cnt_Bytes_Sent <= 0;
      elsif Load_Cnt_Bytes_Sent = '1' then
        if   (StC_Adxl_Ctrl = stAdxlSendResetCmd) 
          or (StC_Adxl_Ctrl = stAdxlConf_Remaining) then
                  Cnt_Bytes_Sent <= NUMBYTES_CMD_CONFIG_REG; 
        elsif  (StC_Adxl_Ctrl = stAdxlRead_Status) 
            or (StC_Adxl_Ctrl = stAdxlRead_Data) then
                  Cnt_Bytes_Sent <= NUMBYTES_CMD_READ;
        else
                  Cnt_Bytes_Sent <= 0;
        end if;
      elsif Shift_Cmd_Reg = '1' then
           if Cnt_Bytes_Sent = 0 then
               Cnt_Bytes_Sent <= 0;
           else
               Cnt_Bytes_Sent <= Cnt_Bytes_Sent - 1;
           end if;
      end if;
   end if;
end process Count_Bytes_Send;

Count_Bytes_Rec: process (SYSCLK, Reset_Cnt_Bytes, Load_Cnt_Bytes_Rec, Shift_Data_Reg, Cnt_Bytes_Rec)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Reset_Cnt_Bytes = '1' then
          Cnt_Bytes_Rec <= 0;
     elsif Load_Cnt_Bytes_Rec = '1' then
        if   (StC_Adxl_Ctrl = stAdxlRead_Status)  then
                  Cnt_Bytes_Rec <= NUMBYTES_READ_STATUS - 1; 
        elsif (StC_Adxl_Ctrl = stAdxlRead_Data) then
                  Cnt_Bytes_Rec <= NUMBYTES_READ_DATA -1;
        else
                  Cnt_Bytes_Rec <= 0;
        end if;
      elsif Shift_Data_Reg = '1' then
           if Cnt_Bytes_Rec = 0 then
               Cnt_Bytes_Rec <= 0;
           else
               Cnt_Bytes_Rec <= Cnt_Bytes_Rec - 1;
           end if;
      end if;
   end if;
end process Count_Bytes_Rec;

Count_Sample_Rate_Div: process (SYSCLK, Reset_Sample_Rate_Div, Sample_Rate_Div)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Reset_Sample_Rate_Div = '1' then
         Sample_Rate_Div <= 0;
      elsif Sample_Rate_Div = (UPDATE_DIV_RATE - 1) then   
         Sample_Rate_Div <= 0;
      else
         Sample_Rate_Div <= Sample_Rate_Div + 1;
      end if;
   end if;
end process Count_Sample_Rate_Div;

Sample_Rate_Tick  <= '1' when Sample_Rate_Div = (UPDATE_DIV_RATE - 1) else '0';

Count_Num_Reads: process (SYSCLK, Reset_Cnt_Num_Reads, CE_Cnt_Num_Reads, Cnt_Num_Reads)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if Reset_Cnt_Num_Reads = '1' then
         Cnt_Num_Reads <= 0;
      elsif CE_Cnt_Num_Reads = '1' then
            if Cnt_Num_Reads = (NUM_READS - 1) then   
               Cnt_Num_Reads <= (NUM_READS - 1);
            else
               Cnt_Num_Reads <= Cnt_Num_Reads + 1;
            end if;
      end if;
   end if;
end process Count_Num_Reads;

Cnt_Num_Reads_Done <= '1' when Cnt_Num_Reads = (NUM_READS - 1) else '0';

Count_SS_Inactive: process (SYSCLK, RESET, Reset_Cnt_SS_Inactive, Cnt_SS_Inactive)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
      if RESET = '1' or Reset_Cnt_SS_Inactive = '1' then
         Cnt_SS_Inactive <= 0;
      elsif Cnt_SS_Inactive = (SS_INACTIVE_CLOCKS - 1) then   
         Cnt_SS_Inactive <= (SS_INACTIVE_CLOCKS - 1);
      else
         Cnt_SS_Inactive <= Cnt_SS_Inactive + 1;
      end if;
   end if;
end process Count_SS_Inactive;

Cnt_SS_Inactive_done <= '1' when Cnt_SS_Inactive = (SS_INACTIVE_CLOCKS - 1) else '0';

Set_SPI_RnW: process (SYSCLK, StC_Adxl_Ctrl)
begin
   if SYSCLK'EVENT AND SYSCLK = '1' then
         if    (StC_Adxl_Ctrl = stAdxlRead_Status) 
            or (StC_Adxl_Ctrl = stAdxlRead_Data) then
                  SPI_RnW <= '1';
         else
                  SPI_RnW <= '0';
         end if;
   end if;
end process Set_SPI_RnW;

SPI_WR_Done <= '1' when Cnt_Bytes_Sent = 0 AND Done = '1' else '0';
SPI_RD_Done <= '1' when Cnt_Bytes_Rec = 0 AND Done = '1' else '0';

Register_StC_Spi_SendRec: process (SYSCLK, RESET, StN_Spi_SendRec)
begin
      if SYSCLK'EVENT AND SYSCLK = '1' then
         if RESET = '1' then
            StC_Spi_SendRec <= stSpiSendRecIdle;
         else
            StC_Spi_SendRec <= StN_Spi_SendRec;
         end if;
      end if;
end process Register_StC_Spi_SendRec;

Cmb_StC_Spi_SendRec: process (StC_Spi_SendRec, StartSpiSendRec, StartSpiSendRec, 
                              SPI_WR_Done, SPI_RD_Done, SPI_RnW, Done)
begin
   StN_Spi_SendRec <= StC_Spi_SendRec;
   case (StC_Spi_SendRec) is
      when stSpiSendRecIdle => if (StartSpiSendRec = '1') then StN_Spi_SendRec <= stSpiPrepareCmd; end if;
      when stSpiPrepareCmd  => StN_Spi_SendRec <= stSpiSendStartW;
      when stSpiSendStartW  => StN_Spi_SendRec <= stSpiWaitOnDoneW;
      when stSpiWaitOnDoneW => if (SPI_RnW = '1') then
                                   if (SPI_WR_Done = '1') then StN_Spi_SendRec <= stSpiSendStartR;
                                   elsif (Done = '1') then StN_Spi_SendRec <= stSpiPrepareCmd;
                                   end if;
                               else
                                    if (SPI_WR_Done = '1') then StN_Spi_SendRec <= stSpiSendRecDone;
                                    elsif (Done = '1') then StN_Spi_SendRec <= stSpiPrepareCmd;
                                    end if;
                               end if;
      when stSpiSendStartR  => StN_Spi_SendRec <= stSpiWaitOnDoneR;
      when stSpiWaitOnDoneR => if (SPI_RD_Done = '1') then StN_Spi_SendRec <= stSpiSendRecDone;
                               elsif (Done = '1') then StN_Spi_SendRec <= stSpiSendStartR;
                               end if;
      when stSpiSendRecDone => StN_Spi_SendRec <= stSpiSendRecIdle;
      when others => StN_Spi_SendRec <= stSpiSendRecIdle;
   end case;
end process Cmb_StC_Spi_SendRec;

Register_StC_Spi_Trans: process (SYSCLK, RESET, StN_Spi_Trans)
begin
      if SYSCLK'EVENT AND SYSCLK = '1' then
         if RESET = '1' then
            StC_Spi_Trans <= stSpiTransIdle;
         else
            StC_Spi_Trans <= StN_Spi_Trans;
         end if;
      end if;
end process Register_StC_Spi_Trans;

Cmb_StC_Spi_Trans: process (StC_Spi_Trans, StartSpiTr, Cnt_SS_Inactive_done, SPI_SendRec_Done)
begin
   StN_Spi_Trans <= StC_Spi_Trans;
   case (StC_Spi_Trans) is
      when stSpiTransIdle      => if (StartSpiTr = '1') then StN_Spi_Trans <= stSpiPrepAndSendCmd; end if;
      when stSpiPrepAndSendCmd => StN_Spi_Trans <= stSpiWaitonDoneSR;
      when stSpiWaitonDoneSR   => if (SPI_SendRec_Done = '1') then StN_Spi_Trans <= stSpiWaitForSsInact; end if;
      when stSpiWaitForSsInact => if (Cnt_SS_Inactive_done = '1') then StN_Spi_Trans <= stSpiTransDone; end if;
      when stSpiTransDone      => StN_Spi_Trans <= stSpiTransIdle;
      when others => StN_Spi_Trans <= stSpiTransIdle;
   end case;
end process Cmb_StC_Spi_Trans;

Adxl_Data_Ready <= Data_Reg(0)(0);
Adxl_Conf_Err <= Data_Reg(0)(7);

Register_StC_Adxl_Ctrl: process (SYSCLK, RESET, StN_Adxl_Ctrl)
begin
      if SYSCLK'EVENT AND SYSCLK = '1' then
         if RESET = '1' then
            StC_Adxl_Ctrl <= stAdxlCtrlIdle;
         else
            StC_Adxl_Ctrl <= StN_Adxl_Ctrl;
         end if;
      end if;
end process Register_StC_Adxl_Ctrl;

Cmb_StC_Adxl_Ctrl: process (StC_Adxl_Ctrl, Cnt_SS_Inactive_done, SPI_Trans_Done, Sample_Rate_Tick,
                            Cmd_Reg_Addr_Done, Adxl_Data_Ready, Adxl_Conf_Err, Cnt_Num_Reads_Done)
begin
   StN_Adxl_Ctrl <= StC_Adxl_Ctrl;
   case (StC_Adxl_Ctrl) is
      when stAdxlCtrlIdle           => if (Sample_Rate_Tick = '1') then StN_Adxl_Ctrl <= stAdxlSendResetCmd; end if;
      when stAdxlSendResetCmd       => if (SPI_Trans_Done = '1') then StN_Adxl_Ctrl <= stAdxlWaitResetDone; end if;
      when stAdxlWaitResetDone      => if (Sample_Rate_Tick = '1') then StN_Adxl_Ctrl <= stAdxlConf_Remaining; end if;
      when stAdxlConf_Remaining     => if ( Cmd_Reg_Addr_Done = '1' AND SPI_Trans_Done = '1') then
                                             StN_Adxl_Ctrl <= stAdxlWaitSampleRateTick;
                                       end if;
      when stAdxlWaitSampleRateTick => if (Sample_Rate_Tick = '1') then StN_Adxl_Ctrl <= stAdxlRead_Status; end if;
      when stAdxlRead_Status        => if SPI_Trans_Done = '1' then 
                                                if Adxl_Conf_Err = '1' then StN_Adxl_Ctrl <= stAdxlCtrlIdle;
                                                elsif Adxl_Data_Ready = '1' then StN_Adxl_Ctrl <= stAdxlRead_Data;
                                                end if;
                                       end if;
      when stAdxlRead_Data          => if (SPI_Trans_Done = '1') then StN_Adxl_Ctrl <= stAdxlFormatandSum; end if;
      when stAdxlFormatandSum       => if (Cnt_Num_Reads_Done = '1') then 
                                            StN_Adxl_Ctrl <= stAdxlRead_Done;
                                       else
                                            StN_Adxl_Ctrl <= stAdxlRead_Status;
                                       end if;
      when stAdxlRead_Done          => StN_Adxl_Ctrl <= stAdxlWaitSampleRateTick;
      when others => StN_Adxl_Ctrl <= stAdxlCtrlIdle;
   end case;
end process Cmb_StC_Adxl_Ctrl;

Sum_Data: process (SYSCLK, RESET, Data_Ready_1, Enable_Sum, Data_Reg, 
                   ACCEL_X_SUM, ACCEL_Y_SUM, ACCEL_Z_SUM, ACCEL_TMP_SUM)
    variable X_SAMPLE   : SIGNED(11 downto 0);
    variable Y_SAMPLE   : SIGNED(11 downto 0);
    variable Z_SAMPLE   : SIGNED(11 downto 0);
    variable TMP_SAMPLE : SIGNED(11 downto 0);
begin
    if SYSCLK'EVENT AND SYSCLK = '1' then
         if (RESET = '1' OR Data_Ready_1 = '1') then
            ACCEL_X_SUM <= (others => '0');
            ACCEL_Y_SUM <= (others => '0');
            ACCEL_Z_SUM <= (others => '0');
            ACCEL_TMP_SUM <= (others => '0');
         elsif Enable_Sum = '1' then
            X_SAMPLE(11 downto 8) := signed(Data_Reg(6)(3 downto 0));
            X_SAMPLE(7 downto 0)  := signed(Data_Reg(7));

            Y_SAMPLE(11 downto 8) := signed(Data_Reg(4)(3 downto 0));
            Y_SAMPLE(7 downto 0)  := signed(Data_Reg(5));

            Z_SAMPLE(11 downto 8) := signed(Data_Reg(2)(3 downto 0));
            Z_SAMPLE(7 downto 0)  := signed(Data_Reg(3));

            TMP_SAMPLE(11 downto 8) := signed(Data_Reg(0)(3 downto 0));
            TMP_SAMPLE(7 downto 0)  := signed(Data_Reg(1));

            ACCEL_X_SUM <= std_logic_vector(signed(ACCEL_X_SUM) + resize(X_SAMPLE, ACCEL_X_SUM'length));
            ACCEL_Y_SUM <= std_logic_vector(signed(ACCEL_Y_SUM) + resize(Y_SAMPLE, ACCEL_Y_SUM'length));
            ACCEL_Z_SUM <= std_logic_vector(signed(ACCEL_Z_SUM) + resize(Z_SAMPLE, ACCEL_Z_SUM'length));
            ACCEL_TMP_SUM <= std_logic_vector(signed(ACCEL_TMP_SUM) + resize(TMP_SAMPLE, ACCEL_TMP_SUM'length));
         end if;
    end if;
end process Sum_Data;
                  
Register_Output_Data: process (SYSCLK, RESET, Data_Ready_1, ACCEL_X_SUM, 
                               ACCEL_Y_SUM, ACCEL_Z_SUM, ACCEL_TMP_SUM)
begin
    if SYSCLK'EVENT AND SYSCLK = '1' then
         if RESET = '1' then
            ACCEL_X <= (others => '0');
            ACCEL_Y <= (others => '0');
            ACCEL_Z <= (others => '0');
            ACCEL_TMP <= (others => '0');
         elsif Data_Ready_1 = '1' then
            ACCEL_X <= ACCEL_X_SUM ((11 + (NUM_READS_BITS)) downto (NUM_READS_BITS));
            ACCEL_Y <= ACCEL_Y_SUM ((11 + (NUM_READS_BITS)) downto (NUM_READS_BITS));
            ACCEL_Z <= ACCEL_Z_SUM ((11 + (NUM_READS_BITS)) downto (NUM_READS_BITS));
            ACCEL_TMP <= ACCEL_TMP_SUM ((11 + (NUM_READS_BITS)) downto (NUM_READS_BITS));
         end if;
    end if;
end process Register_Output_Data;

Pipe_Data_Ready: process (SYSCLK, RESET, Data_Ready_1)
begin
    if SYSCLK'EVENT AND SYSCLK = '1' then
         if RESET = '1' then
            Data_Ready <= '0';
         else
            Data_Ready <= Data_Ready_1;
         end if;
    end if;
end process Pipe_Data_Ready;
 
end Behavioral;