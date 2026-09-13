# glyphs

Phlex icon components for every library the `icons` gem (reached through
`rails_icons`) knows about. `include Glyphs` — a `Phlex::Kit` — puts thirteen
capitalized methods into a component class (`LucideIcon(:house)`,
`HeroIcon(:check, variant: :solid)`, `PhosphorIcon("lock")`, …), each backed by a
`Glyphs::Icon` subclass whose entire body is `LIBRARY = :<icons-gem library>`.
The SVG markup itself comes from the `icons` gem, which reads
`app/assets/svg/icons/<library>/<variant>/<name>.svg`. What this gem adds on top
is three things: **one resolution point** (`Glyphs.svg_for`) carrying a
configurable missing-icon policy and a per-process render cache; a **build-time
icon pruner** (`bin/rails glyphs:prune_icons`) that deletes the thousands of
synced SVGs an app never renders, so a Docker image ships only what it can
display; and a **RuboCop plugin** that validates statically-known icon names,
autocorrects legacy icon helpers, and flags raw `iconify` class strings.

Three invariants govern every change:

1. **Every render resolves through `Glyphs.svg_for`.** A component that called
   `Icons::Icon.new(...).svg` itself would skip `raise_on_missing`,
   `on_missing_icon`, `fallback_icons` and `cache_svgs` — the whole configurable
   surface (`lib/glyphs.rb#svg_for`, `lib/glyphs/icon.rb#svg_markup`).
2. **The pruner deletes files, so it errs toward keeping.** `SourceScanner`
   harvests dynamic call sites as well as literal ones, `IconPruner` refuses to
   prune a library with no library-specific evidence of use, and
   `PruneRunner#verify!` re-asserts afterwards every confirmed reference and
   configured fallback whose library is synced under `icons_root`, raising —
   the rake task turns that into an aborted build rather than a 500.
3. **The dependency budget is three runtime gems** — `phlex ~> 2.0`,
   `rails_icons ~> 1.2`, `zeitwerk ~> 2.6` — on `required_ruby_version >= 3.4`
   (`glyphs.gemspec`). `prism`, which `SourceScanner` requires, is a Ruby default
   gem at that floor and is deliberately not declared.

The packaged gem ships `lib/`, `config/`, `CHANGELOG.md`, `LICENSE.txt` and
`README.md` and nothing else (`glyphs.gemspec:15-28`); the `docs/` directory is a
separate docs-kit Rails app with its own bundle, deployed to
https://glyphs.zoolutions.llc.
