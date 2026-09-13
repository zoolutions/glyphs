# Docs site (`docs/`)

A self-contained docs-kit Rails 8.1 app with its own `Gemfile`, `.rubocop.yml`
and RSpec suite, published at https://glyphs.zoolutions.llc. It depends on the
gem through `gem "glyphs", path: ".."`, so `docs/Gemfile.lock` pins
`glyphs (0.2.4)` — the same number as `lib/glyphs/version.rb`. `rake release`
refreshes both lockfiles (`Rakefile:96-106`), so the pin does not drift.

## Pages

Every page is a `DocsUI::Page` subclass under `app/views/docs/pages/`, and a page
is only routed and in the nav if it also has a `page "…"` line in
`app/models/doc.rb`. The registry holds eight pages:

| Registry line (`app/models/doc.rb`) | View | Documents |
|---|---|---|
| `page "Installation", group: "Getting started"` | `installation.rb` | gemspec deps, `rails_icons:install`/`sync`, `include Glyphs` |
| `page "Quick start", group: "Getting started"` | `quick_start.rb` | name forms, `variant:`, forwarded attributes |
| `page "Components", group: "Guide"` | `components.rb` | the thirteen library components and kit mechanics |
| `page "Missing icons", group: "Guide"` | `missing_icons.rb` | `raise_on_missing`, `on_missing_icon`, `fallback_icons`, `cache_svgs` |
| `page "Custom libraries", group: "Guide"` | `custom_libraries.rb` | `Glyphs.register_library` and where its SVGs live |
| `page "Migration", group: "Guide"` | `migration.rb` | moving an app off local icon helpers with `rubocop -A` |
| `page "RuboCop cops", group: "Reference", slug: "rubocop-cops", view: "RubocopCops"` | `rubocop_cops.rb` | all three cops and every option |
| `page "Shrinking icons in Docker", group: "Guide"` | `shrinking_icons_in_docker.rb` | `glyphs:prune_icons`, `keep_icons`, the Dockerfile step |

A behaviour change lands in the page that owns it *and* in `README.md`, which
documents the same surface in the same order; between them they are the prose a
user reads, with `CHANGELOG.md` recording what moved. The authoring contract is `docs/AGENTS.md` (Section owns
structure and the TOC, Markdown `##` never does, single-quoted heredocs for `md`).

## Configuration that is site-specific

`config/initializers/docs_kit.rb` carries everything that makes the chrome look
like glyphs: brand, tagline, `themes` (which must match the
`@plugin "daisyui" { themes: … }` block in
`app/assets/stylesheets/application.tailwind.css`), Rouge light/dark code
themes, topbar links, SEO/OG knobs, and `nav_registries = { "Docs" => Doc }`.
`c.version_badge` is a lambda so it re-reads `Glyphs::VERSION` on reload.

`config/initializers/glyphs.rb` is the site eating its own dog food: the
docs-kit chrome renders nine lucide icons whose names live in the *gem's* data
(topbar, callouts, search box, theme switcher), which a scan of this app's
source cannot see, so they are listed in `config.keep_icons`.
`circle-question-mark` is not listed because it is already the lucide entry in
`Configuration::DEFAULT_FALLBACK_ICONS`. `config/initializers/rails_icons.rb`
sets `default_library = "lucide"`, and `app/assets/svg/icons/lucide/outline/`
holds the whole synced set — 1745 files, committed.

## CSS build

`bin/build-css` resolves the `daisyui` and `docs-kit` gem paths with
`bundle show` and writes them as `@source` globs into
`app/assets/stylesheets/tailwind.sources.css`, failing fast if either gem cannot
be resolved — a silently missing `@source` would ship an unstyled site. That
generated file *is* committed (see `../review/docs-site.md`) and is listed in
`.dockerignore`, so the image never uses the committed copy. `package.json`
exposes it as `bun run build:css` / `watch:css`, and
`lib/tasks/build_css.rake` enhances `assets:precompile` with `css:build`, so a
production build never forgets it.

## Image and deploy

`docs/Dockerfile` builds from the **repo root**, not `docs/` — the gem is a path
dependency and its gemspec prefers `git ls-files`, so the whole checkout
including `.git` must be in the context (`docker build -f docs/Dockerfile .`).
The build stage runs, in order: `bundle install` (with `frozen` explicitly off,
because the path-gem's git-backed gemspec digest cannot be pinned across
commits), `bun install --frozen-lockfile`, `assets:precompile`, and then
`PRUNE=1 GLYPHS_PRUNE_ICONS=1 ./bin/rails glyphs:prune_icons`. The prune runs
only here, so a developer's checkout keeps every icon while the image ships the
handful it renders; a verification failure aborts the build rather than
shipping broken icons.

`config/deploy.yml` is a dash 4 config (`minimum_version: 4.0.7`) whose
`service`/`image` are `glyphs` / `zoolutions/glyphs` so the ghcr package
auto-links to the repo and `GITHUB_TOKEN` can push it. The `LABEL service="glyphs"`
in the Dockerfile must stay equal to `service:` in that file.
`.github/workflows/deploy-docs.yml` delegates to
`zoolutions/docs-kit/.github/workflows/deploy.yml@main` on every published
Release, so the site ships with the gem.
