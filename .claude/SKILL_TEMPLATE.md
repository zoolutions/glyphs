# Command Template

Use this template when creating a new slash command for glyphs. See the existing
commands in `.claude/commands/` for worked examples.

Copy the content below into `.claude/commands/{name}.md`, then fill it in.

Pick the model tier by the work the command does: `haiku` for mechanical/config
work, `sonnet` for prescriptive pattern-following passes, `opus` for
orchestration, security, review synthesis, and reasoning-heavy specialists.
Always use the tier alias, never a full model ID — aliases track the latest model
in the tier. Pin `fable` only on read-only planning commands that hand execution
to cheaper models (see `/lode:plan`); otherwise choose it per-session with `/model`.

```markdown
---
model: sonnet
description: "{Action verbs describing what it does}. Use when {trigger phrases, contexts, file types}."
argument-hint: "{example input the user might provide}"
allowed-tools: {optional — narrow the tool allowlist, e.g. Bash(gh pr view:*), Read, Grep}
---

# {Command Title}

{One or two sentences: what this command is for and the mental model.}

## When to Use

- {Trigger context 1}
- {Trigger context 2}

## Workflow

1. {Step}
2. {Step}

## Project invariants to respect

- **Icons resolve from disk, never inline** — SVGs live under
  `app/assets/svg/icons/<library>/<variant>/<name>.svg` and are read via the
  transitive `icons` gem; components never embed markup.
- **One thin subclass per library** — new library support is a small `Icon`
  subclass (`lucide_icon.rb`, `phosphor_icon.rb`, …), not resolution logic
  duplicated in `Glyphs.svg_for`.
- **Config gates behavior** — honor `Glyphs.configuration` (`raise_on_missing`,
  `fallback_icons`, `cache_svgs`, `keep_icons`, `prune_source_globs`); don't
  hardcode what config already controls.
- **Pruning is conservative** — the scanner harvests both Prism AST calls and
  template text (incl. dynamic calls); `keep_icons` and `verify!` protect
  referenced icons. Never delete an SVG the scanner can't prove is unused.
- **Cops ship with the gem** — cops under `lib/rubocop/cop/glyphs/` register via
  `lib/glyphs/rubocop.rb`; keep shared matching in `LibraryCallHelpers`.

## Verification

```bash
bundle exec rspec
bundle exec rubocop lib spec
```

## Checklist

- [ ] {Success criterion}
- [ ] `bundle exec rspec` passes (80%+ coverage)
- [ ] `bundle exec rubocop lib spec` passes
```

After creating the file, list it alongside the other commands in `.claude/commands/`
so its tier and purpose stay discoverable. Never bump the gem version inside a
command PR — `rake release` owns the version.
