#!/usr/bin/env python3
"""Lane B statistical gate on per-replicate metrics.
  stat_gate.py <baseline_reps.json> <candidate_reps.json> [--k 3.0] [--slack 0.0] [--dist-factor 1.25]
Each file: {"reps": [ {metric: value, ...}, ... ], "dist": {"base-base": [..]} or "cand-base": [..]}  (dist optional).
Rules, per metric present in the baseline:
  band  = [mean - k*sd, mean + k*sd] of the baseline reps, widened to include every baseline rep and by --slack (relative);
  every candidate rep must fall inside the band;
  distances: mean(cand-base) <= dist-factor * max(base-base).
Prints GATE PASS or GATE FAIL: <first failures> (first line), then a table. Exit 0 on pass, 1 on fail.
Calibrate k on the null candidate: it must always pass."""
import argparse, json, statistics as st, sys
ap = argparse.ArgumentParser(); ap.add_argument('base'); ap.add_argument('cand')
ap.add_argument('--k', type=float, default=3.0); ap.add_argument('--slack', type=float, default=0.0); ap.add_argument('--dist-factor', type=float, default=1.25)
a = ap.parse_args()
B, Cn = json.load(open(a.base)), json.load(open(a.cand))
fails, lines = [], []
for m in sorted(B['reps'][0]):
    bv = [r[m] for r in B['reps'] if m in r]
    if not bv or not all(isinstance(x, (int, float)) for x in bv): continue
    mu = st.mean(bv); sd = st.stdev(bv) if len(bv) > 1 else 0.0
    lo = min(mu - a.k * sd, min(bv)); hi = max(mu + a.k * sd, max(bv))
    lo -= abs(lo) * a.slack; hi += abs(hi) * a.slack
    cv = [r.get(m) for r in Cn['reps']]
    bad = [i for i, x in enumerate(cv) if x is None or not (lo <= x <= hi)]
    lines.append(f'{m:32s} base {mu:.6g} ± {sd:.3g} band [{lo:.6g}, {hi:.6g}]  cand ' + ' '.join('-' if x is None else f'{x:.6g}' for x in cv) + ('  FAIL' if bad else ''))
    if bad: fails.append(f'{m} rep{bad[0]+1}={cv[bad[0]]} outside [{lo:.6g},{hi:.6g}]')
bb = B.get('dist', {}).get('base-base'); cb = Cn.get('dist', {}).get('cand-base')
if bb and cb:
    lim = a.dist_factor * max(bb); ok = st.mean(cb) <= lim
    lines.append(f'distance cand-base mean {st.mean(cb):.4g} vs {a.dist_factor} x max base-base {max(bb):.4g}' + ('' if ok else '  FAIL'))
    if not ok: fails.append(f'distance cand-base {st.mean(cb):.4g} > {lim:.4g}')
print('GATE PASS' if not fails else 'GATE FAIL: ' + '; '.join(fails[:4]))
print('\n'.join(lines))
sys.exit(0 if not fails else 1)
