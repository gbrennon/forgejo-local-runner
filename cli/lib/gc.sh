#!/usr/bin/env bash

# Periodic garbage collection for the disk space the runner consumes.
#
# `fjr prune` is a thin wrapper around `podman system prune` for manual use.
# `fjr gc` is the thorough, periodic variant: it prunes stopped containers,
# unused images/volumes/networks older than a keep window, clears build
# cache, and removes stale entries from the forgejo-runner action cache
# (~/.cache/act) that otherwise grow without bound.
#
# Safe by default:
#   - running containers (and the images/volumes they use) are never touched;
#   - only podman resources older than --keep (default 72h) are pruned;
#   - only children of the act cache dir are removed, never the dir itself;
#   - /tmp and named compose volumes still referenced by containers are left alone.
#
# Environment overrides:
#   FJR_GC_KEEP (default 72h), FJR_GC_ACT_TTL_DAYS (default 14, 0 disables),
#   FJR_ACT_CACHE_DIR (default $HOME/.cache/act),
#   FJR_GC_PRUNE_IMAGES (default 1, 0 skips image pruning),
#   FJR_GC_INTERVAL (default 1h, used by `fjr daemon`; 0 disables).

fjr_gc_keep() {
  printf '%s' "${FJR_GC_KEEP:-72h}"
}

fjr_gc_act_ttl_days() {
  printf '%s' "${FJR_GC_ACT_TTL_DAYS:-14}"
}

fjr_act_cache_dir() {
  printf '%s' "${FJR_ACT_CACHE_DIR:-$HOME/.cache/act}"
}

fjr_gc_interval() {
  printf '%s' "${FJR_GC_INTERVAL:-1h}"
}

fjr_gc_usage() {
  cat <<'USAGE'
Usage: fjr gc [--keep DURATION] [--act-ttl DAYS] [--act-cache DIR] [--no-images] [--dry-run]

  --keep DURATION   only prune podman resources older than this (default 72h,
                    from FJR_GC_KEEP; podman Go duration like 24h, 7d)
  --act-ttl DAYS    remove act cache entries not modified for DAYS
                    (default 14, from FJR_GC_ACT_TTL_DAYS; 0 disables)
  --act-cache DIR   action cache dir (default ~/.cache/act, from FJR_ACT_CACHE_DIR)
  --no-images       skip image pruning (keep the runner image cached)
  --dry-run, -n     print what would be removed without removing it
USAGE
}

fjr_gc_podman() {
  DOCKER_HOST="$(fjr_podman_socket)" "$(fjr_podman_bin)" "$@"
}

# True when the daemon's in-process gc loop should run for this interval value.
fjr_gc_enabled() {
  case "$1" in
    ""|0|off|OFF|no|NO|never|NEVER|false|FALSE|disabled|DISABLED)
      return 1;;
  esac
  return 0
}

