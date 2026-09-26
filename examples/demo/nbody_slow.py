#!/usr/bin/env python3
"""Toy application for the iterative-hillclimber tutorial: a deliberately slow 2-D N-body integrator (pure Python loops).

    python3 nbody_slow.py [--n 400] [--steps 60] [--seed 1] [--out traj.txt]

Writes the final positions and velocities (one line per body, %.17g) and prints the wall time. The output is the "result"
the loop must preserve: a candidate that changes it at all is not Lane A. Everything here is intentionally naive so that a
loop has obvious candidates (pair symmetry, hoisted constants, vectorisation) with different gate consequences."""
import argparse, math, random, time


def forces(xs, ys, ms, eps2):
    n = len(xs)
    fx = [0.0] * n
    fy = [0.0] * n
    for i in range(n):
        for j in range(n):
            if i == j:
                continue
            dx = xs[j] - xs[i]
            dy = ys[j] - ys[i]
            r2 = dx * dx + dy * dy + eps2
            inv = 1.0 / (r2 * math.sqrt(r2))
            fx[i] += ms[j] * dx * inv
            fy[i] += ms[j] * dy * inv
    return fx, fy


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--n', type=int, default=400); ap.add_argument('--steps', type=int, default=60)
    ap.add_argument('--seed', type=int, default=1); ap.add_argument('--dt', type=float, default=1e-3)
    ap.add_argument('--out', default='traj.txt')
    a = ap.parse_args()
    rng = random.Random(a.seed)
    xs = [rng.uniform(-1, 1) for _ in range(a.n)]; ys = [rng.uniform(-1, 1) for _ in range(a.n)]
    vx = [0.0] * a.n; vy = [0.0] * a.n; ms = [rng.uniform(0.5, 1.5) / a.n for _ in range(a.n)]
    eps2 = 1e-4
    t0 = time.time()
    fx, fy = forces(xs, ys, ms, eps2)
    for _ in range(a.steps):                      # velocity Verlet
        for i in range(a.n):
            vx[i] += 0.5 * a.dt * fx[i]; vy[i] += 0.5 * a.dt * fy[i]
            xs[i] += a.dt * vx[i]; ys[i] += a.dt * vy[i]
        fx, fy = forces(xs, ys, ms, eps2)
        for i in range(a.n):
            vx[i] += 0.5 * a.dt * fx[i]; vy[i] += 0.5 * a.dt * fy[i]
    wall = time.time() - t0
    with open(a.out, 'w') as f:
        for i in range(a.n):
            f.write('%.17g %.17g %.17g %.17g\n' % (xs[i], ys[i], vx[i], vy[i]))
    print('wall %.3f s' % wall)


if __name__ == '__main__':
    main()
