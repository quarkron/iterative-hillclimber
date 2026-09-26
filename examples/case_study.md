# Case study: running the loop on a large coupled GPU simulation (method only)

This describes how the loop was organised on a real application, without its results.

## The application's shape
A long simulation made of two arms running in parallel and meeting at fixed intervals: a lattice solver on one GPU with
frequent host-side (Python) hooks, and a separate molecular-dynamics-style program (minimisation + Brownian dynamics, built
on a prebuilt library) on a second GPU, plus once-per-interval solvers on the host. The interval cost is the slower arm.

## Lanes, points and gates
| lane | point | gate |
|---|---|---|
| host hooks (several) | short whole-application run; replays of captured hook inputs | byte-identical captured outputs |
| lattice solver kernels (C++/CUDA library) | short run + a kernel benchmark on a captured frame | identical lattice and counts |
| side program (C++/CUDA + prebuilt library) | replays of captured production steps at several phases of a run | statistical band (per-call displacement and bond statistics vs base-base spread); topology identical |

## How the bottleneck moved
The critical-path model decided the order: speeding up the arm that did not pace a phase bought nothing, so work alternated
between arms as each became the pacing one. The sequence was roughly: host hooks (vectorised scans, cached tables, reused
model templates) → the side program's kernels (many small launch-shape and memory-layout candidates, neighbour cutoffs per
type pair, exclusion lists from topology) → the side program's host overhead (a resident server process; skipping
identical rebuilds; exact faster replacements of library routines defined in the executable) → order-preserving
warp-per-item neighbour builders → the lattice arm's host/device traffic (uploading only what the hook changed, lazy
downloads, device-side reads for the hook).

## What failed, and what it taught
- Loosening a minimiser's tolerances or raising its step cap: fast and "converged", but the statistical gate failed at every
  value tried; the minimiser's path is part of the dynamics. Recorded as a decision for the owner, not a candidate.
- Launch-overhead techniques (graphs, dependent launch) on latency-bound kernel chains: no gain.
- Device-side changes timed on a single-GPU test point were hidden by the other arm sharing the GPU; re-measured in the
  production layout.

## Validation
Periodic full runs of the accumulated head with several seeds, scored with the application's own published analysis
against the production ensemble (per-observable ranges and Welch tests, element-level typicality with a leave-one-out null).

## Where it stopped
At a plateau where the dominant kernels were latency-bound and the remaining large levers were model decisions (step caps,
precision, coupling interval), which were written up for the owner.
