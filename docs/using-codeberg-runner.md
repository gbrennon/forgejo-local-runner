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

## Create the Codeberg runner credentials

On Codeberg, open `Repo -> Settings -> Actions -> Runners -> Create new runner`.
Copy the UUID and token shown by Codeberg. The token is displayed only once.

The runner has already been created when this page appears. Do not use the deprecated
`forgejo-runner register` command for this flow.

## Store the token locally

From the directory that holds the `justfile`, run:

```bash
just runner-token
```

Paste the Codeberg token at the prompt. The recipe stores it in the gitignored
`runner-token` file with owner-only permissions.

The runner UUID is configured in `justfile` as `runner_uuid`. Keep the token out of
source files, shell history, commits, and chat messages.

## Run the runner daemon

```bash
just runner-daemon
```

The recipe connects to Codeberg with the configured UUID and local token file, then
uses the rootless podman socket to execute matching jobs.


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
- Runner UUID and token copied from Codeberg's runner setup page.
- `just runner-token` run; `runner-token` exists with owner-only permissions.
- `just runner-daemon` running in the foreground, `tmux`, or systemd.
- A pushed commit or PR produced a green run in the Actions tab.
