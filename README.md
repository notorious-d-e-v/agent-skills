# Agent Skills

Reusable skills for AI agents, maintained by [Notorious D.E.V.](https://github.com/notorious-d-e-v). Each skill lives in its own folder and can be installed independently.

## Skills

| Skill | Purpose | Environment |
| --- | --- | --- |
| [astra-sol-delegation](skills/astra-sol-delegation/SKILL.md) | Astra delegates implementation and exploration to Sol, chooses reasoning effort, and reviews the result. | Codex with GPT-6 Astra and GPT-5.6 Sol access |
| [advisor-review](skills/advisor-review/SKILL.md) | The session model does the work; when it opens a pull request, two stronger models review the branch in turn and the session fixes what they find. | Claude Code or Codex, with both CLIs installed and access to Fable 5.2 and GPT-6 Astra |

## Install

Install only the skill you want. For the first skill, paste this into Codex:

```text
$skill-installer install the astra-sol-delegation skill from https://github.com/notorious-d-e-v/agent-skills/tree/main/skills/astra-sol-delegation
```

Or download this repository and copy `skills/astra-sol-delegation/` into your user skill directory, `~/.agents/skills/`. For a shared project installation, copy it into `.agents/skills/` in that repository. Codex also supports the `~/.codex/skills/` location used by its bundled installer. Choose one location to avoid duplicate discovery. Keep the included `LICENSE.txt` with the skill.

Codex detects newly installed skills automatically. If it does not appear, restart Codex. See the [official skills documentation](https://learn.chatgpt.com/docs/build-skills).

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

## Advisor review

The session's own model does all of the work. When that work goes into a pull request, two stronger models review the branch, one after the other, and the session fixes what they find before it reports the pull request as ready. It runs for pull requests only, not for every task.

| Harness | Does the work | First reviewer | Second reviewer |
| --- | --- | --- | --- |
| Claude Code | The session model, for example Opus 5.5 | Fable 5.2 | GPT-6 Astra |
| Codex | The session model, for example GPT-5.6 Sol | GPT-6 Astra | Fable 5.2 |

Copy `skills/advisor-review/` into `~/.claude/skills/` for Claude Code and into your Codex skill directory (`~/.agents/skills/` or `~/.codex/skills/`) for Codex. Keep the whole folder together: the agent runs the scripts from the `scripts/` folder beside the `SKILL.md` it loaded.

The skill starts on its own when the session opens a pull request or pushes new work to an open pull request. It stays out of tasks that do not end in a pull request, and it skips pull requests that only fix a typo or bump a version. You can also ask for it on an existing pull request or branch. In Codex:

```text
Use $advisor-review on this pull request.
```

In Claude Code, type `/advisor-review` or say "run advisor-review on this pull request".

### How it works

1. The agent writes a short brief: the task, the branch and its base, how to check it, and what was left out on purpose.
2. First reviewer loop: a fresh review, triage, fixes, then another fresh review of the work as it now stands, until a round has nothing to fix.
3. Second reviewer loop: the same with the other model family.
4. The final report says how many rounds each reviewer ran and what was fixed, rejected and deferred.

Every review is a new session that starts from the brief and the working directory. It gets no transcript, no saved memory and no earlier findings. Each CLI still adds its usual context, such as the signed-in account and the state of the repository. The agent picks the review effort per pull request: `medium` for small low-risk ones, `high` by default, `xhigh` for security-sensitive or money-moving work.

A loop stops at 5 rounds per reviewer. It also stops early and asks you when a fixed finding keeps coming back, when fixes keep introducing new defects, when a finding asks for a redesign, or when findings keep landing outside what the task changed.

### What the scripts run

Reviewers can run your code and tests, so neither is sandboxed.

- `scripts/fable-review.sh` runs `claude -p --model claude-fable-5-2` with Read, Grep, Glob and Bash allowed without prompts. It loads no file-edit tools, no skills, no MCP servers, no user settings and no auto-memory, and it saves no session.
- `scripts/astra-review.sh` runs `codex exec -m gpt-6-astra` with `--dangerously-bypass-approvals-and-sandbox` and `--skip-git-repo-check`. It does not load your `config.toml` and it saves no session. Codex may still show the reviewer your installed skills, so the reviewer rules and a guard in both scripts stop a reviewer from starting a review of its own.

Both refuse to start if `reviewer-rules.md` is missing from the `scripts/` folder, and both work when called through a symlink or without the executable bit (`bash fable-review.sh ...`). Set `CLAUDE_BIN` or `CODEX_BIN` to use a CLI that is not on your `PATH`.

Both reviewers are told not to change, commit, push or deploy anything, but that is an instruction, not a restriction. Use the skill only where you would let an agent run commands unattended, and read the two scripts first.

### Requirements

- The Claude Code CLI and the Codex CLI on the same machine, both signed in. Either harness needs both.
- Access to Fable 5.2 in Claude Code and to `gpt-6-astra` in Codex.
- `bash`.
- A session that is allowed to reach the network, start the other CLI, and write to `~/.advisor-review/`. In a sandboxed session the agent asks for approval first.

Each review counts against your Claude or Codex usage. Installing the skill does not grant model access or change your selected model. If a reviewer cannot be run, the agent says so in its report and does not substitute another model.

## Skill format

```text
skills/astra-sol-delegation/
├── SKILL.md          # Complete workflow and required YAML metadata
├── LICENSE.txt       # Redistribution notice
└── agents/
    └── openai.yaml   # Optional Codex display and invocation metadata
```

For `astra-sol-delegation`, `SKILL.md` contains the complete workflow; no runtime dependencies or helper scripts are required. A skill that needs them keeps them in its own folder, as `advisor-review` does with `scripts/`. The package follows the `skills/<name>/SKILL.md` layout used by [steipete/agent-scripts](https://github.com/steipete/agent-scripts).

## Add a skill

1. Create `skills/<name>/SKILL.md` with a unique `name` and a concise, quoted `description` in YAML front matter. Match the folder name to the skill name.
2. Keep instructions portable. Add supporting files only when the workflow needs them, and include any required redistribution notices inside the skill folder.
3. Add the skill to the table above and run `scripts/validate-skills` (requires Ruby). CI runs the same metadata and duplicate-name checks.

## Credits and license

[MIT](LICENSE). The collection layout and validation helper come from [steipete/agent-scripts](https://github.com/steipete/agent-scripts). Astra → Sol is adapted from its Codex First skill. Original material © Peter Steinberger; adaptations © Notorious D.E.V.
