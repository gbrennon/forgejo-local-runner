#!/usr/bin/env bash

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

failures=0

assert_file_contains() {
  if grep -q "$2" "$repo_root/$1"; then
    echo "PASS: $3"
  else
    echo "FAIL: $3"
    failures=$((failures + 1))
  fi
}

assert_file_exists() {
  if [ -f "$repo_root/$1" ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    failures=$((failures + 1))
  fi
}

assert_file_absent() {
  if [ -f "$repo_root/$1" ]; then
    echo "FAIL: $2"
    failures=$((failures + 1))
  else
    echo "PASS: $2"
  fi
}

main() {
  assert_file_contains README.md 'fjr register' "README documents register"
  assert_file_contains README.md 'fjr daemon' "README documents daemon"
  assert_file_contains README.md 'registering-on-forgejo.md' "README links generic guide"
  assert_file_exists docs/registering-on-forgejo.md "generic guide exists"
  assert_file_absent docs/registering-on-codeberg.md "codeberg-only guide removed"
  assert_file_contains docs/using-codeberg-runner.md 'fjr register' "usage guide uses register"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"