---
name: advisor-review
description: "For pull requests only. When this session opens a pull request or pushes new work to an open pull request, have two stronger models review the branch in turn, fixing and re-reviewing with each until it comes back clean (up to 5 rounds each), before reporting the pull request as ready: first the stronger model of your own family, then the other family's. In Claude Code the reviewers are Fable 5.2 then GPT-6 Astra; in Codex they are GPT-6 Astra then Fable 5.2. Outside that, use it only when the user asks for it on a pull request or branch. Skip pull requests that only fix a typo or bump a version, and never use it when you are the reviewer."
license: "MIT; see LICENSE.txt"
---

# Advisor Review

The session's own model is the executor and does all of the work: for example Opus 5.5 in Claude Code or GPT-5.6 Sol in Codex. When that work goes into a pull request, two stronger models review the pull request's branch, one after the other. With each reviewer the executor loops: review, fix, fresh review, until a round comes back clean. No delegation: the reviewers only review.

| Harness | Executor | First reviewer | Second reviewer |
| --- | --- | --- | --- |
| Claude Code | The session model, for example Opus 5.5 | Fable 5.2 | GPT-6 Astra |
| Codex | The session model, for example GPT-5.6 Sol | GPT-6 Astra | Fable 5.2 |

Whatever model the session runs on, the reviewers and their order stay the same for that harness. That includes a session already on Fable 5.2 or GPT-6 Astra: a fresh session of the same model has not seen the work and still reviews it independently.

## When

Pull requests only.

- Run it when this session opens a pull request, or pushes new work to an open pull request, whoever opened it.
- Pushing fixes from these loops does not start a new run. A new run starts only for new work pushed after both loops have ended.
- Run it when the user asks for it on an existing pull request or branch.
- Do not run it for anything else: answers, research, documents or local changes that are not going into a pull request, or commits pushed without one. For those, finish the task as usual.
- Skip it when the user says to, and for a pull request that only fixes a typo or bumps a version. Say that you skipped it.
- Never run it from inside a review. If you were launched by one of this skill's scripts, you are the reviewer: review, and do not start reviews of your own. The scripts refuse to run there.

Run the loops once the pull request is open. Review the finished, verified branch against the pull request's base; for a branch the user names that has no pull request, use the base they give, or the repository's default branch. Every fix goes to that same branch, and the pull request is not reported as ready until both loops have ended. Never merge.

## Effort

Pick the level by what a miss would cost. Use the same rubric for both reviewers; they need not match. Keep a reviewer at the same level for all of its rounds.

| Effort | Use for |
| --- | --- |
| `medium` | Small, low-risk pull requests that are easy to check: docs, a config tweak, a single-file change with tests. |
| `high` | Default. Multi-file changes, features, bug fixes with unclear blast radius. |
| `xhigh` | Security-sensitive or money-moving logic, concurrency, data migrations, production rollouts, public or upstream pull requests, large diffs. |

`low` is too shallow for a review and `max` is only for when the user asks. State the chosen effort when you launch each review.

## The brief

Write one brief file and give the same file to both reviewers, every round. Each review starts from the brief and the working directory, with no memory of the session that did the work.

```
Task: <what the user asked for, in their terms, with the acceptance criteria>
Result: <the branch and its base (`git diff <base>...HEAD`), and the pull request number once it exists>
How to check: <the exact test, lint, build or run commands; where sample data is>
Out of scope: <what was deliberately not done, so it is not reported as missing>
```

- Describe the task and the result. Do not argue that the result is good, and do not list what you already checked.
- Never put secrets in a brief.
- Do not add earlier findings, or your verdicts on them, to any later review: not to the next round and not to the second reviewer. Every review gets the same brief and the work as it now stands. Independence is the point; a reviewer told what to think agrees. Let a rejected finding be raised again and resolve it against the ledger.
- Update the brief only when the facts in it change (a new commit range, a renamed file), never to steer the review.

Keep everything together, outside the repository, in `~/.advisor-review/<repo>__<branch>/`: `brief.md`, one file per review (`fable-r1.md`, `fable-r2.md`, `astra-r1.md`, ...) and `ledger.md`. The ledger is what lets a new session pick the loop back up: read it first when resuming.

## Running a review

Both scripts are in the `scripts/` folder next to this `SKILL.md`; use the folder this skill was loaded from (for example `~/.claude/skills/advisor-review/scripts/` in Claude Code, or `~/.codex/skills/advisor-review/scripts/` or `~/.agents/skills/advisor-review/scripts/` in Codex). `reviewer-rules.md` must stay beside them. They take the same arguments:

