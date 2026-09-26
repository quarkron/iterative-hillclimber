# Gates

Gates run before timing. A candidate that fails a gate is rejected whatever its speed.

## Lane A: identity
The candidate's outputs must be bitwise identical to the head's at every point.
- **Output hashes**: lattices, counts, files written, final states (sha256 of the bytes).
- **Input hashes of expensive kernels** (`<APP>_INPUT_HASH=1`): FNV-1a over everything a kernel receives (positions, types,
  topology, exclusion lists, coefficients, box). When a stage downstream is not reproducible run to run (atomics,
  non-deterministic scheduling), identical *inputs* to the physics are the strongest evidence available. Do not hash
  structs with padding (uninitialised bytes differ run to run).
- **VERIFY modes** (the most powerful tool): the candidate computes its result and the original result in the same run and
  compares, per call:
  - a replacement parser/formatter renders both texts and compares bytes;
  - a replacement builder writes into a scratch buffer and a comparison kernel counts differing rows;
  - a skipped transfer downloads the device copy and compares it with the host copy;
  - a device-side computation is recomputed on the host and compared.
  Print a summary every N calls and every difference; count calls so you know the path was actually taken (a VERIFY that
  prints nothing usually means the new path never ran).
- Cover the regimes: several phases of a long run, calls with and without the unusual cases (e.g. topology changes).

## Lane B: statistical equivalence
When bitwise identity is impossible:
1. Calibrate: run the **baseline** R times (>= 3) at the point and record every statistic of interest (means, high
   percentiles, maxima, counts of rare events) and pairwise distances between replicate outputs (e.g. RMSD).
2. Band: accept a candidate statistic inside `[min_base - slack, max_base + slack]` or within k·sd of the base mean
   (calibrate k so the null candidate always passes); for distances require `cand-base <= c · max(base-base)`.
3. Run the candidate R times; every rep must pass every band. `scripts/stat_gate.py` implements this on JSON metrics.
4. Keep topology/invariant checks exact even in Lane B (what can be identical should be).

A failing statistic is information: it tells you the change is a model change (e.g. a mean per-call displacement that
shifts outside the base band when a minimiser's step cap is raised: the "numerics" change moved the path).

## Whole-run ensemble validation (for the accumulated head)
Short points cannot prove the whole run is unchanged. Periodically (and before declaring success):
1. Run K full runs of the head (K >= 3 seeds; pair seeds with production replicates if possible).
2. Score them with the **application's own analysis** (the scripts that produced the published figures) and score each
   production replicate the same way, alone.
3. Report, per observable: production mean ± sd and range, each head seed, inside/outside range, Welch t of the head mean
   against the production mean.
4. Species/element-level typicality with leave-one-out calibration (`scripts/ensemble_check.py`): for every tracked
   quantity with enough counts, is the head run inside the production range, and how often |z| > 3 — compared with each
   production replicate scored against the other replicates. A head run should be as typical as a production run is.
5. One value outside the range among dozens is expected; look at whether it is explained (e.g. a count taken at an event
   time that itself fluctuated) and whether other seeds agree.

Write the outcome into STATE.md and the page; this is what the owner needs to trust the speedups.
