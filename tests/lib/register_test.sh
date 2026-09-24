#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/targets.sh"
source "$(dirname "$0")/../../cli/lib/api.sh"
source "$(dirname "$0")/../../cli/lib/register.sh"

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  case "$haystack" in
    *"$needle"*) echo "PASS: $message" ;;
    *) echo "FAIL: $message (missing '$needle')"; failures=$((failures + 1)) ;;
  esac
}

test_register_writes_target() {
  curl() {
    printf '{"id":42,"uuid":"test-uuid-1234","token":"test-token-5678"}'
  }

  fjr_register test-target \
    --instance "https://codeberg.org" \
    --scope repo \
    --owner myorg \
    --repo myrepo \
    --name ci-runner \
    --token fake-pat \
    --description "Test runner" >/dev/null

  local content
  content="$(fjr_read_target test-target)"
  assert_contains "$content" "name: test-target" "target name stored"
  assert_contains "$content" "instance: https://codeberg.org" "instance stored"
  assert_contains "$content" "scope: repo" "scope stored"
  assert_contains "$content" "owner: myorg" "owner stored"
  assert_contains "$content" "repo: myrepo" "repo stored"
  assert_contains "$content" "runner_name: ci-runner" "runner name stored"
  assert_contains "$content" "uuid: test-uuid-1234" "uuid stored"
  assert_contains "$content" "token: test-token-5678" "token stored"

  unset -f curl
}
test_register_all_repos_uses_user_scope() {
  curl() {
    local url="${!#}"
    printf '%s' "$url" > "$TEST_FJR_HOME/curl-url"
    printf '{"id":42,"uuid":"all-repos-uuid","token":"all-repos-token"}'
  }

  fjr_register_all_repos_cmd account-wide \
    --instance "https://codeberg.org" \
    --name ci-runner \
    --token fake-pat >/dev/null

  local content
  content="$(fjr_read_target account-wide)"
  assert_contains "$content" "scope: user" "account-wide target uses user scope"
  assert_contains "$content" "owner: " "account-wide target has empty owner"
  assert_contains "$content" "repo: " "account-wide target has empty repo"
  assert_contains "$content" "instance: https://codeberg.org" "account-wide instance stored"
  assert_contains "$content" "runner_name: ci-runner" "account-wide runner name stored"
  assert_contains "$content" "uuid: all-repos-uuid" "account-wide uuid stored"
  assert_contains "$content" "token: all-repos-token" "account-wide token stored"

  local endpoint
  endpoint="$(cat "$TEST_FJR_HOME/curl-url")"
  assert_contains "$endpoint" "https://codeberg.org/api/v1/user/actions/runners" \
    "account-wide registration uses user endpoint"

  unset -f curl
}

test_register_all_repos_requires_required_arguments() {
  local invocation
  for invocation in \
    "fjr_register_all_repos_cmd '' --instance https://codeberg.org --name ci-runner --token fake-pat" \
    "fjr_register_all_repos_cmd account-wide --name ci-runner --token fake-pat" \
    "fjr_register_all_repos_cmd account-wide --instance https://codeberg.org --token fake-pat" \
    "fjr_register_all_repos_cmd account-wide --instance https://codeberg.org --name ci-runner"; do
    if eval "$invocation" >/dev/null 2>&1; then
      echo "FAIL: account-wide invocation should reject missing required argument"
      failures=$((failures + 1))
    else
      echo "PASS: account-wide invocation rejects missing required argument"
    fi
  done
}

test_register_all_repos_rejects_repository_options() {
  local invocation
  for invocation in \
    "fjr_register_all_repos_cmd account-wide --instance https://codeberg.org --scope repo --name ci-runner --token fake-pat" \
    "fjr_register_all_repos_cmd account-wide --instance https://codeberg.org --owner myorg --name ci-runner --token fake-pat" \
    "fjr_register_all_repos_cmd account-wide --instance https://codeberg.org --repo myrepo --name ci-runner --token fake-pat"; do
    if eval "$invocation" >/dev/null 2>&1; then
      echo "FAIL: account-wide invocation should reject repository option"
      failures=$((failures + 1))
    else
      echo "PASS: account-wide invocation rejects repository option"
    fi
  done
}


test_register_requires_scope_owner() {
  if fjr_register bad-target \
    --instance "https://codeberg.org" \
    --scope repo \
    --name ci-runner \
    --token fake-pat >/dev/null 2>&1; then
    echo "FAIL: repo scope without owner/repo should fail"
    failures=$((failures + 1))
  else
    echo "PASS: repo scope without owner/repo fails"
  fi
}

test_register_missing_token_fails() {
  if fjr_register bad-target \
    --instance "https://codeberg.org" \
    --scope user \
    --name ci-runner >/dev/null 2>&1; then
    echo "FAIL: missing token should fail"
    failures=$((failures + 1))
  else
    echo "PASS: missing token fails"
  fi
}

test_register_rejects_empty_response() {
  curl() { printf '{}'; }

  if fjr_register empty-target \
    --instance "https://codeberg.org" \
    --scope user \
    --name ci-runner \
    --token fake-pat >/dev/null 2>&1; then
    echo "FAIL: empty response should fail"
    failures=$((failures + 1))
  else
    echo "PASS: empty response fails"
  fi

  unset -f curl
}

test_register_surfaces_api_message() {
  curl() { printf '{"message":"access token does not exist","url":"x"}'; }

  local stderr
  stderr="$(fjr_register bad-pat-target \
    --instance "https://codeberg.org" \
    --scope user \
    --name ci-runner \
    --token runner-token 2>&1 >/dev/null)"

  assert_contains "$stderr" "access token does not exist" "api message surfaced"
  assert_contains "$stderr" "personal access token" "pat hint surfaced"

  unset -f curl
}

main() {
  test_register_writes_target
  test_register_requires_scope_owner
  test_register_missing_token_fails
  test_register_rejects_empty_response
  test_register_surfaces_api_message
  test_register_all_repos_uses_user_scope
  test_register_all_repos_requires_required_arguments
  test_register_all_repos_rejects_repository_options
  rm -rf "$TEST_FJR_HOME"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"