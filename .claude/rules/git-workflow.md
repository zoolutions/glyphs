# Git Workflow Rules

## Commit Messages

Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring
- `perf:` - Performance improvement
- `docs:` - Documentation only
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

Format:
```
feat(scope): brief description

Longer explanation if needed. Focus on WHY, not WHAT.

Refs #123
```

Scopes map to the architecture: `scanner`, `prune`, `config`, `rubocop`,
`icon`, `rake`, `docs`, `ci`, `chore`.

## Branch Naming

- `feat/description` - New features
- `fix/description` - Bug fixes
- `refactor/description` - Refactoring
- `ci/description` - CI changes
- `chore/description` - Maintenance

## PR Workflow

All work goes through PRs.

1. Create branch from `main`
2. Make focused, atomic commits
3. Run validators before pushing (`bundle exec rake`)
4. Create PR with summary + test plan
5. Request review
6. Squash merge when approved + CI green

## Release

Releases go through `bin/release` (or `bin/release X.Y.Z --force` to re-create
a botched release), the front door to `rake release[X.Y.Z]` in
`rakelib/release.rake`. It bumps `lib/glyphs/version.rb` and the glyphs pin in
the tracked lockfiles (in place, no re-resolve), verifies `gem build --strict`,
commits, pushes `main`, and creates the GitHub Release. `bin/release`,
`rakelib/release.rake` and the shared jobs of `release.yml` are the zoolutions
release kit (canonical copy in docs-kit): never edit them here. The Release workflow then publishes to RubyGems via trusted
publishing (OIDC + Sigstore attestation). Never `gem push` by hand, and never
bump the version inside a feature PR — `rake release` owns the version.

## Pre-Commit Checklist

Run before EVERY commit:
```bash
bundle exec rubocop lib spec                 # Style (the gem)
bundle exec rspec                             # Full suite
# (docs app — cd docs && bundle exec rubocop && bundle exec rspec — before a PR touching docs/)
```

## Rules

- **NEVER** commit directly to `main`
- **NEVER** force push to shared branches
- **NEVER** `gem push` manually — use `bin/release`
- **NEVER** bump the version in a feature PR — that's `rake release`'s job
- **ALWAYS** run validators before committing
- **ALWAYS** write meaningful commit messages
- Keep commits small and focused — one logical change per commit
