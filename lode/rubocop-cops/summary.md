# RuboCop cops

Three cops shipped with the gem, served through a lint_roller plugin. Files:
`lib/glyphs/rubocop.rb` (39 lines), `lib/rubocop/cop/glyphs/icon_resolution.rb`
(334), `legacy_icon_helper.rb` (97), `prefer_library_component.rb` (46),
`library_call_helpers.rb` (44), and `config/default.yml` (34).

## Plugin wiring

`glyphs.gemspec` sets `"default_lint_roller_plugin" => "Glyphs::RuboCop::Plugin"`,
so `plugins: [glyphs]` in a project `.rubocop.yml` is enough (RuboCop >= 1.72).
`Glyphs::RuboCop::Plugin#rules` (`rubocop.rb:30-36`) points at
`config/default.yml` by path; `#supported?` (26-28) accepts only
`context.engine == :rubocop`. The classic `require: [glyphs/rubocop]` route still
loads the cops but leaves them disabled until the project enables them, because
that path never reads `default.yml`.

`lib/glyphs/rubocop.rb` is outside Zeitwerk's managed set and is reached through
`Glyphs.autoload :RuboCop` at the bottom of `lib/glyphs.rb`, so RuboCop can
constantize the plugin long after the gem was first required.

**Every option a cop reads is declared in `config/default.yml`**, with an empty
default where the value merges. RuboCop derives its supported-parameter list from
the keys present in that file, so an undeclared option is reported as
`does not support <param> parameter` on every run — the bug fixed in the
Unreleased CHANGELOG section. `spec/rubocop/plugin_spec.rb` has an example
(`"declares every cop_config parameter its cops read"`) that guards this.

| Cop | Options | Autocorrect |
|---|---|---|
| `Glyphs/LegacyIconHelper` | `Mappings`, `LibraryComponents`, `DefaultLibraryComponent` | `SafeAutoCorrect: true` in `default.yml` |
| `Glyphs/IconResolution` | `IconsPath`, `Libraries`, `Strict` | only an unambiguous name match; no `SafeAutoCorrect` key, so RuboCop's default (safe) applies |
| `Glyphs/PreferLibraryComponent` | `LibraryComponents` | `SafeAutoCorrect: true` in `default.yml` |

`Mappings` **replaces** the built-in helper map when non-empty
(`legacy_icon_helper.rb:84-89`); `LibraryComponents` and `Libraries` **merge
over** their built-in maps (`library_call_helpers.rb:30-32`,
`icon_resolution.rb:105-107`). That asymmetry is deliberate and is what the
comments in `config/default.yml` document.

## `Glyphs/LegacyIconHelper`

`on_send` (36-44) fires on receiverless calls. Two branches:

- a method in `mappings` (default `_lucide`, `_phosphor`, `_hero`, `_heroicon`,
  `_tabler` — `DEFAULT_MAPPINGS`, 28-34) is renamed in place, arguments
  untouched;
- `icon` with at least one argument goes through `correct_icon_call` (55-66),
  which returns early when the first argument is a hash (a call with no name is
  not an icon render), renames to `DefaultLibraryComponent` (default `HeroIcon`)
  when there is no `library:`/`from:` pair, corrects and removes the pair when it
  is a literal, and otherwise adds an uncorrectable offence.

`remove_library_pair` (`library_call_helpers.rb:34-40`) removes the whole hash
when the pair was its only entry, and otherwise the pair plus its leading comma
and space — so `icon("x", library: :lucide, class: "y")` does not leave a
dangling comma.

## `Glyphs/IconResolution`

Three entry points: `on_send` (81-94) for icon calls, `on_str` (68-72) for a
literal `iconify …` class, `on_dstr` (74-79) for an interpolated one (flagged,
never corrected).

`check_call` (109-135) validates a *literal* first argument at a *literal*
variant and does nothing otherwise. `available_icons` returns three distinguishable
states, and each means something different:

| `available_icons_for` result | Meaning | Behaviour |
|---|---|---|
| `nil` | the directory does not exist | `report_missing_directory` (139-144): an offence when `Strict`, otherwise `warn_once` |
| `[]` | the directory exists with no SVGs | silent — a synced-but-empty library is not a misconfiguration |
| names | validated | offence + suggestion when the name is absent |

`warn_once` (311-317) dedupes on the message for the whole process, because
RuboCop builds a fresh cop instance per file; `reset_warnings!` (319-321) exists
for the specs, which call it in a `before`. The sibling memo
`@available_icons_cache` (297-303) has **no** reset and uses `key?` rather than
`||=` so a `nil` is not re-probed — a directory created mid-process stays
"missing" for the rest of it.

`icons_base_path` (285-287) expands `IconsPath` against `Dir.pwd`, not against
the `.rubocop.yml` that set it, so running RuboCop from a subdirectory changes
what the cop reads. The *message*, by contrast, is built from the unexpanded
configured path (`configured_directory`, 148-150) so it shows the project's own
spelling.

`DEFAULT_LIBRARIES` (29-35) covers **five** components — `LucideIcon`,
`PhosphorIcon`, `HeroIcon`, `TablerIcon`, `SidekickIcon` — out of the thirteen
the gem defines. `FeatherIcon(:nope)` is not a missing-directory warning and not
an offence: `component_for` (98-103) finds it in neither `libraries` nor
`LEGACY_HELPERS`, so `on_send` returns at line 85 and the call is simply
unvalidated until the project adds a `Libraries` row.
`LEGACY_HELPERS` (37-43) maps the same five helper names as the scanner does, and
`ICONIFY_PREFIX_TO_COMPONENT` (45-49) covers three libraries.

Suggestions come from `build_suggestion` (217-233): a `KNOWN_LUCIDE_RENAMES`
entry (51-55, three pairs: `alert-triangle`, `alert-circle`, `x-circle`) wins
first and autocorrects, then `fuzzy_match` (235-249) — a hand-rolled score over
dash-separated parts plus a Damerau-Levenshtein distance (259-283) — autocorrects
only when exactly one candidate scores >= 3, lists up to five without correcting
when several do, and says `No similar icons found.` otherwise. The replacement
keeps the argument's own form: a symbol stays a symbol with underscores, a string
stays a double-quoted string (127-133).

`check_iconify_string` (173-194) only corrects when the string is the sole
`class:` value of a single-argument `span(...)` call (`enclosing_span_call`,
196-211); anywhere else the offence is reported with no corrector.

`on_send` wraps its body in `rescue StandardError` (91-94) and warns
`[Glyphs/IconResolution] suppressed …` — the cop fails open on an unexpected
node shape rather than aborting a lint run.

## `Glyphs/PreferLibraryComponent`

The smallest cop (`on_send`, 23-42): a receiverless `Icon(...)` with arguments
and a `library:`/`from:` pair. A literal pair with a known component is renamed
and the pair removed; a dynamic pair gets `MSG_DYNAMIC` with no corrector; an
unknown library is ignored entirely (line 35), since there is nothing to suggest.
