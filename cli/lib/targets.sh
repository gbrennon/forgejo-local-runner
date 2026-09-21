#!/usr/bin/env bash

fjr_targets_dir() {
  local home
  home="$(fjr_home)"
  local targets_dir="${home}/targets"
  mkdir -p "$targets_dir"
  printf '%s' "$targets_dir"
}

fjr_target_file() {
  local target_name="$1"
  if [ -z "$target_name" ]; then
    echo "fjr_target_file: target name required" >&2
    return 1
  fi
  local targets_dir
  targets_dir="$(fjr_targets_dir)"
  printf '%s/%s.yaml' "$targets_dir" "$target_name"
}

fjr_write_target() {
  local target_name="$1"
  local config="$2"
  if [ -z "$target_name" ]; then
    echo "fjr_write_target: target name required" >&2
    return 1
  fi
  if [ -z "$config" ]; then
    echo "fjr_write_target: config required" >&2
    return 1
  fi
  local target_file
  target_file="$(fjr_target_file "$target_name")"
  printf '%s' "$config" > "$target_file"
  chmod 600 "$target_file"
}

fjr_read_target() {
  local target_name="$1"
  if [ -z "$target_name" ]; then
    echo "fjr_read_target: target name required" >&2
    return 1
  fi
  local target_file
  target_file="$(fjr_target_file "$target_name")"
  if [ ! -f "$target_file" ]; then
    return 1
  fi
  cat "$target_file"
}

fjr_delete_target() {
  local target_name="$1"
  if [ -z "$target_name" ]; then
    echo "fjr_delete_target: target name required" >&2
    return 1
  fi
  local target_file
  target_file="$(fjr_target_file "$target_name")"
  if [ ! -f "$target_file" ]; then
    return 1
  fi
  rm -f "$target_file"
}

fjr_list_targets() {
  local targets_dir
  targets_dir="$(fjr_targets_dir)"
  local targets=()
  for file in "$targets_dir"/*.yaml; do
    [ -f "$file" ] || continue
    local basename
    basename="$(basename "$file")"
    targets+=("${basename%.yaml}")
  done
  if [ ${#targets[@]} -eq 0 ]; then
    return 0
  fi
  printf '%s\n' "${targets[@]}"
}