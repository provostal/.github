# provostal/.github

Shared GitHub Actions workflows for Provostal. This repository is **public** so
that repositories in other organisations can call its workflows. Nothing secret
belongs here: every secret arrives from the caller.

| Workflow | What it does |
| --- | --- |
| [`coding-run.yml`](.github/workflows/coding-run.yml) | Lets Provostal's coding agent implement a work item in a repository and open the pull request |

## Coding runs

Provostal's coding agent does not write code inside Provostal. It writes a brief
and dispatches a workflow in the work item's repository. That workflow is a
small stub which calls `coding-run.yml` here: the run checks the branch out,
sets up the repository's toolchain, lets Claude Code (or Codex) implement the
brief, and opens a pull request with a GitHub App's token. Provostal then
notices the pull request and hands it to QA. The product side, and the rest of
what a repository needs (the GitHub connection, the app installation, a
protected default branch), is in `provostal/provostal`,
`docs/guides/coding-runs-setup.md`.

A repository takes two files.

### 1. The stub: `.github/workflows/provostal-coding.yml`

The name is the connection's `coding_workflow` setting in Provostal;
`provostal-coding.yml` is its default. The five dispatch inputs are the contract
with Provostal's `StartCodingRun` and are passed on unchanged.

```yaml
name: Provostal coding run

on:
  workflow_dispatch:
    inputs:
      work_item:
        description: Work item identifier, e.g. WI-12
        required: true
        type: string
      title:
        description: Work item title
        required: true
        type: string
      branch:
        description: The branch to work on
        required: true
        type: string
      base_branch:
        description: The branch the pull request targets
        required: true
        type: string
      instructions:
        description: The coding agent's brief
        required: true
        type: string

permissions:
  contents: read

jobs:
  code:
    # One run per branch at a time; a second dispatch waits for the first.
    concurrency:
      group: provostal-coding-${{ inputs.branch }}
      cancel-in-progress: false
    # A full commit SHA, see Versions below.
    uses: provostal/.github/.github/workflows/coding-run.yml@<sha> # v1.1.0
    with:
      work_item: ${{ inputs.work_item }}
      title: ${{ inputs.title }}
      branch: ${{ inputs.branch }}
      base_branch: ${{ inputs.base_branch }}
      instructions: ${{ inputs.instructions }}
      # The commands CLAUDE.md names, one per line; no commas or double quotes.
      checks: |
        ./vendor/bin/pint
        npm run build
        php artisan test
      # Optional: anything the agent must know about this repository that
      # CLAUDE.md does not already say.
      notes: ""
      engine: ${{ vars.PROVOSTAL_CODING_ENGINE }}
      app_id: ${{ vars.PROVOSTAL_CODING_APP_ID }}
    # Named one by one: `secrets: inherit` does not cross organisations.
    secrets:
      app_private_key: ${{ secrets.PROVOSTAL_CODING_APP_PRIVATE_KEY }}
      anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
      openai_api_key: ${{ secrets.OPENAI_API_KEY }}
      # Optional, for the setup action below:
      # setup_token: ${{ secrets.SOME_READ_ONLY_TOKEN }}
```

The concurrency group belongs on this calling job, which covers both jobs of
the called workflow. Do not add one inside `coding-run.yml` as well: a caller and
a called workflow sharing a group get in each other's way.

### 2. The setup action: `.github/actions/provostal-coding-setup/action.yml`

A composite action that installs whatever the checks need, as the repository's
CI does. It runs after the checkout and before the agent. A run that cannot
execute the checks can only write them, so a repository with checks needs one;
without the file the step is skipped.

```yaml
name: Provostal coding setup
description: The toolchain the coding run's checks need

runs:
  using: composite
  steps:
    - uses: shivammathur/setup-php@v2
      with:
        php-version: "8.4"
        coverage: none
        tools: composer:v2
    - uses: actions/setup-node@v7
      with:
        node-version: "26"
        cache: npm
    - shell: bash
      run: |
        composer install --no-interaction --no-progress --prefer-dist
        cp .env.example .env
        php artisan key:generate
        npm ci
        npm run build
```

