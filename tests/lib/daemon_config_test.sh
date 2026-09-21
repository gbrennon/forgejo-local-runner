#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/targets.sh"
source "$(dirname "$0")/../../cli/lib/list_targets.sh"
source "$(dirname "$0")/../../cli/lib/daemon_config.sh"

TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

failures=0

assert_contains() {
  case "$1" in
    *"$2"*) echo "PASS: $3" ;;
    *) echo "FAIL: $3 (missing '$2')"; failures=$((failures + 1)) ;;
  esac
}

seed_targets() {
  fjr_write_target target1 "$(printf 'name: target1\ninstance: https://codeberg.org\nscope: repo\nowner: o1\nrepo: r1\nrunner_name: run1\ndescription: d\nuuid: uuid-1\ntoken: token-1\nlabels: codeberg-tiny:docker://img1,codeberg-small:docker://img2\n')"
  fjr_write_target target2 "$(printf 'name: target2\ninstance: https://forgejo.example.com/\nscope: org\nowner: o2\nrepo: \nrunner_name: run2\ndescription: d\nuuid: uuid-2\ntoken: token-2\nlabels: forgejo-medium:docker://img3\n')"
}

test_generates_all_connections() {
  seed_targets
  local config
  config="$(fjr_generate_daemon_config)"

  assert_contains "$config" "server:" "has server section"
  assert_contains "$config" "connections:" "has connections section"
  assert_contains "$config" "    target1:" "connection target1 present"
  assert_contains "$config" "    target2:" "connection target2 present"
  assert_contains "$config" "url: https://codeberg.org/" "target1 url normalized"
  assert_contains "$config" "url: https://forgejo.example.com/" "target2 url normalized"
  assert_contains "$config" "uuid: uuid-1" "target1 uuid"
  assert_contains "$config" "uuid: uuid-2" "target2 uuid"
  assert_contains "$config" "token: token-1" "target1 token"
  assert_contains "$config" "token: token-2" "target2 token"
  assert_contains "$config" '- "codeberg-tiny:docker://img1"' "target1 label1"
  assert_contains "$config" '- "codeberg-small:docker://img2"' "target1 label2"
  assert_contains "$config" '- "forgejo-medium:docker://img3"' "target2 label"
  assert_contains "$config" 'docker_host: "-"' "podman docker_host disabled"
}

test_empty_registry_fails() {
  local empty_home
  empty_home="$(mktemp -d)"
  if FJR_HOME="$empty_home" fjr_generate_daemon_config >/dev/null 2>&1; then
    echo "FAIL: empty registry should fail"
    failures=$((failures + 1))
  else
    echo "PASS: empty registry fails"
  fi
  rm -rf "$empty_home"
}

main() {
  test_generates_all_connections
  test_empty_registry_fails
  rm -rf "$TEST_FJR_HOME"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"