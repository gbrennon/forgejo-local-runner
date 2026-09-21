#!/usr/bin/env bash

fjr_remove_target_cmd() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "fjr remove-target: missing target name" >&2
    return 1
  fi
  if ! fjr_delete_target "$name"; then
    echo "fjr: target '$name' not found" >&2
    return 1
  fi
  echo "fjr: removed target '$name'"
}