```bash
fable-review.sh [--detach] <workdir> <brief-file> <out-file> [effort]   # Claude Code CLI, Fable 5.2
astra-review.sh [--detach] <workdir> <brief-file> <out-file> [effort]   # Codex CLI, GPT-6 Astra
```

- Each call is a brand-new reviewer session with the model and effort pinned. Never resume a reviewer.
- Launching a review needs network access, permission to start the other CLI, and write access to the folder holding the brief and reviews. If your own sandbox blocks any of these, ask the user for approval; if it is refused, report the review as not runnable. Do not work around the restriction.
- Reviewers can read files and run commands, so they can run the code and its tests. They are told not to change the work, and the Fable reviewer has no file-edit tools. They run in your working directory: do not edit files there while a review is running, and check `git status -sb` afterwards for stray test or build output.
- Without `--detach` the script blocks until the review is done. In Claude Code run it as a background command and continue when it exits. With `--detach` it returns at once; wait for `<out-file>.done` (`exit <code> <HH:MMZ>`), then read `<out-file>`. Use `--detach` where a command cannot run for many minutes. Either way the script exits with code 2 and starts nothing if its arguments are wrong or it cannot write the output file.
- A review at `xhigh` on a large change can take 20 minutes or more. A quiet run is not a hang.
- A nonzero exit or an empty review is a failed launch, not a review. Read `<out-file>.log`, fix the cause (not signed in, CLI moved, model unavailable) and relaunch. If a reviewer cannot be run, say so in the final report; do not silently swap in another model.
- Each review spends the user's Claude or Codex usage. Do not launch a review on work you already know is incomplete.

## After each review

Triage every finding yourself, record it in the ledger, then fix:

| Verdict | Meaning | Action |
| --- | --- | --- |
| `fix` | Real defect or unmet part of the request | Fix it now, then re-run the proof (tests, build) |
| `reject` | Wrong, or intentional per the request | Leave it; record the reason in one line |
| `defer` | Real but outside this task | Leave it; report it to the user as a follow-up |
| `duplicate` | Already in the ledger | Resolve from the earlier verdict and reason |

- `[P0]`–`[P3]` tags are input to your judgment, not a substitute for it. Verify a claimed defect before fixing it.
- Fix exactly what was found. No refactors or extras on the back of a review.
- If a finding needs a design decision the user has not made, stop and ask.

Ledger entry per finding:

```
### <reviewer> R<round> · <P-tag> · <where> — <title>
verdict: fix | reject | defer | duplicate-of <reviewer> R<n>
reason: <one line; required for reject, defer and duplicate>
status: open | fixed-in-R<n> | closed
```

## Sequence

1. Finish and verify the branch. Write the brief.
2. **First reviewer loop.** Review, triage, fix, re-run the proof, then a fresh review of the work as it now stands. Repeat until this reviewer's loop ends (below).
3. **Second reviewer loop.** The same loop with the other reviewer, on the work as the first loop left it.
4. Report.

The first reviewer is not called again after the second loop. If the second loop changed a lot, say so in the report.

## When a reviewer's loop ends

Clean exit, move on:

- a round has no `fix` verdicts (the reviewer says "Verdict: ready", or everything it raised is `reject`, `defer` or `duplicate`). A review always runs after the previous round's fixes, so a clean round already covers them; no extra confirmation round.
- two rounds in a row raise only `[P3]` nits beyond what is already in the ledger. Fix or drop the nits and move on.

Stop and hand back to the user, with the ledger, instead of spending more:

- **Round cap: 5 per reviewer.** Hard ceiling. An earlier "keep going" does not lift it: at the cap, stop and ask, with the trend of the findings and the growth of the change in the question.
- **Oscillation:** a finding marked fixed comes back twice.
- **Regression:** a new `fix` finding lands in code the previous round just changed, twice.
- **Design demand:** a finding asks for a different design rather than a fix.
- **Scope growth:** findings keep landing outside what the task changed (older code, neighbouring features). Defer those to a follow-up rather than growing this change; prefer cutting scope over adding guard code.

Say in one line when each round starts: reviewer, round number, effort. After each round note the findings by verdict and the size of the pull request's diff so far (lines added and removed).

## Final report

Along with the normal report of the work, say in a few lines:

- how many rounds each reviewer ran, at what effort, and how each loop ended (clean, cap, or handed back)
- findings fixed, rejected (with the reason) and deferred
- anything changed after the last review that no reviewer has seen
- any review that could not be run
