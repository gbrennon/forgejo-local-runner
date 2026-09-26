#!/usr/bin/env bash

# Reclaim podman disk space so the rootless storage does not hit its quota.
#
# By default this removes only dangling images, stopped containers and unused
# networks (safe, keeps the runner image cached). Opt into heavier reclamation:
#   --all      also remove all images not used by a container (re-pulled later)
#   --volumes  also remove unused local volumes
fjr_prune() {
  local prune_all=0
  local prune_volumes=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all)
        prune_all=1
        ;;
      --volumes)
        prune_volumes=1
        ;;
      *)
        echo "fjr prune: unknown option: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  fjr_require_podman || return 1

  local args=(system prune --force)
  [ "$prune_all" -eq 1 ] && args+=(--all)
  [ "$prune_volumes" -eq 1 ] && args+=(--volumes)

  echo "fjr: reclaiming podman disk space (${args[*]})" >&2
  DOCKER_HOST="$(fjr_podman_socket)" "$(fjr_podman_bin)" "${args[@]}"
}
