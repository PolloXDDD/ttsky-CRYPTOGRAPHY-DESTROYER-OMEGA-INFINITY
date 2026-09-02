
![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# OMEGA INFINITY KAORU: 3D Volumetric Circuit-SAT Processor

A custom hardware Circuit-SAT acceleration engine fabricated on SkyWater 130nm via Tiny Tapeout, featuring an unconventional 3D volumetric lattice interface and a reconfigurable Boolean evaluation DAG.

- [Datasheet & Specifications](docs/info.md)

---

## Architectural Overview

The processor interfaces a 3D volumetric resistive grid of $256 \times 256 \times 256$ nodes ($16,777,216$ nodes total) with a digital CMOS verification plane:

* **Variable Capacity:** The origin coordinate $(0,0,0)$ serves as the positive excitation source ($+$), while the remaining $16,777,215$ nodes represent addressable Boolean variables.
* **24-bit Spatial Addressing:** Coordinates $(X, Y, Z)$ are ingested sequentially in three 8-bit bytes via `ui_in`, enabling full random access across the 16.7M node volume.
* **Dynamic Tap Cache:** Holds up to 8 active boundary/internal variables concurrently for instant evaluation against user-defined gate constraints.
* **Topological Gate DAG:** A 16-gate array supporting `AND`, `OR`, `XOR`, `XNOR`, `NAND`, `NOR`, `NOT`, and `BUF` primitives to evaluate arbitrary Tseitin-encoded CNF clauses.
* **Physical Relaxation Capture:** Latches the final circuit satisfiability decision (`SAT`, `UNSAT`, `DONE`) when the relaxation settling condition (`grid_stable`) is asserted.

---

## Pinout Mapping

| Pin | Direction | Name | Function / Mapping |
| :--- | :--- | :--- | :--- |
| `ui_in[7:0]` | Input | `stream_in` | Multiplexed: Coordinate bytes (X/Y/Z), Gate opcodes & operands |
| `uo_out[0]` | Output | `SAT` | High if candidate assignment satisfies the circuit |
| `uo_out[1]` | Output | `UNSAT` | High if candidate assignment fails |
| `uo_out[2]` | Output | `DONE` | High when decision is latched |
| `uo_out[7:3]` | Output | `assignment` | Real-time readout of active satisfying variables |
| `uio_in[0]` | Input | `prog_en` | Mode select: `1` = Programming/Streaming, `0` = Execution |
| `uio_in[1]` | Input | `stream_addr` | `1` = Stream 24-bit address, `0` = Write gate descriptor |
| `uio_in[2]` | Input | `we_pulse` | Strobe to latch gate configuration |
| `uio_in[3]` | Input | `grid_stable` | Signals physical lattice relaxation completion |
| `uio_in[5:4]` | Input | `byte_sel` | Coordinate axis: `00` = X, `01` = Y, `10` = Z |
| `uio_in[6]` | Input | `var_val_in` | Quantized logic bit from addressed 3D lattice coordinate |
| `uio_in[7]` | Input | `load_tap_val`| Strobe to load `var_val_in` into local tap cache |

---

## Simulation & Automated CNF Solving

The design includes a Cocotb testbench that parses standard DIMACS `.cnf` files, streams corresponding 3D coordinates, programs the gate network, and extracts satisfying assignments directly into a clean `solution.txt` output.

### Running Tests Locally

Ensure `cocotb` and `iverilog` are installed, then execute:

```bash
cd test
make

```

Upon completion, `solution.txt` is populated with the decision and literal assignment:

```text
SAT
1 -2 3 0

```

---

## Hardware Implementation Details

* **Foundry:** SkyWater 130nm CMOS (`sky130_fd_sc_hd`)
* **Target Tile Allocation:** 1x1 Standard Tile ($160 \times 100\ \mu\text{m}$)
* **Clock Frequency:** 10 MHz nominal
* **Synthesis Engine:** OpenLane / LibreLane Flow

```