`setup_token` reaches the action as the environment variable `SETUP_TOKEN`, for
one credential the setup itself needs (reading another repository, for
instance). It is not available to the agent's step, but it is to **every** step
of the action, including the ones that run the branch's code (`composer
install`, `npm ci`, a build). Blank it on those with `env: { SETUP_TOKEN: "" }`
and leave it only on the step that needs it.

### Engine

`engine` picks the agent: `claude` (also when empty) runs Claude Code with
`anthropic_api_key`; `codex` runs OpenAI's Codex in its `workspace-write`
sandbox, with sudo dropped first, with `openai_api_key`. Only the chosen
engine's key is needed. Both read the repository's `CLAUDE.md`, which is written
for whichever agent reads it. When the agent stops on an error, the step after it
prints the agent's final message, which is where a key without credit shows up.

### What the agent can reach

The brief can carry text that came from outside — a customer's mail, decomposed
into a work item — into a step where an agent edits files and runs the checks.
That is code execution of whatever the agent writes, and no `--allowedTools` list
bounds it; what bounds it is what is in reach:

- The app's write token never exists on the agent's runner. The run is two
  jobs: `code` checks out, sets up and runs the agent with only the workflow's
  read-only `github.token`, and hands its work on as a patch artifact.
  `publish` starts on a fresh runner, mints the app token there, applies the
  patch with hooks switched off, pushes and opens the pull request. Whatever
  the agent's code leaves behind on its runner — git hooks or config,
  `$GITHUB_ENV`, `$PATH` — stays on a runner that never holds the token.
- The push, the pull request and the token handling live here, in a repository
  the app is not installed on, so a run cannot rewrite them. The stub is under
  `.github/workflows/`, which the app cannot change either: it deliberately
  holds no *Workflows* permission.
- The model key is in the agent's process and cannot be kept from code it runs.
  Codex mitigates that by dropping sudo; for Claude, keep the key on a workspace
  with a spending limit.
- The protected default branch is the last line: nothing reaches it without a
  person merging it.

What is **not** out of reach: the setup action, and anything it runs (a
Makefile target, a script), sits outside `.github/workflows/`. A run can change
it on its branch, and the next run on that branch executes the changed version
before its agent starts, with `SETUP_TOKEN` in its environment. Give
`setup_token` only a read-only credential, scoped as narrowly as the setup
allows, blank it on every setup step that does not need it, and keep the setup
from writing it anywhere the agent can read later: not to disk, not to
`$GITHUB_ENV`.

Nor is the repository's own CI. The pull request is pushed with the app's token
precisely so that CI runs on it, and CI then runs the agent's code: its tests,
its build, its scripts. Treat a coding run's branch the way you would treat a
pull request from a fork. A CI job that runs the repository's code must not hold
a secret; a secret belongs only in a step that runs nothing from the branch
(a `gh api` call, an action pinned elsewhere).

## Versions

Releases are tagged `v<major>.<minor>.<patch>`; `v1` follows the latest `v1.x.y`.
A minor or patch keeps the inputs and secrets above working; anything that breaks
a caller is a new major. The dispatch inputs follow Provostal's `StartCodingRun`:
when that contract changes, this workflow gets a new major.

**Callers pin a full commit SHA**, with the tag as a comment:

```yaml
uses: provostal/.github/.github/workflows/coding-run.yml@<40-character sha> # v1.1.0
```

Not `@v1`: the stub hands this workflow the GitHub App's private key and the
model keys, and a tag can be moved by anyone who can push here. A pinned SHA
means a change here reaches a repository only when its stub is changed, which is
under `.github/workflows/` and so beyond the coding app's reach. Dependabot's
`github-actions` ecosystem can keep such pins current from the tags, once the
caller enables it in its `.github/dependabot.yml`.

The actions this workflow uses itself (`anthropics/claude-code-action`,
`openai/codex-action`, `actions/create-github-app-token` and the rest) are pinned
by major tag, as across the rest of the organisation's workflows. That trusts
their publishers with the same keys; pinning them by SHA as well is the next
step if that trust is not enough.

## Development

```bash
make workflows/lint    # actionlint over .github/workflows
```

CI runs the same check on every push. Every change to a workflow here reaches
every repository that calls it, so it is reviewed before it is merged.
