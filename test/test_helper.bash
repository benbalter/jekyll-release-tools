# Shared setup for the BATS suite. Every test runs offline against the
# PATH-shimmed fakes in test/stubs, driven by fixtures under $BATS_TEST_TMPDIR.

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load "$TEST_ROOT/libs/bats-support/load"
load "$TEST_ROOT/libs/bats-assert/load"

SCRIPT="$TEST_ROOT/../bin/release-jekyll-gems"

setup() {
  export REMOTE_DIR="$BATS_TEST_TMPDIR/remote"
  export RUBYGEMS_DIR="$BATS_TEST_TMPDIR/rubygems"
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  export GEMS_FILE="$BATS_TEST_TMPDIR/gems.txt"
  export RELEASE_TTY="$BATS_TEST_TMPDIR/tty"
  export RELEASE_POLL_ATTEMPTS=2 RELEASE_POLL_INTERVAL=0
  export PATH="$TEST_ROOT/stubs:$PATH"
  mkdir -p "$REMOTE_DIR" "$RUBYGEMS_DIR"
  : >"$CALLS_LOG"
  printf '# test gems\n' >"$GEMS_FILE"
}

# Runs the script under $BASH_UNDER_TEST (CI sets /bin/bash on macOS to
# exercise bash 3.2).
run_script() {
  run "${BASH_UNDER_TEST:-bash}" "$SCRIPT" "$@"
}

# add_gem NAME VERSION: a repo on main whose HEAD has green checks, the
# version in lib/NAME/version.rb, and a matching CHANGELOG.md entry. Not
# published and not tagged until you say so.
add_gem() {
  local name="$1" version="$2" d="$REMOTE_DIR/$1"
  printf 'benbalter/%s\n' "$name" >>"$GEMS_FILE"
  mkdir -p "$d/files/lib/$name" "$d/tags"
  echo main >"$d/branch"
  echo "0123456789abcdef0123456789abcdef0123$(printf '%04d' $((RANDOM % 10000)))" >"$d/sha"
  cat >"$d/tree.json" <<JSON
{"tree":[
  {"path":"lib","type":"tree"},
  {"path":"lib/$name.rb","type":"blob"},
  {"path":"lib/$name/version.rb","type":"blob"},
  {"path":"spec/fixtures/lib/mock/version.rb","type":"blob"}
]}
JSON
  printf 'module Jekyll\n  module Thing\n    VERSION = "%s"\n  end\nend\n' "$version" \
    >"$d/files/lib/$name/version.rb"
  printf '# Changelog\n\n## %s\n\n- Stuff\n\n## 0.0.1\n\n- Init\n' "$version" >"$d/files/CHANGELOG.md"
  set_checks "$name" success success
}

sha_of() { cat "$REMOTE_DIR/$1/sha"; }

# set_checks NAME CONCLUSION...: completed check runs with these conclusions.
# Use "in_progress" for a run that hasn't finished.
set_checks() {
  local name="$1" c runs="" i=0
  shift
  for c in "$@"; do
    i=$((i + 1))
    if [ "$c" = "in_progress" ]; then
      runs="$runs${runs:+,}{\"name\":\"check $i\",\"status\":\"in_progress\",\"conclusion\":null}"
    else
      runs="$runs${runs:+,}{\"name\":\"check $i\",\"status\":\"completed\",\"conclusion\":\"$c\"}"
    fi
  done
  printf '{"total_count":%d,"check_runs":[%s]}' "$i" "$runs" >"$REMOTE_DIR/$name/checks.json"
}

publish() {  # NAME VERSION...
  local name="$1" v list=""
  shift
  for v in "$@"; do list="$list${list:+,}{\"number\":\"$v\"}"; done
  printf '[%s]' "$list" >"$RUBYGEMS_DIR/$name.json"
}

tag() { : >"$REMOTE_DIR/$1/tags/$2"; }            # NAME TAG
release() { : >"$REMOTE_DIR/$1/release"; }        # NAME
set_runs() { printf '%s' "$2" >"$REMOTE_DIR/$1/runs.json"; }  # NAME JSON

# Asserts the calls log does / doesn't contain a line matching a regex.
assert_called() { grep -Eq -- "$1" "$CALLS_LOG" || fail "expected call matching: $1"$'\n'"$(cat "$CALLS_LOG")"; }
refute_called() { ! grep -Eq -- "$1" "$CALLS_LOG" || fail "unexpected call matching: $1"$'\n'"$(grep -E -- "$1" "$CALLS_LOG")"; }
