# Testing, CI and release

## The suite

RSpec, 13 spec files and 140 `it` blocks under `spec/`, plus one request spec
(5 examples) in the docs app. No Rails app boots for the gem specs.

`spec/spec_helper.rb` does four things that every spec depends on:

- points `Icons.config.base_path` at `spec/fixtures` with `icons_path = "svg/icons"`,
  so an icon resolves to `spec/fixtures/svg/icons/<library>/<variant>/<name>.svg`;
- `Glyphs.reset_configuration!` and `Glyphs.reset_cache!` in a global `before`,
  because both are process-global;
- marks anything under `spec/rubocop/` as `type: :cop_spec` and includes
  `RuboCop::RSpec::ExpectOffense` there, so cop specs use `expect_offense` /
  `expect_correction` rather than hand-built matchers;
- `config.order = :random` with `Kernel.srand config.seed` — order-dependent
  state is a bug, and `IconResolution`'s process-wide warning memo is reset in
  that file's own `before` for exactly this reason.

| Under test | File | Notes |
|---|---|---|
| `Glyphs::Icon`, `svg_for`, the cache | `spec/glyphs/icon_spec.rb` | asserts `data-glyph="…"` — an attribute the *fixture* SVGs carry, not something the gem emits |
| The kit | `spec/glyphs/kit_spec.rb` | asserts a component exists for all thirteen libraries |
| `register_library` | `spec/glyphs/register_library_spec.rb` | idempotence and the conflicting-constant raise |
| Configuration | `spec/glyphs/configuration_spec.rb` | defaults and the two `keep_icons` shapes |
| `IconReference` | `spec/glyphs/icon_reference_spec.rb` | the maps, `normalize_variant`, `default_variant_for` per library |
| Scanner | `spec/glyphs/source_scanner_spec.rb` | drives the real `spec/fixtures/source` tree (7 files) |
| Pruner | `spec/glyphs/icon_pruner_spec.rb` | keep/delete, the wipe guard, the animated skip |
| Runner | `spec/glyphs/prune_runner_spec.rb` | copies fixture SVGs into a `Dir.mktmpdir` and deletes for real |
| Report | `spec/glyphs/prune_report_spec.rb` | the printed strings and the sums |
| Cops | `spec/rubocop/cop/glyphs/*_spec.rb` | `expect_offense` + `expect_correction` |
| Plugin | `spec/rubocop/plugin_spec.rb` | `about`, `supported?`, and that every `cop_config` key the cops read is declared in `config/default.yml` |

### Fixtures

- `spec/fixtures/svg/icons/` — 10 SVGs across `lucide/outline`,
  `heroicons/outline`, `heroicons/solid`, `phosphor/regular`, `phosphor/light`,
  plus an empty `emptylib/regular/` (a `.keep`) that proves the
  directory-exists-but-empty branch of `Glyphs/IconResolution`.
- `spec/fixtures/source/` — a miniature app of 7 files: a Phlex component
  covering the component, legacy-helper, generic `Icon`/`icon` and `iconify`
  call forms plus three dynamic shapes (dynamic name, dynamic variant, dynamic
  library); a notifier with an `ICON` constant; a frozen `ICONS` hash; an ERB
  view; a plain model; and `broken.rb`, which is deliberately unparseable. The
  scanner finds 13 confirmed references and dynamic keeps for `lucide` and
  `phosphor` in that tree.
- Both trees are excluded from RuboCop (`.rubocop.yml`, `AllCops/Exclude`).

Anything that writes must work in a `Dir.mktmpdir` — `prune_runner_spec.rb`
copies the fixture icons into one before deleting, so a real prune never touches
the repo.

## CI (`.github/workflows/main.yml`)

On `push` to `main` and on every `pull_request`, four jobs:

| Job | Ruby | Runs |
|---|---|---|
| `Lint` | 4.0 | `bundle exec rubocop lib spec` |
| `Gem Tests (Ruby 3.4)` / `(Ruby 4.0)` | matrix, `fail-fast: false` | `bundle exec rspec` |
| `Docs Lint` | 4.0 | `bundle exec rubocop` from `docs/` — inspects 0 files today, since the root `.rubocop.yml` excludes `docs/**/*` for every run beneath it (issue #15) |
| `Docs Tests` | 4.0 | `bundle exec rspec` from `docs/` |

Green means all five check runs. The gem and the docs app are separate bundles
(`bundler-cache` with `working-directory: docs` for the docs jobs), so a docs
failure is fixed from inside `docs/`.

The matrix floor matches `required_ruby_version >= 3.4`, and `release.yml`
carries a comment saying its own matrix must stay equal to it — a Ruby the gem
claims to support but does not test is the failure that comment exists to
prevent. Nothing in the suite reaches the network, and no two jobs share state,
so parallel runs and two local worktrees are both safe.

Note the local/CI asymmetry: `rake` (the default task) runs `spec` then a **bare**
`rubocop`, which also lints `Rakefile` and `glyphs.gemspec`; CI's `Lint` job runs
`rubocop lib spec`. A `rake`-clean tree is therefore the stricter of the two.

## Release

`rake release[X.Y.Z]` (`Rakefile:33-160`) is the only supported path, and only
from `main` with a clean tree — it aborts otherwise. In order: optional
`force` cleanup (`gh release delete --cleanup-tag`, then `git tag -d`), rewrite
`VERSION` in `lib/glyphs/version.rb`, `bundle install` at the root *and* in
`docs/`, `gem build --strict` as a smoke test, commit
`chore: bump version to X.Y.Z` with both lockfiles, push `main`, and
`gh release create vX.Y.Z --generate-notes` (`--prerelease` when the version
matches `/alpha|beta|rc|pre/`, or for the bare `pre` argument, which re-releases
the current version). The version bump, the commit, the push and the release
creation each skip themselves when already done, so a re-run after a partial
failure is safe; `bundle install` and `gem build` always run.

Publishing the release fires two workflows:

- `release.yml` — test on 3.4 and 4.0, then build: verify the tag equals
  `Glyphs::VERSION`, `gem build --strict`, unpack and refuse the build if the gem
  contains any `.git*` file, any `*.gemspec`, or a `spec`/`test` directory, emit
  sha256/sha512; then publish to RubyGems through trusted publishing (OIDC, the
  `rubygems` environment, `id-token: write`) with a Sigstore attestation,
  skipping with a warning if that version is already on RubyGems; then upload
  the gem, both checksums and the Sigstore bundle to the release.
- `deploy-docs.yml` — the docs site, via docs-kit's reusable workflow.

`publish-tag.yml` is the manual re-run: `workflow_dispatch` with a `tag` input,
same test → build → publish chain against that tag. There is no API key anywhere
in either workflow.
