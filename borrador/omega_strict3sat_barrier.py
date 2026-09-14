#!/usr/bin/env python3
"""
Strict 3-SAT barrier family for the current OMEGA clause-feedback rule.
Every clause has exactly three distinct variables.
"""

import argparse
import math


def two_clause_gadget(a, b, z):
    return [[a, b, z], [a, b, -z]]


def unit_gadget(x, u, v):
    return [
        [x, u, v],
        [x, u, -v],
        [x, -u, v],
        [x, -u, -v],
    ]


def strict_barrier_formula(n):
    if n < 2:
        raise ValueError("n must be >= 2")

    clauses = []
    next_var = n + 1

    # Equality-chain copies.
    for i in range(1, n):
        w = n - i
        for _ in range(w):
            z = next_var
            next_var += 1
            clauses.extend(two_clause_gadget(-i, i + 1, z))

            z = next_var
            next_var += 1
            clauses.extend(two_clause_gadget(i, -(i + 1), z))

    # Strict gadget for unit clause (x_n).
    u, v = next_var, next_var + 1
    next_var += 2
    clauses.extend(unit_gadget(n, u, v))

    return next_var - 1, clauses


def lit_truth(lit, bits):
    value = bits[abs(lit) - 1]
    return value if lit > 0 else 1 - value


def energy(clauses, bits):
    return sum(
        not any(lit_truth(l, bits) for l in c)
        for c in clauses
    )


def macro_bits(num_total, n, k, aux_pattern=0):
    bits = [0] * num_total
    bits[n-k:n] = [1] * k
    # auxiliary pattern 0 leaves all auxiliaries zero
    return bits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=10)
    ap.add_argument("--explore", type=float, default=0.45)
    args = ap.parse_args()

    total_vars, clauses = strict_barrier_formula(args.n)
    n = args.n
    p = args.explore

    print(f"original vars: {n}")
    print(f"total vars: {total_vars}")
    print(f"strict 3-clauses: {len(clauses)}")
    assert all(len(c) == 3 for c in clauses)
    assert all(len({abs(x) for x in c}) == 3 for c in clauses)

    print("macro-state energies with auxiliary bits = 0:")
    for k in range(n + 1):
        bits = macro_bits(total_vars, n, k)
        print(k, energy(clauses, bits))

    R0 = (3.0 - p) / (2.0 * p)
    L = n - 1
    hit_upper = (R0 - 1.0) / (R0 ** L - 1.0)
    excursion_lower = 1.0 / hit_upper

    print(f"R0 lower bound on backward/forward ratio: {R0}")
    print(f"upper bound on one-excursion barrier-crossing probability: {hit_upper}")
    print(f"expected excursions lower bound: {excursion_lower}")
    print(f"log10 expected-excursion lower bound: {math.log10(excursion_lower)}")


if __name__ == "__main__":
    main()
