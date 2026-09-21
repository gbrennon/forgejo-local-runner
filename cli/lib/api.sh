#!/usr/bin/env bash

fjr_get_registration_endpoint() {
  local instance="$1"
  local scope="$2"

  case "$scope" in
    user)
      printf '%s/api/v1/user/actions/runners' "$instance"
      ;;
    org)
      local org="$3"
      printf '%s/api/v1/orgs/%s/actions/runners' "$instance" "$org"
      ;;
    repo)
      local owner="$3"
      local repo="$4"
      printf '%s/api/v1/repos/%s/%s/actions/runners' "$instance" "$owner" "$repo"
      ;;
    admin)
      printf '%s/api/v1/admin/actions/runners' "$instance"
      ;;
    *)
      printf '' >&2
      return 1
      ;;
  esac
}

fjr_register_runner() {
  local instance="$1"
  local scope="$2"
  local pat="$3"
  local runner_name="$4"
  local description="${5:-}"
  local owner="${6:-}"
  local repo="${7:-}"

  local endpoint
  endpoint="$(fjr_get_registration_endpoint "$instance" "$scope" "$owner" "$repo")" || return 1

  local json_payload
  json_payload=$(printf '{"name":"%s","description":"%s"}' "$runner_name" "$description")

  local response
  response=$(curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: token $pat" \
    -d "$json_payload" \
    "$endpoint")

  printf '%s' "$response"
}