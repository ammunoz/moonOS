# Building

## CI

Pushes to any branch, pull requests, a daily schedule at 06:00 UTC and manual
dispatches all trigger a build.

Two jobs are defined:

- **Validate Recipe** runs `bluebuild validate recipes/recipe.yml`, which
  checks the recipe against the published JSON schema. It runs in parallel
  with the build rather than in front of it, and the nightly schedule skips
  it — so a scheduled build runs the build job alone.
- **Build Custom Image** first checks that the base image and the
  kernel-module bundle are built for the same kernel, then builds the image
  and pushes it.

The workflow lives in
[`.forgejo/workflows/build.yml`](../.forgejo/workflows/build.yml). A push that
only touches Markdown files does not trigger a build; pull requests are always
built.

## Required secrets

Set these in the repository's **Settings → Secrets** on `git.ajiky.com`:

| Secret | Value |
|---|---|
| `SIGNING_SECRET` | the cosign **private** key (PEM). Must match the committed `cosign.pub`. |
| `REGISTRY_TOKEN` | a Forgejo personal access token with the `write:package` scope, used to push to `git.ajiky.com`. |

The private key is never committed — `.gitignore` excludes `cosign.key` and
`cosign.private`.

## Published tags

The CLI derives the tags from the event that triggered the build. Where
`<fedora>` is the Fedora version of the base image the build used (currently
`44`), `<timestamp>` is the build date as `YYYYMMDD` and `<short-sha>` is the
first seven characters of the commit:

| Trigger | Tags |
|---|---|
| Default branch — a push to `main` or the nightly schedule | `latest`, `<timestamp>`, `<fedora>`, `<timestamp>-<fedora>`, `<short-sha>-<fedora>` |
| Pull request | `pr-<number>-<fedora>`, `<short-sha>-<fedora>` |
| Any other branch | `br-<branch>-<fedora>`, `<short-sha>-<fedora>` |

Only a default-branch build moves `latest`. A `/` in a branch name becomes an
underscore, so `feature/x` is tagged `br-feature_x-44`.

## Building locally

```bash
bluebuild build -v recipes/recipe.yml
```

See the [BlueBuild local build guide](https://blue-build.org/how-to/local/).
A local build does not push; add `--push` plus `--registry`/`--username`/
`--password` to publish.

The kernel check can be run on its own at any time:

```bash
python3 .forgejo/scripts/check-akmods-kernel.py
```

See [kernel-modules.md](kernel-modules.md) for what it compares and why the
build stops on a mismatch.

## See also

- [kernel-modules.md](kernel-modules.md) — the kernel-match check in detail
- [image-composition.md](image-composition.md) — what goes into the image
- [upstream-template.md](upstream-template.md) — syncing with the upstream template
