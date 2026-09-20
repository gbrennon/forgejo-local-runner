# Registering this machine as a Codeberg runner

This guide turns your machine into a persistent Forgejo Actions runner that Codeberg
dispatches jobs to. It uses the official `forgejo-runner daemon` command against the
rootless podman socket. For fast local iteration without a server, see the
"Running workflows locally" section in the [README](../README.md) instead.

## Local exec vs. registered daemon

| Concern | `just ci-local` (exec) | `just runner-daemon` (daemon) |
| --- | --- | --- |
| Trigger | You, manually, offline | Codeberg dispatches on push or PR |
| Server | None | Registered with Codeberg |
| Image selection | `--image` flag | `label:docker://image` in config |
| Podman socket | `DOCKER_HOST` env | `DOCKER_HOST` env |

The same `.forgejo/workflows/ci.yml` runs unchanged in both modes.

## Prerequisites

- `forgejo-runner` on your `PATH`.
- A running rootless podman socket. Check it with `systemctl --user status podman.socket`.
- `just` for the recipes below.
- Actions enabled for the target repository on Codeberg.

## Step 1: Get a registration token from Codeberg

Open the runner settings for the scope you want the runner to serve:

- Repository runner: `Repo -> Settings -> Actions -> Runners -> Create new runner`.
- Organization or user runner: the equivalent `Actions -> Runners` page at that level.

Copy the registration token shown. It is single-use and short-lived, so register soon
after generating it.

## Step 2: Register the runner

Run the register recipe with the token from Step 1:

```bash
just runner-register token=<REGISTRATION_TOKEN>
```

This calls `forgejo-runner register` against `https://codeberg.org`, names the runner
after your hostname, and advertises the `codeberg-tiny` label. It writes a `.runner`
credentials file in the current directory. That file holds a secret and is gitignored;
keep it next to `runner-config.yaml` so the daemon finds it.

To target a different instance, label, or name, override the justfile variables:

```bash
just --set instance https://another.forgejo.host --set runner_labels ci-linux runner-register token=<TOKEN>
```

## Step 3: Review the daemon config

The committed `runner-config.yaml` drives the daemon. Two settings matter on a
podman-only host:

- `runner.labels` maps the `runs-on:` label to a container image:
  `codeberg-tiny:docker://ghcr.io/catthehacker/ubuntu:act-latest`. The daemon has no
  `--image` flag, so this mapping is how it selects the image.
- `container.docker_host: "-"` disables mounting a docker socket into job containers,
  which is required with no `/var/run/docker.sock`. The daemon still reaches podman
  through the `DOCKER_HOST` environment variable the recipe sets.

The label after `runs-on:` in your workflow must match a key in `runner.labels`, and
that label must be one the runner advertised at registration.

## Step 4: Run the daemon

Start the runner:

```bash
just runner-daemon
```

It sets `DOCKER_HOST` to the rootless podman socket and runs
`forgejo-runner daemon --config runner-config.yaml`. The process stays in the
foreground and polls Codeberg for matching jobs. Leave it running.

## Step 5: Trigger a job

Push a commit or open a pull request on the repository. Any job whose `runs-on:` label
the daemon advertises runs on your machine. Watch progress in the repository's `Actions`
tab on Codeberg and in the daemon's terminal output.

## Keep it running with systemd (optional)

To keep the runner alive across reboots, create a user service. Adjust `WorkingDirectory`
to the directory that holds `.runner` and `runner-config.yaml`:

```ini
# ~/.config/systemd/user/forgejo-runner.service
[Unit]
Description=Forgejo Actions runner (podman)
After=podman.socket

[Service]
Environment=DOCKER_HOST=unix:///run/user/%U/podman/podman.sock
WorkingDirectory=%h/Documents/repos/gbrennon/forgejo-local-runner
ExecStart=forgejo-runner daemon --config runner-config.yaml
Restart=on-failure

[Install]
WantedBy=default.target
```

Enable and start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now forgejo-runner.service
```

## Troubleshooting

- `docker.sock` permission errors: confirm `container.docker_host` is `"-"` and that the
  daemon was launched with `DOCKER_HOST` pointing at the podman socket.
- Jobs stay queued on Codeberg: confirm the runner's advertised label matches the
  workflow's `runs-on:` value, and confirm the daemon shows the runner as online.
- Cannot reach podman: start the socket with `systemctl --user start podman.socket`, then
  restart the daemon.
