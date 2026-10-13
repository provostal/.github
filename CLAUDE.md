# CLAUDE.md

Shared GitHub Actions workflows for Provostal. [`README.md`](README.md) is the
reference: how a repository calls each workflow, and why it is built the way it
is.

## Rules that are easy to get wrong

- **This repository is public.** No secrets, no customer names, no installation
  details. Every secret a workflow needs arrives from its caller as a declared
  `secrets:` input, and `secrets: inherit` does not cross organisations.
- **Every change reaches every caller.** Callers pin a major tag (`@v1`) that
  moves with compatible changes, so a merged change runs in every repository on
  its next dispatch. Have a change reviewed before it is merged; a change that
  breaks an input or a secret is a new major tag, not a move of the old one.
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
