#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/api.sh"

failures=0

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $message"
  else
    echo "FAIL: $message (expected '$expected', got '$actual')"
    failures=$((failures + 1))
  fi
}

test_user_endpoint() {
  local endpoint
  endpoint="$(fjr_get_registration_endpoint "https://codeberg.org" "user")"
  assert_equals "https://codeberg.org/api/v1/user/actions/runners" "$endpoint" \
    "user endpoint"
}

test_org_endpoint() {
  local endpoint
  endpoint="$(fjr_get_registration_endpoint "https://codeberg.org" "org" "myorg")"
  assert_equals "https://codeberg.org/api/v1/orgs/myorg/actions/runners" "$endpoint" \
    "org endpoint"
}

test_repo_endpoint() {
  local endpoint
  endpoint="$(fjr_get_registration_endpoint "https://codeberg.org" "repo" "myorg" "myrepo")"
  assert_equals "https://codeberg.org/api/v1/repos/myorg/myrepo/actions/runners" "$endpoint" \
    "repo endpoint"
}

test_admin_endpoint() {
  local endpoint
  endpoint="$(fjr_get_registration_endpoint "https://codeberg.org" "admin")"
  assert_equals "https://codeberg.org/api/v1/admin/actions/runners" "$endpoint" \
    "admin endpoint"
}

test_unknown_scope_fails() {
  if fjr_get_registration_endpoint "https://codeberg.org" "bogus" >/dev/null 2>&1; then
    echo "FAIL: unknown scope should fail"
    failures=$((failures + 1))
  else
    echo "PASS: unknown scope fails"
  fi
}

test_register_runner_parses_response() {
  curl() {
    printf '{"id":42,"uuid":"test-uuid-1234","token":"test-token-5678"}'
  }

  local response
  response="$(fjr_register_runner "https://codeberg.org" "repo" "fake-pat" \
    "ci-runner" "desc" "myorg" "myrepo")"

  assert_equals '{"id":42,"uuid":"test-uuid-1234","token":"test-token-5678"}' "$response" \
    "register runner returns API response"

  unset -f curl
}

main() {
  test_user_endpoint
  test_org_endpoint
  test_repo_endpoint
  test_admin_endpoint
  test_unknown_scope_fails
  test_register_runner_parses_response

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"