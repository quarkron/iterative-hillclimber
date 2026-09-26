#!/usr/bin/env python3
"""Critical-path projection for an application whose two arms (A: paced loop, B: coupled side process) run in parallel and
meet every interval: each bin costs max(A, B) + the serial part.
  critical_path.py <model.json>
model.json:
  {"bins": [{"t0": 0, "t1": 600, "A": {"comp1": s_per_unit, ...}, "B": s_per_unit, "serial": s_per_unit}, ...],
   "speedup_A": {"comp1": x, ...},            # measured per-component speedups of arm A at the points
   "speedup_B": [[t, x], ...] or x,           # arm B speedup at phase points (interpolated), or one number
   "serial_factor": 1.0}                      # optional scaling of the serial part
Prints the reference and projected totals (units of the bins' time axis x cost) and a per-bin table.
Calibrate against one measured full run: bin-average models under-predict the per-interval max of two noisy arms."""
import json, sys
m = json.load(open(sys.argv[1])); sa = m.get('speedup_A', {}); sb = m.get('speedup_B', 1.0); sf = m.get('serial_factor', 1.0)
def spB(t):
    if not isinstance(sb, list): return sb
    pts = sorted(sb)
    if t <= pts[0][0]: return pts[0][1]
    for (x0, v0), (x1, v1) in zip(pts, pts[1:]):
        if t <= x1: return v0 + (v1 - v0) * (t - x0) / (x1 - x0)
    return pts[-1][1]
ref = new = 0.0
print('   t0     t1   ref/unit  A_new  B_new  wait  new/unit')
for b in m['bins']:
    w = b['t1'] - b['t0']; A = sum(b['A'].values()); A2 = sum(v / sa.get(k, 1.0) for k, v in b['A'].items())
    B2 = b['B'] / spB(0.5 * (b['t0'] + b['t1'])); S = b.get('serial', 0.0)
    r = max(A, b['B']) + S; n = max(A2, B2) + S * sf
    ref += r * w; new += n * w
    print(f"{b['t0']:6g} {b['t1']:6g} {r:9.3f} {A2:6.3f} {B2:6.3f} {max(0.0, B2 - A2):5.3f} {n:9.3f}")
print(f'reference total {ref:.6g}, projected total {new:.6g}, speedup {ref / new:.3f}x')
