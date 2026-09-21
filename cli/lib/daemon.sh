#!/usr/bin/env bash

fjr_daemon() {
  fjr_require_forgejo_runner

  local config_file
  config_file="$(mktemp --suffix=.yaml)"
  trap 'rm -f "$config_file"' RETURN

  fjr_generate_daemon_config > "$config_file" || return 1

  DOCKER_HOST="$(fjr_podman_socket)" forgejo-runner daemon \
    --config "$config_file" "$@"
}