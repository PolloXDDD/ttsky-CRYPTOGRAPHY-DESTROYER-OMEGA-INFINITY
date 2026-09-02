import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def parse_cnf(filepath):
    clauses = []
    num_vars = 0
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("c"):
                continue
            if line.startswith("p"):
                parts = line.split()
                num_vars = int(parts[2])
                continue
            literals = [int(x) for x in line.split() if int(x) != 0]
            if literals:
                clauses.append(literals)
    return num_vars, clauses

async def stream_lattice_coordinate(dut, x, y, z):
    # Stream X (byte 0)
    dut.ui_in.value = x & 0xFF
    dut.uio_in.value = 0x01 | 0x02 | (0x00 << 4)
    await ClockCycles(dut.clk, 1)

    # Stream Y (byte 1)
    dut.ui_in.value = y & 0xFF
    dut.uio_in.value = 0x01 | 0x02 | (0x01 << 4)
    await ClockCycles(dut.clk, 1)

    # Stream Z (byte 2)
    dut.ui_in.value = z & 0xFF
    dut.uio_in.value = 0x01 | 0x02 | (0x02 << 4)
    await ClockCycles(dut.clk, 1)

async def load_lattice_tap(dut, quantized_bit):
    dut.uio_in.value = 0x01 | 0x80 | ((quantized_bit & 0x01) << 6)
    await ClockCycles(dut.clk, 1)

async def write_gate(dut, op, a, b):
    dut.ui_in.value = (op & 0x07) | ((a & 0x1F) << 3)
    dut.uio_in.value = 0x01 | 0x04 | ((b & 0x03) << 4)
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

async def set_output_node(dut, target_node):
    dut.ui_in.value = (target_node & 0x1F) << 3
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_cnf_solver(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    cnf_path = "input.cnf"
    if not os.path.exists(cnf_path):
        with open(cnf_path, "w") as f:
            f.write("p cnf 3 2\n1 -2 0\n2 3 0\n")

    num_vars, clauses = parse_cnf(cnf_path)

    # Program mode
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

    # Map variables to 3D grid coords and stream
    for var_idx in range(1, min(num_vars, 8) + 1):
        x = var_idx % 256
        y = (var_idx // 256) % 256
        z = (var_idx // 65536) % 256
        await stream_lattice_coordinate(dut, x, y, z)
        await load_lattice_tap(dut, quantized_bit=1)

    # Map clauses into evaluation plane
    gate_idx = 8
    clause_nodes = []
    for clause in clauses:
        lit = clause[0]
        var = abs(lit) - 1
        curr = var
        if lit < 0:
            await write_gate(dut, op=6, a=curr, b=0)
            curr = gate_idx
            gate_idx += 1
        for next_lit in clause[1:]:
            next_var = abs(next_lit) - 1
            op_b = next_var
            if next_lit < 0:
                await write_gate(dut, op=6, a=op_b, b=0)
                op_b = gate_idx
                gate_idx += 1
            await write_gate(dut, op=1, a=curr, b=op_b)
            curr = gate_idx
            gate_idx += 1
        clause_nodes.append(curr)

    # Conjoin clauses
    out_node = clause_nodes[0]
    for c_node in clause_nodes[1:]:
        await write_gate(dut, op=0, a=out_node, b=c_node)
        out_node = gate_idx
        gate_idx += 1

    await set_output_node(dut, out_node)

    # Search-to-decision extraction
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 2)

    solution = []
    for i in range(num_vars):
        dut.uio_in.value = 0x01
        for bit in solution:
            await load_lattice_tap(dut, bit)
        await load_lattice_tap(dut, 1)
        for _ in range(num_vars - len(solution) - 1):
            await load_lattice_tap(dut, 0)

        dut.uio_in.value = 0x08
        await ClockCycles(dut.clk, 2)

        if dut.uo_out[0].value == 1:
            solution.append(1)
        else:
            solution.append(0)

    # Verification run
    dut.uio_in.value = 0x01
    for bit in solution:
        await load_lattice_tap(dut, bit)
    for _ in range(8 - len(solution)):
        await load_lattice_tap(dut, 0)

    dut.uio_in.value = 0x08
    await ClockCycles(dut.clk, 2)

    with open("solution.txt", "w") as f:
        if dut.uo_out[0].value == 1:
            sat_str = " ".join(f"{i+1}" if val == 1 else f"-{i+1}" for i, val in enumerate(solution))
            f.write(f"SAT\n{sat_str} 0\n")
        else:
            f.write("UNSAT\n")
