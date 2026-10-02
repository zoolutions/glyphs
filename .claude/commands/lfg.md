---
model: opus
description: "Executes full autonomous engineering workflow with verification. Use when implementing complete features, tackling GitHub issues, or running end-to-end development cycles."
argument-hint: "GitHub issue number/URL or feature description"
allowed-tools: Bash(gh issue view:*), Bash(gh search:*), Bash(gh issue list:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh pr edit:*), Bash(bin/labels infer:*), Bash(bin/labels sync), Bash(bundle exec:*), Bash(git:*), Read, Write, Edit, Glob, Grep, Agent
---

# LFG - Full Autonomous Workflow

Execute a complete engineering workflow with verification at each phase.

## Phase 0: Branch Setup

**BEFORE any other work, prepare the git branch:**

1. Check the current branch: `git branch --show-current`
2. If NOT on `main`, switch: `git checkout main`
3. Pull latest: `git pull origin main`
4. Create feature branch: `git checkout -b issue-{number}-{brief-description}` (or `feat/{description}` if no issue number)

---

## Phase 1: Understand

### Step 1: Gather Requirements

If `$ARGUMENTS` is a GitHub issue number or URL:

```bash
gh issue view <number> --json title,body,labels,assignees,comments
```

If `$ARGUMENTS` is a description, use it directly.

**Keep the issue's `type` and `area` labels** — Phase 7 puts them on the pull request. `/lfg` never edits the issue's own labels; the issue's lifecycle is the user's to manage. A `docs/plans/*.md` plan carries them on its `Labels:` line. If there are none, or you were given a description, infer them: one `type` label plus `bin/labels infer <changed paths>` for the areas (`.github/LABELS.md`).

### Step 2: Define Acceptance Criteria

**MANDATORY:** Write explicit acceptance criteria:

- **GIVEN** [context/setup]
- **WHEN** [action taken]
- **THEN** [expected outcome]

You MUST NOT proceed until you can articulate these clearly.

### Step 3: Comprehension Gate

Before proceeding, you must:

1. State the problem/feature in one sentence
2. Explain WHY this is needed (the user-facing payoff — "a pleasure to work with")
3. List what changes from the developer's perspective (the API delta — new component, config option, cop, or rake behavior)
4. Identify edge cases not explicitly mentioned
5. Explain the flow: how the change moves through the gem (icon resolution `svg_for` → SVG read, or scan → prune → verify, or cop → offense → autocorrect)

If you cannot complete ALL five items, investigate further.

### Step 4: Create Task List

Create a TaskCreate todo list with specific implementation steps.

---

## Phase 2: Explore

1. Find related files (Glob/Grep or an Explore agent with `model: haiku`)
2. Read existing patterns in similar features
3. Understand integration points across the gem's surfaces
4. Check existing test coverage in `spec/glyphs/` and `spec/rubocop/cop/glyphs/`
5. If touching icon rendering, review `lib/glyphs.rb` (the `Glyphs` kit + `svg_for` resolution) and `lib/glyphs/icon.rb` (base `Icon < Phlex::HTML`), plus the relevant per-library subclass (`lib/glyphs/lucide_icon.rb`, etc.)
6. If touching pruning, review the scan → prune → report chain: `lib/glyphs/source_scanner.rb`, `lib/glyphs/icon_pruner.rb`, `lib/glyphs/prune_runner.rb`, `lib/glyphs/prune_report.rb`, and the `glyphs:prune_icons` task in `lib/tasks/glyphs.rake` + `lib/glyphs/railtie.rb`
7. If touching cops, review `lib/rubocop/cop/glyphs/*.rb` and the shared `library_call_helpers.rb`, plus the plugin wiring in `lib/glyphs/rubocop.rb`
8. If SVG resolution is involved, **verify the real path layout** — icons resolve from `app/assets/svg/icons/<library>/<variant>/<name>.svg` via the transitive `icons` gem; specs point `Icons.config.base_path` at `spec/fixtures`

---

## Phase 3: Plan

