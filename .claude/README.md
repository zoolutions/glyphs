# `.claude/` — commands, agents, and rules for glyphs

This directory configures how Claude Code works in this repo. It is checked in so
the whole team (and every autonomous session) shares the same conventions.

```
.claude/
├── commands/          Slash commands (/lfg, /tdd, /plan, /security, …) — one markdown file each
├── rules/             Standing rules (agents, coding-style, git-workflow, performance, testing)
├── README.md          This file — how to author a command
└── SKILL_TEMPLATE.md  Copy-paste starting point for a new command
```

## Anatomy of a command

A command is a markdown file under `commands/` with a YAML frontmatter block
followed by the prompt body. `.claude/commands/tdd.md` is a good reference.

```markdown
---
model: sonnet
description: "What it does. Use when {trigger phrases, contexts, file types}."
argument-hint: "example input the user might provide"
allowed-tools: Bash(gh pr view:*), Read, Write, Edit, Glob, Grep, Agent
---

# Command Title

The prompt body — instructions Claude follows when the command runs.
```

### Frontmatter fields

| Field | Purpose |
|-------|---------|
| `model` | Model **tier alias** — see the convention below. Use an alias, never a full model ID, so the command tracks the latest model in its tier. |
| `description` | One line. Leads with action verbs and the trigger context; this is what surfaces the command in the skill list. |
| `argument-hint` | Example of the input the user passes as `$ARGUMENTS`. Omit for zero-argument commands. |
| `allowed-tools` | Optional allowlist that narrows what the command may call (e.g. scoping `Bash` to specific `gh`/`git`/`bundle exec` invocations). Omit to inherit the session's tools. |

## The model tier convention

Pin a model **tier** by the work the command does, not the model you happen to be
running. Tier aliases (`haiku`, `sonnet`, `opus`, `fable`) always resolve to the
latest model in that tier, so a command never goes stale on an outdated pin.

| Tier | Use for | Commands here |
|------|---------|---------------|
| `haiku` | Mechanical / config work, diff pattern-scanning | *(none yet)* |
| `sonnet` | Prescriptive, pattern-following passes with a tight prompt | `/github-review-comments`, `/github-review-failures` |
| `opus` | Orchestration, security, review synthesis, and reasoning-heavy specialists | `/lfg`, `/architect`, `/security`, `/review-pr`, `/github-review-pr`, `/tdd`, `/perf` |
| `fable` | Read-only planning that hands execution to cheaper models | `/plan` |

Rules of thumb:

- **Always use the alias**, never `claude-opus-4-8` or another full model ID —
  aliases track the latest model per tier and never rot.
- **`fable` is pinned only on `/plan`.** Sessions run on `opus` with `fable` as the
  advisor (`.claude/settings.json`), and the `fable-validator` agent checks a finished
  change before its pull request opens (`/lfg`, Phase 6.5).
- **Subagents don't inherit the tier for free.** When a command (or you) spawns a
  subagent for mechanical work — file finding, naming-convention sweeps, pattern
  scans (e.g. sweeping the 13 `*_icon.rb` subclasses or the cop specs) — pass a
  cheaper `model:` explicitly. Left unset, a subagent runs on `sonnet`
  (`CLAUDE_CODE_SUBAGENT_MODEL` in `.claude/settings.json`), never on the session's model.

## Authoring a new command

1. Copy an existing command (`.claude/commands/tdd.md`) into `commands/{name}.md`
   and strip it down to the frontmatter plus a fresh prompt body.
2. Pick the tier by the table above.
3. Write a `description` that leads with what it does and when to use it.
4. Scope `allowed-tools` if the command should be constrained (review/CI commands
   usually are — e.g. `Bash(bundle exec rspec:*)`, `Bash(bundle exec rubocop:*)`,
   `Bash(gh pr:*)`; open implementation commands usually are not).
5. Update the tier table above so the new command appears in its tier's row.