fjr_gc() {
  local keep act_ttl act_cache dry_run=0 prune_images=1

  keep="$(fjr_gc_keep)"
  act_ttl="$(fjr_gc_act_ttl_days)"
  act_cache="$(fjr_act_cache_dir)"
  if [ "${FJR_GC_PRUNE_IMAGES:-1}" = "0" ]; then
    prune_images=0
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --keep)
        [ "$#" -ge 2 ] || { echo "fjr gc: --keep requires a value" >&2; return 1; }
        keep="$2"; shift 2;;
      --keep=*)
        keep="${1#--keep=}"; shift;;
      --act-ttl)
        [ "$#" -ge 2 ] || { echo "fjr gc: --act-ttl requires a value" >&2; return 1; }
        act_ttl="$2"; shift 2;;
      --act-ttl=*)
        act_ttl="${1#--act-ttl=}"; shift;;
      --act-cache)
        [ "$#" -ge 2 ] || { echo "fjr gc: --act-cache requires a value" >&2; return 1; }
        act_cache="$2"; shift 2;;
      --act-cache=*)
        act_cache="${1#--act-cache=}"; shift;;
      --no-images)
        prune_images=0; shift;;
      --dry-run|--dryrun|-n)
        dry_run=1; shift;;
      -h|--help|help)
        fjr_gc_usage; return 0;;
      *)
        echo "fjr gc: unknown option: $1" >&2; return 1;;
    esac
  done

  case "$act_ttl" in
    ''|*[!0-9]*)
      echo "fjr gc: --act-ttl must be a non-negative number of days (got '$act_ttl')" >&2
      return 1;;
  esac

  fjr_require_podman || return 1

  if [ "$dry_run" -eq 1 ]; then
    echo "fjr gc --dry-run: would run:" >&2
    echo "  podman container prune --force --filter until=${keep}" >&2
    if [ "$prune_images" -eq 1 ]; then
      echo "  podman image prune --force --all --filter until=${keep}" >&2
    fi
    echo "  podman volume prune --force --filter until=${keep}" >&2
    echo "  podman network prune --force --filter until=${keep}" >&2
    echo "  podman image prune --force --build-cache" >&2
    if [ "$act_ttl" != "0" ]; then
      echo "  find ${act_cache} -mindepth 1 -maxdepth 1 -mtime +${act_ttl} -exec rm -rf {} +" >&2
      if [ -d "$act_cache" ]; then
        find "$act_cache" -mindepth 1 -maxdepth 1 -mtime "+$act_ttl" -print 2>/dev/null | sed 's/^/  would remove: /' >&2 || true
      fi
    fi
    return 0
  fi

  local failures=0

  echo "fjr: collecting garbage (keep=${keep}, act-ttl=${act_ttl}d)" >&2

  fjr_gc_podman container prune --force --filter "until=${keep}" >&2 \
    || { echo "fjr gc: container prune failed" >&2; failures=$((failures + 1)); }

  if [ "$prune_images" -eq 1 ]; then
    fjr_gc_podman image prune --force --all --filter "until=${keep}" >&2 \
      || { echo "fjr gc: image prune failed" >&2; failures=$((failures + 1)); }
  fi

  fjr_gc_podman volume prune --force --filter "until=${keep}" >&2 \
    || { echo "fjr gc: volume prune failed" >&2; failures=$((failures + 1)); }

  fjr_gc_podman network prune --force --filter "until=${keep}" >&2 \
    || { echo "fjr gc: network prune failed" >&2; failures=$((failures + 1)); }

  # Best effort: older podman releases may not know --build-cache.
  fjr_gc_podman image prune --force --build-cache >&2 \
    || echo "fjr gc: build-cache prune skipped/failed (ignoring)" >&2

  fjr_gc_act_cache "$act_cache" "$act_ttl" || failures=$((failures + 1))

  if [ "$failures" -ne 0 ]; then
    echo "fjr gc: finished with ${failures} error(s)" >&2
    return 1
  fi
  echo "fjr gc: done" >&2
}

# Remove stale children of the forgejo-runner action cache dir.
fjr_gc_act_cache() {
  local act_cache="$1" act_ttl="$2"

  if [ "$act_ttl" = "0" ]; then
    return 0
  fi
  if [ ! -d "$act_cache" ]; then
    return 0
  fi
  case "$act_cache" in
    ""|/|"$HOME")
      echo "fjr gc: refusing to clean unsafe act cache dir '$act_cache'" >&2
      return 1;;
  esac

  local removed=0
  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    if rm -rf -- "$entry" 2>/dev/null; then
      removed=$((removed + 1))
    else
      echo "fjr gc: failed to remove $entry" >&2
    fi
  done < <(find "$act_cache" -mindepth 1 -maxdepth 1 -mtime "+$act_ttl" -print 2>/dev/null)

  echo "fjr gc: removed ${removed} stale entr(ies) from ${act_cache}" >&2
}
