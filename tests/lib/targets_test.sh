#!/usr/bin/env bash
# Tests for target registry utilities

# Source the libraries
source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/targets.sh"

# Test setup/teardown
TEST_FJR_HOME="$(mktemp -d)"
export FJR_HOME="$TEST_FJR_HOME"

teardown() {
  rm -rf "$TEST_FJR_HOME"
}

# Test fjr_targets_dir creates directory
test_fjr_targets_dir_creates_dir() {
  local dir
  dir="$(fjr_targets_dir)"
  [ -d "$dir" ] || { echo "FAIL: directory not created"; return 1; }
  [ "$dir" = "$TEST_FJR_HOME/targets" ] || { echo "FAIL: wrong path: $dir"; return 1; }
  echo "PASS: fjr_targets_dir creates directory"
}

# Test fjr_target_file returns correct path
test_fjr_target_file_returns_path() {
  local file
  file="$(fjr_target_file "my-target")"
  [ "$file" = "$TEST_FJR_HOME/targets/my-target.yaml" ] || { echo "FAIL: wrong path: $file"; return 1; }
  echo "PASS: fjr_target_file returns correct path"
}

# Test fjr_target_file fails without name
test_fjr_target_file_fails_without_name() {
  fjr_target_file "" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_target_file fails without name"
}

# Test fjr_write_target writes config
test_fjr_write_target_writes_config() {
  local config="instance: https://example.com
token: secret123"
  fjr_write_target "test-target" "$config" || { echo "FAIL: write failed"; return 1; }
  local file
  file="$(fjr_target_file "test-target")"
  [ -f "$file" ] || { echo "FAIL: file not created"; return 1; }
  local content
  content="$(cat "$file")"
  [ "$content" = "$config" ] || { echo "FAIL: content mismatch"; return 1; }
  echo "PASS: fjr_write_target writes config"
}

# Test fjr_write_target fails without name
test_fjr_write_target_fails_without_name() {
  fjr_write_target "" "config" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_write_target fails without name"
}

# Test fjr_write_target fails without config
test_fjr_write_target_fails_without_config() {
  fjr_write_target "name" "" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_write_target fails without config"
}

# Test fjr_read_target reads config
test_fjr_read_target_reads_config() {
  local config="instance: https://example.com
token: secret123"
  fjr_write_target "read-target" "$config"
  local read_config
  read_config="$(fjr_read_target "read-target")"
  [ "$read_config" = "$config" ] || { echo "FAIL: content mismatch"; return 1; }
  echo "PASS: fjr_read_target reads config"
}

# Test fjr_read_target fails for non-existent target
test_fjr_read_target_fails_for_missing() {
  fjr_read_target "nonexistent" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_read_target fails for non-existent target"
}

# Test fjr_read_target fails without name
test_fjr_read_target_fails_without_name() {
  fjr_read_target "" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_read_target fails without name"
}

# Test fjr_delete_target deletes target
test_fjr_delete_target_deletes() {
  fjr_write_target "delete-target" "config"
  fjr_delete_target "delete-target" || { echo "FAIL: delete failed"; return 1; }
  local file
  file="$(fjr_target_file "delete-target")"
  [ ! -f "$file" ] || { echo "FAIL: file still exists"; return 1; }
  echo "PASS: fjr_delete_target deletes target"
}

# Test fjr_delete_target fails for non-existent target
test_fjr_delete_target_fails_for_missing() {
  fjr_delete_target "nonexistent" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_delete_target fails for non-existent target"
}

# Test fjr_delete_target fails without name
test_fjr_delete_target_fails_without_name() {
  fjr_delete_target "" 2>/dev/null && { echo "FAIL: should have failed"; return 1; }
  echo "PASS: fjr_delete_target fails without name"
}

# Test fjr_list_targets empty - runs first with clean state
test_fjr_list_targets_empty() {
  local list
  list="$(fjr_list_targets)"
  [ -z "$list" ] || { echo "FAIL: should be empty"; return 1; }
  echo "PASS: fjr_list_targets empty"
}

# Test fjr_list_targets lists targets
test_fjr_list_targets_lists() {
  fjr_write_target "target-a" "config-a"
  fjr_write_target "target-b" "config-b"
  fjr_write_target "target-c" "config-c"
  local list
  list="$(fjr_list_targets)"
  [ "$(echo "$list" | grep -c '^target-a$')" -eq 1 ] || { echo "FAIL: target-a missing"; return 1; }
  [ "$(echo "$list" | grep -c '^target-b$')" -eq 1 ] || { echo "FAIL: target-b missing"; return 1; }
  [ "$(echo "$list" | grep -c '^target-c$')" -eq 1 ] || { echo "FAIL: target-c missing"; return 1; }
  echo "PASS: fjr_list_targets lists targets"
}

# Run all tests
main() {
  local failed=0
  test_fjr_list_targets_empty || failed=1
  test_fjr_targets_dir_creates_dir || failed=1
  test_fjr_target_file_returns_path || failed=1
  test_fjr_target_file_fails_without_name || failed=1
  test_fjr_write_target_writes_config || failed=1
  test_fjr_write_target_fails_without_name || failed=1
  test_fjr_write_target_fails_without_config || failed=1
  test_fjr_read_target_reads_config || failed=1
  test_fjr_read_target_fails_for_missing || failed=1
  test_fjr_read_target_fails_without_name || failed=1
  test_fjr_delete_target_deletes || failed=1
  test_fjr_delete_target_fails_for_missing || failed=1
  test_fjr_delete_target_fails_without_name || failed=1
  test_fjr_list_targets_lists || failed=1
  teardown
  if [ "$failed" -eq 0 ]; then
    echo "All tests passed"
    exit 0
  else
    echo "Some tests failed"
    exit 1
  fi
}

main "$@"