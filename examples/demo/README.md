# Toy application for the tutorial

`nbody_slow.py`: 2-D N-body, velocity Verlet, naive O(N^2) forces in pure Python loops. Deterministic (fixed seed): the
output `traj.txt` is byte-identical between runs, so a Lane A gate is a single hash comparison. See the top-level README
for the tutorial. It is small on purpose: every kind of candidate (identical, reordered, different numerics) is one edit away.
