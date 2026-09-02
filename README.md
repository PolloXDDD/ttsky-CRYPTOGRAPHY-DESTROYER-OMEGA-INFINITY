```markdown
# OMEGA INFINITY KAORU - 3D BEOL Metal Grid Circuit-SAT Processor

**Author:** Kaoru Aguilera Katayama  
**Process:** SkyWater 130nm (`sky130_fd_sc_hd`)  
**Target:** Tiny Tapeout (1x1 tile, $160 \times 100\ \mu\text{m}$)

---

## Overview

OMEGA INFINITY KAORU interfaces a custom physical Backend-of-Line (BEOL) 3D metallic grid mesh (`omega_metal_grid_3d.gds`) directly into the digital CMOS routing plane of a SkyWater 130nm ASIC. The passive metal network spans metal layers `met1` through `met5`, interlinked with vertical via stacks (`via1` to `via4`). Continuous analog potentials within the conductive mesh are quantized via standard-cell CMOS threshold inverters ($\theta \approx 0.9\text{ V}$) to drive an on-chip runtime-programmable Boolean Directed Acyclic Graph (DAG) for Circuit-SAT verification.

---

## Architectural Block Diagram

```text
       +-------------------------------------------------------------+
       |                  SKYWATER 130nm SILICON DIE                 |
       |                                                             |
       |   +-----------------------------------------------------+   |
       |   |      3D BEOL PHYSICAL MESH (omega_metal_grid_3d)    |   |
       |   |        Layers: met1, met2, met3, met4, met5         |   |
       |   |        Interconnect: via1, via2, via3, via4         |   |
       |   +--------------------------+--------------------------+   |
       |                              | raw_grid_wire_taps[7:0]      |
       |                              v                              |
       |   +-----------------------------------------------------+   |
       |   |          CMOS ANALOG THRESHOLD DETECTORS            |   |
       |   |      8x sky130_fd_sc_hd__inv_1 (theta ~ 0.9V)       |   |
       |   +--------------------------+--------------------------+   |
       |                              | quantized_taps[7:0]          |
       |                              v                              |
       |   +-----------------------------------------------------+   |
       |   |        PROGRAMMABLE BOOLEAN DAG ENGINE (16 GATES)    |   |
       |   |        Supported ops: AND, OR, NAND, NOR,           |   |
       |   |                       XOR, XNOR, NOT                |   |
       |   +--------------------------+--------------------------+   |
       |                              |                              |
       +------------------------------|------------------------------+
                                      v
                             uo_out[0] = SAT
                             uo_out[1] = UNSAT
                             uo_out[2] = DONE
                             uo_out[7:3] = tap_out[4:0]

```

---

## Pinout Configuration

| Pin | Name | Type | Description |
| --- | --- | --- | --- |
| `ui[2:0]` | `prog_op[2:0]` | Input | Gate opcode selection (0: AND, 1: OR, 6: NOT, etc.) |
| `ui[7:3]` | `prog_a[4:0]` | Input | Operand A source index or target output node selector |
| `uo[0]` | `SAT` | Output | High when the selected target node evaluates to true |
| `uo[1]` | `UNSAT` | Output | High when the selected target node evaluates to false |
| `uo[2]` | `DONE` | Output | Evaluation valid strobe (mirrors `grid_stable`) |
| `uo[7:3]` | `tap_out[4:0]` | Output | Quantized digital values of physical taps 0 through 4 |
| `uio[0]` | `prog_en` | Input | Mode control (1 = Program DAG, 0 = Execute evaluation) |
| `uio[1]` | `prog_we` | Input | Write enable strobe for DAG gate programming |
| `uio[2]` | `unused` | Input | Tied / reserved |
| `uio[3]` | `grid_stable` | Input | Relaxation stabilization trigger signal |
| `uio[7:4]` | `prog_b[3:0]` | Input | Operand B source index |

---

## Operating Modes

### 1. Programming Mode (`uio_in[0] = 1`)

* **Writing a Gate:** Set the opcode on `ui_in[2:0]`, Operand A on `ui_in[7:3]`, Operand B on `uio_in[7:4]`, and pulse `uio_in[1]` (`prog_we`) high for 1 clock cycle.
* **Selecting the Output Evaluation Node:** Set `uio_in[1] = 0` and provide the target node index on `ui_in[7:3]`.

### 2. Physical Evaluation Mode (`uio_in[0] = 0`)

* Lower `uio_in[0]` to enter execution mode.
* Assert `uio_in[3]` (`grid_stable = 1`) to signal potential relaxation across the physical mesh.
* Read the evaluation result on `uo_out[0]` (`SAT`) and `uo_out[1]` (`UNSAT`).

---

## How to Test

### Simulation with Cocotb

Dependencies are managed through Python virtual environments:

```bash
cd test
pip install -r requirements.txt
make

```

The testbench parses a standard DIMACS CNF formula (`input.cnf`), compiles the clauses into the hardware DAG format, routes the physical grid taps, and outputs the final boolean assignment to `solution.txt`.

### Waveform Inspection

Waveforms are exported in FST format for analysis:

```bash
gtkwave tb.fst tb.gtkw

```

```

```
