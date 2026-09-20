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

## License

To be determined.
