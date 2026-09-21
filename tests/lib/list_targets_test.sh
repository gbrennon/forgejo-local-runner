#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/targets.sh"
source "$(dirname "$0")/../../cli/lib/list_targets.sh"

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

assert_contains() {
  case "$1" in
    *"$2"*) echo "PASS: $3" ;;
    *) echo "FAIL: $3 (missing '$2')"; failures=$((failures + 1)) ;;
  esac
}

test_empty_message() {
  local output
  output="$(fjr_list_targets_cmd)"
  assert_contains "$output" "No targets registered" "empty registry message"
}

test_lists_targets() {
  fjr_write_target target1 \
    "$(printf 'name: target1\ninstance: https://a.com\nscope: user\nowner: \nrepo: \nrunner_name: r1\n')"
  fjr_write_target target2 \
    "$(printf 'name: target2\ninstance: https://b.org\nscope: org\nowner: myorg\nrepo: \nrunner_name: r2\n')"

  local output
  output="$(fjr_list_targets_cmd)"
  assert_contains "$output" "target1" "target1 listed"
  assert_contains "$output" "target2" "target2 listed"
  assert_contains "$output" "https://a.com" "instance1 listed"
  assert_contains "$output" "myorg" "owner listed"
}

main() {
  test_empty_message
  test_lists_targets
  rm -rf "$TEST_FJR_HOME"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"