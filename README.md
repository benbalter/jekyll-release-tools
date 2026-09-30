# jekyll-release-tools

Release tooling for the Jekyll plugin gems I maintain. They publish to RubyGems from GitHub Actions using [trusted publishing](https://guides.rubygems.org/trusted-publishing/). Each gem has a `.github/workflows/release.yml` workflow, in the `rubygems` environment, that runs when a `vX.Y.Z` tag is pushed.

[`bin/release-jekyll-gems`](bin/release-jekyll-gems) handles the tagging. It checks which gems need a release and confirms that CI is green and the changelog is updated. Then it pushes a signed tag, and that tag triggers the publish. The script never builds or pushes a gem itself.

The gems it manages are listed in [`gems.txt`](gems.txt):

- [jekyll-remote-theme](https://github.com/benbalter/jekyll-remote-theme)
- [jekyll-include-cache](https://github.com/benbalter/jekyll-include-cache)
- [jekyll-relative-links](https://github.com/benbalter/jekyll-relative-links)
- [jekyll-titles-from-headings](https://github.com/benbalter/jekyll-titles-from-headings)
- [jekyll-optional-front-matter](https://github.com/benbalter/jekyll-optional-front-matter)
- [jekyll-readme-index](https://github.com/benbalter/jekyll-readme-index)
- [jekyll-default-layout](https://github.com/benbalter/jekyll-default-layout)

## Prerequisites

- bash (3.2 or newer, so the macOS system bash works), [git](https://git-scm.com), [curl](https://curl.se), and [jq](https://jqlang.org)
- [GitHub CLI](https://cli.github.com), authenticated (`gh auth status`) as someone allowed to push tags. An admin-only ruleset protects `v*` tags on these repos.
- git set up to sign tags (`git tag -s`), e.g. [SSH signing through 1Password](https://developer.1password.com/docs/ssh/git-commit-signing/). Use `--no-sign` to create unsigned annotated tags.
- git able to push to `https://github.com/<repo>.git`, e.g. through a credential helper

## Release flow

1. **Open a PR** in the gem's repo that bumps `lib/<gem>/version.rb` and adds a `## X.Y.Z` section to `CHANGELOG.md` (or `HISTORY.md`).
2. **Merge it** once CI passes.
3. **Run the script**:

   ```sh
   bin/release-jekyll-gems --dry-run   # see the plan
   bin/release-jekyll-gems --watch     # tag, then follow the release runs
   ```

4. **The gem's `release.yml` publishes** the version to RubyGems through trusted publishing when it sees the tag.

## Usage

```text
bin/release-jekyll-gems [options] [repo=version ...]

  -n, --dry-run     Print the plan and run read-only checks; write nothing
  -y, --yes         Don't ask for confirmation before each tag; required
                    when run without a TTY (e.g. from an editor or a `!` prompt)
  -w, --watch       Wait for release workflow runs to finish (gh run watch)
  -o, --only REPO   Only process REPO (name or owner/name); repeatable
      --no-sign     Create annotated tags (git tag -a) instead of signed ones
  -h, --help        Show help

  repo=version      Guard: fail that gem unless version.rb matches
```

Examples:

```sh
# Release just remote-theme, and make sure it's the version I think it is
bin/release-jekyll-gems --only jekyll-remote-theme jekyll-remote-theme=0.6.3

# Tag everything that's ready without prompting, and wait for the publishes
bin/release-jekyll-gems --yes --watch
```

Without `--yes`, the script asks before each tag, reading the answer from `/dev/tty`. When there's no terminal to read from (for example, when it runs from an editor, a `!` shell prompt, or CI), pass `--yes`; otherwise each gem that's ready to tag fails with "no terminal to confirm".

### What it does per gem

The script reads the gem's version from `lib/**/version.rb` on the default branch's HEAD commit. Then it checks three things: whether that version is on [RubyGems](https://rubygems.org/api/v1/versions/jekyll-remote-theme.json), whether the `vX.Y.Z` tag exists, and whether a GitHub release exists. It does only what's missing, so it's safe to run again at any time.

| RubyGems | Tag | Action |
| --- | --- | --- |
| published | yes | Nothing to do. Warns if there's no GitHub release. |
| not published | no | Runs preflight checks, then creates a signed tag on the HEAD commit and pushes only that ref. |
| not published | yes | Reports the `release.yml` run for that tag. With `--watch`, waits for it to finish. |
| published | no | Warns and skips. It won't guess which commit an old release came from. |

The preflight checks run before any tag is created:

- Every check run on the commit completed as `success`, `skipped`, or `neutral`. A commit with no check runs fails.
- `CHANGELOG.md` or `HISTORY.md` has a `## X.Y.Z` heading. `## vX.Y.Z` and `## [X.Y.Z]` also count.
- The version isn't on RubyGems yet, and the tag doesn't exist.

The tag goes on the exact commit that passed preflight, even if the branch moves during the run. The script fetches only that commit into a temporary directory, which it deletes on exit. If a gem fails, the script records the reason and moves on to the next gem. At the end it prints a summary table (gem, version, action, result) and exits non-zero if any gem failed.

## One-time setup: RubyGems trusted publishers

Each gem needs a trusted publisher on RubyGems before its `release.yml` can publish. For each row, open the link and add a **GitHub Actions** publisher with these values:

| Gem | Owner | Repository | Workflow | Environment | Link |
| --- | --- | --- | --- | --- | --- |
| jekyll-remote-theme | `benbalter` | `jekyll-remote-theme` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-remote-theme/trusted_publishers) |
| jekyll-include-cache | `benbalter` | `jekyll-include-cache` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-include-cache/trusted_publishers) |
| jekyll-relative-links | `benbalter` | `jekyll-relative-links` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-relative-links/trusted_publishers) |
| jekyll-titles-from-headings | `benbalter` | `jekyll-titles-from-headings` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-titles-from-headings/trusted_publishers) |
| jekyll-optional-front-matter | `benbalter` | `jekyll-optional-front-matter` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-optional-front-matter/trusted_publishers) |
| jekyll-readme-index | `benbalter` | `jekyll-readme-index` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-readme-index/trusted_publishers) |
| jekyll-default-layout | `benbalter` | `jekyll-default-layout` | `release.yml` | `rubygems` | [trusted publishers](https://rubygems.org/gems/jekyll-default-layout/trusted_publishers) |

## Development

The tests use [bats-core](https://github.com/bats-core/bats-core), with [bats-support](https://github.com/bats-core/bats-support) and [bats-assert](https://github.com/bats-core/bats-assert) vendored as git submodules. The fake `gh`, `git`, and `curl` in [`test/stubs`](test/stubs) serve fixtures, so the tests never touch the network.

```sh
git submodule update --init
test/libs/bats-core/bin/bats test/
shellcheck bin/release-jekyll-gems test/stubs/*
```

To run the tests against a specific bash, such as the macOS system bash 3.2, set `BASH_UNDER_TEST=/bin/bash`. CI does this on macOS.

## License

[MIT](LICENSE)
