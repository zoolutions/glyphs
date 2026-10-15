# Glyphs

Phlex icon components for every [rails_icons](https://github.com/rails-designer/rails_icons) library —
plus bundled RuboCop cops that validate icon names at lint time and autocorrect legacy icon helpers.

```ruby
class ApplicationComponent < Phlex::HTML
  include Glyphs
end

LucideIcon(:house, class: "size-4")
PhosphorIcon("lock", variant: :bold)
HeroIcon(:check, class: "size-5 text-success")
```

## Installation

```ruby
# Gemfile
gem "glyphs"
```

Glyphs renders the SVG files that rails_icons syncs into your app. If you haven't already:

```bash
rails generate rails_icons:install --libraries=lucide heroicons
rails generate rails_icons:sync --libraries=lucide heroicons
```

Outside Rails, configure the [icons](https://rubygems.org/gems/icons) gem directly:

```ruby
Icons.configure do |config|
  config.base_path = File.expand_path(__dir__)
  config.icons_path = "svg/icons"
end
```

## Components

`include Glyphs` (a `Phlex::Kit`) into your component base class and call icons as capitalized methods:

| Component | rails_icons library |
|---|---|
| `LucideIcon` | lucide |
| `PhosphorIcon` | phosphor |
| `HeroIcon` | heroicons |
| `TablerIcon` | tabler |
| `FeatherIcon` | feather |
| `BoxIcon` | boxicons |
| `FlagIcon` | flags |
| `HugeIcon` | hugeicons |
| `LinearIcon` | linear |
| `RadixIcon` | radix |
| `SidekickIcon` | sidekickicons |
| `WeatherIcon` | weather |
| `AnimatedIcon` | animated (bundled spinners: `faded-spinner`, `bouncing-dots`, ...) |

Names can be symbols or strings; underscores are dasherized (`:circle_check` → `circle-check.svg`).
`variant:` selects the library variant (default comes from your rails_icons/icons configuration);
every other keyword (`class:`, `data:`, `stroke_width:`, ...) is forwarded onto the `<svg>` tag.

The generic component requires an explicit library:

```ruby
Icon(:house, library: :lucide) # flagged by Glyphs/PreferLibraryComponent, prefer LucideIcon(:house)
```

Custom libraries get first-class components too:

```ruby
Glyphs.register_library(:brand, component: :BrandIcon)
BrandIcon(:logo)
```

(The SVG location for a custom library is configured through rails_icons/icons custom-library config.)

## Missing-icon policy

```ruby
# config/initializers/glyphs.rb
Glyphs.configure do |config|
  # Re-raise Icons::IconNotFound? Defaults to true in local Rails
  # environments (and outside Rails), false otherwise.
  config.raise_on_missing = Rails.env.local?

  # Optional handler, called before the fallback renders (when not raising).
  config.on_missing_icon = lambda do |error, name:, library:, variant:|
    Rails.logger.error("Icon missing: #{library}/#{variant}/#{name} (#{error.message})")
  end

  # Rendered instead of the missing icon (per library). nil/absent => re-raise.
  config.fallback_icons = {
    lucide: "circle-question-mark",
    phosphor: "question",
    heroicons: "question-mark-circle"
  }

  # Memoize rendered SVGs per [library, variant, name]; the call's attributes
  # (class:, data:, ...) are applied to the cached markup each time. Default: true.
  # Note: fallback renders are cached under the original name, so on_missing_icon
  # fires once per missing icon while it stays cached, rather than on every render.
  config.cache_svgs = true

  # How many icons the cache holds (least recently used evicted first). One
  # cache per Ractor, so a plain threaded server has one. Default: 1024.
  config.svg_cache_size = 1024
end
```

## Ractors

Call `Glyphs.finalize!` once at the end of boot, after every `Glyphs.configure`. It deep-freezes the
configuration so it can be read from any Ractor; an unshareable setting raises `ArgumentError` naming
it. `on_missing_icon` is the usual one: a lambda that closes over `self` (like the one above) cannot be
shared, a frozen object with a `#call` method or `Ractor.shareable_proc` (Ruby 4.0+) can.

```ruby
# config/initializers/glyphs.rb, after Glyphs.configure
Rails.application.config.after_initialize { Glyphs.finalize! }
```

The icons gem cannot render inside a non-main Ractor today (its configuration is unshareable module
state, and Nokogiri is Ractor-unsafe), so each Ractor's cache starts empty and a miss there raises.
Render on the main Ractor and hand the markup over with `Glyphs.preload_svg`; cache hits, attributes
included, then work in that Ractor:

```ruby
svg = Glyphs.svg_for(name: "house", library: :lucide, variant: nil, attributes: {}) # main Ractor
Glyphs.preload_svg(name: "house", library: :lucide, svg:)                           # in the Ractor
```

## Shrinking icons in Docker

`rails g rails_icons:sync` copies a library's **entire** icon set into
`app/assets/svg/icons/<library>/<variant>/` — often thousands of SVGs, of which
an app uses a handful. `glyphs:prune_icons` deletes the unreferenced ones so a
Docker image ships only what it renders, while the committed repo keeps the full
set for development.

It scans your source (`app/**/*.rb`, `lib/**/*.rb` with a real parser, plus
`.erb/.haml/.slim` text) for `LucideIcon(:house)`, legacy helpers, generic
`Icon(:x, library: :lucide)`, and `iconify lucide--house` class strings, then
keeps that set **plus** two safety nets: the `keep_icons` allowlist and every
configured `fallback_icons` (a pruned fallback would 500 on the next missing
icon).

### Dynamic calls are resolved automatically

Most apps render most icons dynamically — `LucideIcon(tile[:icon])`,
`PhosphorIcon(notification.icon)` — where the name lives in a `{ icon: :activity }`
hash, a `CHANNEL_ICONS` map, or an `ICON = :bell` constant, sometimes in a
different file from the render. A naïve static scan can't read those names and
would prune the icons they use.

The scanner resolves them from source, so you rarely need `keep_icons` at all:

- **File-scoped** — a file that renders a library dynamically (`LucideIcon(x)`)
  keeps every icon-name-shaped literal in that file for that library. Catches
  ternaries (`@open ? "caret-up" : "caret-down"`), `case/when`, and locals.
- **Declaration-based** — literals in icon-declaration positions *anywhere* — a
  hash pair keyed like an icon (`icon: :gear`, `menu_icon: "house"`) or a
  constant named like one (`ICON = :bell`, `STATUS_ICONS = { .. => :warning }`,
  including trailing `.freeze`) — are kept for every dynamically-rendered
  library, so a name declared in one file and rendered from another survives.

Only literals are harvested, so the scanner never invents a reference; the
worst case is keeping a coincidentally icon-named string, which the post-prune
verification tolerates.

### `keep_icons` — the last-resort escape hatch

For names a static scan genuinely can't see — read from a database, an ENV var,
or a gem's own chrome — list them explicitly:

```ruby
# config/initializers/glyphs.rb
Glyphs.configure do |config|
  # Flat list or per-library hash; names or fnmatch globs.
  config.keep_icons = %w[menu palette search circle-*]
  # config.keep_icons = { lucide: %w[menu palette], phosphor: %w[lock] }
end
```

```bash
# Preview (dry run — deletes nothing):
bin/rails glyphs:prune_icons

# Delete (both env vars required — a deliberate opt-in so it never fires
# accidentally on a developer's working tree):
PRUNE=1 GLYPHS_PRUNE_ICONS=1 bin/rails glyphs:prune_icons
```

Run it in the image build, **after** `assets:precompile` and before the final
stage copies the app — so the deletions land in the image but never in a
developer's checkout:

```dockerfile
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
RUN SECRET_KEY_BASE_DUMMY=1 PRUNE=1 GLYPHS_PRUNE_ICONS=1 ./bin/rails glyphs:prune_icons
```

After deleting, the task **verifies** every kept icon still resolves and exits
non-zero if not — a bad prune (e.g. a missing allowlist entry) fails the build
instead of shipping broken icons. The bundled `animated` library and any
`custom_path` library are left untouched, and it refuses to empty a library
whose keep-set is empty.

## RuboCop cops

Add the plugin (RuboCop >= 1.72):

```yaml
# .rubocop.yml
plugins:
  - glyphs
```

(Classic `require: [glyphs/rubocop]` also works, but you must enable the cops yourself.)

### Glyphs/LegacyIconHelper

Autocorrects legacy helper calls to Glyphs components:

```ruby
_lucide(:house, class: "size-4")   # => LucideIcon(:house, class: "size-4")
_heroicon(:check)                  # => HeroIcon(:check)
icon("check", library: "lucide")   # => LucideIcon("check")
icon("check")                      # => HeroIcon("check")  (DefaultLibraryComponent)
```

```yaml
Glyphs/LegacyIconHelper:
  Include:
    - app/**/*.rb
  DefaultLibraryComponent: HeroIcon
  # Mappings replaces the built-in defaults (_lucide/_phosphor/_hero/_heroicon/_tabler):
  # Mappings:
  #   _custom: CustomIcon
  # LibraryComponents merges over the built-in library => component map, so
  # `icon("x", library: "customlib")` corrects to `CustomIcon("x")`:
  # LibraryComponents:
  #   customlib: CustomIcon
```

### Glyphs/IconResolution

Validates statically-known icon names against your synced SVG directories, honors literal
`variant:` keywords, suggests close matches (with autocorrect for unambiguous typos and the
Lucide v1 renames), and flags raw `iconify` class strings:

```ruby
LucideIcon(:alert_triangle)                 # => corrected to LucideIcon(:triangle_alert)
span(class: "iconify lucide--house size-4") # => corrected to LucideIcon(:house, class: "size-4")
```

```yaml
Glyphs/IconResolution:
  Include:
    - app/**/*.rb
  IconsPath: app/assets/svg/icons
  # Libraries merges over the built-in defaults (component => Dir/DefaultVariant):
  Libraries:
    PhosphorIcon: { Dir: phosphor, DefaultVariant: regular }
  # Escalate a missing icon directory from a warning to an offence:
  Strict: false
```

If the directory a library resolves to does not exist — the library was never synced, or
`DefaultVariant` names a variant you do not have — the cop cannot validate any of that
library's call sites. Rather than pass silently, it warns once per library/variant:

```
[Glyphs/IconResolution] Icon directory `app/assets/svg/icons/phosphor/regular` not found,
so `PhosphorIcon` names are not validated. Sync the library or fix `IconsPath`/`Libraries`.
```

Set `Strict: true` to make that an offence instead, so CI fails closed rather than reporting
green while checking nothing. A directory that exists but ships no SVGs is not a
misconfiguration and stays silent either way.

### Glyphs/PreferLibraryComponent

```ruby
Icon(:house, library: :lucide) # => LucideIcon(:house)
```

```yaml
Glyphs/PreferLibraryComponent:
  Include:
    - app/**/*.rb
  # LibraryComponents merges over the built-in library => component map:
  # LibraryComponents:
  #   customlib: CustomIcon
```

## Migrating an app off icon helpers

1. Add `gem "glyphs"`, `include Glyphs` where the helpers used to be included.
2. Add the plugin and cop config above to `.rubocop.yml`.
3. Delete your local icon helper, then run:

```bash
bundle exec rubocop -A --only Glyphs/LegacyIconHelper,Glyphs/PreferLibraryComponent
```

4. Wire your old missing-icon logging into `Glyphs.configure` (see above).

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
