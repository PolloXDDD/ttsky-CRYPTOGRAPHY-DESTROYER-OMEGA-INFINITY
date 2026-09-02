# OMEGA INFINITY KAORU 3D Metal Grid Processor

## How it works
This processor interfaces an integrated 3D BEOL physical wire mesh (`omega_metal_grid_3d.gds`) fabricated in the SkyWater 130nm metallization stack (`met1` through `met5`) directly with standard-cell CMOS threshold inverters.

The metal mesh provides continuous analog potential relaxation across physical conductors. The state of these physical wires is quantized into digital logic levels that feed a runtime-programmable Boolean circuit DAG (Directed Acyclic Graph) to evaluate Circuit-SAT formulations directly in hardware.

## How to test
1. Hold `rst_n` low for 4 clock cycles, then bring high.
2. Enable programming mode by asserting `uio_in[0] = 1`.
3. Stream gate operations by providing `prog_op` on `ui[2:0]`, `prog_a` on `ui[7:3]`, `prog_b` on `uio[7:4]`, and toggling `uio[1]` (`prog_we`).
4. Select the target evaluation node by driving `prog_a` with `uio[1] = 0`.
5. Switch to execution mode (`uio_in[0] = 0`) and assert `uio[3] = 1` (`grid_stable`).
6. Read `uo_out[0]` for SAT, `uo_out[1]` for UNSAT, and `uo_out[7:3]` for the evaluated physical tap states.
