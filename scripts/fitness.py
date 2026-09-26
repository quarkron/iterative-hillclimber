#!/usr/bin/env python3
"""Fitness of a candidate: geometric-mean speedup over points against the baseline.
  fitness.py <baseline.json> <candidate timing.json> [--out fitness.json] [--weights w.json]
Both JSON files map point name -> seconds (lower is better). Points missing from either file are ignored (listed on stderr).
Optional weights (point -> weight) give a weighted geometric mean. Prints FITNESS <x> and writes {"fitness", "per_point"}."""
import argparse, json, math, sys
ap = argparse.ArgumentParser(); ap.add_argument('baseline'); ap.add_argument('candidate'); ap.add_argument('--out'); ap.add_argument('--weights')
a = ap.parse_args()
b, c = json.load(open(a.baseline)), json.load(open(a.candidate))
w = json.load(open(a.weights)) if a.weights else {}
common = sorted(set(b) & set(c))
for k in sorted(set(b) ^ set(c)): print(f'point {k} missing from one side, ignored', file=sys.stderr)
if not common: sys.exit('no common points')
per = {k: b[k] / c[k] for k in common}
tw = sum(w.get(k, 1.0) for k in common)
fit = math.exp(sum(w.get(k, 1.0) * math.log(per[k]) for k in common) / tw)
print(f'FITNESS {fit:.4f}  ' + '  '.join(f'{k} {per[k]:.3f}x' for k in common))
if a.out: json.dump(dict(fitness=fit, per_point=per, baseline=b, candidate=c), open(a.out, 'w'), indent=1)
