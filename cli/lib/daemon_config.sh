#!/usr/bin/env bash

fjr_daemon_config_header() {
  cat <<'YAML'
log:
  level: info

runner:
  file: .runner
  capacity: 1
  timeout: 3h

cache:
  enabled: true

container:
  network: host
  docker_host: "-"
  valid_volumes: []

server:
  connections:
YAML
}

fjr_emit_labels() {
  local labels_csv="$1"
  local label
  local IFS=','
  for label in $labels_csv; do
    [ -n "$label" ] || continue
    printf '        - "%s"\n' "$label"
  done
}

fjr_emit_connection() {
  local name="$1"
  local content
  content="$(fjr_read_target "$name")"

  local instance uuid token labels
  instance="$(fjr_target_field "$content" instance)"
  uuid="$(fjr_target_field "$content" uuid)"
  token="$(fjr_target_field "$content" token)"
  labels="$(fjr_target_field "$content" labels)"

  printf '    %s:\n' "$name"
  printf '      url: %s/\n' "${instance%/}"
  printf '      uuid: %s\n' "$uuid"
  printf '      token: %s\n' "$token"
  printf '      labels:\n'
  fjr_emit_labels "$labels"
}

fjr_generate_daemon_config() {
  local names
  names="$(fjr_list_targets)"
  if [ -z "$names" ]; then
    echo "fjr: no targets registered. Run 'fjr register' first." >&2
    return 1
  fi

  fjr_daemon_config_header
  local name
  while IFS= read -r name; do
    fjr_emit_connection "$name"
  done <<< "$names"
}