# Using this runner with Codeberg

Practical guide for serving a Codeberg repository with the `fjr` runner, running jobs on
this machine, and viewing workflow status. Codeberg is a hosted Forgejo instance, so the
generic flow in [registering-on-forgejo.md](registering-on-forgejo.md) applies unchanged;
this page covers the Codeberg-specific details.

## Put the workflow on Codeberg

The remote repository must contain `.forgejo/workflows/ci.yml` before any run happens:

- Create the repository on Codeberg, or use an existing one.
- Enable Actions: `Repo -> Settings -> Units (Advanced) -> Enable Actions`.
- Commit and push the workflow.
- Merge via pull request when ready; do not merge directly into `main`.

## Create a Forgejo access token

`fjr register` needs a personal access token to create the runner through the API:

- On Codeberg, open `User Settings -> Applications -> Access Tokens`.
- Create a token with the `write:actions` scope for the scope you target.
- Copy the token; you only need it during registration.

## Register the runner

From anywhere, register a target using either the account-wide or repository-scoped flow:

When one account-wide runner is desired, the recommended path is:

```bash
fjr register-all-repos codeberg-account \
  --instance https://codeberg.org \
  --name my-machine \
  --token <codeberg-pat-with-write:actions>
```

This serves every repository owned by the authenticated Codeberg user. Use the
repository-scoped command below when the runner should serve only one repository.

```bash
fjr register codeberg-app \
  --instance https://codeberg.org \
  --scope repo --owner myuser --repo myapp \
  --name my-machine \
  --token <codeberg-pat-with-write:actions>
```

`fjr` stores the returned `uuid` and `token` in `~/.local/share/fjr/targets/codeberg-app.yaml`
with owner-only permissions. Keep tokens out of source files, shell history, and commits.

## Run the runner daemon

```bash
fjr daemon
```

The daemon connects to Codeberg with the stored credentials and uses the rootless podman
socket to execute matching jobs. It serves every registered target in one process.

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
- Forgejo access token with `write:actions` created.
- `fjr register` run; `fjr list-targets` shows the target.
- `fjr daemon` running in the foreground, `tmux`, or systemd.
- A pushed commit or PR produced a green run in the Actions tab.
