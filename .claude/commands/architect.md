---
model: opus
description: "Coordinates a change across the glyphs subsystems. Use when planning a feature that spans the icon components, the pruning pipeline, and the RuboCop cops."
argument-hint: "feature or task to coordinate"
---

# glyphs Architect Mode

You are in **Architect Mode** — coordinating a change across the glyphs subsystems.

## Why this exists

A glyphs feature usually touches several subsystems in a specific order. Tackle
them out of order and you miss integration points (e.g. teach the scanner a new
call shape before the icon component actually emits it) or break the
resolution contract that every library subclass and the pruner both depend on.

## The subsystems

```
Docs         docs/app/views/docs/pages/ (DocsUI::Page subclasses, write-docs-page skill)
Cops         lib/rubocop/cop/glyphs/*.rb (IconResolution, LegacyIconHelper,
             PreferLibraryComponent, LibraryCallHelpers); plugin lib/glyphs/rubocop.rb
Rake/Railtie lib/tasks/glyphs.rake + lib/glyphs/railtie.rb (glyphs:prune_icons)
Pruning      source_scanner.rb (Prism AST + template scan, dynamic-call harvest),
             icon_pruner.rb (deletes SVGs), prune_runner.rb (wiring + verify!),
             prune_report.rb
Components   lib/glyphs/icon.rb (Icon < Phlex::HTML) + one subclass per library
             (lucide_icon.rb, phosphor_icon.rb, hero_icon.rb, … 13 total)
Core/config  lib/glyphs.rb (Glyphs::Kit, svg_for resolution, config accessor),
             lib/glyphs/configuration.rb (raise_on_missing, fallback_icons,
             cache_svgs, keep_icons, prune_source_globs)
```

## Typical implementation flow (bottom-up)

1. **Core/config** — add a config option or extend `svg_for` resolution if needed
2. **Components** — the `Icon` base + per-library subclass that renders it
3. **Pruning** — teach the scanner to recognize the new call/reference shape
4. **Rake/Railtie** — expose it through the `glyphs:prune_icons` task if relevant
5. **Cops** — enforce/steer the new convention (offense + autocorrect)
6. **Docs + specs** — a docs page and specs at every touched subsystem

## Delegate vs. do directly

**Delegate** (Explore agents with `model: haiku`, or `model: sonnet` to read a subsystem; Plan agents with `model: sonnet`) when: multiple files change, you need to
verify the real signature of a transitive `icons` gem call, or the work is
cleanly scoped to one subsystem.

**Directly** when: a single-file change, or a cross-cutting concern (the
`svg_for` resolution contract, the scanner's reference model) that you must
hold in your head.

## Decision guide

| Decision | Use When |
|----------|----------|
| New config option | Feature needs host-app-configurable behavior |
| New `svg_for`/resolution behavior | The path or fallback resolution changes |
| New library subclass | Adding support for another rails_icons library |
| Scanner change | A new call/template shape references icons |
| New/changed cop | A new convention must be enforced or autocorrected |
| Docs page | User-facing behavior changed |

## Integration points

| When working on... | Also consider... |
|--------------------|------------------|
| `svg_for` resolution | every library subclass; the pruner reads the same paths |
| A new icon call shape | the scanner that must harvest it; `keep_icons` overlap |
| The scanner | what components/templates actually emit; dynamic-call harvesting |
| The pruner | `prune_report`; `verify!` in `prune_runner`; `fallback_icons` safety |
| A cop | `LibraryCallHelpers` for shared call parsing; `expect_offense` specs |
| Config | the docs site + README; backwards compatibility |

## Common mistakes

| Wrong | Right |
|-------|-------|
| Start with the cop | Start with the resolution/component contract |
| Prune without a scanner update | Scanner must first recognize the reference |
| Hard-code one library's path | Resolve via `svg_for` for all 13 libraries |
| Skip dynamic-call harvesting | Dynamic `send`/interpolated names must survive pruning |
| Skip the spec fixtures | Specs drive off `spec/fixtures` (`Icons.config.base_path`) |
| Monolith methods | Small files, focused classes |

## Verification checklist

- [ ] Implementation order planned (bottom-up)
- [ ] Resolution contract preserved across all library subclasses
- [ ] Pruner-safe: referenced icons survive; `fallback_icons`/`keep_icons` honored
- [ ] Spec fixtures cover the new shape (`spec/fixtures`)
- [ ] Tests cover every touched subsystem (gem specs + cop specs)
- [ ] `bundle exec rubocop lib spec` + `bundle exec rspec` pass
- [ ] Never bump the version in a feature PR — `rake release` owns it

## Handoff

If this session implemented a change (a plan-only run has an empty diff, and the validator BLOCKs an empty change): run the `fable-validator` agent on the combined diff first. On BLOCK do not open or merge: mark it `needs-user` (or the command's equivalent) and report the blockers instead of calling it ready.

Summarize: the subsystem-ordered plan, files per subsystem, integration points,
the pruner-safety story, and the architectural decisions made.

Now coordinate the change with this architectural perspective.
