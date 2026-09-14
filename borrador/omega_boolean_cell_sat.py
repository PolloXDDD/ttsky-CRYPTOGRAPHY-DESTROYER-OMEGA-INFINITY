#!/usr/bin/env python3
"""
OMEGA Boolean Cell + exact 3-SAT clause-feedback experiment
============================================================

This script is an experimental dynamics layer for the exact 3-SAT energy

    E_F(x) = number of violated clauses.

Every variable is represented as a dual-rail OMEGA Boolean Cell:

    x_i = 1  <=>  (V_i^+, V_i^-) = (VDD, 0)
    x_i = 0  <=>  (V_i^+, V_i^-) = (0, VDD)

The clause DAG computes OR/NOT exactly. A violated-clause feedback pulse selects
one cell from an unsatisfied clause and flips it. Greedy selection minimizes the
local energy change; an optional exploration probability allows escape from
non-global local minima.

IMPORTANT:
This script demonstrates an exact logical energy and a polynomially capped
experimental update rule. It does NOT prove worst-case polynomial-time global
convergence for arbitrary 3-SAT. That convergence theorem is exactly the
remaining P=NP burden.

Usage
-----

Benchmark:
    python omega_boolean_cell_sat.py --benchmark --sizes 10 20 50 100 \
        --trials 20 --step-factor 50 --restarts 4

Single planted instance:
    python omega_boolean_cell_sat.py --n 50 --ratio 4.2 --seed 123

Local-trap demonstration:
    python omega_boolean_cell_sat.py --trap-demo
"""

from __future__ import annotations

import argparse
import csv
import math
import random
import statistics
import time
from dataclasses import dataclass
from typing import Dict, List, Tuple


@dataclass
class OmegaBooleanCell:
    """Idealized dual-rail threshold/bistable Boolean cell."""
    bit: int
    vdd: float = 1.0
    threshold: float = 0.5

    @property
    def v_plus(self) -> float:
        return self.vdd if self.bit else 0.0

    @property
    def v_minus(self) -> float:
        return 0.0 if self.bit else self.vdd

    def read(self) -> int:
        return int(self.v_plus >= self.threshold)

    def flip(self) -> None:
        self.bit ^= 1


def literal_truth(lit: int, bits: List[int]) -> int:
    value = bits[abs(lit) - 1]
    return value if lit > 0 else 1 - value


def clause_satisfied(clause: List[int], bits: List[int]) -> bool:
    return any(literal_truth(lit, bits) for lit in clause)


def energy(clauses: List[List[int]], bits: List[int]) -> int:
    """Exact clause energy: E_F(x) = number of violated clauses."""
    return sum(not clause_satisfied(c, bits) for c in clauses)


def planted_3sat(n: int, ratio: float, seed: int):
    rng = random.Random(seed)
    planted = [rng.randrange(2) for _ in range(n)]
    m = int(round(ratio * n))
    clauses = []

    for _ in range(m):
        if n >= 3:
            vars_ = rng.sample(range(1, n + 1), 3)
        else:
            vars_ = [rng.randrange(1, n + 1) for _ in range(3)]

        clause = []
        for v in vars_:
            clause.append(v if rng.random() < 0.5 else -v)

        if not clause_satisfied(clause, planted):
            v = abs(clause[0])
            clause[0] = v if planted[v - 1] else -v

        clauses.append(clause)

    assert energy(clauses, planted) == 0
    return clauses, planted


class OmegaClauseFeedbackNetwork:
    """Sparse clause/DAG feedback simulator."""

    def __init__(self, n: int, clauses: List[List[int]], seed: int):
        self.n = n
        self.clauses = clauses
        self.rng = random.Random(seed)
        self.cells = [OmegaBooleanCell(self.rng.randrange(2)) for _ in range(n)]

        self.incident: List[List[int]] = [[] for _ in range(n)]
        for ci, clause in enumerate(clauses):
            for lit in clause:
                self.incident[abs(lit) - 1].append(ci)

        self.satisfied = [False] * len(clauses)
        self.unsat = set()
        self._refresh_all()

    def bits(self) -> List[int]:
        return [cell.read() for cell in self.cells]

    def _eval_clause(self, ci: int) -> bool:
        bits = self.bits()
        return clause_satisfied(self.clauses[ci], bits)

    def _refresh_all(self) -> None:
        bits = self.bits()
        self.unsat.clear()
        for ci, c in enumerate(self.clauses):
            sat = clause_satisfied(c, bits)
            self.satisfied[ci] = sat
            if not sat:
                self.unsat.add(ci)

    def current_energy(self) -> int:
        return len(self.unsat)

    def delta_if_flip(self, var: int) -> int:
        """Exact local energy change using only incident clauses."""
        before = 0
        after = 0
        bits = self.bits()

        for ci in self.incident[var]:
            if not self.satisfied[ci]:
                before += 1

        bits[var] ^= 1

        for ci in self.incident[var]:
            if not clause_satisfied(self.clauses[ci], bits):
                after += 1

        return after - before

    def flip(self, var: int) -> None:
        self.cells[var].flip()
        bits = self.bits()

        for ci in self.incident[var]:
            sat = clause_satisfied(self.clauses[ci], bits)
            self.satisfied[ci] = sat
            if sat:
                self.unsat.discard(ci)
            else:
                self.unsat.add(ci)

    def solve(
        self,
        max_steps: int,
        exploration_probability: float = 0.45,
    ) -> Tuple[bool, int, List[int]]:
        for step in range(max_steps + 1):
            if not self.unsat:
                return True, step, self.bits()

            if step == max_steps:
                break

            ci = self.rng.choice(tuple(self.unsat))
            clause = self.clauses[ci]
            candidates = sorted(set(abs(lit) - 1 for lit in clause))

            if self.rng.random() < exploration_probability:
                chosen = self.rng.choice(candidates)
            else:
                deltas = [(self.delta_if_flip(v), v) for v in candidates]
                best_delta = min(d for d, _ in deltas)
                best_vars = [v for d, v in deltas if d == best_delta]
                chosen = self.rng.choice(best_vars)

            self.flip(chosen)

        return False, max_steps, self.bits()


