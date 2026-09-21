#!/usr/bin/env bash

fjr_target_field() {
  local content="$1"
  local field="$2"
  printf '%s' "$content" | sed -n "s/^$field: \(.*\)$/\1/p"
}

fjr_print_target_row() {
  local name="$1"
  local content
  content="$(fjr_read_target "$name")"
  printf '%-20s %-32s %-6s %-14s %-14s %s\n' \
    "$name" \
    "$(fjr_target_field "$content" instance)" \
    "$(fjr_target_field "$content" scope)" \
    "$(fjr_target_field "$content" owner)" \
    "$(fjr_target_field "$content" repo)" \
    "$(fjr_target_field "$content" runner_name)"
}

fjr_list_targets_cmd() {
  local names
  names="$(fjr_list_targets)"
  if [ -z "$names" ]; then
    echo "No targets registered. Use 'fjr register' to add one."
    return 0
  fi

  printf '%-20s %-32s %-6s %-14s %-14s %s\n' \
    NAME INSTANCE SCOPE OWNER REPO RUNNER
  local name
  while IFS= read -r name; do
    fjr_print_target_row "$name"
  done <<< "$names"
}