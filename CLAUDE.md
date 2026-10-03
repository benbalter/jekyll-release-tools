# CLAUDE.md

[`bin/release-jekyll-gems`](bin/release-jekyll-gems) tags releases for the Jekyll plugin gems listed in [`gems.txt`](gems.txt). This repo isn't a gem itself; the tags it pushes publish gems from the other repos.

## Commands

Run what [CI](.github/workflows/ci.yml) runs before committing:

```sh
git submodule update --init
test/libs/bats-core/bin/bats test/
shellcheck bin/release-jekyll-gems test/stubs/*
shellcheck -s bash test/test_helper.bash test/*.bats
```

The tests use stubbed `gh`, `git` and `curl` from [`test/stubs`](test/stubs), so they never touch the network or push anything.

## Releasing

Each `vX.Y.Z` tag the script pushes triggers that gem's `release.yml`, which publishes to RubyGems through trusted publishing. One run without `--only` tags every gem that's ready. The admin-only `v*` tag ruleset doesn't stop an agent, because the script runs with the owner's `gh` credentials.

Releases happen only after the owner explicitly approves them. Agents may run `bin/release-jekyll-gems --dry-run` (it writes nothing) and may open version-bump and changelog PRs in the gem repos, but must never run the script without `--dry-run`, push a `v*` tag, or create a GitHub Release. Never pass `--yes`: the per-tag prompt is the owner's approval step, and `--yes` skips it. The README tells non-TTY callers to pass `--yes`; that advice is for the owner running it from an editor, not for agents.
