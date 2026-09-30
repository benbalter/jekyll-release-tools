#!/usr/bin/env bats

load test_helper

@test "--help prints usage and exits 0" {
  run_script --help
  assert_success
  assert_output --partial "Usage: release-jekyll-gems"
  assert_output --partial "--dry-run"
}

@test "unknown option exits 2" {
  run_script --bogus
  assert_failure 2
  assert_output --partial "unknown option: --bogus"
}

@test "published, tagged, and released gem is skipped as up to date" {
  add_gem jekyll-foo 1.2.3
  publish jekyll-foo 1.2.2 1.2.3
  tag jekyll-foo v1.2.3
  release jekyll-foo
  run_script --yes
  assert_success
  assert_output --regexp "jekyll-foo +1\.2\.3 +skip +ok +up to date"
  refute_called "^git "
}

@test "published and tagged without a GitHub release warns but succeeds" {
  add_gem jekyll-foo 1.2.3
  publish jekyll-foo 1.2.3
  tag jekyll-foo v1.2.3
  run_script --yes
  assert_success
  assert_output --regexp "jekyll-foo +1\.2\.3 +skip +warn +published and tagged, but no GitHub release"
}

@test "dry run plans a tag for an unpublished, untagged gem without writing" {
  add_gem jekyll-foo 1.2.3
  publish jekyll-foo 1.2.2
  run_script --dry-run
  assert_success
  assert_output --partial "would create signed tag v1.2.3 at $(sha_of jekyll-foo)"
  assert_output --regexp "jekyll-foo +1\.2\.3 +tag +dry-run"
  refute_called "^git "
}

@test "tags the default branch HEAD with a signed tag and pushes only that ref" {
  add_gem jekyll-foo 1.2.3
  sha="$(sha_of jekyll-foo)"
  run_script --yes
  assert_success
  assert_called "^git -C .* fetch -q --depth 1 origin $sha\$"
  assert_called "^git -C .* tag -s v1\.2\.3 -m jekyll-foo 1\.2\.3 $sha\$"
  assert_called "^git -C .* push -q --no-follow-tags origin refs/tags/v1\.2\.3:refs/tags/v1\.2\.3\$"
  assert_output --regexp "jekyll-foo +1\.2\.3 +tag +ok +pushed v1\.2\.3"
}

@test "--no-sign creates an annotated tag" {
  add_gem jekyll-foo 1.2.3
  run_script --yes --no-sign
  assert_success
  assert_called "^git -C .* -c tag\.gpgSign=false tag -a v1\.2\.3 "
  refute_called "^git -C .* tag -s "
}

@test "confirmation is read from the tty; answering no skips the gem" {
  add_gem jekyll-foo 1.2.3
  echo n >"$RELEASE_TTY"
  run_script
  assert_success
  assert_output --regexp "jekyll-foo +1\.2\.3 +tag +skipped"
  refute_called "^git "

  echo y >"$RELEASE_TTY"
  run_script
  assert_success
  assert_called "tag -s v1\.2\.3"
}

@test "no readable tty without --yes fails the gem" {
  add_gem jekyll-foo 1.2.3
  RELEASE_TTY="$BATS_TEST_TMPDIR/missing/tty" run_script
  assert_failure 1
  assert_output --partial "use --yes"
  refute_called "^git "
}

@test "refuses to tag when a check run failed" {
  add_gem jekyll-foo 1.2.3
  set_checks jekyll-foo success failure skipped
  run_script --yes
  assert_failure 1
  assert_output --partial "checks not green"
  assert_output --partial "check 2 (failure)"
  refute_called "^git "
}

@test "refuses to tag while check runs are still in progress" {
  add_gem jekyll-foo 1.2.3
  set_checks jekyll-foo success in_progress
  run_script --yes
  assert_failure 1
  assert_output --partial "checks still running"
  refute_called "^git "
}

@test "refuses to tag a commit with no check runs" {
  add_gem jekyll-foo 1.2.3
  set_checks jekyll-foo
  run_script --yes
  assert_failure 1
  assert_output --partial "no check runs found"
}

@test "skipped and neutral check runs count as green" {
  add_gem jekyll-foo 1.2.3
  set_checks jekyll-foo success skipped neutral
  run_script --yes
  assert_success
  assert_called "tag -s v1\.2\.3"
}

@test "refuses to tag without a changelog entry for the version" {
  add_gem jekyll-foo 1.2.3
  printf '# Changelog\n\n## 1.2.2\n' >"$REMOTE_DIR/jekyll-foo/files/CHANGELOG.md"
  run_script --yes
  assert_failure 1
  assert_output --partial 'CHANGELOG.md has no "## 1.2.3" heading'
  refute_called "^git "
}

@test "finds the version heading in HISTORY.md, and doesn't match a prefix" {
  add_gem jekyll-foo 1.2.3
  rm "$REMOTE_DIR/jekyll-foo/files/CHANGELOG.md"
  printf '## 1.2.30\n' >"$REMOTE_DIR/jekyll-foo/files/HISTORY.md"
  run_script --yes
  assert_failure 1
  assert_output --partial 'HISTORY.md has no "## 1.2.3" heading'

  printf '## v1.2.3 (2026-09-30)\n' >"$REMOTE_DIR/jekyll-foo/files/HISTORY.md"
  run_script --yes
  assert_success
}

@test "published but untagged warns and skips without tagging" {
  add_gem jekyll-foo 1.2.3
  publish jekyll-foo 1.2.3
  run_script --yes
  assert_success
  assert_output --partial "not tagging after the fact"
  assert_output --regexp "jekyll-foo +1\.2\.3 +skip +warn"
  refute_called "^git "
}

