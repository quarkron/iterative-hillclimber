# <LOOP> — STATE (read this first in every session)

Last updated: <ISO date/time> (<one line: head, what is running>)

## What this is
<Application>, <what "faster" means here>, <what must stay identical / statistically equal>. Owner framing: "<quote>".
Layout: notes/HARNESS.md (how), notes/PROFILE_<date>.md (why), baseline/, candidates/LEDGER.md, report/, queue/.

## One-command candidate evaluation
    cd <loop> && REV=<commit> tools/eval_candidate.sh <lane> <NNN_slug> "<note>"
Candidate = one commit on the lane's dev branch. Accept = fast-forward the lane branch; reject = keep patch, reset dev.
Worktrees: <repo> -> <path> (branches era-<app> / era-<app>-dev, tag pre-era-<app>-<date>).

## Baseline
<per-component cost of the baseline, per unit of work; total; how it was measured (which runs, median of what)>

## Lanes
| lane | point(s) | gate | status | next candidate |
|---|---|---|---|---|

## Node etiquette
<which GPUs/cores the loop may use, which to avoid and why, who else uses the node>

## Log
## <date> <time>
- <entry>
