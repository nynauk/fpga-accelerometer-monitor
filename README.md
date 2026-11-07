# FPGA accelerometer monitor (VHDL, Nexys A7-100T)

A VHDL design for the Digilent Nexys A7-100T (Xilinx Artix-7, XC7A100T-1CSG324C) that reads the on-board ADXL362
accelerometer over SPI and shows the result on the 7-segment display, with an RGB LED that changes colour with
the board's orientation. It was my Digital Systems Design coursework at Royal Holloway (module mark 84%),
built in Vivado 2023.2 between January and March 2026.

[![simulate](https://github.com/nynauk/fpga-accelerometer-monitor/actions/workflows/simulate.yml/badge.svg)](https://github.com/nynauk/fpga-accelerometer-monitor/actions/workflows/simulate.yml)

## At a glance

- **What it does.** With SW15 on, the display shows the 12-bit signed number set on SW11-SW0. With SW15 off, it
  shows the X, Y or Z acceleration (selected on SW14-SW13), each averaged over 32 readings, or X in milli-g.
- **Verified.** The binary-to-BCD converter has a self-checking testbench: 20 chosen values (zero, the limits
  -2048 and 2047, and the digit boundaries in both signs) plus an exhaustive sweep of all 4,096 inputs. It
  passes in Vivado XSim and in GHDL, and GitHub Actions re-runs it on every push.
- **Implemented.** Routed in Vivado at 100 MHz with all timing constraints met: worst setup slack 5.385 ns,
  worst hold slack 0.142 ns, 290 LUTs and 280 flip-flops (0.46% and 0.22% of the device), no block RAM or DSP.
  The reports are in [`reports/`](reports).

## Design

```
                    ┌──────────────── accel_monitor_top ────────────────┐
 ADXL362 ◄── SPI ───┤ ACC_XYZ (supplied)                                │
                    │   SPI_If + ADXL362Ctrl: 1 MHz SCLK, 32-read mean  │
                    │        │ X, Y, Z (12-bit signed)                   │
 SW15, SW14-13 ─────┤   source and axis select ──► display ─────────────┼──► 7-segment (5 digits)
 SW11-SW0 ──────────┤                               bin2BCD            │
                    │                               mux, bin2seg       │
                    │                               clock, counter     │
                    │                               DAnC               │
                    │   orientation thresholds ──────────────────────────┼──► LED16 (RGB)
                    └────────────────────────────────────────────────────┘
```

| Module | Role | Author |
|---|---|---|
| `accel_monitor_top.vhd` | Top level: switch decoding, axis selection, milli-g output, orientation LED | Me |
| `display.vhd` | Structural display path: converter, digit multiplexer, decoder and anode control | Me |
| `bin2BCD.vhd` | 12-bit two's complement to sign plus four BCD digits, by double dabble (shift and add 3) | Me |
| `mux.vhd`, `bin2seg.vhd` | Pick the active digit and decode it to active-low segments (the sign digit shows a dash) | Me |
| `clock.vhd`, `counter.vhd`, `DAnC.vhd` | Digit scan: a tick every 800 µs (80,000 cycles at 100 MHz), 4 ms per full refresh, active-low anodes | Me |
| `sim/bin2BCD_tb.vhd` | Self-checking testbench with assertions and an exhaustive sweep | Me |
| `constraints/*.xdc` | Pins and the 100 MHz clock for the Nexys A7-100T | Me |
| `src/supplied/SPI_If.vhd`, `ADXL362Ctrl.vhd`, `ACC_XYZ.vhd` | SPI master, ADXL362 configuration and read-out, averaging wrapper | Supplied with the coursework, unchanged; the top level sets `NUM_READS_AVG` to 32 |

### Display path

`bin2BCD` takes the absolute value of the input, then runs the double-dabble algorithm: for each of the 12 bits it
adds 3 to any BCD digit that is 5 or more and shifts left, so the digits are correct at the end without any
division. The sign is returned separately and drawn as a dash on the leftmost of the five digits. The display
scans one digit every 800 µs, which refreshes all five every 4 ms (250 Hz), fast enough to look steady.

### Orientation LED

The averaged readings are compared with fixed thresholds in milli-g: red when |X| is above 100, blue when |Y| is
above 100, green when Z is above 800 (flat, face up). The colours mix, so a board tilted diagonally shows purple
and an upside-down board shows nothing.

## Verification

```bash
sim/run_ghdl.sh
```

The script analyses and runs the testbench in GHDL, fails unless it reports `ALL TESTS PASSED`, and then
elaborates the whole design. In GHDL 4.1 the testbench finishes at 20.68 µs of simulated time with no
assertion failures. The only warning comes from the supplied `ADXL362Ctrl.vhd` (a loop variable shadowing
another), which I left as supplied.

What is not covered: the supplied SPI and ADXL362 modules and the top level have no testbench here, so the
switch modes, axis selection and LED thresholds are checked only by elaboration and synthesis.

## Build in Vivado

1. Create an RTL project for part `xc7a100tcsg324-1`.
2. Add every file in `src/` and `src/supplied/` as design sources, `sim/bin2BCD_tb.vhd` as a simulation source
   and `constraints/Nexys-A7-100T-AccelMonitor.xdc` as the constraint file.
3. Set `accel_monitor_top` as the top module, then run synthesis, implementation and bitstream generation.

## Layout

```
src/            my VHDL modules
src/supplied/   SPI and ADXL362 modules provided with the coursework
sim/            bin2BCD testbench and the GHDL script
constraints/    Nexys A7-100T pin and clock constraints
reports/        Vivado 2023.2 timing summary and utilisation after place and route
```
