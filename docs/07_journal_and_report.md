# Journal and report

## STATE.md (`templates/STATE.md`)
The single file a new session reads first. Top: what the loop is, the one-command evaluation, the baseline, the lanes
table (point, gate, status), the node etiquette. Below: a dated log, newest last. Write an entry for every:
- accept / reject (candidate number, revision, the gate evidence in one line, the timing, the new head);
- measurement that changes the plan (a profile, a trace, a phase re-measurement, a model projection);
- harness change and every trap (what happened, how to avoid it);
- owner directive (quote it), and every decision you left to the owner.
Use absolute dates and times. Keep numbers in the entry (the reader should not need to open a log to know the result).

## LEDGER.md (`templates/LEDGER.md`)
One Markdown table row per evaluation, appended by the evaluator (never edited):
`| lane | NNN_slug | ISO time | gates / evidence | fitness | per-point timings | note |`.
Rows marked `(RESCORED ...)` restate an earlier candidate under a new basis (e.g. a changed timing basis); keep both.

## The page
A generated HTML page (rebuilt after every evaluation) that shows: the headline (baseline → head, with the basis), per
lane what was accepted/rejected, fitness vs candidate with the running best, where the time went (baseline vs head per
component), the whole-run phases (model vs measured), every candidate with its detail, and the validation of the head.
Generate it from the ledger + candidate directories + baseline files so it never drifts from the data.

## Talking to the owner
- Lead with the answer (faster by how much, still identical / statistically equal, what is running).
- Separate measured numbers from projections; say which layout and which point a number comes from.
- For anything that changes the model, present the trade-off (speed vs the gate statistic that moved) and ask.
- Say when a result surprised you and what you did about it; say when something failed and why.
- Report the state of every running job (progress, health, ETA) when asked for status.
