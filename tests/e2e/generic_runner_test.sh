#!/usr/bin/env bash

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
fjr="$repo_root/cli/fjr"

if [ -z "${TEST_FORGEJO_INSTANCE:-}" ] \
  || [ -z "${TEST_FORGEJO_OWNER:-}" ] \
  || [ -z "${TEST_FORGEJO_REPO:-}" ] \
  || [ -z "${TEST_FORGEJO_PAT:-}" ]; then
  echo "SKIP: set TEST_FORGEJO_INSTANCE, TEST_FORGEJO_OWNER, TEST_FORGEJO_REPO, TEST_FORGEJO_PAT"
  exit 0
fi

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

cleanup() {
  "$fjr" remove-target e2e-test >/dev/null 2>&1 || true
  rm -rf "$TEST_FJR_HOME"
}
trap cleanup EXIT

test_register_lists_and_removes() {
  "$fjr" register e2e-test \
    --instance "$TEST_FORGEJO_INSTANCE" \
    --scope repo \
    --owner "$TEST_FORGEJO_OWNER" \
    --repo "$TEST_FORGEJO_REPO" \
    --name e2e-runner \
    --token "$TEST_FORGEJO_PAT" \
    --description "fjr e2e test" >/dev/null

  case "$("$fjr" list-targets)" in
    *e2e-test*) echo "PASS: registered target listed" ;;
    *) echo "FAIL: registered target not listed"; failures=$((failures + 1)) ;;
  esac

  "$fjr" remove-target e2e-test >/dev/null
  case "$("$fjr" list-targets)" in
    *e2e-test*) echo "FAIL: target not removed"; failures=$((failures + 1)) ;;
    *) echo "PASS: target removed" ;;
  esac
}

main() {
  test_register_lists_and_removes

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"