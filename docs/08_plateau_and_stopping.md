# Plateaus, stopping, and the owner's decisions

## Recognising a plateau
- The critical-path model's remaining levers are each worth ~1-2 % of the run and each needs a large or risky change.
- The kernels that dominate are latency-bound and have been through many candidates; the last few candidates returned <2 %.
- The remaining big levers are model changes (tolerances, step caps, coupling intervals, precision with different results).

Write the plateau down: the per-component costs now, the levers left with estimated savings and effort, the projected
floor with all of them, and what would move the floor (the owner's decisions). Then stop, unless the owner asks to go on.

## Decisions that are the owner's
- Numerics that change results (tolerances, step caps, precision) even if a statistical gate passes: present the gate
  statistics, the speed gain, and offer a whole-run ensemble validation of the changed model.
- Coupling changes between parallel arms (coarser intervals, asynchronous/lagged coupling). Prefer deterministic variants
  (a fixed lag) over wall-clock-dependent ones: the latter make runs irreproducible and timing-dependent.
- Hardware and booking (which GPUs, whether to hold them idle).

## Beyond greedy (optional)
Greedy hill climbing is efficient while bottlenecks are distinct. Consider a wider search only when knobs interact:
- beam search over exposed parameters (list skins, check intervals, chunk sizes, launch bounds) with the gate + critical
  path as the score, keeping the best few heads;
- re-trying rejected candidates on the current head (context changed: registers, occupancy, other kernels);
- keeping two competing heads (e.g. FP32 vs FP64 branch) and expanding the one that projects best.
Budget it explicitly: each evaluation costs minutes to hours and noise is several percent.

## Validation before declaring success
Run the accumulated head for full runs (several seeds) and validate with the application's own analysis against the
production ensemble (03_gates.md). Report measured whole-run time against the model, bin by bin.
