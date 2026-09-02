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

async def write_gate(dut, op, a, b):
    # ui_in[2:0] = op, ui_in[7:3] = prog_a
    dut.ui_in.value = (op & 0x07) | ((a & 0x1F) << 3)
    # uio_in[0] = prog_en, uio_in[1] = prog_we, uio_in[7:4] = prog_b
    dut.uio_in.value = 0x01 | 0x02 | ((b & 0x0F) << 4)
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

    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

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

    out_node = clause_nodes[0]
    for c_node in clause_nodes[1:]:
        await write_gate(dut, op=0, a=out_node, b=c_node)
        out_node = gate_idx
        gate_idx += 1

    await set_output_node(dut, out_node)

    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 2)

    dut.uio_in.value = 0x08  # grid_stable = 1
    await ClockCycles(dut.clk, 4)

    is_sat = (dut.uo_out[0].value == 1)
    raw_assignments = dut.uo_out.value >> 3

    with open("solution.txt", "w") as f:
        if is_sat:
            sol = [f"{i+1}" if ((raw_assignments >> i) & 1) else f"-{i+1}" for i in range(min(num_vars, 5))]
            f.write("SAT\n" + " ".join(sol) + " 0\n")
        else:
            f.write("UNSAT\n")
