#!/usr/bin/env bash

# Run one runner daemon process for all registered targets, with an optional
# in-process garbage-collection loop so disk cleanup survives even when the
# hourly systemd timer is missing or broken. FJR_GC_INTERVAL controls it
# (Go duration for `sleep`, e.g. 1h; 0/off disables the loop). The loop calls
# `fjr gc`, which never touches running containers or the images they use.
fjr_daemon() {
  fjr_require_forgejo_runner

  local gc_interval gc_pid=""
  gc_interval="$(fjr_gc_interval)"

  local config_file
  config_file="$(mktemp --suffix=.yaml)"
  trap 'rm -f "$config_file"' RETURN

  fjr_generate_daemon_config > "$config_file" || return 1

  if fjr_gc_enabled "$gc_interval"; then
    (
      trap - RETURN
      while sleep "$gc_interval"; do
        fjr_gc >>"${FJR_GC_LOG:-/dev/null}" 2>&1 || true
      done
    ) &
    gc_pid="$!"
    trap 'kill "$gc_pid" 2>/dev/null || true; rm -f "$config_file"' RETURN
  fi

  DOCKER_HOST="$(fjr_podman_socket)" forgejo-runner daemon \
    --config "$config_file" "$@"
}
