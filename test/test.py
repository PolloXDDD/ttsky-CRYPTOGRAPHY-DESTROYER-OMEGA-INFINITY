import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# Helper to program an arbitrary gate
async def program_gate(dut, opcode, op_a, op_b):
    # ui_in[2:0] = opcode, ui_in[7:3] = op_a
    dut.ui_in.value = (opcode & 0x07) | ((op_a & 0x1F) << 3)
    # uio_in[0] = prog_en (1), uio_in[1] = prog_we (1), uio_in[7:4] = op_b
    dut.uio_in.value = 0x01 | 0x02 | ((op_b & 0x0F) << 4)
    await ClockCycles(dut.clk, 1)
    # Deassert write strobe
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

# Helper to designate the circuit's final output gate
async def set_output_gate(dut, out_gate_idx):
    dut.uio_in.value = 0x01 | ((out_gate_idx & 0x0F) << 4)
    await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_universal_sat_loader(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # System Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Enable Programming Mode
    dut.uio_in.value = 0x05  # prog_en=1, prog_rst_ptr=1
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x01  # prog_en=1
    await ClockCycles(dut.clk, 1)

    # -------------------------------------------------------------
    # Program Any Arbitrary SAT Instance:
    # Example Instance: F = (v0 AND v1) OR (NOT v2)
    # Node map:
    # v0 = 0, v1 = 1, v2 = 2
    # Gate 0 (Node 8)  : NOT(v2)       -> op=6, a=2, b=0
    # Gate 1 (Node 9)  : AND(v0, v1)   -> op=0, a=0, b=1
    # Gate 2 (Node 10) : OR(Node 8, 9) -> op=1, a=8, b=9
    # -------------------------------------------------------------
    await program_gate(dut, opcode=6, op_a=2, op_b=0)
    await program_gate(dut, opcode=0, op_a=0, op_b=1)
    await program_gate(dut, opcode=1, op_a=8, op_b=9)

    # Set final output to Gate 2 (Node 10)
    await set_output_gate(dut, out_gate_idx=10)

    # Exit programming mode
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 2)

    # Evaluate Candidate Assignment 1: v2=1, v1=0, v0=0 -> Expect UNSAT (0)
    dut.ui_in.value = 0x04       # v2=1, v1=0, v0=0
    dut.uio_in.value = 0x08      # grid_stable=1
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out[0].value == 0, "Error: Expected UNSAT"
    assert dut.uo_out[1].value == 1, "Error: Expected UNSAT flag asserted"
    assert dut.uo_out[2].value == 1, "Error: Expected DONE asserted"

    # Evaluate Candidate Assignment 2: v2=0 -> Expect SAT (1)
    dut.ui_in.value = 0x00       # v2=0
    dut.uio_in.value = 0x08      # grid_stable=1
    await ClockCycles(dut.clk, 2)
    assert dut.uo_out[0].value == 1, "Error: Expected SAT"
    assert dut.uo_out[1].value == 0, "Error: Expected SAT flag asserted"
    assert dut.uo_out[2].value == 1, "Error: Expected DONE asserted"
