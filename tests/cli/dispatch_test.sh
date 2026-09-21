#!/usr/bin/env bash

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
fjr="$repo_root/cli/fjr"

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

assert_contains() {
  case "$1" in
    *"$2"*) echo "PASS: $3" ;;
    *) echo "FAIL: $3 (missing '$2')"; failures=$((failures + 1)) ;;
  esac
}

test_usage_lists_commands() {
  local output
  output="$("$fjr" 2>&1 || true)"
  assert_contains "$output" "register" "usage mentions register"
  assert_contains "$output" "list-targets" "usage mentions list-targets"
  assert_contains "$output" "remove-target" "usage mentions remove-target"
  assert_contains "$output" "daemon" "usage mentions daemon"
}

test_unknown_command_fails() {
  if "$fjr" bogus-command >/dev/null 2>&1; then
    echo "FAIL: unknown command should fail"
    failures=$((failures + 1))
  else
    echo "PASS: unknown command fails"
  fi
}

test_list_targets_empty() {
  local output
  output="$("$fjr" list-targets 2>&1 || true)"
  assert_contains "$output" "No targets registered" "list-targets empty message"
}

test_register_then_list_then_remove() {
  curl() { printf '{"id":1,"uuid":"u-1","token":"t-1"}'; }
  export -f curl

  "$fjr" register cli-target \
    --instance "https://codeberg.org" \
    --scope user \
    --name ci-runner \
    --token fake-pat >/dev/null

  local listed
  listed="$("$fjr" list-targets 2>&1 || true)"
  assert_contains "$listed" "cli-target" "registered target appears in list"

  "$fjr" remove-target cli-target >/dev/null
  local after
  after="$("$fjr" list-targets 2>&1 || true)"
  case "$after" in
    *cli-target*) echo "FAIL: target should be removed"; failures=$((failures + 1)) ;;
    *) echo "PASS: target removed from list" ;;
  esac

  unset -f curl
}

main() {
  test_usage_lists_commands
  test_unknown_command_fails
  test_list_targets_empty
  test_register_then_list_then_remove
  rm -rf "$TEST_FJR_HOME"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"