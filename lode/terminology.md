# Terminology

- **kit** — `Glyphs` itself, `extend Phlex::Kit`. `include Glyphs` in a component
  class exposes every `Glyphs::Icon` subclass as a capitalized method
  (`LucideIcon(...)`), including ones added later by `register_library`.
- **library** — an icons-gem library symbol (`:lucide`, `:heroicons`,
  `:sidekickicons`). `Icons.config.libraries` in icons 0.9.0 holds thirteen, and
  `Glyphs::IconReference::LIBRARY_TO_COMPONENT` names all thirteen.
- **component** — the Phlex class for one library (`Glyphs::LucideIcon`), one
  `lib/glyphs/<name>_icon.rb` file each, thirteen of them.
- **generic component** — `Glyphs::Icon` used directly; it has `LIBRARY = nil`
  and so requires an explicit `library:` keyword or raises `ArgumentError`.
- **variant** — the subdirectory under a library (`outline`, `solid`, `regular`).
  Not every library has one: of the thirteen, seven resolve a default variant
  from the icons gem (`lucide`, `phosphor`, `heroicons`, `tabler`, `boxicons`,
  `flags`, `sidekickicons`) and five resolve `nil` (`feather`, `hugeicons`,
  `linear`, `radix`, `weather`). `animated` is the odd one — see below.
- **variant-less convention** — `nil`, `""` and `"."` all mean "no variant
  subdirectory"; `IconReference.normalize_variant` folds the last two to `nil`.
- **dasherize** — `name.to_s.tr("_", "-")`, applied in `Icon#initialize` and
  everywhere the scanner and cops read a literal name, so `:circle_check` and
  `"circle-check"` are the same icon.
- **missing-icon policy** — the `raise_on_missing` / `on_missing_icon` /
  `fallback_icons` triple in `Glyphs::Configuration`, applied in
  `Glyphs.handle_missing_icon`.
- **fallback icon** — the per-library replacement rendered when an icon is
  missing and `raise_on_missing` is false. Three ship by default
  (`Configuration::DEFAULT_FALLBACK_ICONS`: lucide, phosphor, heroicons); a
  library with no entry re-raises.
- **confirmed reference** — an `IconReference(library, variant, name)` the
  scanner read off a literal call site or an `iconify` string. Returned by
  `SourceScanner#call`, kept by the pruner, and asserted by `verify!`.
- **advisory keep** — a name that is kept if present but never asserted: the
  configured `keep_icons`, and the scanner's `dynamic_keeps`.
- **dynamic keep / harvest** — names recovered from call sites whose first
  argument is not a literal (`LucideIcon(tile[:icon])`), via
  `SourceScanner::DynamicHarvest`. Two sources: file-scoped literals and
  declaration literals.
- **declaration position** — a hash pair whose key matches `/icon/i`
  (`icon: :gear`), or a constant whose name matches `/ICON/i`
  (`STATUS_ICONS = { … }.freeze`). Harvested repo-wide.
- **keep_icons** — the configured last-resort allowlist for names no static scan
  can see (database, ENV, a gem's own chrome). A flat array or a
  `{ library => [names/globs] }` hash; entries are fnmatch globs.
- **wipe guard** — `IconPruner#library_used?`, which refuses to prune a library
  with no reference, no fallback and no *per-library* `keep_icons` entry.
- **iconify string** — a raw `"iconify lucide--house size-4"` CSS class. Both the
  scanner and `Glyphs/IconResolution` recognise it, for three libraries only
  (`lucide|phosphor|heroicons`).
- **legacy helper** — `_lucide`, `_phosphor`, `_hero`, `_heroicon`, `_tabler`
  (five entries in `IconReference::LEGACY_HELPERS`), the app-local helpers this
  gem replaces and `Glyphs/LegacyIconHelper` autocorrects.
- **cop plugin** — the lint_roller `Glyphs::RuboCop::Plugin`, named in the
  gemspec's `default_lint_roller_plugin` metadata, serving `config/default.yml`.
- **docs app** — `docs/`, a self-contained docs-kit Rails app with its own
  Gemfile, RuboCop config and RSpec suite, deployed on every GitHub Release.
- **lode** — this directory: the repo's durable memory. `lode/review/` holds
  accepted review findings as rules; `/lode:gate` enforces them before a push.
