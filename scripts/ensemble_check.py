#!/usr/bin/env python3
"""Whole-run typicality of a candidate run against a production ensemble, with leave-one-out calibration.
  ensemble_check.py --head run.csv --prod p1.csv p2.csv ... [--times 1800,3600] [--min 10] [--out result.json]
CSV layout (one file per run): first row = header ("name,t0,t1,..."), then one row per tracked quantity: name, value at each time.
Every production file must list the same quantities in the same order. For each requested time (nearest column) and every
quantity whose production mean >= --min:
  inside = the run's value lies within the production [min, max]; z = (value - mean) / sd.
Scored for the head against the whole ensemble with one replicate left out (averaged over which), and for every production
replicate against the other ones (the null). A head run is typical if its 'inside' and '|z|>3' rates match the null's."""
import argparse, csv, json, numpy as np
ap = argparse.ArgumentParser(); ap.add_argument('--head', required=True); ap.add_argument('--prod', nargs='+', required=True)
ap.add_argument('--times', default=''); ap.add_argument('--min', type=float, default=10.0); ap.add_argument('--out')
a = ap.parse_args()
def load(path, times):
    with open(path, newline='') as fh:
        r = csv.reader(fh); h = next(r); t = np.array(h[1:], float)
        ts = times or [float(t[-1])]
        idx = [int(np.argmin(abs(t - x))) + 1 for x in ts]
        names, rows = [], []
        for row in r:
            if row: names.append(row[0]); rows.append([float(row[i]) if row[i] else np.nan for i in idx])
    return names, np.array(rows), ts
times = [float(x) for x in a.times.split(',') if x]
nh, H, times = load(a.head, times)
P = []
for p in a.prod:
    n, x, _ = load(p, times)
    if n != nh: raise SystemExit(f'quantity list differs in {p}')
    P.append(x)
P = np.array(P)
def score(x, ens):
    m, s = ens.mean(0), ens.std(0, ddof=1); keep = m >= a.min
    inside = (x >= ens.min(0)) & (x <= ens.max(0)); z = np.where(s > 0, (x - m) / np.where(s > 0, s, 1), 0.0)
    return {str(times[j]): dict(n=int(keep[:, j].sum()), inside=float(inside[keep[:, j], j].mean()), z3=float((abs(z[keep[:, j], j]) > 3).mean())) for j in range(len(times))}
avg = lambda L: {t: {k: float(np.mean([l[t][k] for l in L])) for k in ('n', 'inside', 'z3')} for t in L[0]}
res = dict(head=avg([score(H, np.delete(P, i, 0)) for i in range(len(P))]), null=avg([score(P[i], np.delete(P, i, 0)) for i in range(len(P))]))
res['null_worst'] = {t: dict(inside=min(score(P[i], np.delete(P, i, 0))[t]['inside'] for i in range(len(P))),
                             z3=max(score(P[i], np.delete(P, i, 0))[t]['z3'] for i in range(len(P)))) for t in res['head']}
for t in res['head']:
    h, n, w = res['head'][t], res['null'][t], res['null_worst'][t]
    print(f"t={t}: {h['n']:.0f} quantities | inside: run {h['inside']:.3f}  ensemble {n['inside']:.3f} (worst {w['inside']:.3f}) | |z|>3: run {h['z3']:.4f}  ensemble {n['z3']:.4f} (worst {w['z3']:.4f})")
if a.out: json.dump(res, open(a.out, 'w'), indent=1)
