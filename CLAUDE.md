# CLAUDE.md

Shared GitHub Actions workflows for Provostal. [`README.md`](README.md) is the
reference: how a repository calls each workflow, and why it is built the way it
is.

## Rules that are easy to get wrong

- **This repository is public.** No secrets, no customer names, no installation
  details. Every secret a workflow needs arrives from its caller as a declared
  `secrets:` input, and `secrets: inherit` does not cross organisations.
- **Every release reaches every caller.** Callers pin a commit SHA and move it
  to a new `v<major>.<minor>.<patch>` tag when they update (README.md,
  *Versions*), which they do on trust. Have a change reviewed before it is
  merged; a change that breaks an input or a secret is a new major.
- **Inputs reach a shell through `env:`, never interpolated into `run:`.** A
  work item title is free text.
- **Keep the write token off the agent's runner.** The agent's job holds only
  the read-only `github.token`; the app token is minted in the `publish` job, on
  a fresh runner. Do not merge the two jobs. README.md, *What the agent can
  reach*, says why.

## Checks

```bash
make workflows/lint    # actionlint; CI runs it too
```

## Git

Conventional commits, in English.
