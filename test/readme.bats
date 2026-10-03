#!/usr/bin/env bats

load test_helper

# The README restates gems.txt as a linked list so it reads well on GitHub.
# gems.txt is what the script actually uses, so fail when the two disagree.
@test "README's gem list matches gems.txt" {
  local root="$TEST_ROOT/.."

  # Bullets between "The gems it manages" and the next heading, as owner/repo.
  # Each bullet must be "- [repo](https://github.com/owner/repo)".
  local readme
  readme="$(sed -n '/^The gems it manages/,/^## /p' "$root/README.md" |
    sed -n 's|^- \[\([^]]*\)\](https://github\.com/\([^/)]*\)/\1)$|\2/\1|p')"

  # Every bullet in that section has to parse, so a malformed entry can't be
  # silently dropped from the comparison.
  local bullets
  bullets="$(sed -n '/^The gems it manages/,/^## /p' "$root/README.md" | grep -c '^- ' || true)"
  [ "$bullets" -eq "$(printf '%s\n' "$readme" | grep -c .)" ] ||
    fail "README has $bullets gem bullets but only some match '- [repo](https://github.com/owner/repo)'"

  local gems
  gems="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$root/gems.txt")"

  [ "$readme" = "$gems" ] ||
    fail "README gem list doesn't match gems.txt (order matters)
README:
$readme
gems.txt:
$gems"
}