@test "tagged but unpublished reports the release run status" {
  add_gem jekyll-foo 1.2.3
  tag jekyll-foo v1.2.3
  set_runs jekyll-foo '[{"databaseId":42,"status":"in_progress","conclusion":"","url":"https://example.test/run/42"}]'
  run_script --yes
  assert_success
  assert_output --regexp "jekyll-foo +1\.2\.3 +check +pending +release run in_progress: https://example\.test/run/42"
  refute_called "^git "
  refute_called "^gh run watch"
}

@test "tagged but unpublished with --watch waits for the run" {
  add_gem jekyll-foo 1.2.3
  tag jekyll-foo v1.2.3
  set_runs jekyll-foo '[{"databaseId":42,"status":"queued","conclusion":"","url":"https://example.test/run/42"}]'
  run_script --yes --watch
  assert_success
  assert_called "^gh run watch 42 --repo benbalter/jekyll-foo --exit-status"
  assert_output --regexp "jekyll-foo +1\.2\.3 +check +ok +release run succeeded"

  echo 1 >"$REMOTE_DIR/jekyll-foo/watch-exit"
  run_script --yes --watch
  assert_failure 1
  assert_output --regexp "jekyll-foo +1\.2\.3 +check +FAIL +release run failure"
}

@test "tagged but unpublished with a failed run fails" {
  add_gem jekyll-foo 1.2.3
  tag jekyll-foo v1.2.3
  set_runs jekyll-foo '[{"databaseId":7,"status":"completed","conclusion":"failure","url":"https://example.test/run/7"}]'
  run_script --yes
  assert_failure 1
  assert_output --partial "release run failure"
}

@test "tagged but unpublished without a release workflow fails clearly" {
  add_gem jekyll-foo 1.2.3
  tag jekyll-foo v1.2.3
  : >"$REMOTE_DIR/jekyll-foo/no-workflow"
  run_script --yes
  assert_failure 1
  assert_output --partial "does .github/workflows/release.yml exist?"
}

@test "--watch after tagging follows the new release run" {
  add_gem jekyll-foo 1.2.3
  set_runs jekyll-foo '[{"databaseId":9,"status":"in_progress","conclusion":"","url":"https://example.test/run/9"}]'
  run_script --yes --watch
  assert_success
  assert_called "tag -s v1\.2\.3"
  assert_called "^gh run watch 9 "
  assert_output --regexp "jekyll-foo +1\.2\.3 +tag +ok +release run succeeded"
}

@test "one failing gem doesn't stop the others; summary lists all; exit is non-zero" {
  add_gem jekyll-bad 1.0.0
  set_checks jekyll-bad failure
  add_gem jekyll-good 2.0.0
  add_gem jekyll-done 3.0.0
  publish jekyll-done 3.0.0
  tag jekyll-done v3.0.0
  release jekyll-done
  run_script --yes
  assert_failure 1
  assert_output --regexp "jekyll-bad +1\.0\.0 +tag +FAIL +checks not green"
  assert_output --regexp "jekyll-good +2\.0\.0 +tag +ok +pushed v2\.0\.0"
  assert_output --regexp "jekyll-done +3\.0\.0 +skip +ok +up to date"
  assert_output --partial "1 gem(s) failed."
  assert_called "push .*refs/tags/v2\.0\.0"
  refute_called "refs/tags/v1\.0\.0"
}

@test "a failed push fails that gem" {
  add_gem jekyll-foo 1.2.3
  GIT_STUB_FAIL=push run_script --yes
  assert_failure 1
  assert_output --partial "creating or pushing v1.2.3 failed"
}

@test "--only limits the run to the named gems" {
  add_gem jekyll-foo 1.0.0
  add_gem jekyll-bar 2.0.0
  run_script --yes --only jekyll-bar
  assert_success
  assert_output --regexp "jekyll-bar +2\.0\.0"
  refute_output --partial "jekyll-foo"
  refute_called "benbalter/jekyll-foo"

  run_script --yes --only benbalter/jekyll-foo
  assert_success
  assert_output --regexp "jekyll-foo +1\.0\.0"
}

@test "--only with a gem not in the list is an error" {
  add_gem jekyll-foo 1.0.0
  run_script --only jekyll-nope
  assert_failure 2
  assert_output --partial "jekyll-nope is not in"
}

@test "version guard mismatch fails that gem without tagging" {
  add_gem jekyll-foo 1.2.3
  add_gem jekyll-bar 2.0.0
  run_script --yes jekyll-foo=1.2.4 jekyll-bar=2.0.0
  assert_failure 1
  assert_output --regexp "jekyll-foo +1\.2\.3 +- +FAIL +version guard: expected 1\.2\.4"
  assert_output --regexp "jekyll-bar +2\.0\.0 +tag +ok"
  refute_called "refs/tags/v1\.2\.3"
}

@test "a RubyGems lookup failure fails the gem, not the run" {
  add_gem jekyll-foo 1.2.3
  : >"$RUBYGEMS_DIR/fail"
  run_script --yes
  assert_failure 1
  assert_output --partial "RubyGems lookup failed"
  assert_output --regexp "jekyll-foo +1\.2\.3 +- +FAIL"
}

@test "gems.txt ignores comments and blank lines" {
  printf '\n  # a comment\n\n' >>"$GEMS_FILE"
  add_gem jekyll-foo 1.2.3
  printf 'benbalter/jekyll-foo # trailing comment\n' >"$GEMS_FILE.tmp"
  cat "$GEMS_FILE.tmp" >>"$GEMS_FILE"
  run_script --dry-run
  assert_success
  # listed twice: once from add_gem, once with a trailing comment
  [ "$(grep -cE '^jekyll-foo +1\.2\.3 +tag +dry-run' <<<"$output")" -eq 2 ]
}
