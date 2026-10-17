# Glyphs

Project instructions for every agent: Claude Code (`CLAUDE.md` imports this file), and any other
tool that reads `AGENTS.md` directly. The delivery workflow (`/flow:lfg`, `/flow:plan`, …) is the
`flow` plugin from the `claude-plugins` marketplace; `/ruby-gem:release` and `/ruby-gem:perf` come
from `ruby-gem`. Both are enabled in `.claude/settings.json`. Local extras live under `.claude/`.

## What this is

Phlex icon components for every [rails_icons](https://github.com/rails-designer/rails_icons)
library (`LucideIcon`, `PhosphorIcon`, `HeroIcon`, `TablerIcon`, ...), plus bundled RuboCop cops
(`Glyphs/IconResolution`, `Glyphs/LegacyIconHelper`, `Glyphs/PreferLibraryComponent`) that validate
icon names at lint time and autocorrect legacy icon helpers. Ruby gem, MIT licensed.

## Layout

- `lib/glyphs/` — the Phlex components (`icon.rb` base + one `*_icon.rb` per library),
  `configuration.rb`, and the pruning pipeline (`source_scanner.rb`, `icon_pruner.rb`,
  `prune_runner.rb`, `prune_report.rb`) behind the `glyphs:prune_icons` task, plus `railtie.rb`.
- `lib/rubocop/cop/glyphs/` — the three bundled cops + `library_call_helpers.rb`, wired through
  the lint_roller plugin in `lib/glyphs/rubocop.rb`.
- `lib/tasks/glyphs.rake` — the `glyphs:prune_icons` rake task.
- `config/default.yml` — default gem configuration.
- `spec/glyphs/` and `spec/rubocop/cop/glyphs/` — specs, mirroring `lib/`.
- `docs/` — a separate Rails app (own `Gemfile`, own `AGENTS.md`, own CI jobs) that builds the
  published docs site. Read `docs/AGENTS.md` before working there.

## Test / lint

```bash
bundle exec rspec              # specs (Ruby 3.4 and 4.0 in CI)
bundle exec rubocop lib spec   # lint — CI lints lib + spec only; docs/ has its own .rubocop.yml
```

`.github/workflows/main.yml` runs both, plus a separate lint/spec pair for `docs/`.
`required_ruby_version` is `>= 3.4` (`glyphs.gemspec`) — match it if you touch the CI matrix.

Command output is condensed by rtk (PreToolUse hook). No project `.rtk/filters.toml`: every
command this repo's agents run (`bundle exec rspec`, `bundle exec rubocop`) is already rewritten
by the global hook and comes back clean — add a filter only if that stops being true.

## Releases

`bin/release` (`list`, `--dry-run`, `minor`/`major`/`X.Y.Z`, `--force` to re-cut) is the front
door to `rake release[X.Y.Z]` (`rakelib/release.rake`), which bumps `lib/glyphs/version.rb` and
the glyphs pin in the tracked lockfiles, commits, pushes `main`, and cuts a GitHub release; on
publish, `.github/workflows/release.yml` tests, builds, verifies gem contents, signs with Sigstore,
and publishes to RubyGems. Both files and the shared jobs of `release.yml` are the zoolutions
release kit (canonical copy in docs-kit, `RELEASE_KIT.md`): never edit them here. To re-publish a
release whose workflow failed, fix `main` and run `bin/release X.Y.Z --force` (the publish skips a
version that is already on RubyGems). `rake build` builds the gem locally and lists its files for a manual check.
Never `gem push` by hand and never bump `version.rb` in a feature PR: `rake release` owns the version.
Changelog entries go under `## [Unreleased]` in `CHANGELOG.md`, grouped by `### Added` /
`### Fixed` / etc.

## Invariants

- **Resolve through `Glyphs.svg_for`.** Components never call `Icons::Icon` directly; that skips
  `raise_on_missing`, `on_missing_icon`, `fallback_icons` and `cache_svgs`. A library component is a
  tiny `Icon` subclass that only declares `LIBRARY`.
- **The missing-icon policy is configured**, never hardcoded: raise, instrument, or fall back.
- **Pruning errs toward keeping.** The scanner harvests only static names (Prism AST, plus the
  template text scan); dynamic ones are covered by `keep_icons`. A parse failure warns and skips that
  one file, never a whole glob. The pruner never deletes `keep_icons` or `fallback_icons`;
  `PruneRunner#verify!` aborts before deleting on an empty scan.
- **The SVG cache** (`SvgCache`, per-Ractor LRU) keys on everything that changes the cached bytes
  (`[library, variant, name, data:-given?]`) and never on per-call attributes, which are merged on
  every call. It stays mutex-guarded and `reset_cache!`-clearable; `cache_svgs = false` bypasses it.
- **Specs** point `Icons.config.base_path` at `spec/fixtures`; no Rails app boots. Cop specs assert
  `expect_offense` and `expect_correction`. Scanner specs cover static AST calls and dynamic/text
  harvesting; pruner specs prove a referenced SVG and a `keep_icons` entry survive. 100% coverage on
  the pruner, `svg_for` resolution, the scanner and cop autocorrection; 80% elsewhere.
- **No speed claim without a same-machine before/after** (throughput and allocations, per render
  not per request). Hot paths: `lib/glyphs.rb` (`svg_for`, `render_svg`, `build_svg`),
  `svg_cache.rb`, `svg_template.rb`, `icon.rb`, `source_scanner.rb`, `prune_runner.rb`. Never trade
  one of the invariants above for speed.
- Commit scopes: `scanner`, `prune`, `config`, `rubocop`, `icon`, `rake`, `docs`, `ci`, `chore`.

## Workflow

- **Verify:** `bundle exec rubocop lib spec` · `bundle exec rspec` · docs app, before a PR touching `docs/`: `cd docs && bundle exec rubocop && bundle exec rspec`
- **Specs:** fast loop `bundle exec rspec <file>`; full suite `bundle exec rspec` (Ractor subset `--tag ractor`); two worktrees at once: yes, no shared state
- **CI:** `main.yml` jobs Lint, Gem Tests (Ruby 3.4 / 4.0), Docs Lint, Docs Tests; required checks (ruleset `main`) are only `conformance / Conformance settings` and `conformance / Conformance (Ruby 4.0)`; full suite on the PR; failure report none
- **Review bot:** cubic
- **Merge:** squash — `gh pr merge <PR> --squash --delete-branch` (no merge queue)
- **PR contract:** body with summary and test plan; exactly one `type` label and at least one `area` label (`bin/labels infer <paths>`), never `status`; rendering or `docs/` changes attach before/after pictures (below)
- **Conflicts:** `CHANGELOG.md` — union under `## [Unreleased]`, no duplicated subheads; `lib/glyphs/version.rb` — take main's; `Gemfile.lock`, `docs/Gemfile.lock` — take main's, then `bundle install` at the root / in `docs/`; `docs/app/models/doc.rb`, `docs/config/routes.rb`, icon-subclass registrations — keep both appended lines
- **Worktree setup:** `bundle install`; in `docs/`: `bundle install` when working there
- **Release:** `bin/release <v>`; changelog `CHANGELOG.md`, `## [Unreleased]`; lockfiles `Gemfile.lock` `docs/Gemfile.lock`; docs `deploy-docs.yml` on release; prep none; human none
- **Main health:** `gh run list --workflow main.yml --branch main --event push --limit 1 --json conclusion,headSha`
- **Upstream:** libraries we own `zoolutions/*`; scrub none
- **Bench:** `bundle exec ruby bench/svg_for.rb` (Glyphs.svg_for per call); CI holds none

## Labels

Every pull request carries exactly one `type` label and at least one `area`
label from `.github/labels.yml` — never a `status` label. `/flow:plan` labels the
issue, `/flow:lfg` copies the issue's `type` and `area` labels onto the PR (never
`plan` or another status label). Without an issue, the type comes from the
change's conventional-commit prefix and the areas from
`bin/labels infer $(git diff --name-only origin/main...HEAD)`. Labels change in
the manifest and reach GitHub with `bin/labels sync`, never through the UI.
Rules: `.github/LABELS.md`. `bin/labels` + `.github/LABELS.md` are the shared
labels kit (canonical copy in docs-kit): never edit them in place.

