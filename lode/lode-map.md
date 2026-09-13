# Lode map

The index of this repository's durable memory. Read this first; it beats a
directory listing. Every file describes the system as it is now, with the
reasoning; `../CHANGELOG.md` records what changed.

- `summary.md` — what glyphs is, the three invariants, what ships in the gem
- `terminology.md` — the words this repo uses (kit, variant, confirmed reference,
  advisory keep, declaration position, wipe guard, iconify string…)
- `practices.md` — practices learned from the code that `../.claude/rules/` does
  not state: the keep-over-delete asymmetry, two-edit library additions, resets
  for process-global memos, counting the constant behind a universal claim
- `workflow.md` — the profile the shared `/lode:` workflow skills read: commands,
  layers, input shapes, constraints, CI, flake sources, conflict rules
- `plans/README.md` — plans live in GitHub issues; file-mode plans in `docs/plans/`

## Subsystems

- `components/summary.md` — the render path: Zeitwerk and Railtie loading, the
  kit, `Icon`, the thirteen library subclasses, `Glyphs.svg_for` and its cache,
  the missing-icon policy, `register_library`, `Configuration`
- `pruning/summary.md` — `glyphs:prune_icons` end to end: the two-env-var gate,
  what `SourceScanner` counts as a reference, dynamic harvesting, `IconPruner`'s
  wipe guard and keep set, `PruneRunner#verify!` and what it does *not* assert,
  `PruneReport`
- `rubocop-cops/summary.md` — the lint_roller plugin and all three cops:
  option declaration, the three directory states, the fuzzy matcher, which
  libraries each table actually covers
- `docs-site/summary.md` — the docs-kit app: the eight-page registry and what
  each documents, site-specific config, the CSS build, the repo-root Dockerfile
  and the dash deploy
- `testing-and-ci/summary.md` — the RSpec suite and its fixtures, the four CI
  jobs, and `rake release` through to RubyGems trusted publishing

## Review rules (`review/`)

Accepted review findings rewritten as rules about the system and verified
against the code. `/lode:gate` reads every file here before reviewing a diff;
`/lode:learn` adds to them.

- `review/docs-site.md` — one *Not a bug*: the committed, generated
  `tailwind.sources.css`

## Not memory

- `tmp/` — git-ignored: gate reports, handovers, scratch
