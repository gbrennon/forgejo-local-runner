podman_sock := "unix:///run/user/" + `id -u` + "/podman/podman.sock"
image := "ghcr.io/catthehacker/ubuntu:act-latest"
workflows := ".forgejo/workflows"
instance := "https://codeberg.org"
runner_name := `hostname`
runner_labels := "codeberg-tiny"
config := "runner-config.yaml"

# List the jobs Forgejo would run, discovered from the workflow files
ci-list:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --list

# Run every workflow locally against the rootless podman socket
ci-local *ARGS:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --image {{image}} --container-daemon-socket - {{ARGS}}

# Run a single job by its id, e.g. `just ci-job check`
ci-job job *ARGS:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --image {{image}} --container-daemon-socket - --job {{job}} {{ARGS}}

# Register this machine as a runner on the remote instance, e.g. `just runner-register token=<TOKEN>`
runner-register token:
    forgejo-runner register --no-interactive --instance {{instance}} --token {{token}} --name {{runner_name}} --labels {{runner_labels}}

# Run the registered runner as a daemon that dispatches remote jobs to podman
runner-daemon:
    DOCKER_HOST={{podman_sock}} forgejo-runner daemon --config {{config}}