1. List files to modify with specific changes
2. List new files to create with purpose
3. Identify config-driven behavior branches (e.g. `raise_on_missing` on vs off, `cache_svgs`, `fallback_icons`, `keep_icons`) — the change must honor every relevant `Glyphs::Configuration` toggle
4. Plan test coverage (TDD: tests FIRST) — unit specs for the class, cop specs with `expect_offense`/`expect_correction` for cop work, fixture SVGs under `spec/fixtures/` where rendering is exercised
5. Update the task list
6. Consider backwards compatibility (existing components, config options, and cop behavior must keep working verbatim)

---

## Phase 4: Implement (TDD)

### The deviation log (keep it from the first edit)

The plan is the map; the codebase is the territory. The moment reality forces a choice the plan or issue didn't settle, log it in `implementation-notes.md` at the repo root — one line, at the moment it happens, not reconstructed later:

- **Deviations** — the plan said X, you did Y, because Z
- **Discoveries** — facts about the codebase the plan didn't know
- **Judgment calls** — choices the user might have made differently (defaults, naming, scope cuts)

Pick the conservative option and keep going. The log is how the user audits your judgment afterwards. Never commit the file: its contents move into the PR body (Phase 7), then the file is deleted.

For each logical unit:

### 4.1: Write Failing Test First

```bash
bundle exec rspec <spec_file>
```

### 4.2: Implement Minimum Code

Write the MINIMUM code to make the test pass. Follow project patterns:

| Never Do | Always Do |
|----------|-----------|
| Add a new per-library class by hand | Follow the existing subclass shape (`lib/glyphs/<lib>_icon.rb`) |
| Read an SVG path directly | Resolve through `svg_for` / the base `Icon` so config applies |
| Ignore a missing icon silently | Respect `raise_on_missing` + `fallback_icons` config |
| Delete SVGs eagerly in a cop or component | Pruning lives in the scan → prune → verify chain only |
| Regex-scan Ruby for icon calls | Use the Prism AST path in `SourceScanner` (template text scan is the fallback) |
| Hardcode a fixture path in a spec | Rely on `spec_helper` pointing `Icons.config.base_path` at `spec/fixtures` |
| Hand-assert cop offenses | `expect_offense` / `expect_correction` |

### 4.3: Refactor

Once green, refactor while keeping tests passing.

### 4.4: Validate

```bash
bundle exec rubocop lib spec
```

### 4.5: Repeat

Move to the next unit. Mark task items complete.

---

## Phase 5: Deep Root Cause Analysis (Bug Fixes Only)

**If this is a bug fix, investigate before implementing.**

### Trace the lifecycle

For the failing behavior:
- Where did resolution start? Which library/variant/name did it ask for, and what path did that map to?
- For a prune bug: did the scanner miss a reference, or did the pruner delete something it shouldn't have? Check the report.
- What ASSUMPTIONS does the code make at the failure point? Which was violated, and WHY?

### Use git history

```bash
git log --oneline -20 <file>
git blame <file>
```

### Map all callers

Use Grep to find every call site. Does the bug happen only for one library? Only for a specific variant? Only when `raise_on_missing` is off? Only for dynamically-referenced icons the scanner harvests?

### Five Whys

Keep asking WHY until you reach the real fix point.

### Fix-location principle

The best fix is usually NOT where the error surfaced:
- Icon renders blank → the `svg_for` resolution / variant path, not a `rescue` in the component
- Referenced icon got pruned → the `SourceScanner` dynamic-call harvesting, not a `keep_icons` band-aid
- Cop autocorrect produces invalid Ruby → the corrector's replacement, not disabling the cop
- Missing-icon crash in production → the `raise_on_missing` / `fallback_icons` path, not a caller-side `&.`

### Unacceptable superficial fixes — DO NOT DO THESE

- `rescue nil` / bare `rescue` to silence an error you don't understand
- `&.` to paper over a nil without finding why it's nil
- `return if x.nil?` to silently skip
- swallowing errors instead of logging + fixing the cause

**These HIDE bugs. Find the EARLIEST point you could prevent the error and fix there.**

---

## Phase 6: Verify

**ALL of these must pass before committing:**

```bash
bundle exec rubocop lib spec
bundle exec rspec
# docs-app changes: also lint and test the docs site
cd docs && bundle exec rubocop && bundle exec rspec
```

### Solution verification

