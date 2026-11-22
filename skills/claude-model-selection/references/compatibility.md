# Compatibility checks before switching models

Every current model supports tool use and image input, but a request that works on one model can fail on another. Test these before moving a route.

## Breaking differences

| Area | Rule | Fix |
| --- | --- | --- |
| `max_tokens` | Thinking tokens count toward `max_tokens` and bill as output. | Leave headroom; a low cap truncates the answer. |
| Thinking off | Opus 5.5 and Fable 5.2 always think. `thinking: {type: "disabled"}` or `budget_tokens` returns 400. Sonnet 5.5 rejects `disabled`; use `{type: "between_tools"}` (effort `high` or below). Haiku 5.5 can disable thinking only at effort `high` or below. | Omit `thinking` or send `adaptive`; lower `output_config.effort` instead. |
| `budget_tokens` | Removed on all four current models. | Replace with an effort level. |
| Forced tool use | `tool_choice` `any` or `tool` returns 400 on Sonnet 5.5, Opus 5.5, Fable 5.2. Haiku 5.5 isn't on that list, but build for the strictest model so routes can move. | Send `auto`, mark the tool `strict: true`, and say in the prompt when to call it. Use structured outputs (`output_config.format`) if the forced call only existed to get JSON. |
| Preserved thinking | Fable 5.2 rejects (400) a request if anything before one of its thinking blocks changed: system prompt, tools, or an earlier message, unless you opt in to dropping that thinking. Claude Code, the Agent SDK, and Managed Agents handle this. | Keep custom harness history append-only. Put per-turn context (time, open files) in a mid-conversation system message appended to `messages` (`{"role": "system", "content": "..."}`) instead of rewriting the top-level system prompt. Trim with server-side context editing or compaction, which don't count as edits, not client-side deletion. To accept the loss instead, opt in with `prefix_mismatch_behavior: "drop_block"` (beta `thinking-binding-controls-2026-08-01`). Check the current docs for exact shapes. |
| Thinking carryover | Each model reads only some other models' thinking blocks. Opus 5.5 reads Sonnet 5.5 and Haiku 5.5 blocks; Sonnet 5.5 reads Haiku 5.5; Fable 5.2 reads Opus 5.5, Sonnet 5.5, and Haiku 5.5. No model reads a block from a model above it, and nothing else reads Fable 5.2 blocks. | Unreadable blocks are dropped silently and the request succeeds, but reasoning is lost. Switch at a natural break with a summary. |
| Response shape | A response can begin with a thinking block. | Read content blocks by `type`, never `content[0].text`. |
| Computer use | Current models accept computer use only via `computer_toolset_20260801` on the Claude API and Claude Models on Google Cloud. | Update the tool type. |
| Prefill | A final assistant turn for the model to continue returns 400. | End with a user turn; use structured outputs or instructions for format. |
| Sampling params | Non-default `temperature`, `top_p`, `top_k` return 400 on Haiku 5.5 and Sonnet 5.5; Opus 5.5 and Fable 5.2 reject them outright. | Remove them; get consistency from precise prompts, `strict` tools, or structured outputs. |
| Prompt cache | Caches are per model. | Expect one full cache write on the first turn after a switch. |

## Haiku 4.5 to Haiku 5.5

Replace `budget_tokens` with effort, drop non-default `temperature` / `top_p` / `top_k`, and end every request with a user turn. Haiku 5.5 refusals have no server-side fallback.

Going from Haiku 4.5 to Sonnet 5.5 or Opus 5.5 hits all of the above plus the forced `tool_choice` and always-on thinking rules in the table.

## Safety classifiers

Opus 5.5, Sonnet 5.5, and Fable 5.2 run safety classifiers that most often flag cybersecurity and biology content. In Claude Code a flagged request can re-run on an older model and the transcript says which (Fable 5.2: cybersecurity falls back to Opus 4.8, biology to Opus 5; for other models, read the transcript notice). On the API, handle `stop_reason: "refusal"` and consider server-side fallbacks. Legitimate security or life-sciences workloads should expect occasional false positives.

## Data retention

Fable 5.2 requires 30-day data retention. Organizations on zero data retention get a 400 unless Anthropic has authorized them.

## Multi-model systems

Build every request for the strictest model in the system: append-only history, `tool_choice: auto` with strict tools, content read by type, and prompts and tool descriptions precise enough for the most literal model. A step can then move up or down a tier without code changes.
