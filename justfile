podman_sock := "unix:///run/user/" + `id -u` + "/podman/podman.sock"
image := "ghcr.io/catthehacker/ubuntu:act-latest"
workflows := ".forgejo/workflows"
instance := "https://codeberg.org"
runner_uuid := "dc94b1b4-f252-436e-a31f-e340b223ca52"
runner_token_file := `pwd` + "/runner-token"
config := "runner-config.yaml"
default:
    @just --list


# List the jobs Forgejo would run, discovered from the workflow files
ci-list:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --list

# Run every workflow locally against the rootless podman socket
ci-local *ARGS:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --image {{image}} --container-daemon-socket - {{ARGS}}

# Run a single job by its id, e.g. `just ci-job check`
ci-job job *ARGS:
    DOCKER_HOST={{podman_sock}} forgejo-runner exec --workflows {{workflows}} --image {{image}} --container-daemon-socket - --job {{job}} {{ARGS}}

# Store the Codeberg runner token in a local ignored file
runner-token:
    @read -rsp "Codeberg runner token: " token; echo; printf '%s' "$token" > runner-token; chmod 600 runner-token

# Run the Codeberg runner daemon against the rootless podman socket
runner-daemon:
    DOCKER_HOST={{podman_sock}} forgejo-runner daemon --config {{config}} --url {{instance}}/ --uuid {{runner_uuid}} --token-url file://{{runner_token_file}}