- "If I were the requester, is this fully resolved?"
- "Did I fix the ROOT CAUSE, not the symptom?"
- "Do the tests prove it, including the `raise_on_missing`-off / `fallback_icons` path where relevant?"
- "Does every existing component, config option, and cop still behave verbatim (backwards compatible)?"

---

## Phase 6.5: Fable validation

Spawn the `fable-validator` agent (it is pinned to Fable) with the issue, the acceptance criteria from Phase 1 and the base branch. On **BLOCK**, fix every blocker (back to Phase 4 for code, with a failing test first), re-verify, and run the validator again. On **PASS WITH NOTES**, fix the risks you agree with (if those fixes change the diff, re-verify and run the validator again) and list the rest in the pull request under "Accepted risks". Put the validator's one-line verdict and its "Not verified" list in the pull request body. Do not open the pull request before a PASS or PASS WITH NOTES.

---

## Phase 7: Commit & PR

**Never bump the gem version inside a feature PR — `rake release` owns the version.**

### Commit

```bash
git add <specific_files>
git commit -m "$(cat <<'EOF'
feat(scope): brief description

## Summary
[What changed and why]

## Test Coverage
- spec 1: validates X
- spec 2: validates the missing-icon / fallback path

## Verification
- [x] bundle exec rubocop lib spec passes
- [x] bundle exec rspec passes
EOF
)"
```

Use a scope that fits glyphs: `scanner`, `prune`, `config`, `rubocop`, `icon`, `rake`, `docs`, `ci`, `chore`.

### Push & PR

```bash
git push -u origin $(git branch --show-current)

gh pr create --title "feat(scope): brief description" --label <type> --label <area> [--label <area>…] --body-file /tmp/pr-body.md
```

**Label the PR — every time.** The `--label` flags are the issue's `type` + `area` labels from Phase 1, never a `status` label (`plan`, `epic`, …). For a description-only run, infer them: one `type` (`.github/LABELS.md` maps conventional-commit prefixes to types) plus `bin/labels infer $(git diff --name-only origin/main...HEAD)`. Exactly one type, at least one area. `gh pr create` fails on a label that doesn't exist on GitHub: run `bin/labels sync` (or label after the fact with `gh pr edit <n> --add-label …`).

Write the PR body to a temp file (`--body-file`) to avoid shell-interpolation of
backticks/tables. The body is copied verbatim — if you would not type a
backslash in a GitHub comment, do not type one in the heredoc.

The PR body MUST end with a `## Deviations & judgment calls` section copied from
`implementation-notes.md` (then delete the file). If the plan held completely,
write "None — the plan held." This section is read FIRST in review — it is the
audit trail for every decision the plan didn't make.

---

## Phase 8: Comprehension Close-Out

The tests prove the CODE is right; this phase keeps the USER's mental model right. After the PR is up, end your final message with:

1. **The decisions, not the diff** — the 3–5 non-obvious choices in this change someone must understand to maintain it. Lead with anything from the deviation log; the user has never seen those.
2. **Three merge-gate questions** the user should be able to answer before merging (e.g. "why does the scanner harvest dynamic calls before the pruner runs?"). If any answer isn't obvious to them, offer a walkthrough — an unanswerable question is comprehension debt, and merging anyway is how it compounds.

---

## Verification Checklist

- [ ] All acceptance criteria met
- [ ] Tests written BEFORE implementation
- [ ] `bundle exec rubocop lib spec` passes
- [ ] `bundle exec rspec` passes (docs site too, if `docs/` changed)
- [ ] Backwards compatible — existing components, config options, and cops unchanged
- [ ] Config toggles honored (`raise_on_missing`, `fallback_icons`, `cache_svgs`, `keep_icons` where relevant)
- [ ] Version NOT bumped — `rake release` owns that
- [ ] `fable-validator` verdict PASS or PASS WITH NOTES (Phase 6.5), verdict and "Not verified" in the PR body
- [ ] PR created with summary + test plan
- [ ] PR labelled: one `type` + at least one `area`, no `status` (`.github/LABELS.md`)
- [ ] PR body ends with `## Deviations & judgment calls` (from implementation-notes.md, since deleted)
- [ ] Comprehension close-out delivered (decisions + three merge-gate questions)

Now, execute this workflow for the provided issue or feature.
</content>
</invoke>
