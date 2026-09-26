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

Working. The `fjr` CLI runs workflows locally and registers/serves runners for any
Forgejo instance and scope (user, organization, repository, or admin).

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

## Installing the fjr CLI

The `just` recipes are for development inside a checkout. Install the same
commands once as the `fjr` CLI to use them from any repository:

- `just install` — copy the CLI to `~/.local/share/fjr` and link `fjr` into
  `~/.local/bin`.
- `bash scripts/install.sh` — the same install without `just`.

The install is idempotent; a foreign file already at `~/.local/bin/fjr` is moved
to `fjr.bak`. Override the targets with `FJR_HOME` and `FJR_BIN_DIR`.

From any repository checkout:

- `fjr list` — list the jobs Forgejo would run.
- `fjr run` — run every workflow; extra `forgejo-runner` flags pass through.
- `fjr job check` — run a single job by its id.
- `fjr register NAME [options]` — create a runner on any Forgejo instance via its API.
- `fjr list-targets` — show every registered runner target.
- `fjr remove-target NAME` — delete a registered runner target.
- `fjr daemon` — run one runner process that serves every registered target.
- `fjr prune [--all] [--volumes]` — reclaim podman disk space so rootless storage does not hit its quota. Removes only dangling images by default; `--all` also drops unused images (re-pulled on next run) and `--volumes` unused volumes. `just install-service` schedules this hourly via a `fjr-prune.timer` systemd user unit.

Without installing, run the CLI straight from the checkout with `just fjr <command>`.

## Registering runners for any Forgejo repository

`fjr register` creates a runner on any Forgejo instance through the Forgejo HTTP API and
stores its `uuid` and `token` in a per-target file under `~/.local/share/fjr/targets/`.
The scope decides which jobs the runner receives:

- `--scope user` — every repository owned by the token's user.
- `--scope org --owner ORG` — every repository in an organization.
- `--scope repo --owner OWNER --repo REPO` — a single repository.
- `--scope admin` — every repository on the instance (admin token required).

Use `fjr register-all-repos NAME` when one runner should serve every repository owned by
the authenticated user without specifying an owner or repository. See the
[Forgejo registration guide](docs/registering-on-forgejo.md) for the account-wide flow,
token requirements, and scope details.

Register one or more targets, then run a single daemon for all of them:

```bash
fjr register codeberg-app \
  --instance https://codeberg.org \
  --scope repo --owner myuser --repo myapp \
  --name my-machine --token <forgejo-pat-with-write:actions>

fjr daemon
```

The daemon generates a combined `forgejo-runner` config with one `server.connections`
entry per target and serves them all in one process. See
[docs/registering-on-forgejo.md](docs/registering-on-forgejo.md) for the full walkthrough,
token scopes, and an optional systemd service.

See [docs/using-codeberg-runner.md](docs/using-codeberg-runner.md) for how Forgejo and
Codeberg display workflow status, including an optional Actions badge.

## License

This project is licensed under the [MIT License](LICENSE).
