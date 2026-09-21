fjr_home() {
  printf '%s' "${FJR_HOME:-$HOME/.config/fjr}"
}


fjr_podman_socket() {
  printf '%s' "${FJR_PODMAN_SOCKET:-unix:///run/user/$(id -u)/podman/podman.sock}"
}

fjr_image() {
  printf '%s' "${FJR_IMAGE:-ghcr.io/catthehacker/ubuntu:act-latest}"
}

fjr_workflows() {
  printf '%s' "${FJR_WORKFLOWS:-.forgejo/workflows}"
}

fjr_require_forgejo_runner() {
  if ! command -v forgejo-runner >/dev/null; then
    echo "fjr: forgejo-runner is not on PATH; install it first" >&2
    exit 1
  fi
}

fjr_require_workflows_dir() {
  local workflows_dir
  workflows_dir="$(fjr_workflows)"
  if [ ! -d "$workflows_dir" ]; then
    echo "fjr: workflows dir '$workflows_dir' not found in $(pwd)" >&2
    exit 1
  fi
}

fjr_usage() {
  cat <<'USAGE'
fjr — run Forgejo Actions workflows locally and manage remote runners

Usage:
  fjr list                     List the jobs Forgejo would run
  fjr run [runner-args]        Run every workflow in the current repository
  fjr job JOB [args...]        Run a single job by id
  fjr register NAME [options]  Register a runner on Forgejo via the API
  fjr list-targets             List registered runner targets
  fjr remove-target NAME       Remove a registered runner target
  fjr daemon                   Run one daemon for all registered targets

Register options:
  --instance URL   --scope user|org|repo|admin
  --owner OWNER    --repo REPO    --name RUNNER_NAME
  --description D   --token FORGEJO_PAT

Environment overrides:
  FJR_HOME  FJR_PODMAN_SOCKET  FJR_WORKFLOWS  FJR_IMAGE  FJR_LABELS
USAGE
}

fjr_usage_error() {
  echo "fjr: $1" >&2
  fjr_usage >&2
  exit 1
}
