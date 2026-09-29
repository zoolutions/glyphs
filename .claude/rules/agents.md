# Agent Orchestration Rules

## Available Agents

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| Explore (`model: haiku`, or `sonnet` to read a subsystem) | Codebase exploration | Finding files, understanding patterns across the gem + docs app |
| Plan (`model: sonnet`) | Implementation planning | Complex features spanning icon component → scanner → prune/rake |
| general-purpose (`model: sonnet`) | Multi-step tasks | Research, complex searches |

Every agent spawned names its `model:`. One that does not runs on `sonnet` (`CLAUDE_CODE_SUBAGENT_MODEL` in `.claude/settings.json`).

## Immediate Agent Usage

Use agents PROACTIVELY without waiting for a prompt:

1. **Complex feature requests** → Plan agent first
2. **Codebase exploration** → Explore agent
3. **Multi-file searches** → Explore agent (not direct Glob/Grep)
4. **Cross-context questions** (gem ↔ docs app) → Explore agent against both `lib/` and `docs/`

## Parallel Execution

ALWAYS run independent operations in parallel:

```markdown
# GOOD: parallel
1. Agent 1: how the source scanner harvests referenced icons today
2. Agent 2: how the icon pruner decides what to delete
3. Agent 3: which RuboCop cop guards this icon-resolution path

# BAD: sequential when independent
```

## When to Use Explore

Use the Explore agent (subagent_type=Explore, `model: haiku`) instead of direct Glob/Grep when:
- Open-ended exploration across the gem (`lib/glyphs/`, `lib/rubocop/cop/glyphs/`) and the docs app (`docs/`)
- Confirming a Phlex/Icons API's real signature (e.g. how `svg_for` resolves a
  variant path, or how `Icons.config.base_path` is read) before building against it —
  verify the actual behavior, don't assume
