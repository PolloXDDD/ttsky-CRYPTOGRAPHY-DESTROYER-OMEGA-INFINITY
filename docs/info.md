<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The OMEGA INFINITY KAORU processor implements a programmable Circuit-SAT engine designed to couple an unconventional resistive relaxation substrate to a CMOS digital evaluation stage[cite: 1].

The architecture addresses a 3D volumetric lattice of $256 \times 256 \times 256$ nodes ($16,777,216$ nodes total), where node $(0,0,0)$ acts as the positive excitation source ($+$) and the remaining $16,777,215$ nodes represent potential Boolean assignment variables.

Key operational stages include:

* **3D Coordinate Engine:** A 24-bit addressing engine streams $(X, Y, Z)$ coordinates via 3-byte sequences over `ui_in` to select any node within the $256^3$ volumetric lattice.
* **Quantization & Local Tap Cache:** The thresholded analog voltage state from the selected node coordinate is latched through `var_val_in` (`uio_in[6]`) into an active 8-variable evaluation cache (`cached_taps`)[cite: 1].
* **Programmable Evaluation Plane:** A topological gate-array memory stores up to 16 arbitrary gate descriptors covering standard Boolean basis operations (`AND`, `OR`, `XOR`, `XNOR`, `NAND`, `NOR`, `NOT`, `BUF`)[cite: 1].
* **Combinational Decision Network:** Evaluates the programmed circuit DAG concurrently against the cached lattice taps[cite: 1]. When the physical relaxation flag `grid_stable` (`uio_in[3]`) is asserted, the output gate value is captured into the `SAT` (`uo_out[0]`), `UNSAT` (`uo_out[1]`), and `DONE` (`uo_out[2]`) registers, while the active satisfying assignment bits are presented directly on `uo_out[7:3]`[cite: 1].

## How to test

The chip operates in two primary modes governed by `uio_in[0]` (`prog_en`):

### 1. Configuration Mode (`uio_in[0] = 1`)

* **Stream 3D Lattice Coordinates:** Set `uio_in[1] = 1` (`stream_addr`). Drive `ui_in` with the coordinate byte and select the target axis using `uio_in[5:4]` (`byte_sel`):
  * `2'b00`: $X$ coordinate ($0 \dots 255$)
  * `2'b01`: $Y$ coordinate ($0 \dots 255$)
  * `2'b10`: $Z$ coordinate ($0 \dots 255$)
* **Load Variable Values:** Present the thresholded logic bit on `uio_in[6]` (`var_val_in`) and pulse `uio_in[7]` (`load_tap_val`) high to shift it into the active tap window.
* **Program Gate Descriptors:** Set `uio_in[1] = 0` (`stream_addr`). Provide the gate opcode on `ui_in[2:0]`, operand A on `ui_in[7:3]`, operand B on `uio_in[5:4]`/`ui_in[2]`, and pulse `uio_in[2]` (`we_pulse`) high to latch the descriptor into the next gate slot.
* **Set Output Gate:** With `we_pulse = 0`, present the final gate node index on `ui_in[7:3]`.

### 2. Execution Mode (`uio_in[0] = 0`)

* Lower `uio_in[0]` to `0` to enter evaluation mode.
* Assert `uio_in[3] = 1` (`grid_stable`) to latch the decision.
* Read `uo_out[0]` for `SAT`, `uo_out[1]` for `UNSAT`, and `uo_out[2]` for `DONE`.
* Verify the recovered variable values on `uo_out[7:3]`.

An automated Cocotb testbench (`test/test.py`) parses standard DIMACS `.cnf` files, programs the gate network, queries candidate variable states, and outputs the resulting assignment directly to `solution.txt`.

## External hardware

* **Host Microcontroller / FPGA:** An external host (such as an RP2040, STM32, or FPGA development board) to stream DIMACS CNF clauses, coordinate indices, and gate write strobes over the 8-bit bidirectional IO interface.
* **Optional 3D Conductive GRID Substrate:** An external resistive lattice or discrete resistor grid array interfaced via analog comparators to supply real-time thresholded relaxation potentials directly to `var_val_in`[cite: 1].