def solve_with_restarts(
    n: int,
    clauses: List[List[int]],
    seed: int,
    step_factor: int,
    restarts: int,
    exploration_probability: float,
):
    # Per-restart cap = c*n^2, explicitly polynomial in n.
    max_steps = int(step_factor * n * n)
    best_energy = math.inf
    best_bits = None
    total_steps = 0

    for r in range(restarts):
        net = OmegaClauseFeedbackNetwork(
            n, clauses, seed + 1_000_003 * r
        )
        ok, steps, bits = net.solve(
            max_steps=max_steps,
            exploration_probability=exploration_probability,
        )
        total_steps += steps

        e = energy(clauses, bits)
        if e < best_energy:
            best_energy = e
            best_bits = bits

        if ok:
            return {
                "solved": True,
                "energy": 0,
                "steps": total_steps,
                "restarts_used": r + 1,
                "assignment": bits,
            }

    return {
        "solved": False,
        "energy": int(best_energy),
        "steps": total_steps,
        "restarts_used": restarts,
        "assignment": best_bits,
    }


def trap_demo():
    """A satisfiable formula with a nonzero one-flip local minimum."""
    clauses = [
        [-3, 2, -1],
        [3, -2, -1],
        [2, 1, -3],
        [1, -2, -3],
        [2, 1, 3],
        [-3, 1, -2],
        [2, -3, -1],
        [3, -1, 2],
    ]
    x = [0, 0, 1]
    e = energy(clauses, x)
    neigh = []

    for i in range(3):
        y = x.copy()
        y[i] ^= 1
        neigh.append(energy(clauses, y))

    print("Satisfiable local-trap example")
    print("formula clauses:", clauses)
    print("state:", x)
    print("energy:", e)
    print("one-bit-neighbor energies:", neigh)
    print(
        "This state is not satisfying, but no single strictly "
        "energy-decreasing flip exists."
    )


def benchmark(
    sizes: List[int],
    ratio: float,
    trials: int,
    step_factor: int,
    restarts: int,
    exploration_probability: float,
    seed: int,
    csv_path: str,
):
    rows = []

    print(
        "n,m,trials,successes,success_rate,median_steps,"
        "mean_steps,median_ms,mean_ms,max_final_energy"
    )

    for n in sizes:
        solved_count = 0
        steps_list = []
        times_ms = []
        energies = []
        m = int(round(ratio * n))

        for t in range(trials):
            instance_seed = seed + n * 100_000 + t
            clauses, planted = planted_3sat(n, ratio, instance_seed)

            t0 = time.perf_counter()
            result = solve_with_restarts(
                n=n,
                clauses=clauses,
                seed=instance_seed ^ 0x5A5A5A5A,
                step_factor=step_factor,
                restarts=restarts,
                exploration_probability=exploration_probability,
            )
            elapsed_ms = (time.perf_counter() - t0) * 1000.0

            # Independent exact verification of any returned SAT witness.
            if result["solved"]:
                assert energy(clauses, result["assignment"]) == 0
                solved_count += 1

            steps_list.append(result["steps"])
            times_ms.append(elapsed_ms)
            energies.append(result["energy"])

        row = {
            "n": n,
            "m": m,
            "trials": trials,
            "successes": solved_count,
            "success_rate": solved_count / trials,
            "median_steps": statistics.median(steps_list),
            "mean_steps": statistics.mean(steps_list),
            "median_ms": statistics.median(times_ms),
            "mean_ms": statistics.mean(times_ms),
            "max_final_energy": max(energies),
        }
        rows.append(row)

        print(
            f"{n},{m},{trials},{solved_count},"
            f"{row['success_rate']:.3f},"
            f"{row['median_steps']:.1f},{row['mean_steps']:.1f},"
            f"{row['median_ms']:.3f},{row['mean_ms']:.3f},"
            f"{row['max_final_energy']}"
        )

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nSaved benchmark CSV to: {csv_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--benchmark", action="store_true")
    ap.add_argument("--trap-demo", action="store_true")
    ap.add_argument("--sizes", nargs="+", type=int, default=[10, 20, 50, 100])
    ap.add_argument("--trials", type=int, default=20)
    ap.add_argument("--step-factor", type=int, default=50)
    ap.add_argument("--restarts", type=int, default=4)
    ap.add_argument("--explore", type=float, default=0.45)
    ap.add_argument("--ratio", type=float, default=4.2)
    ap.add_argument("--seed", type=int, default=26032009)
    ap.add_argument("--csv", default="omega_boolean_cell_results.csv")
    ap.add_argument("--n", type=int, default=50)
    args = ap.parse_args()

    if args.trap_demo:
        trap_demo()
        return

    if args.benchmark:
        benchmark(
            sizes=args.sizes,
            ratio=args.ratio,
            trials=args.trials,
            step_factor=args.step_factor,
            restarts=args.restarts,
            exploration_probability=args.explore,
            seed=args.seed,
            csv_path=args.csv,
        )
        return

    clauses, planted = planted_3sat(args.n, args.ratio, args.seed)
    result = solve_with_restarts(
        n=args.n,
        clauses=clauses,
        seed=args.seed ^ 0x5A5A5A5A,
        step_factor=args.step_factor,
        restarts=args.restarts,
        exploration_probability=args.explore,
    )

    print(f"n={args.n}, m={len(clauses)}")
    print(result)


if __name__ == "__main__":
    main()
