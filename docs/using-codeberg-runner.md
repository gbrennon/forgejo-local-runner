# Using this runner with Codeberg

Practical guide for registering this repository's Forgejo Actions runner with Codeberg,
running jobs on this machine, and viewing workflow status in the remote repository.
For detailed configuration and troubleshooting, see
[registering-on-codeberg.md](registering-on-codeberg.md).

## Put the workflow on Codeberg

The remote repository must contain `.forgejo/workflows/ci.yml` before any run happens:

- Create the repository on Codeberg, or use an existing one.
- Enable Actions: `Repo -> Settings -> Units (Advanced) -> Enable Actions`.
- Commit and push the current tree from the `feat-impl-runner` branch.
- Merge via pull request when ready; do not merge directly into `main`.

## Create a Codeberg runner token

On Codeberg, open `Repo -> Settings -> Actions -> Runners -> Create new runner` and copy
the registration token. The token is single-use and short-lived, so generate it
immediately before registering.

## Register this machine

From the directory that holds the `justfile`:

```bash
just runner-register token=<TOKEN>
```

This writes a gitignored `.runner` credentials file and advertises the
`codeberg-tiny` label. See [registering-on-codeberg.md](registering-on-codeberg.md)
for what the recipes and config do.

## Run the runner daemon

```bash
just runner-daemon
```

Leave it running. For persistence across reboots, install the `systemd --user` unit
described in [registering-on-codeberg.md](registering-on-codeberg.md); its
`WorkingDirectory` must be the directory holding `.runner` and `runner-config.yaml`.

## View workflow status on Codeberg

Once the daemon picks up a job, status reporting requires no extra work:

- The repository's `Actions` tab shows every run with live logs streamed from the daemon.
- Each commit and pull request receives a status check for the `check` job.
- The daemon's terminal shows the same runs locally.

The status write-back is part of the runner protocol, not something the workflow does.

## Add a workflow status badge (optional)

Add an Actions badge to `README.md` so pass/fail is visible at a glance. Replace
`<owner>/<repo>` with the Codeberg repository path:

```markdown
[![Actions status](https://codeberg.org/<owner>/<repo>/actions/workflows/ci.yml/badge.svg?branch=main)](https://codeberg.org/<owner>/<repo>/actions)
```

## Usage checklist

- Repository created and Actions enabled on Codeberg.
- `.forgejo/workflows/ci.yml` committed and pushed.
- Registration token obtained from the repository's Actions runner settings.
- `just runner-register` run; `.runner` file exists locally.
- `just runner-daemon` running (foreground, `tmux`, or the systemd unit).
- A pushed commit or PR produced a green run in the Actions tab.
