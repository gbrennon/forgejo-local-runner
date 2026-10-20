#!/usr/bin/env bash

source "$(dirname "$0")/../../cli/lib/common.sh"
source "$(dirname "$0")/../../cli/lib/gc.sh"

TEST_DIR="$(mktemp -d)"
CALLS_LOG="$TEST_DIR/calls.log"
ACT_CACHE="$TEST_DIR/actcache"
mkdir -p "$ACT_CACHE"

# Fake podman that records each invocation on its own line.
cat > "$TEST_DIR/podman" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CALLS_LOG"
exit 0
EOF
chmod +x "$TEST_DIR/podman"

export FJR_PODMAN_BIN="$TEST_DIR/podman"
export FJR_ACT_CACHE_DIR="$ACT_CACHE"

failures=0

reset_logs() { rm -f "$CALLS_LOG"; }
call_count() { grep -c -- "$1" "$CALLS_LOG" 2>/dev/null || true; }

assert_calls_contain() {
  if grep -q -- "$1" "$CALLS_LOG"; then
    echo "PASS: $2"
  else
    echo "FAIL: $2 (calls: $(cat "$CALLS_LOG" 2>/dev/null))"
    failures=$((failures + 1))
  fi
}

assert_calls_absent() {
  if grep -q -- "$1" "$CALLS_LOG"; then
    echo "FAIL: $2 (calls: $(cat "$CALLS_LOG"))"
    failures=$((failures + 1))
  else
    echo "PASS: $2"
  fi
}

test_default_gc_prunes_everything_with_keep() {
  reset_logs
  fjr_gc >/dev/null 2>&1
  assert_calls_contain 'container prune --force --filter until=72h' "containers pruned with keep window"
  assert_calls_contain 'image prune --force --all --filter until=72h' "unused images pruned with keep window"
  assert_calls_contain 'volume prune --force --filter until=72h' "volumes pruned with keep window"
  assert_calls_contain 'network prune --force --filter until=72h' "networks pruned with keep window"
  assert_calls_contain 'image prune --force --build-cache' "build cache pruned"
}

test_no_images_flag() {
  reset_logs
  fjr_gc --no-images >/dev/null 2>&1
  assert_calls_absent 'image prune --force --all' "--no-images skips image pruning"
  assert_calls_contain 'container prune' "--no-images still prunes containers"
}

test_keep_override() {
  reset_logs
  fjr_gc --keep 24h >/dev/null 2>&1
  assert_calls_contain 'until=24h' "--keep overrides the window"
}

test_dry_run_removes_nothing() {
  reset_logs
  fjr_gc --dry-run >/dev/null 2>&1
  if [ -f "$CALLS_LOG" ]; then
    echo "FAIL: --dry-run must not call podman"
    failures=$((failures + 1))
  else
    echo "PASS: --dry-run does not call podman"
  fi
}

test_act_cache_ttl() {
  local stale="$ACT_CACHE/stale-action" fresh="$ACT_CACHE/fresh-action"
  mkdir -p "$stale" "$fresh"
  touch -d '30 days ago' "$stale"
  reset_logs
  fjr_gc --act-ttl 14 >/dev/null 2>&1
  if [ -d "$stale" ]; then
    echo "FAIL: stale act cache entry should be removed"
    failures=$((failures + 1))
  else
    echo "PASS: stale act cache entry removed"
  fi
  if [ -d "$fresh" ]; then
    echo "PASS: fresh act cache entry kept"
  else
    echo "FAIL: fresh act cache entry should be kept"
    failures=$((failures + 1))
  fi
  if [ ! -d "$ACT_CACHE" ]; then
    echo "FAIL: act cache dir itself must be kept"
    failures=$((failures + 1))
  else
    echo "PASS: act cache dir itself kept"
  fi
}

test_act_ttl_zero_disables() {
  local stale="$ACT_CACHE/stale-keep" 
  mkdir -p "$stale"
  touch -d '30 days ago' "$stale"
  reset_logs
  fjr_gc --act-ttl 0 >/dev/null 2>&1
  if [ -d "$stale" ]; then
    echo "PASS: --act-ttl 0 keeps entries"
  else
    echo "FAIL: --act-ttl 0 should keep entries"
    failures=$((failures + 1))
  fi
  rm -rf "$stale"
}

test_unknown_option_fails() {
  if fjr_gc --bogus >/dev/null 2>&1; then
    echo "FAIL: unknown option should fail"
    failures=$((failures + 1))
  else
    echo "PASS: unknown option fails"
  fi
}

test_gc_enabled_flag() {
  for v in 0 off no never false disabled; do
    if fjr_gc_enabled "$v"; then
      echo "FAIL: gc should be disabled for '$v'"
      failures=$((failures + 1))
    else
      echo "PASS: gc disabled for '$v'"
    fi
  done
  if fjr_gc_enabled "1h"; then
    echo "PASS: gc enabled for interval"
  else
    echo "FAIL: gc should be enabled for interval"
    failures=$((failures + 1))
  fi
}

main() {
  test_default_gc_prunes_everything_with_keep
  test_no_images_flag
  test_keep_override
  test_dry_run_removes_nothing
  test_act_cache_ttl
  test_act_ttl_zero_disables
  test_unknown_option_fails
  test_gc_enabled_flag
  rm -rf "$TEST_DIR"

  if [ "$failures" -eq 0 ]; then
    echo "All tests passed"
    return 0
  fi
  echo "Some tests failed"
  return 1
}

main "$@"
