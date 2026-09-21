#!/usr/bin/env bash

fjr_json_field() {
  local json="$1"
  local field="$2"
  printf '%s' "$json" \
    | sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

fjr_default_labels() {
  printf '%s' "${FJR_LABELS:-codeberg-tiny:docker://ghcr.io/catthehacker/ubuntu:act-latest}"
}

fjr_build_target_config() {
  printf 'name: %s\n' "$1"
  printf 'instance: %s\n' "$2"
  printf 'scope: %s\n' "$3"
  printf 'owner: %s\n' "$4"
  printf 'repo: %s\n' "$5"
  printf 'runner_name: %s\n' "$6"
  printf 'description: %s\n' "$7"
  printf 'uuid: %s\n' "$8"
  printf 'token: %s\n' "$9"
  printf 'labels: %s\n' "${10}"
}

fjr_require_register_args() {
  local specs=(
    "$1|missing target name"
    "$2|--instance required"
    "$3|--scope required"
    "$4|--name required"
    "$5|--token required (Forgejo PAT with write:actions scope)"
  )
  local spec
  for spec in "${specs[@]}"; do
    if [ -z "${spec%%|*}" ]; then
      echo "fjr register: ${spec#*|}" >&2
      return 1
    fi
  done
}

fjr_require_register_scope() {
  local scope="$1"
  local owner="$2"
  local repo="$3"
  case "$scope" in
    user | admin) return 0 ;;
    org)
      [ -n "$owner" ] && return 0
      echo "fjr register: --owner required for org scope" >&2
      return 1
      ;;
    repo)
      [ -n "$owner" ] && [ -n "$repo" ] && return 0
      echo "fjr register: --owner and --repo required for repo scope" >&2
      return 1
      ;;
    *)
      echo "fjr register: --scope must be user, org, repo, or admin" >&2
      return 1
      ;;
  esac
}

fjr_validate_register() {
  fjr_require_register_args "$1" "$2" "$3" "$6" "$8" || return 1
  fjr_require_register_scope "$3" "$4" "$5" || return 1
}

fjr_perform_registration() {
  local name="$1" instance="$2" scope="$3" owner="$4" repo="$5"
  local runner_name="$6" description="$7" pat="$8"

  local response
  response="$(fjr_register_runner \
    "$instance" "$scope" "$pat" "$runner_name" "$description" "$owner" "$repo")" || {
    echo "fjr: runner registration request failed" >&2
    return 1
  }

  local uuid token
  uuid="$(fjr_json_field "$response" "uuid")"
  token="$(fjr_json_field "$response" "token")"
  if [ -z "$uuid" ] || [ -z "$token" ]; then
    fjr_report_registration_failure "$response"
    return 1
  fi

  local config
  config="$(fjr_build_target_config \
    "$name" "$instance" "$scope" "$owner" "$repo" \
    "$runner_name" "$description" "$uuid" "$token" "$(fjr_default_labels)")"
  fjr_write_target "$name" "$config"
  echo "fjr: registered target '$name' (uuid: $uuid)"
}

fjr_report_registration_failure() {
  local response="$1"
  local api_message
  api_message="$(fjr_json_field "$response" "message" | sed 's/\\n/; /g')"
  if [ -n "$api_message" ]; then
    echo "fjr: Forgejo API rejected the registration: $api_message" >&2
  else
    echo "fjr: registration response missing uuid or token" >&2
  fi
  echo "fjr: --token must be a Forgejo personal access token with the" >&2
  echo "     write:actions scope, not the runner token shown in the UI." >&2
}

fjr_register() {
  declare -A opts=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --*) opts["${1#--}"]="${2:-}"; shift 2 ;;
      *) opts[target]="$1"; shift ;;
    esac
  done

  fjr_validate_register \
    "${opts[target]:-}" "${opts[instance]:-}" "${opts[scope]:-}" \
    "${opts[owner]:-}" "${opts[repo]:-}" "${opts[name]:-}" \
    "${opts[description]:-}" "${opts[token]:-}" || return 1

  fjr_perform_registration \
    "${opts[target]:-}" "${opts[instance]:-}" "${opts[scope]:-}" \
    "${opts[owner]:-}" "${opts[repo]:-}" "${opts[name]:-}" \
    "${opts[description]:-}" "${opts[token]:-}"
}