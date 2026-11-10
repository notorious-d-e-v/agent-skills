# Setting model and effort per harness

Write the real config for the harness in use. Flags and fields change between versions; confirm with the tool's `--help` or docs when unsure.

## Claude Code

Session:

- Interactive: `/model <alias or ID>` and `/effort <level>`; `/effort` with no argument shows the current level. `/usage` shows spend.
- CLI: `claude --model sonnet --effort medium`, or non-interactive `claude -p "<task>" --model haiku --effort low`. `--model` takes an alias (`haiku`, `sonnet`, `opus`, `fable`) or a full model ID; prefer the full ID when the alias could resolve to an older model on your platform.
- `--fallback-model <model>` falls back when the main model is overloaded or unavailable.

Subagents (`.claude/agents/<name>.md` in a project, or `~/.claude/agents/` for the user):

```markdown
---
name: log-reader
description: Reads test output and logs and reports each failing case. Use after a test run.
tools: Read, Grep, Glob, Bash
model: haiku
---

Read the logs you are given. For each failure, report the file, the test name, and the first error line. Do not edit files.
```

- `model:` takes `haiku`, `sonnet`, `opus`, `fable`, a full model ID, or `inherit`.
- `CLAUDE_CODE_SUBAGENT_MODEL` sets the default for subagents that don't name a model.
- Project agents (`.claude/agents/`) are shared with the repo; user agents (`~/.claude/agents/`) apply everywhere. Use project scope unless the user wants it in every project.
- Effort for a subagent: if the installed version's subagent docs list an `effort` field, set it; otherwise the subagent uses its model's default.
- The built-in Explore subagent now runs on the session's model (capped at Opus on the Claude API), not always Haiku. To keep exploration cheap, define your own subagent named `Explore` with `model: haiku`.
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` pins what the `haiku` alias resolves to. On the Anthropic API, `haiku` resolves to Haiku 5.5 (needs Claude Code v2.1.293 or later). On Bedrock, Google Cloud, Microsoft Foundry, and Claude Platform on AWS it still resolves to Haiku 4.5.
- `opusplan` plans with Opus in plan mode, then executes with Sonnet. That puts code edits on the smaller model, the opposite of this skill's default advice; measure it before adopting.
- Switching `/model` mid-session re-caches the whole conversation on the first turn. Run `/compact` first, or start a fresh session from a short plan.

## Claude API (Messages)

```json
{
  "model": "claude-sonnet-5-5",
  "max_tokens": 16000,
  "thinking": {"type": "adaptive"},
  "output_config": {"effort": "medium"},
  "messages": [{"role": "user", "content": "..."}]
}
```

- Effort lives at `output_config.effort`, not top level.
- `strict: true` goes at the top level of each tool definition (beside `name` and `input_schema`), and the schema needs `additionalProperties: false`.
- Cache a large static prefix with `cache_control: {"type": "ephemeral"}`; confirm hits with `usage.cache_read_input_tokens`.
- `thinking: {"type": "adaptive"}` works on all four current models; omitting it also runs adaptive. Don't send `budget_tokens`.
- Fast mode: top-level `"speed": "fast"` on Opus 5.5 or Fable 5.2 (Claude API). On Microsoft Foundry it is a separate `-fast` deployment instead. Fast mode has its own rate limit; on 429, retry or drop to standard speed (which invalidates the cache).
- Refusals: Opus 5.5, Sonnet 5.5, and Fable 5.2 can return `stop_reason: "refusal"`. Check `stop_reason` before reading content. Server-side fallbacks: beta `server-side-fallback-2026-07-01` with `"fallbacks": "default"`.
- Cost per task: sum `usage.input_tokens`, `usage.cache_read_input_tokens`, `usage.cache_creation_input_tokens`, and `usage.output_tokens` across the task's requests and multiply by the rates in [models.md](models.md).
- Agent SDK and Managed Agents set the model the same way (`model` option or the agent's model object) and handle preserved-thinking history rules for you.

## Codex and other non-Claude harnesses

The harness's own model setting (for example Codex `-m` or `-c model=...`) selects its native models. To put Claude on a piece of work from such a harness, either:

- **Shell out to Claude Code** for a bounded, self-contained task:
  `claude -p "<self-contained task and expected output>" --model sonnet --effort medium`
  Choose model and effort from the SKILL.md table. Run it from the repository root. Give the worker everything it needs in the prompt: the files, the failing test or acceptance check, what not to change, and what to report back. A non-interactive run can't answer permission prompts, so grant only what the task needs (for example `--allowedTools "Read,Edit,Bash(npm test:*)"` or a `--permission-mode` your policy allows), and review the diff before using it.
- **Call the Claude API** from the harness's code or a script with the request shape above.

When the harness routes between several Claude models, apply the strictest model's rules to every request (append-only history, `tool_choice: auto` with strict tools, read content blocks by type) so routes can change tiers without code changes.

Installing this skill doesn't grant model access or API credentials. If the requested model isn't available, say so and pick the nearest available tier rather than silently substituting.
