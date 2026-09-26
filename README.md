# iterative_hillclimber

LLM-guided autoresearch loop: a disciplined, journaled hill-climbing workflow for making an existing scientific application faster
without changing its results. Inspired by [ERA: An AI system to help scientists write expert-level empirical software](https://www.nature.com/articles/s41586-026-10658-6).

Application-independent: the method (docs/), templates for a new loop (templates/),
generic tools (scripts/), and a worked example (examples/).

- Agents: start at [SKILL.md](SKILL.md), then `docs/00_overview.md`.
- People: `docs/00_overview.md` is the one-page version; `examples/case_study.md` shows how it was run on a real application.

## Install as a Claude Code skill
    ln -s "$PWD" ~/.claude/skills/iterative-hillclimber      # user-level skill (available in every project)
    # or, per project:  ln -s "$PWD" <project>/.claude/skills/iterative-hillclimber
The skill is `SKILL.md` (frontmatter name/description) plus the files it points to.

## Using it with Claude Code (quick tutorial)

### 1. Install
    git clone https://github.com/quarkron/iterative-hillclimber.git
    mkdir -p ~/.claude/skills
    ln -s "$PWD/iterative-hillclimber" ~/.claude/skills/iterative-hillclimber
Start (or restart) Claude Code. The skill is picked up from `~/.claude/skills/`; Claude loads it automatically when a request
matches its description ("make X faster without changing its results", "resume the optimisation loop"), or you can invoke
it explicitly by typing `/iterative-hillclimber` followed by your request.

### 2. Try it on the toy application
`examples/demo/nbody_slow.py` is a deliberately slow pure-Python N-body integrator (~1 s per run, no GPU needed). Copy it into
a scratch project and ask Claude to optimise it:

    mkdir -p ~/hillclimb-demo && cp iterative-hillclimber/examples/demo/nbody_slow.py ~/hillclimb-demo/
    cd ~/hillclimb-demo && git init -q && git add . && git commit -qm "toy app" && claude

Then, in Claude Code:

    > /iterative-hillclimber Set up an optimisation loop for nbody_slow.py. The output file (traj.txt) must stay
      byte-identical. Put the loop in ./era.

Claude will, following the skill: create `era/STATE.md` and `era/candidates/LEDGER.md` from the templates; make a worktree
with `era-demo` / `era-demo-dev` branches; define a point (e.g. `--n 400 --steps 60`, median of 5 runs), record the
baseline timing and the output hash in `era/baseline/`; and run the null candidate (fitness ~1.00) to prove the harness.

    > Profile the head and run three candidates.

Expect it to profile first (cProfile shows the time in `forces`) and to classify each idea by what the gate says, not by
what it looks like. On the toy, three natural candidates behave like this (timings from one machine):
| idea | lane | gate result | speed |
|---|---|---|---|
| bind lists and `math.sqrt` to locals, accumulate in locals | A | output hash identical | ~1.25x |
| pair symmetry (each i<j pair once, apply +/-) | A | hash **identical**: every body still receives its terms in the same order, and the mirrored term is an exact sign flip | ~1.4x |
| vectorise with numpy | B | hash differs (max relative difference ~5e-14) | ~5.8x |
The second one looks like a reordering and is not: check, don't assume. The third is a numerics change: Claude reports it
with the measured difference and asks whether you allow Lane B.

Each candidate is one commit on the dev branch, one row in `era/candidates/LEDGER.md`, and a dated entry in `era/STATE.md`.

    > What's the status of the loop?        # progress, head, fitness, what is running
    > Allow Lane B with a tolerance of 1e-12 on positions, then continue.   # an owner decision, recorded in STATE.md
    > We've plateaued, stop and summarise.

### 3. Resume later
Open Claude Code in the same project and say "resume the optimisation loop in ./era". The skill tells Claude to read
`era/STATE.md` and the ledger first, so a new session (or another agent) continues where the last one stopped.

### 4. On a real application
Same conversation, larger pieces: describe what must stay identical (files, counts, statistics), what the expensive stages
are, and which GPUs/cores the loop may use. The scripts in `scripts/` (queue runner, GPU guard, thermal watchdog, Slurm
lanes, statistical gate, ensemble check, critical-path model, CUPTI trace) are there for long-running, multi-GPU loops;
the toy needs none of them.

## Requirements
bash, git, python3 (numpy for `ensemble_check.py`), docker and nvidia-smi for the GPU tools, Slurm optional (lanes).

## Layout
    SKILL.md              skill entry point: when to use, reading order, non-negotiables
    docs/                 00 overview ... 08 plateau and stopping, lessons_traps
    templates/            STATE.md, LEDGER.md, HARNESS.md, candidate commit message, queue job, config.env
    scripts/              queue runner, lanes (Slurm), GPU guard, thermal watchdog, evaluator skeleton, fitness,
                          statistical gate, ensemble check, critical-path model, CUPTI trace
    examples/             worked case study
