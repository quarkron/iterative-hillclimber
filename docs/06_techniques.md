# Techniques catalogue

Patterns that paid off in real loops, with the evidence type that made each one safe. Each is a template, not a rule.

## Remove work the result does not depend on (Lane A)
- **Skip rebuilds whose inputs did not change**: compare a signature of the inputs (the exact text/bytes that would be
  read, plus configuration) with the last rebuild's; skip when equal. VERIFY: do the rebuild anyway and compare a
  fingerprint of the resulting state.
- **Lazy evaluation of expensive side products** nobody reads in the hot path (e.g. a bond-exclusion list rebuilt at every
  data read although the fused kernels build their own): mark it stale, rebuild on demand before any consumer.
- **Skip redundant transfers**: upload only what the host changed (report "site types only" from the host step; the
  device side keeps the rest); download lazily (mark the host copy stale; every host accessor downloads on first use; an
  upload while stale sends only what the host could have changed). VERIFY: download and compare on every skipped transfer.
- **Move small host reads to the device**: a mask or gather computed on the GPU instead of downloading the whole state to
  compute it on the CPU.
- **Resident processes**: keep a server process alive across calls instead of paying process, runtime and library start
  per call (identity: outputs of the same inputs are identical; check memory returns to baseline between requests).

## Exact faster reimplementations (Lane A)
- **Override a library function from the executable** when the library is fixed (e.g. a prebuilt simulation library):
  define the same mangled symbol in the executable, export it (`-Wl,--export-dynamic-symbol=<sym>`), reach the original
  with `dlsym(RTLD_NEXT, ...)`. Handle only the plain case exactly; pass everything else to the original. Works for direct
  calls, virtual calls and member-function pointers (check with `LD_DEBUG=bindings`).
- **Formatting**: `std::to_chars(v, chars_format::general, 6)` is specified as `printf("%.6g")`; verify on millions of
  values (real data + random over all exponents + edge cases) and then byte-compare whole files in VERIFY.
- **Parsing**: plain-numeric lines parsed with a hand-written integer parser replicating the library's checks, falling back
  on anything else.

## GPU kernels
- **Warp-per-item builders that preserve order**: when one thread per item walks a long, uneven candidate list (tail threads
  set the kernel time), give each item a warp, flatten its candidates with a warp prefix sum, test 32 at once and place
  accepted ones with ballot + popcount so the output order equals the serial loop's. VERIFY: build both, compare rows.
- **Launch shape and registers**: launch bounds to fit one more block per SM; batch loads before barriers; fetch k items per
  round of loads; skip blocks outside the live region (bounding box of occupied/live sites); skip empty windows.
- **Latency-bound vs bandwidth-bound**: most per-step kernels in these codes are latency-bound; fusing launches or CUDA
  graphs rarely helps (measure before building); reducing per-thread dependent load chains does.
- **Precision**: FP32 pair math with FP64 storage and FP64 reductions is a Lane B candidate; tolerance-sensitive reductions
  (energies compared at 1e-5 relative) must stay FP64. The gain is large on consumer GPUs (FP64 at 1/64 rate), modest on
  data-centre GPUs.

## Host (Python) pipelines
- Parse static tables once per process; cache by (file, sheet, mtime); build lookup dicts once instead of filtering data
  frames per lookup; vectorise scans (reduce over the slot axis first; `flatnonzero` of a bool mask instead of `argwhere`
  of integers); set-based duplicate checks; model templates reused when the structure is unchanged.

## Anti-patterns (measured failures)
- Raising a solver's tolerances or step caps "because the result is converged anyway": failed the statistical gate every
  time; the path is part of the dynamics.
- CUDA graphs / programmatic dependent launch on latency-bound kernel chains: no gain.
- Folding a control kernel into the last block of a compute kernel: slower (register pressure, serialisation).
- Packing data "for fewer loads" when it raises registers past an occupancy step: slower.
- Timing on a single-GPU point for a change on the device side of one arm of a two-GPU application: hidden by the other arm.
