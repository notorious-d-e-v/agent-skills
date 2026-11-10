# Models, prices, and defaults

As of 2026-11-09. Claude API list prices, USD per million tokens. Partner platforms (Amazon Bedrock, Google Vertex AI) price separately. Check the Models API (`GET /v1/models`) or the pricing page for current values.

## Lineup

| | Haiku 5.5 | Sonnet 5.5 | Opus 5.5 | Fable 5.2 |
| --- | --- | --- | --- | --- |
| API model ID | `claude-haiku-5-5` | `claude-sonnet-5-5` | `claude-opus-5-5` | `claude-fable-5-2` |
| Claude Code alias | `haiku` | `sonnet` | `opus` | `fable` |
| Built for | High-volume, cost-sensitive tasks | Fast help on well-scoped work | Daily driver for complex coding and knowledge work | The hardest open-ended technical work |
| Relative latency | Fastest | Fast | Moderate | Moderate |
| Input / output | $0.10 / $0.50 (prompt ≤100K); $0.50 / $2.50 (>100K) | $2 / $10 | $4 / $20 | $8 / $40 |
| Cache reads | $0.01 (≤100K); $0.05 (>100K) | $0.10 | $0.20 | $0.20 |
| Context window | 1M | 1M | 1M | 1M |
| Max output | 128K | 128K | 128K | 128K |
| Thinking | Adaptive, on by default; can be turned off at effort `high` or below | Adaptive, on by default; `between_tools` limits it to gaps between tool calls | Adaptive, always on | Adaptive, always on |
| Default effort (API) | `medium` | `high` | `medium` | `high` |
| Default effort (Claude Code) | check `/effort` | `medium` | `medium` | `medium` |
| Fast mode | No | No | Yes ($8 / $40) | Yes ($16 / $80) |

Effort levels on all four: `low`, `medium`, `high`, `xhigh`, `max`.

Claude Mythos 5.2 (`claude-mythos-5-2`) has the Fable 5.2 surface and pricing but is available only to organizations in Anthropic's cybersecurity and life-sciences verification programs.

Use model IDs exactly as written; don't append date suffixes. Bedrock IDs take an `anthropic.` prefix (for example `anthropic.claude-opus-5-5`).

## Other pricing levers

- Cache writes: 1.25x the input rate for the 5-minute TTL, 2x for the 1-hour TTL. Cache reads are the per-model rates above.
- Message Batches API: 50% off every token, including cache reads and writes, for work nobody waits on.
- Fast mode: premium per-token rates above, for higher output speed on the same model.
- Thinking tokens bill at the output rate.

## Price ratios worth remembering

- Sonnet 5.5 is half the per-token price of Opus 5.5; Opus 5.5 is half of Fable 5.2.
- Haiku 5.5 short-prompt input is 1/20 of Sonnet 5.5. Its long-prompt tier (>100K) is 5x its base rate but still 1/4 of Sonnet.
- Opus 5.5 and Fable 5.2 share a $0.20 cache-read rate, so on cache-heavy long runs the gap is mostly uncached input and output.

## Reference data points from Anthropic's runs

Use these to calibrate expectations, not as guarantees for a given workload.

- **Opus 5.5 on SWE-bench Pro**, relative to `high`: `medium` scored about 2.5 points lower at about 70% of the cost; `low` about 8 points lower at about a third of the cost; `xhigh` about 1.4 points higher at 2.5x the cost.
- **Run low, retry high** (same subset): Opus 5.5 at `low` with failures re-run at `high` passed about 97% at about $0.17 per task, versus 95.3% at $0.29 with every task at `high`.
- **Fable vs Opus on the hardest work** (FrontierCode 2.0): Fable 5.2 at `high` scored 45.3% versus Opus 5.5 at `max` 45.5%, at roughly half the cost per task.
- **Bigger isn't always more tokens** (Terminal-Bench 3.0): Opus 5.5 at `high` scored 58.9% with half the tokens of Fable 5.1 at `max` (58.0%).
- **Spend concentrates**: on one 20-problem search benchmark, two problems carried 43% of the spend.
- **Context cost**: on Opus 5.5 a turn's cache read is about $0.03 at 150K context versus about $0.004 at 20K.
- **Advisor**: an Opus 5.5 executor at `high` with a Fable 5.1 advisor gained 1.7 points for about 2.1x the cost, within run-to-run noise and about what raising effort buys.
- **Fan-out**: over about 22M tokens of source, an Opus 5.5 lead with up to 25 parallel Sonnet 5.5 workers cost about a third less than Opus 5.5 alone at default effort, with about the same score.
- **Speed**: Fable 5.2 generates output up to 30% faster than Fable 5.1; Sonnet 5.5 runs 30% faster than Sonnet 5.
