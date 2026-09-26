podman_sock := "unix:///run/user/" + `id -u` + "/podman/podman.sock"
image := "ghcr.io/catthehacker/ubuntu:act-latest"
workflows := ".forgejo/workflows"
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

# Register a runner on any Forgejo instance via the API, e.g. `just register mine --instance https://codeberg.org --scope repo --owner me --repo app --name ci --token TOKEN`
register name *ARGS:
    @bash cli/fjr register {{name}} {{ARGS}}

# List the registered runner targets
list-targets:
    @bash cli/fjr list-targets

# Remove a registered runner target by name
remove-target name:
    @bash cli/fjr remove-target {{name}}

# Run one runner daemon for all registered targets
daemon:
    @bash cli/fjr daemon

# Run the fjr CLI from the checkout without installing it
fjr *ARGS:
    @bash cli/fjr {{ARGS}}

# Install the fjr CLI into the user PATH by delegating to scripts/install.sh
install:
    @bash scripts/install.sh

# Install fjr and enable its user systemd service
install-service: install
    @mkdir -p "{{ env_var("HOME") }}/.config/systemd/user"
    @printf '%s\n' \
        '[Unit]' \
        'Description=Forgejo Actions runner managed by fjr' \
        'After=network-online.target podman.socket' \
        'Wants=network-online.target podman.socket' \
        'Requires=podman.socket' \
        '' \
        '[Service]' \
        '# Restart the podman API service so the runner always talks to a fresh' \
        '# instance. A long-lived (--time=0) podman service goes stale after a' \
        '# podman package upgrade and then fails container/volume creation with' \
        '# "attempt to write a readonly database".' \
        'ExecStartPre=-/usr/bin/systemctl --user restart podman.service' \
        'ExecStart=%h/.local/bin/fjr daemon' \
        'Restart=on-failure' \
        'RestartSec=10' \
        'Environment=FJR_HOME=%h/.config/fjr' \
        'Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        '' \
        '[Install]' \
        'WantedBy=default.target' \
        > "{{ env_var("HOME") }}/.config/systemd/user/fjr-runner.service"
    @printf '%s\n' \
        '[Unit]' \
        'Description=Reclaim podman disk space for fjr runner' \
        'After=podman.socket' \
        'Wants=podman.socket' \
        '' \
        '[Service]' \
        'Type=oneshot' \
        'ExecStart=%h/.local/bin/fjr prune --volumes' \
        'Environment=FJR_HOME=%h/.config/fjr' \
        'Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        > "{{ env_var("HOME") }}/.config/systemd/user/fjr-prune.service"
    @printf '%s\n' \
        '[Unit]' \
        'Description=Periodically reclaim podman disk space for fjr runner' \
        '' \
        '[Timer]' \
        'OnBootSec=15min' \
        'OnUnitActiveSec=1h' \
        'Persistent=true' \
        '' \
        '[Install]' \
        'WantedBy=timers.target' \
        > "{{ env_var("HOME") }}/.config/systemd/user/fjr-prune.timer"
    @systemctl --user daemon-reload
    @systemctl --user enable fjr-runner.service
    @systemctl --user restart fjr-runner.service
    @systemctl --user enable fjr-prune.timer
    @systemctl --user restart fjr-prune.timer

# Follow logs for the fjr user systemd service
logs:
    @journalctl --user -u fjr-runner.service --no-pager -n 50 -f

# Verify the fjr service state and print recent logs
verify-logs:
    @systemctl --user --no-pager --full status fjr-runner.service
    @journalctl --user -u fjr-runner.service --no-pager -n 20