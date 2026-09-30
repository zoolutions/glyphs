---
model: opus
description: Review a GitHub pull request for code quality, patterns, and best practices
argument-hint: "PR URL or number (e.g., 5 or https://github.com/mhenrixon/glyphs/pull/5)"
---

# PR Review

Review a PR for pattern compliance and issues. Be concise.

## Workflow

1. Fetch PR details and diff via `mcp__github__pull_request_read`
2. Categorize files by area (icon components, config, scanner/prune, rubocop cops, rake/railtie, docs, spec)
3. Check for pattern violations
4. Output a structured review

## Pattern Violations to Check

```text
# WRONG -> RIGHT
New library subclass duplicates Icon      -> Subclass sets library only; render logic stays in Icon
Hardcoded SVG path in a component         -> Resolve via svg_for / Icons config base_path
Missing raise_on_missing / fallback path  -> Honor Configuration (raise_on_missing, fallback_icons)
Scanner misses a dynamic icon call        -> Harvest dynamic calls in SourceScanner (Prism AST + text scan)
Pruner deletes a still-referenced SVG     -> PruneRunner#verify! must gate the delete set
keep_icons / prune_source_globs ignored   -> Read them from Configuration, don't hardcode
Cop matches by string, not AST node       -> Use LibraryCallHelpers over the Prism/RuboCop node
Cop spec lacks correction assertion       -> expect_offense + expect_correction
Version bumped inside a feature PR         -> rake release owns version; never bump in a PR
Manual gem push                           -> bin/release
Feature branch off a non-main base        -> Branch off main (feat/, fix/, refactor/, ci/, chore/)
New/changed behavior without a spec        -> RSpec first (RED -> GREEN), 80%+ coverage
```

## Output Format

```
## Files Requiring Manual Review

| File | Reason |
|------|--------|
| lib/glyphs/source_scanner.rb | Reference harvesting — verify dynamic-call coverage |
| lib/glyphs/prune_runner.rb | Delete gate — verify verify! before removing SVGs |
| lib/rubocop/cop/glyphs/*.rb | Cop logic — verify AST match + autocorrection |

## Critical Issues

- `lib/glyphs/prune_runner.rb:NN` - Deletes set not verified against referenced icons
- `lib/glyphs/source_scanner.rb:NN` - Dynamic icon call not harvested (false-negative prune)

## Suggestions (non-blocking)

- Consider extracting X

## Verdict

**Request Changes** | **Approve** | **Comment** — one-line justification
```

## Tools

```text
mcp__github__pull_request_read
  method: "get"        -> PR details
  method: "get_diff"   -> Changes
  method: "get_files"  -> File list
  method: "get_status" -> CI status

bundle exec rubocop lib spec  -> Style checks (gem)
bundle exec rspec             -> Tests
```
