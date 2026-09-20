# forgejo-local-runner

A local runner for Forgejo Actions that executes workflow jobs on your own machine,
so you do not have to wait for hosted runners on [Codeberg](https://codeberg.org) to
pick up and run your jobs.

## Motivation

Workflow jobs pushed to Codeberg wait in a shared queue before a hosted Forgejo Actions
runner becomes available. That wait slows down the feedback loop while developing
pipelines. `forgejo-local-runner` runs those same jobs locally to shorten the
edit-run-inspect cycle before pushing.

## Goals

- Run Forgejo Actions workflow jobs locally against a checked-out repository.
- Shorten the feedback loop compared to waiting for hosted Codeberg runners.
- Reproduce the hosted runner environment closely enough to trust local results.

## Status

Early development. The runner is not yet implemented; this repository currently
defines the project's intent and scope.

## Running workflows locally

Run the workflows in `.forgejo/workflows/` on your own machine with the official
[`forgejo-runner exec`](https://forgejo.org/docs/latest/admin/actions/) command. No Forgejo
server is involved: exec runs each job in a container directly from the workflow files.

### Prerequisites

- `forgejo-runner` on your `PATH`.
- A running rootless podman socket. Check it with `systemctl --user status podman.socket`.
- `just` for the convenience recipes below.

There is no `docker` binary on this setup, so `DOCKER_HOST` must point at the podman socket,
and the container daemon socket mount must be disabled with `--container-daemon-socket -`.
The `justfile` recipes handle both automatically.

### Commands

- `just ci-list` — list the jobs discovered from the workflow files.
- `just ci-local` — run every workflow.
- `just ci-job check` — run a single job by its id.

The recipes pass extra flags through, e.g. `just ci-local -E pull_request` or
`just ci-local --dryrun`.

Without `just`, run the equivalent directly:

```bash
DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock \
  forgejo-runner exec --workflows .forgejo/workflows \
  --image ghcr.io/catthehacker/ubuntu:act-latest --container-daemon-socket -
```

### Behavior notes

- exec ignores the `runs-on:` label and uses the `--image` value for every job.
- exec skips `actions/checkout` and copies the current working tree into the container.
- `forgejo.*`/`github.*` event-context values are only partially populated locally, so
  workflows that depend on rich event context may behave differently than on Codeberg.
- `--container-daemon-socket -` disables mounting the host docker socket into the job
  container, which is required on a podman-only host with no `/var/run/docker.sock`.

## Registering as a remote runner

To have Codeberg dispatch jobs to this machine instead of running them locally, register
it as a persistent Forgejo Actions runner and start the daemon:

- `just runner-register token=<TOKEN>` — register with a Codeberg runner token.
- `just runner-daemon` — run the registered runner against the podman socket.

See [docs/registering-on-codeberg.md](docs/registering-on-codeberg.md) for the full
registration walkthrough, including where to get the token, the `runner-config.yaml`
settings, and an optional systemd service.

See [docs/using-codeberg-runner.md](docs/using-codeberg-runner.md) for the practical
usage guide and how Codeberg displays workflow status, including an optional Actions badge.

## License

This project is licensed under the [MIT License](LICENSE).
