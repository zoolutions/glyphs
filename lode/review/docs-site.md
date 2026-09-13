# Review rules: the docs site

Accepted findings about `docs/`, rewritten as rules about the system and checked
against the code. `/lode:gate` reads this before reviewing a diff.

### Not a bug: `docs/app/assets/stylesheets/tailwind.sources.css` is generated *and* committed

- **Holds because:** nothing consumes the committed copy. `bin/build-css`
  regenerates it from `bundle show daisyui` / `bundle show docs-kit` before every
  compile and aborts if either gem cannot be resolved, so a stale snapshot can
  never reach a build; `docs/.dockerignore` lists the file, so the image never
  receives it either. The machine-specific absolute paths it carries are
  therefore noise in the diff, not a deployment hazard. Committing it is the
  docs-kit fleet convention — every site does it — so gitignoring it here would
  be a one-site divergence; the change belongs in the docs-kit generator plus a
  `--sync` migration, tracked at zoolutions/docs-kit#71.
- **Where:** `docs/bin/build-css`, `docs/.dockerignore:32`,
  `docs/package.json` (`build:css`, `watch:css`),
  `docs/lib/tasks/build_css.rake` (enhances `assets:precompile` with `css:build`)
- **Safe direction:** if the resolution ever fails, `bin/build-css` exits
  non-zero rather than emitting a file with no `@source` globs — an unstyled
  site is the failure it refuses to ship.
- **Proven by:** no test; `set -euo pipefail` plus the explicit `exit 1` in
  `bin/build-css` is the only guard, and `docs-test`/`docs-lint` never run it.
- **Origin:** cubic learning 36654a4c; PR #11 review thread (declined, with the
  reasoning above)