## Screenshots on PRs and issues (rendering changes)

`gh` ≥ 2.99 uploads images and videos itself. A change to icon rendering (`lib/glyphs/*_icon.rb`,
`svg_for` resolution, a new library, `Glyphs.configure` fallback/variant behavior) or to the
`docs/` site ships with before/after pictures **on the PR**, attached from the terminal. Never a
local path, a base64 blob, or "screenshot available on request". Cop and pruning changes are text
diffs — no screenshot needed.

```bash
gh pr create --attach './after.png#LucideIcon fallback rendering' --title … --label <type> --label <area> --body …   # picture in hand already
gh pr comment <n> --attach './after.png#LucideIcon fallback rendering' --body 'Before/after for the fallback.'
gh pr comment <n> --attach ./before.png --attach ./after.png   # repeat the flag, up to 50 files
gh issue comment <n> --attach ./repro.mp4                       # video renders as a player
```

- Quote the whole argument: the alt text has spaces and bare `<`/`>` would redirect.
  `<file>#<alt text>` sets the alt text; without it the filename is used. A body that already
  references the file (`![alt](./after.png)`) gets that reference rewritten to the uploaded asset,
  so images can sit inline; unreferenced attachments are appended at the end.
- `create`, `edit` and `comment` all take `--attach`. Attach at create time when the picture
  already exists; comment when it comes later, as it does after a verification run.
- Capture with `agent-browser screenshot <file>` against a rendered page — the `docs/` app, or a
  throwaway host app with `gem "glyphs", path: "..."`. Save under the scratchpad, never in the
  repo.
- No `--attach` flag means an old `gh`: `brew upgrade gh`.

## Models

Sessions run on `opus` with `fable` as the advisor (`.claude/settings.json`); `/flow:plan` runs on
Fable and `flow:fable-validator` checks every finished implementation before its PR opens. Name
a `model:` on every spawned agent: one that does not runs on `sonnet`
(`CLAUDE_CODE_SUBAGENT_MODEL`), never on the session's model.
