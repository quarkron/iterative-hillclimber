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

## Requirements
bash, git, python3 (numpy for `ensemble_check.py`), docker and nvidia-smi for the GPU tools, Slurm optional (lanes).

## Layout
    SKILL.md              skill entry point: when to use, reading order, non-negotiables
    docs/                 00 overview ... 08 plateau and stopping, lessons_traps
    templates/            STATE.md, LEDGER.md, HARNESS.md, candidate commit message, queue job, config.env
    scripts/              queue runner, lanes (Slurm), GPU guard, thermal watchdog, evaluator skeleton, fitness,
                          statistical gate, ensemble check, critical-path model, CUPTI trace
    examples/             worked case study
