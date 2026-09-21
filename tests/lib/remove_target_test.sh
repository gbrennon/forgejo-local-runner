#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/targets.sh"
source "$(dirname "$0")/../../cli/lib/remove_target.sh"

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

test_removes_existing() {
  fjr_write_target to-remove "$(printf 'name: to-remove\n')"
  fjr_remove_target_cmd to-remove >/dev/null
  if [ -f "$(fjr_target_file to-remove)" ]; then
    echo "FAIL: target file should be deleted"
    failures=$((failures + 1))
  else
    echo "PASS: existing target removed"
  fi
}

test_missing_fails() {
  if fjr_remove_target_cmd nonexistent >/dev/null 2>&1; then
    echo "FAIL: removing missing target should fail"
    failures=$((failures + 1))
  else
    echo "PASS: removing missing target fails"
  fi
}

test_no_name_fails() {
  if fjr_remove_target_cmd >/dev/null 2>&1; then
    echo "FAIL: missing name should fail"
    failures=$((failures + 1))
  else
    echo "PASS: missing name fails"
  fi
}

main() {
  test_removes_existing
  test_missing_fails
  test_no_name_fails
  rm -rf "$TEST_FJR_HOME"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"