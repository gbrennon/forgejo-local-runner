#!/usr/bin/env bash

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
justfile="$repo_root/justfile"

failures=0

assert_present() {
  if grep -q "$1" "$justfile"; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    failures=$((failures + 1))
  fi
}

assert_absent() {
  if grep -q "$1" "$justfile"; then
    echo "FAIL: $2"
    failures=$((failures + 1))
  else
    echo "PASS: $2"
  fi
}

main() {
  assert_present '^register ' "register recipe present"
  assert_present '^list-targets:' "list-targets recipe present"
  assert_present '^remove-target ' "remove-target recipe present"
  assert_present '^daemon:' "daemon recipe present"
  assert_present 'fjr-prune.timer' "prune timer installed by install-service"
  assert_present 'fjr prune' "prune service runs fjr prune"

  assert_absent '^runner-token:' "runner-token recipe removed"
  assert_absent '^runner-daemon:' "runner-daemon recipe removed"
  assert_absent 'dc94b1b4-f252-436e-a31f-e340b223ca52' "hardcoded uuid removed"
  assert_absent 'instance := "https://codeberg.org"' "hardcoded instance removed"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"