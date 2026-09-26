#!/usr/bin/env python3
"""Summarise a cuptitrace trace.bin (records u64 start,end u32 name,stream; footer name table): per kernel count, total, mean,
share of GPU busy time, and the idle gaps between consecutive kernels (host-side stalls).   trace_summary.py <trace.bin> [top=25]"""
import struct, sys, collections
p = sys.argv[1]; top = int(sys.argv[2]) if len(sys.argv) > 2 else 25
b = open(p, 'rb').read()
magic, ver, off = struct.unpack_from('<IIQ', b, 0)
n = (off - 16) // 24
recs = [struct.unpack_from('<QQII', b, 16 + 24 * i) for i in range(n)]
k = off; nn, = struct.unpack_from('<I', b, k); k += 4; names = []
for _ in range(nn):
    L, = struct.unpack_from('<I', b, k); k += 4; names.append(b[k:k + L].decode(errors='replace')); k += L
recs.sort()
tot = collections.defaultdict(float); cnt = collections.Counter(); busy = 0.0
for s, e, ni, st in recs:
    d = (e - s) / 1e6; tot[ni] += d; cnt[ni] += 1; busy += d
span = (recs[-1][1] - recs[0][0]) / 1e6
gaps = collections.Counter(); gap_ms = 0.0; big = 0.0
for (s0, e0, n0, _), (s1, e1, n1, _) in zip(recs, recs[1:]):
    g = (s1 - e0) / 1e6
    if g > 0: gap_ms += g
    if g > 0.05: big += g; gaps[(names[n0][:40], names[n1][:40])] += g
print(f'{n} kernels, span {span:.1f} ms, busy {busy:.1f} ms, idle {gap_ms:.1f} ms (gaps > 50 us: {big:.1f} ms)')
for ni, t in sorted(tot.items(), key=lambda x: -x[1])[:top]:
    print(f'{t:9.1f} ms {100*t/busy:5.1f}%  n={cnt[ni]:7d}  mean {1000*t/cnt[ni]:8.1f} us  {names[ni][:90]}')
print('largest idle gaps (after -> before):')
for (a, c), g in gaps.most_common(12): print(f'{g:8.1f} ms  {a}  ->  {c}')
