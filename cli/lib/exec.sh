fjr_list() {
  fjr_require_forgejo_runner
  fjr_require_workflows_dir
  DOCKER_HOST="$(fjr_podman_socket)" forgejo-runner exec \
    --workflows "$(fjr_workflows)" --list "$@"
}

fjr_run() {
  fjr_require_forgejo_runner
  fjr_require_workflows_dir
  DOCKER_HOST="$(fjr_podman_socket)" forgejo-runner exec \
    --workflows "$(fjr_workflows)" --image "$(fjr_image)" \
    --container-daemon-socket - "$@"
}

fjr_job() {
  if [ "$#" -lt 1 ]; then
    fjr_usage_error "job requires a job id"
  fi
  local job_id="$1"
  shift
  fjr_require_forgejo_runner
  fjr_require_workflows_dir
  DOCKER_HOST="$(fjr_podman_socket)" forgejo-runner exec \
    --workflows "$(fjr_workflows)" --image "$(fjr_image)" \
    --container-daemon-socket - --job "$job_id" "$@"
}
