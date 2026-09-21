# Registering runners on any Forgejo instance

This guide turns your machine into a persistent Forgejo Actions runner for any Forgejo
instance and scope. `fjr register` creates the runner through the Forgejo HTTP API, and
`fjr daemon` serves every registered target from one process.

For fast local iteration without a server, see the "Running workflows locally" section in
the [README](../README.md) instead.

## Prerequisites

- `forgejo-runner` on your `PATH` (v12 or newer; multiple `server.connections` are used).
- A running rootless podman socket (`systemctl --user status podman.socket`).
- A Forgejo personal access token (PAT) with the `write:actions` scope for the scope you
  target. Admin scope requires an admin token.

## Runner scopes

The scope decides which repositories dispatch jobs to the runner:

| Scope   | Flags                                   | Serves                              |
| ------- | --------------------------------------- | ----------------------------------- |
| `user`  | `--scope user`                          | Every repo owned by the token user  |
| `org`   | `--scope org --owner ORG`               | Every repo in the organization      |
| `repo`  | `--scope repo --owner OWNER --repo REPO`| One repository                      |
| `admin` | `--scope admin`                         | Every repo on the instance          |

## Step 1: Register one or more targets

```bash
fjr register codeberg-app \
  --instance https://codeberg.org \
  --scope repo --owner myuser --repo myapp \
  --name my-machine \
  --token <forgejo-pat-with-write:actions>
```

`fjr register` calls the matching Forgejo API endpoint, receives the runner `uuid` and
`token`, and writes them to `~/.local/share/fjr/targets/<name>.yaml` with `600`
permissions. The PAT is used only for this request and is never stored.

Repeat `fjr register` for every instance, organization, or repository you want to serve.

## Step 2: Review the registered targets

```bash
fjr list-targets
```

This prints one row per target with its instance, scope, owner, repo, and runner name.

## Step 3: Run the daemon for all targets

```bash
fjr daemon
```

`fjr daemon` generates a combined `forgejo-runner` config containing one
`server.connections` entry per target and runs a single daemon that connects to all of
them over the rootless podman socket. The process stays in the foreground; leave it
running.

## Step 4: Trigger a job

Push a commit or open a pull request on any registered repository. Any job whose
`runs-on:` label the runner advertises runs on your machine. Watch progress in the
repository's `Actions` tab and in the daemon's terminal output.

## Labels

Each target stores its labels (set with `FJR_LABELS` at registration time, or the built-in
default). Labels are emitted per connection, so different targets can advertise different
labels. The `runs-on:` label in a workflow must match one advertised by the runner.

## Removing a target

```bash
fjr remove-target codeberg-app
```

This deletes the target file. The next `fjr daemon` run no longer connects to it. Delete
the runner in the Forgejo UI as well if you want it gone server-side.

## Keeping it running with systemd (optional)

Create a user service so the runner survives reboots:

```ini
[Unit]
Description=Forgejo runner (all fjr targets)
After=network-online.target podman.socket
Wants=network-online.target

[Service]
ExecStart=%h/.local/bin/fjr daemon
Restart=on-failure

[Install]
WantedBy=default.target
```

Enable and start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now fjr-runner.service
```
