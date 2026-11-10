# Agent Skills

Reusable skills for AI agents, maintained by [Notorious D.E.V.](https://github.com/notorious-d-e-v). Each skill lives in its own folder and can be installed independently.

## Skills

| Skill | Purpose | Environment |
| --- | --- | --- |
| [astra-sol-delegation](skills/astra-sol-delegation/SKILL.md) | Astra delegates implementation and exploration to Sol, chooses reasoning effort, and reviews the result. | Codex with GPT-6 Astra and GPT-5.6 Sol access |
| [claude-model-selection](skills/claude-model-selection/SKILL.md) | Picks the Claude model and effort level for a task, subagent, or API route, plans escalation, estimates cost, and flags API breaks before a model switch. | Claude Code, Codex, or any harness that calls Claude |

## Install

Install only the skill you want. For the first skill, paste this into Codex:

```text
$skill-installer install the astra-sol-delegation skill from https://github.com/notorious-d-e-v/agent-skills/tree/main/skills/astra-sol-delegation
```

Or download this repository and copy `skills/astra-sol-delegation/` into your user skill directory, `~/.agents/skills/`. For a shared project installation, copy it into `.agents/skills/` in that repository. Codex also supports the `~/.codex/skills/` location used by its bundled installer. Choose one location to avoid duplicate discovery. Keep the included `LICENSE.txt` with the skill.

Codex detects newly installed skills automatically. If it does not appear, restart Codex. See the [official skills documentation](https://learn.chatgpt.com/docs/build-skills).

For Claude Code, copy the skill folder into `~/.claude/skills/` (every project) or `.claude/skills/` in a repository (that project only).

## Astra → Sol delegation

Select **GPT-6 Astra** in Codex, then ask for work normally or invoke the skill explicitly:

```text
Use $astra-sol-delegation to implement this feature. Choose which parts to
delegate to Sol and its reasoning effort, then review and verify the result.
```

The skill can activate automatically for suitable Astra tasks. It skips Sol and other-model sessions and leaves tiny tasks in Astra when delegation would add overhead.

### How it works

1. Astra settles design decisions and defines a bounded assignment.
2. Sol implements or investigates at the effort Astra chooses, typically `low` through `xhigh`, or `max` when supported and useful.
3. Astra inspects the changes, verifies the evidence, and integrates the result.

Native Codex subagents are preferred. A Codex CLI fallback pins the Sol model and effort, uses standard service, and preserves execution restrictions. Workers receive a self-contained assignment and do not delegate further.

### Requirements

- Access to `gpt-6-astra` and `gpt-5.6-sol` in your Codex environment.
- A native subagent tool that supports choosing the worker model, or a permitted, authenticated Codex CLI installation.
- Support for the chosen reasoning effort. Tool names, parameters, and available modes vary by version; the skill tells Astra to check the active interface.

Installing the skill adds workflow instructions. It does not grant model access, change your selected model, or enable tools. If Sol is unavailable, Astra reports the limitation and continues directly when feasible.

## Claude model selection

Use it in Claude Code, Codex, or any agent that picks Claude models for its own work or for an app it is building. Ask normally or invoke it explicitly:

```text
Use $claude-model-selection to pick the Claude model and effort for this
pipeline, with an escalation plan and a rough cost per day.
```

In Claude Code it activates on its own for questions like "which model should I use for X", "is Haiku enough", or "make my subagents cheaper".

### What it covers

1. A starting model and effort for common task shapes. The default is Opus 5.5 at `medium`, stepping down to Sonnet 5.5 or Haiku 5.5 or up to Fable 5.2 for specific reasons.
2. An escalation order: give the model a way to check its own work, then raise effort one level, then move up one model.
3. Cost per finished task, including caching, the Batch API, and Haiku's long-prompt price tier.
4. Mixing models: cheap subagents, switching models without losing the cache, and fan-out to parallel workers.
5. API changes that break when you switch models: always-on thinking, forced `tool_choice`, preserved thinking, and sampling parameters.
6. Exact config for Claude Code (subagent frontmatter, `--model`, `--effort`), the Messages API, and handing tasks from Codex to `claude -p`.

The lineup and prices are as of 2026-11-09. The skill tells the agent to trust a live model list over its own tables when they differ. It is distilled from Anthropic's [Which Claude model should you build with?](https://claude.dev/blog/which-claude-model-should-you-build-with/) and the Claude API docs.

## Skill format

```text
skills/astra-sol-delegation/
├── SKILL.md          # Complete workflow and required YAML metadata
├── LICENSE.txt       # Redistribution notice
└── agents/
    └── openai.yaml   # Optional Codex display and invocation metadata
```

`SKILL.md` contains the complete workflow; no runtime dependencies or helper scripts are required by the skill itself. The package follows the `skills/<name>/SKILL.md` layout used by [steipete/agent-scripts](https://github.com/steipete/agent-scripts).

## Add a skill

1. Create `skills/<name>/SKILL.md` with a unique `name` and a concise, quoted `description` in YAML front matter. Match the folder name to the skill name.
2. Keep instructions portable. Add supporting files only when the workflow needs them, and include any required redistribution notices inside the skill folder.
3. Add the skill to the table above and run `scripts/validate-skills` (requires Ruby). CI runs the same metadata and duplicate-name checks.

## Credits and license

[MIT](LICENSE). The collection layout and validation helper come from [steipete/agent-scripts](https://github.com/steipete/agent-scripts). Astra → Sol is adapted from its Codex First skill. Original material © Peter Steinberger; adaptations © Notorious D.E.V.
