#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/prune.sh"

TEST_DIR="$(mktemp -d)"
ARGS_LOG="$TEST_DIR/args.log"

# Fake podman that records the arguments it was invoked with.
cat > "$TEST_DIR/podman" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$ARGS_LOG"
exit 0
EOF
chmod +x "$TEST_DIR/podman"

export FJR_PODMAN_BIN="$TEST_DIR/podman"

failures=0

assert_log_contains() {
  if grep -q -- "$1" "$ARGS_LOG"; then
    echo "PASS: $2"
  else
    echo "FAIL: $2 (log: $(cat "$ARGS_LOG"))"
    failures=$((failures + 1))
  fi
}

assert_log_absent() {
  if grep -q -- "$1" "$ARGS_LOG"; then
    echo "FAIL: $2 (log: $(cat "$ARGS_LOG"))"
    failures=$((failures + 1))
  else
    echo "PASS: $2"
  fi
}

test_default_prunes_non_interactively() {
  fjr_prune >/dev/null 2>&1
  assert_log_contains 'system prune' "default runs system prune"
  assert_log_contains '\-\-force' "default is non-interactive (--force)"
  assert_log_absent '\-\-all' "default does not prune all images"
  assert_log_absent '\-\-volumes' "default does not prune volumes"
}

test_all_flag() {
  fjr_prune --all >/dev/null 2>&1
  assert_log_contains '\-\-all' "--all forwards to podman"
}

test_volumes_flag() {
  fjr_prune --volumes >/dev/null 2>&1
  assert_log_contains '\-\-volumes' "--volumes forwards to podman"
}

test_unknown_option_fails() {
  if fjr_prune --bogus >/dev/null 2>&1; then
    echo "FAIL: unknown option should fail"
    failures=$((failures + 1))
  else
    echo "PASS: unknown option fails"
  fi
}

main() {
  test_default_prunes_non_interactively
  test_all_flag
  test_volumes_flag
  test_unknown_option_fails
  rm -rf "$TEST_DIR"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"
