# Performance Rules

glyphs must be fast in the two places that matter: the icon **render path**
(runs on every `svg_for` call in a request) and the prune **scan path** (a
Prism AST walk over an entire host codebase). These rules make performance a
standing part of every change, not an afterthought.

## The prime directive

**Measure before you change. Measure after. Report both, honestly.**

A performance claim without a same-machine before/after is not allowed in a PR
or a commit message. If you didn't baseline, you don't have a delta — say
"measured after only" or go capture the baseline.

## When performance is in scope

Any change to a **hot path** must come with a measurement and a before/after:

| Hot path | File |
|----------|------|
| Per-render SVG resolution + cache | `lib/glyphs.rb` (`svg_for`, `render_svg`, `build_svg`), `lib/glyphs/svg_cache.rb`, `lib/glyphs/svg_template.rb` |
| Icon component render | `lib/glyphs/icon.rb` (`view_template`, attribute merge) |
| Source scan (build-time, whole repo) | `lib/glyphs/source_scanner.rb` (`scan`, `scan_ruby`, `scan_template`, `glob`) |
| Prune wiring | `lib/glyphs/prune_runner.rb` (`references`, `pruner`) |

A pure docs/test/refactor change with no hot-path edit does not need a bench.

## Always Do

1. **Baseline first** — capture `main` (or pre-change) numbers BEFORE editing.
   Use `benchmark-ips` for the render path and `Benchmark.realtime` (or
   `benchmark-ips` on a fixed fixture tree) for the scanner over a
   representative `spec/fixtures`-sized repo.
2. **Report throughput AND allocations** — i/s + obj/call (use `memory_profiler`
   or `benchmark-ips`'s allocation stats). Flag any per-render allocation growth
   on `svg_for`; the cached path should allocate close to nothing on a hit.
3. **Distinguish per-render from per-request wins** — a 2× faster `svg_for` does
   NOT mean 2× faster requests (the Rails stack + view render dominate); it means
   ~2× on pages that render many icons and less GC pressure. Say which the number
   is. For the scanner, frame it per-repo-scan, not per-request — it runs once at
   prune time.
4. **Update the CHANGELOG** — if representative numbers moved, note the change
   under a `perf:` CHANGELOG entry.

## Never Do

1. **Never claim a speedup without a measured before/after.** No "this should be
   faster." Prove it or don't say it.
2. **Never optimize a cold path** the measurement shows isn't hot — three clear
   lines beat a clever micro-optimization that obscures behavior for no measured
   gain. Icon registration (`register_library`) runs once at boot; don't tune it.
3. **Never break a correctness invariant for speed** — the missing-icon policy
   (raise / instrument / fallback), the thread-safe cache (the mutex-guarded
   per-Ractor `SvgCache`), and the scanner's dynamic-call harvesting (a name it fails to
   see gets a live SVG pruned) are not negotiable. A faster wrong answer is wrong.
4. **Never make the cache thread-unsafe for a marginal win.** `svg_for` is called
   concurrently under a threaded server; the `SvgCache` lock
   stays. Hoisting a key computation or freezing a constant: yes. Dropping the
   lock or swapping to an unsynchronized structure: only if the bench proves it
   matters AND thread-safety is preserved and tested.
5. **Never make the scanner skip files to go faster.** Under-scanning silently
   prunes referenced icons. A parse failure already warns-and-skips a single file
   (by design); do not widen that to whole globs for speed.

## Caching for speed — the correctness guards

The render path memoizes rendered SVGs as `SvgTemplate`s in a bounded, per-Ractor
LRU (`Glyphs.svg_cache`, `svg_cache_size` entries), keyed by
`[library, variant, name, data:-given?]` (see `svg_for` in `lib/glyphs.rb`); each
call's attributes are applied to the cached markup:

- **Key the cache on everything that changes the cached bytes, never on per-call
  input.** Attributes stay out of the key (a dynamic `id:` per render made the old
  attribute-keyed cache grow without bound); they are merged on every call, and
  `spec/glyphs/svg_template_spec.rb` holds that merge byte-identical to the icons
  gem's own render. A bare `@x ||=` that ignores a changeable input serves stale markup.
- **Honor the toggle.** `svg_for` bypasses the cache entirely when
  `configuration.cache_svgs` is false — keep that early return; don't populate the
  cache on the uncached path.
- **Reset when the source can change.** `reset_cache!` exists for exactly this;
  anything that changes what an icon resolves to (reconfiguring the `icons` base
  path, swapping libraries in tests) must clear it, or the process serves stale
  SVGs. Don't add a second cache that lacks a reset.

## Checklist (before marking perf work complete)

- [ ] Baseline captured BEFORE the change (same machine, same script)
- [ ] After numbers captured; before/after in the PR body
- [ ] Throughput + allocations reported; cached-render allocations near zero
- [ ] Per-render vs per-request (or per-repo-scan) framing is honest
- [ ] CHANGELOG updated if numbers moved
- [ ] Cache stays mutex-guarded and `reset_cache!`-clearable; `cache_svgs` toggle honored
- [ ] `bundle exec rspec` still green
- [ ] No correctness invariant (missing-icon policy, scan completeness) traded for speed
