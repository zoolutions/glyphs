# Changelog

## [0.3.0]

### Changed

- **The configuration is frozen once a Rails app has booted.** `Glyphs::Railtie`
  calls `Glyphs.finalize!` from `after_initialize`, after every
  `config/initializers` file; no application code is needed. Writing to it
  after that raises `FrozenError`: `Glyphs.configure` in an app's own
  `config.after_initialize` block (it runs after glyphs' hook) or
  `Glyphs.configuration.<setting> =` at runtime. Configure glyphs in an
  initializer; in tests, `Glyphs.reset_configuration!` starts over with a
  fresh, writable configuration. Outside Rails nothing is frozen until you call
  `Glyphs.finalize!`. Refs #25

- **perf: `svg_for` per call, measured with `bench/svg_for.rb`** (Ruby 4.0.6,
  YJIT, arm64 macOS, before → after, same machine, interleaved runs):

  | case | before | after | allocations |
  |---|---|---|---|
  | cache hit, no attributes | 0.51-0.53 µs | 0.67 µs | 2 → 3 |
  | cache hit, same `class:` | 0.65-0.77 µs | 2.25-2.30 µs | 2 → 15 |
  | distinct `id:` per call | 113-188 µs (a miss every call, cache growing) | 3.3-3.5 µs | 302 → 22 |
  | `cache_svgs = false` | 86-129 µs | unchanged | 297 |

  A repeated identical render is about 1.6 µs slower per icon (the attributes
  are now merged on every call); renders with varying attributes are 30× or more
  faster and the cache's memory is bounded. Per icon, not per request. `svg_for`
  without attributes returns the cached markup, frozen. Refs #25

### Fixed

- **fix: the SVG cache no longer grows without bound.** It was keyed on
  `[library, variant, name, attributes]`, so a dynamic `class:` or `id:` per
  render added an entry per call, for the life of the process: a memory leak on
  any busy page. It is now a bounded LRU (`config.svg_cache_size`, 1024 by
  default) keyed on `[library, variant, name]`; each call's attributes are
  applied to the cached markup in plain Ruby, byte-identical to the icons gem's
  own render (HTML boolean attributes, `href`/`src`/`action` and control
  characters, which libxml2 writes specially, render through the icons gem,
  uncached). Refs #25

- **fix: `Glyphs.register_library` and `Glyphs.configure` are serialized.**
  `register_library` was an unguarded `const_defined?`/`const_set`, so threads
  registering the same library at once could each define the constant and get
  different classes back. Both now run under one module lock (a Monitor, so a
  `configure` block may register a library). The configuration is created at
  load instead of on first read. Refs #25

- **fix: `Glyphs/IconResolution`'s class-level memos are locked.** The
  icon-directory cache and the warn-once set were lazily built class instance
  variables; they are now read and written under a Mutex. Refs #25

### Added

- **`Glyphs.finalize!`**: freezes the configuration and makes every setting
  Ractor-shareable that can be, so `svg_for` can read it from a non-main
  Ractor. Called for you in a Rails app (above); outside Rails, call it at the
  end of boot. It never raises and never freezes an object of the app's: a
  collection setting or a Proc becomes a shareable copy, and a value that
  cannot be shared, such as the README's `on_missing_icon` lambda (it closes
  over the initializer's `self`) or a callable holding a logger, is kept as
  is. The configuration is then readable on the main Ractor only; reading it
  from another Ractor raises `Ractor::IsolationError` until `on_missing_icon`
  is a Ractor-shareable callable (frozen, with nothing unshareable inside) or a
  `Ractor.shareable_proc` (Ruby 4.0+). The SVG cache is per Ractor;
  `Glyphs.preload_svg` seeds a Ractor's cache with markup rendered on the main
  Ractor, since the icons gem cannot render inside another one. It serves calls
  without `data:` whose attributes the cache can apply. Refs #25

- **`config.svg_cache_size`** (default 1024; anything but a positive Integer
  raises `ArgumentError`), and `Glyphs.svg_cache`, the current Ractor's cache.
  Refs #25

## [0.2.4] - 2026-07-25

### Fixed

- **`Glyphs/IconResolution` no longer fails open on a missing icon directory.**
  A directory that did not exist produced the same empty list as one that
  existed with no SVGs, and both were read as "nothing to check" — so a library
  that was never synced, or a `DefaultVariant` naming a variant the project does
  not have, silently disabled the cop for every call site of that library. Green
  cop, green CI, no validation at all, indefinitely. `load_icons` now returns
  `nil` for an absent directory and `[]` for an empty one; the absent case warns
  once per library/variant, naming the path. The synced-but-empty case still
  passes silently. Refs #8

- **Cop options are declared, so RuboCop stops calling them unsupported.**
  `config/default.yml` documented `Libraries` (`Glyphs/IconResolution`) and
  `Mappings` (`Glyphs/LegacyIconHelper`) only in comments, and never mentioned
  `LibraryComponents` (`Glyphs/LegacyIconHelper`, `Glyphs/PreferLibraryComponent`)
  at all. RuboCop derives its supported-parameter list from the keys actually
  present in that file, so it warned `does not support <param> parameter` on
  every run — for four working options, one of which
  `Glyphs/LegacyIconHelper` itself tells you to add. Each is now declared with an
  empty default (a no-op merge), so the options are validated instead of
  reported, with behaviour unchanged. Refs #7

### Added

- **`Glyphs/IconResolution` gained a `Strict` option** (default `false`). It
  escalates the missing-icon-directory warning above to an offence, so projects
  that depend on this cop can fail closed in CI instead of trusting a warning
  not to scroll past.

## [0.2.3] - 2026-07-17

### Fixed

- **Declaration harvest unwraps trailing `.freeze`.** `ICONS = { "x" => :car }.freeze`
  (and `%i[a b].freeze`) used to yield a Prism `CallNode`, so hash/array values
  were never collected. Cross-file dynamics (`PhosphorIcon(@icon)` in a shared
  component + names only in a frozen `ICONS` map) then lost those icons at
  `glyphs:prune_icons`. `collect_declaration` now unwraps zero-arg `.freeze`
  (and parentheses) before walking the value.

## [0.2.2] - 2026-07-11

### Added

- **Dynamic icon calls are now resolved from source.** `SourceScanner` no longer
  silently skips `LucideIcon(some_var)` / `PhosphorIcon(tile[:icon])` — it harvests
  the literal name from two places so the pruner keeps it:
  - _file-scoped_: a file that dynamically renders a library keeps every
    icon-name-shaped literal in that file for that library (ternaries, `case`,
    locals);
  - _declaration-based_: literals in icon-declaration positions anywhere (a hash
    pair keyed `/icon/i`, or a constant named `/ICON/`) are kept for every
    dynamically-rendered library, closing the cross-file gap (e.g. a notifier
    `ICON = :bell` constant rendered from a view). Frozen maps
    (`ICONS = { … }.freeze`) are included since 0.2.3.

  This makes `keep_icons` a last-resort escape hatch (DB/ENV/gem-chrome names)
  rather than the primary mechanism. Only literals are harvested, so the scanner
  never invents a reference.

## [0.2.0] - 2026-07-07

### Changed

- **Breaking:** `config.raise_on_missing_icon` (a callable) is now `config.raise_on_missing`,
  an honest boolean. The default is evaluated once: `Rails.env.local?` under Rails, `true` outside.
- **Breaking:** `config.on_missing_icon` now defaults to `nil` — set it only if you want a handler.

### Added

- Release workflow with RubyGems trusted publishing (OIDC) and Sigstore attestation.

## [0.1.0] - 2026-07-07

### Added

- `Glyphs::Icon` base Phlex component rendering SVGs through the `icons` gem (rails_icons).
- Library components exposed via `Phlex::Kit`: `LucideIcon`, `PhosphorIcon`, `HeroIcon`, `TablerIcon`,
  `FeatherIcon`, `BoxIcon`, `FlagIcon`, `HugeIcon`, `LinearIcon`, `RadixIcon`, `SidekickIcon`,
  `WeatherIcon`, `AnimatedIcon`.
- `Glyphs.register_library` for custom icon libraries.
- Configurable missing-icon policy (`raise_on_missing_icon`, `on_missing_icon` hook, `fallback_icons`)
  and per-process SVG render cache (`cache_svgs`).
- RuboCop plugin (lint_roller) with `Glyphs/LegacyIconHelper`, `Glyphs/IconResolution`, and
  `Glyphs/PreferLibraryComponent`.
