---
model: fable
description: "Investigates the codebase, designs a solution, and produces a durable plan artifact — a GitHub issue or a plan markdown under docs/plans/. Read-only: never edits gem or docs code. Use before /lfg for anything non-trivial."
argument-hint: "issue <feature or problem> | md <feature or problem> | <feature or problem>"
allowed-tools: Bash(gh issue create:*), Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh search:*), Bash(gh label list:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(date:*), Read, Grep, Glob, Write, Agent, AskUserQuestion
---

# Plan — design expensive, execute cheap

You are the planning specialist. This command runs on the most capable model deliberately: the thinking happens here, the execution happens later on cheaper models (`/lfg` on Opus, `/tdd` and the review specialists on Sonnet). That split only works if the plan is **self-contained** — an executor with none of this session's context must be able to implement it without guessing.

## Output mode from $ARGUMENTS

| $ARGUMENTS starts with | Artifact |
|------------------------|----------|
| `issue` | GitHub issue (default — feeds directly into `/lfg <issue-number>`) |
| `md` or `file` | Markdown file at `docs/plans/YYYY-MM-DD-<slug>.md` (date from `date +%F`) |
| anything else | GitHub issue |

## Hard constraints

- **Read-only for source code.** Never edit gem (`lib/`) or spec code, never touch the docs app (`docs/`), never commit, never create branches. The only file you may Write is a new plan markdown under `docs/plans/`.
- **Never reproduce secrets** (RubyGems API keys, `gh` tokens, deploy credentials) in the plan, even redacted ones you encounter while reading config.
- **Dedupe before creating an issue**: `gh issue list --search "<keywords>"` — if an existing issue covers this, extend it in your summary instead of duplicating.

## Phase 1 — Investigate

Protect this session's context: delegate mechanical exploration to cheaper subagents and keep Fable for judgment.

1. Fan out Explore agents (`subagent_type: Explore`) for file discovery and naming-convention sweeps across the gem (`lib/glyphs/`, `lib/rubocop/cop/glyphs/`) and the specs (`spec/glyphs/`, `spec/rubocop/cop/glyphs/`). Launch independent explorations in parallel. If the change touches SVG resolution, verify the real `Icons.config` surface from the transitive `icons` gem — don't assume the path layout (`app/assets/svg/icons/<library>/<variant>/<name>.svg`).
2. Read the load-bearing files yourself — the ones the design decision actually hinges on. Don't design from subagent summaries alone. The likely surfaces, by area:
   - **Icon components**: `lib/glyphs.rb` (the `Glyphs` Phlex::Kit, `svg_for` resolution, config), `lib/glyphs/icon.rb` (base `Icon < Phlex::HTML`), and the per-library subclass (`lucide_icon.rb`, `phosphor_icon.rb`, `hero_icon.rb`, …).
   - **Configuration**: `lib/glyphs/configuration.rb` (`raise_on_missing`, `fallback_icons`, `cache_svgs`, `keep_icons`, `prune_source_globs`).
   - **Pruning**: `lib/glyphs/source_scanner.rb` (Prism AST + template text scan, dynamic-call harvesting), `lib/glyphs/icon_pruner.rb`, `lib/glyphs/prune_runner.rb` (wiring + `verify!`), `lib/glyphs/prune_report.rb`, `lib/tasks/glyphs.rake` + `lib/glyphs/railtie.rb` (the `glyphs:prune_icons` task).
   - **RuboCop cops**: `lib/rubocop/cop/glyphs/*.rb` (IconResolution, LegacyIconHelper, PreferLibraryComponent + shared LibraryCallHelpers), plugin wiring in `lib/glyphs/rubocop.rb`.
3. Read `AGENTS.md` and `.rubocop.yml` at the repo root — the invariants and lint gotchas live there. The published `docs/` site pages are the deeper reference for public API and usage.
4. Check `git log` for recent related work; the design should extend it, not fight it.

## Phase 2 — Surface the unknowns (blindspot pass + interview)

Investigation tells you what the codebase says; this phase finds what the REQUEST doesn't say. Run it BEFORE designing — a wrong assumption caught here costs one question; caught in review it costs a rewrite.

1. **Blindspot pass.** Write down the unknowns you are carrying into the design:
   - decisions the request leaves open (defaults, naming, public API/config surface, backwards-compat & upgrade story)
   - edge cases the codebase makes possible that the request never mentions (missing SVGs, unknown variant, dynamic icon names the scanner can't resolve statically, a library with no subclass)
   - anything with no precedent in this repo — flag it explicitly as unknown-unknown territory
2. **Interview the user** with AskUserQuestion, one question at a time, prioritized by blast radius: architecture-changing answers first, then public API / config surface, then developer ergonomics. Rules:
   - Skip anything the codebase, AGENTS.md, or an existing issue already answers.
   - 2–5 questions is the sweet spot; zero is fine when the request is genuinely unambiguous — say so rather than inventing questions.
   - Every question offers concrete options with a recommended default, never an open-ended essay prompt.
3. **Record the answers** in the plan's Decision section as `Settled in interview:` bullets — constraints the executor must not re-litigate.

## Phase 3 — Design

- Develop 2–3 candidate approaches with real tradeoffs. Pick one and say why; record why the others lost.
- The chosen design must respect the project invariants:
  - **Config, not constants** — new behavior toggles hang off `Glyphs::Configuration`, with a safe default; never hardcode paths or library lists that config should own.
  - **Resolve, don't fabricate SVGs** — icons come from real files under `app/assets/svg/icons/<library>/<variant>/<name>.svg` via the `icons` gem; honor `raise_on_missing`/`fallback_icons` on a miss rather than inventing markup.
  - **The scanner must stay conservative** — pruning deletes files, so `source_scanner.rb` errs toward keeping (dynamic-call harvesting, `keep_icons`); a design that makes the scanner miss references is a regression, and `prune_runner`'s `verify!` must still guard the delete.
  - **Cops correct safely** — an autocorrect must never break resolution; every cop change carries `expect_offense`/`expect_correction` specs.
  - **Ruby floor is 3.4** — no syntax or stdlib that breaks the 3.4 / 4.0 CI matrix.
  - **Never bump the version in a feature PR** — `rake release[x.y.z]` owns the version, tag, and publish.
- Decide the test strategy per the RSpec conventions: unit specs in `spec/glyphs/*_spec.rb`, cop specs in `spec/rubocop/cop/glyphs/*_spec.rb` (using `expect_offense`/`expect_correction`), fixtures under `spec/fixtures/` (`spec_helper.rb` points `Icons.config.base_path` there). Specs are named before the implementation steps they cover (TDD, RED→GREEN→REFACTOR, 80%+ coverage).

## Phase 4 — Emit the plan artifact

Use this structure for the issue body or markdown file. Every section is load-bearing — an executor uses Context to avoid re-discovery, Steps to act, Gates to verify, Boundaries to stop.

```markdown
# <Title>

## Problem / Goal
<What's wrong or missing, who it affects, what done looks like.>

## Context (read these first)
<Bullet list: `path/to/file.rb` — why it matters to this change. Include the component/config/scanner/cop it touches and the matching specs and fixtures. Self-contained: no references to "as discussed" or this session.>

## Decision
<Chosen approach and rationale. Then: alternatives considered and why each was rejected. Call out backwards-compat impact (public API, config surface, SVG resolution) explicitly. End with `Settled in interview:` bullets for every constraint the user confirmed in Phase 2 — the executor must not re-litigate these.>

## Implementation steps
<Ordered, small, each mapped to a specialist where useful (/tdd, /architect). Specs come before the code they cover. Name exact files to create or change.>

## Verification gates
<Exact commands + expected outcome:>
- `bundle exec rspec` — all green
- `bundle exec rubocop lib spec` — no offenses
- `rake build` — builds and verifies gem contents (only if packaging/gemspec/file manifest changed)

## Out of scope
<Explicit boundaries — the adjacent things an eager executor must NOT do. E.g. "do not bump the version", "do not add a hard rails_icons dependency", "do not break backwards compatibility for existing icon components", "do not touch the docs app".>

## Execution
Execute with `/lfg <issue-number>` (or `/lfg docs/plans/<file>.md`).
```

For GitHub issues: create with `gh issue create --title "..." --body "$(cat <<'EOF' ... EOF)"` — single-quoted heredoc delimiter, backticks unescaped. Apply the `plan` label if it exists (`gh label list`); don't create labels.

For markdown files: Write to `docs/plans/YYYY-MM-DD-<slug>.md`. Leave it uncommitted — committing is the user's call.

## Phase 5 — Handoff

Report back: link to the issue (or file path), the chosen approach in 2–3 sentences, and the exact execute command. Stop there — do not start implementing.
