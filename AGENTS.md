# Glyphs

Project instructions for every agent: Claude Code (`CLAUDE.md` imports this file), and any other
tool that reads `AGENTS.md` directly. Claude-only extras (commands, standing rules) live under
`.claude/`.

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

`rake release[X.Y.Z]` (`[pre]` for a pre-release, `[X.Y.Z,force]` to re-cut) bumps
`lib/glyphs/version.rb`, commits, pushes `main`, and cuts a GitHub release; on publish,
`.github/workflows/release.yml` tests, builds, verifies gem contents, signs with Sigstore, and
publishes to RubyGems. `rake build` builds the gem locally and lists its files for a manual check.
Changelog entries go under `## [Unreleased]` in `CHANGELOG.md`, grouped by `### Added` /
`### Fixed` / etc.

## Screenshots on PRs and issues (rendering changes)

`gh` ≥ 2.99 uploads images and videos itself. A change to icon rendering (`lib/glyphs/*_icon.rb`,
`svg_for` resolution, a new library, `Glyphs.configure` fallback/variant behavior) or to the
`docs/` site ships with before/after pictures **on the PR**, attached from the terminal. Never a
local path, a base64 blob, or "screenshot available on request". Cop and pruning changes are text
diffs — no screenshot needed.

```bash
gh pr create --attach './after.png#LucideIcon fallback rendering' --title … --body …   # picture in hand already
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
