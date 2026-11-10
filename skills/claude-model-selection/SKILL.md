---
name: claude-model-selection
description: "Pick the Claude model (Haiku 5.5, Sonnet 5.5, Opus 5.5, Fable 5.2) and effort level for a task, subagent, worker, or API route; make subagents and exploration cheaper; decide when to escalate or step down; estimate cost or cut a Claude bill that is too high; and check API compatibility before switching models. Works in Claude Code, Codex, or any harness that calls Claude."
license: "MIT; see LICENSE.txt"
---

# Claude Model Selection

Choose a Claude model and effort level for a piece of work, then adjust from evidence. Distilled from Anthropic's guide [Which Claude model should you build with?](https://claude.dev/blog/which-claude-model-should-you-build-with/) (claude.dev, 2026-11-09) and the Claude API docs.

**Freshness.** This lineup and these prices are as of 2026-11-09. If the session shows a newer model list (the harness's model picker, the Models API `GET /v1/models`, or a newer article), trust the live source and say the skill may be stale. Don't invent model IDs; use the ones in [references/models.md](references/models.md).

**Unknown model names.** If the user names a model this skill doesn't list (for example a rumored "Opus 6"), don't confirm or deny that it exists. Say it isn't in this skill's lineup, point to the live check (model picker or `GET /v1/models`), recommend from the known lineup in the meantime, and treat a confirmed new model as a candidate to measure (section 6), not an automatic switch.

## When to use

- Someone asks "which model should I use for X", "is Haiku enough", "should this be Fable", "why is this so expensive", or how to make subagents or exploration cheaper.
- You are configuring a subagent, worker, judge, router, or API route and must name a model and effort.
- A task failed on one model and you must decide whether to retry, raise effort, or move up.
- You are about to change the model in existing API code (check [references/compatibility.md](references/compatibility.md) first).

Don't override a model the user already chose. If the user named a model, recommend that model and configure it well; then mention a better fit once, in one or two sentences with the cost difference, and stop.

## 1. Start from the default

**Default: Claude Opus 5.5 (`claude-opus-5-5`) at `medium` effort.** It is the Claude Code default and costs half of Fable 5.2 per token. Move from there only for a reason in the table.

| Work | Start with | Effort | Reason |
| --- | --- | --- | --- |
| Not sure yet | Opus 5.5 | `medium` | Safe default for coding and knowledge work. |
| Everyday engineering, debugging, multi-PR features | Opus 5.5 | `medium`, then `high` | Best balance for open-ended work. |
| Computer use, screenshot- or image-heavy agent loops | Opus 5.5 | `medium` | Long agentic loops over many images. |
| Scoped coding: bug fix, spec-driven feature, iteration | Sonnet 5.5 | `medium`, then `high` | Handles clear scope at half the Opus price. |
| Chat or anything a person waits on | Sonnet 5.5 (Haiku 5.5 for simple chat at volume) | `low` or `medium` | Fast at low effort. |
| Repeated, well-defined agent jobs: review, investigation, drafting | Sonnet 5.5 | `medium` | Repetitive defined work rarely needs more. |
| Documents, slides, spreadsheets | Sonnet 5.5 | `high` | Fast iteration, good design sense. Use Opus 5.5 for complex financial models or docs built from a large pile of sources. |
| Classification, routing, tagging, bulk extraction | Haiku 5.5 | `medium` | Cheapest and fastest; outputs are checkable. |
| Side-task subagents: file search, log reading, summarizing | Haiku 5.5 or Sonnet 5.5 | model default | Mistakes are cheap to spot; the main model keeps the judgment calls. |
| Major refactors or migrations, architecture, leading many subagents | Fable 5.2 | `medium`, then `high` | Most capable generally available model for technical work. |
| Deep research, scientific or quantitative analysis | Fable 5.2 | `medium`, then `high` | Built for the hardest technical problems. |
| Long unattended runs, or Opus 5.5 at `high` still falls short | Fable 5.2 | `medium` | The next step when Opus is out of headroom. |

Tie-breakers when two rows fit:

- **Sonnet 5.5 vs Opus 5.5 for coding.** Sonnet when the scope is pinned down and verifiable: known location, failing test or clear acceptance check, few files. Opus when the cause is unknown, the change crosses modules, or the work runs many steps without a check.
- **Haiku 5.5 vs Sonnet 5.5.** Haiku for single-shot calls with short inputs and outputs a check or a reviewer can verify. Sonnet once the job is a multi-step tool loop (editing code counts), the output is customer-facing and hard to check, or inputs pass 100K tokens.
- **No row fits** (for example security analysis, legal review): map by shape, not domain. Open-ended and high-stakes maps to Opus; scoped and repeated maps to Sonnet; bulk and checkable maps to Haiku.

Traps:

- **A clear spec does not make a task easy.** A migration or performance optimization can have a precise spec and still need Opus 5.5, or Fable 5.2 if it is large.
- **Haiku is for short, checkable work.** Small models are weak in long agentic loops. Above 100K prompt tokens Haiku 5.5 costs 5x its base rate, so compare it with Sonnet 5.5 on cost per finished task when prompts are long. If the fields or answers don't depend on the whole document, splitting inputs under 100K keeps Haiku on its cheap tier; verify accuracy on the split version.
- **Cybersecurity and biology work** can trip safety classifiers on Opus 5.5, Sonnet 5.5, and Fable 5.2. Plan for refusals and fallbacks (see compatibility reference): treat a refusal as a handled state with a retry or human path, not a crash. Claude Mythos 5.2 serves those fields but only through Anthropic's verification programs; don't assume access.

## 2. Effort before model

Effort (`low`, `medium`, `high`, `xhigh`, `max`) is a finer dial than model choice for both cost and capability. Higher effort helps when the model must think longer, call more tools, or check more of its work. It adds latency, and it can't supply knowledge or skill the model lacks.

When a model isn't good enough, escalate in this order:

1. **Give it a way to verify its own work**: a test, a build, a script that hits the endpoint. This is often cheaper and faster than any effort change.
2. **Raise effort one level.**
3. **Move up one model, at a lower effort** than you used on the smaller one.

Rules of thumb:

- Past `high`, one more effort level can cost as much as the next model up. Before pushing Opus 5.5 to `xhigh` or `max` on a hard task, test Fable 5.2 at `medium` or `high`.
- Step down too: one level lower often holds quality at a lower price.
- **Run low, retry high.** When outcomes can be checked automatically and there are many tasks, run everything at `low` and re-run only failures at `high`. In Anthropic's SWE-bench Pro run on Opus 5.5 this beat all-`high` on both pass rate and cost; the same logic applies to other models, but confirm on a pilot. This overrides the table's starting effort for batch work with automatic checks; the table's effort is for interactive or one-off work.
- Defaults differ: on the API, Haiku 5.5 and Opus 5.5 default to `medium`, Sonnet 5.5 and Fable 5.2 to `high`. Claude Code runs Sonnet 5.5 and Fable 5.2 at `medium` by default (`/effort` shows the current level). Set effort explicitly instead of relying on a default.

## 3. Judge cost per finished task

A pricier token can produce a cheaper task: fewer turns, fewer retries, less wasted work. Compare setups by cost per completed, verified task.

- Price the hardest tasks in the set, not only typical ones. A few hard tasks usually carry most of the spend.
- Context is billed on every turn. Long runs mostly bill as cache reads, which cost the same on Opus 5.5 and Fable 5.2 ($0.20/M), so on cache-heavy runs the Fable premium is mostly uncached input and output.
- Keep the expensive model's context lean; let cheaper subagents do the verbose reading and hand back summaries.
- Need the same model faster? Fast mode (Opus 5.5, Fable 5.2) buys output speed at premium pricing instead of trading capability.
- Cache any large static prefix (system prompt, FAQ, category definitions, tool list). Reads cost a small fraction of input; writes cost 1.25x input (5-minute TTL) or 2x (1-hour).
- Work nobody waits on (backfills, bulk classification, evals) can go through the Message Batches API at 50% off every token, stacking with caching.

For a rough estimate, per request: `cost ≈ uncached_input × in_rate + cache_writes × 1.25 × in_rate + cache_reads × cache_rate + output × out_rate`, rates per million tokens from [references/models.md](references/models.md). Thinking tokens bill as output and count toward `max_tokens`, so leave headroom. Sum over all requests in a task. State the token assumptions behind any estimate, then measure real numbers from each response's `usage` field.

## 4. Mixing models

**Subagents on smaller models.** Put Haiku 5.5 or Sonnet 5.5 on work where a mistake is cheap to notice: finding files, running tests, reading logs. Keep code edits and judgment calls on the main model; a small model's misread search result sends the main model down the wrong path. Harness-specific setup is in [references/harness-config.md](references/harness-config.md).

**Switch models at a natural break.** The prompt cache belongs to the model that wrote it, so the first turn on a new model pays to re-cache the whole conversation. Compact first, or start the new model from a short written summary or plan instead of the full history. Moving down a tier also loses earlier thinking blocks (the API drops ones the new model can't read; the request still succeeds).

**Bulk fan-out.** For work too big for one context window, a top-tier lead splitting work across many cheaper parallel workers can cut cost at similar quality (Anthropic: an Opus 5.5 lead over Sonnet 5.5 workers cost about a third less than Opus alone). Skip it for a single chain of dependent steps or work that fits one context; the planning and merging cost more than they save. Partly dependent work, like a large migration, can do both: the lead settles shared pieces first (types, conventions, core modules), then fans out the independent leaves.

**Advisor tool (beta).** A cheap executor can consult a stronger advisor mid-task. Gains measured so far are small, about what raising effort buys. Measure the executor's consult rate before adopting it, and check the allowed executor/advisor pairs.

**Routing.** When the rule is simple (one model per step type), let code choose the model, not another model. Build every request so it works on the strictest model in the system; then a step can move tiers without code changes.

## 5. Before changing the model in code

Model choice is not always a string swap. Read [references/compatibility.md](references/compatibility.md) before migrating. The most common breaks:

- Opus 5.5 and Fable 5.2 always think; sending disabled thinking or `budget_tokens` returns 400. Control depth with `output_config.effort`.
- `tool_choice` of `any` or `tool` returns 400 on Sonnet 5.5, Opus 5.5, and Fable 5.2. Use `auto` with `strict: true` tools and tell the model in the prompt when to call the tool. With `auto`, handle the case where no tool call comes back.
- Fable 5.2 enforces preserved thinking: editing anything before a thinking block (system prompt, tools, earlier messages) returns 400 unless you opt in to dropping that thinking. Keep history append-only.
- Read response content blocks by type; a response may start with a thinking block.
- For labels or fixed fields, prefer structured outputs (`output_config.format`) over a forced tool call or prefill.

## 6. Measure on real work

Published benchmarks give a starting point. Before committing a route or default:

1. Sample real tasks (a few dozen is a reasonable start; include the hardest ones), each with an automatic outcome check (passing test, closed ticket, correct row count).
2. Run each candidate model at two or three effort levels, each in its own session so runs don't share a cache.
3. Record cost per completed task from `usage`.
4. Plot score against spend. Keep a multi-model setup only if it beats every single-model point.
5. Shadow the winner on a slice of real traffic before cutting over.

Quick check in Claude Code: run one backlog task on two models with `/model` and compare `/usage`.

Measurement spends real money. Get the user's approval before running paid comparisons.

## Output

When asked for a recommendation, answer briefly with:

- **Model and effort**: exact model ID and effort level (for example `claude-sonnet-5-5`, `medium`).
- **Why**: one or two sentences tied to the task's shape (scope, volume, latency, horizon, checkability).
- **Escalation trigger**: what signal would move it up (or down), and the next step on the ladder.
- **Cost note** when relevant: rough per-task or per-call estimate and the main cost driver.
- **Compatibility note** only if a model switch would break existing request code.

When configuring a harness, write the actual config (subagent frontmatter, CLI flags, request parameters) rather than describing it.
