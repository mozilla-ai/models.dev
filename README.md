# models.dev, with the models Otari needs

This is a fork of [anomalyco/models.dev](https://github.com/anomalyco/models.dev)
that publishes the same catalog JSON upstream serves, plus the models upstream
does not list yet. [Otari](https://github.com/mozilla-ai/otari) reads it from
<https://mozilla-ai.github.io/models.dev/experimental/v2.0/api.json>. Everything
added here is also offered upstream; once a file lands there, it leaves this repo.

## How it is laid out

| Branch | Holds | Who writes it |
|---|---|---|
| `dev` | a byte-for-byte mirror of `anomalyco/models.dev:dev` | the `sync` job only, by force-push |
| `otari` (default) | this README, the workflow, `scripts/`, `overlay/`, `patches/` | people, by pull request |
| `feat/*` | one upstream contribution each, cut from `dev` | `scripts/contribute.sh` |

Our commits never sit on a branch that also carries upstream history, so there is
nothing to merge and nothing that can conflict. `otari` is the default branch because
GitHub fires `schedule` triggers from the default branch only. Upstream's own
workflows stay on `dev`; their `if: github.repository == 'anomalyco/models.dev'`
guards skip them here.

`overlay/` mirrors upstream's tree: `overlay/providers/togetherai/models/<id>.toml`
is served as `providers/togetherai/models/<id>.toml`. A file that replaces one
upstream already has keeps the upstream version it was written against in
`overlay/.base/<same path>`.

`patches/` holds code changes that wait for an upstream merge, such as a new model
type. The overlay can only add or replace whole files, and upstream edits its code
too often for a whole-file override to hold. Each patch is the commit of an open
upstream pull request, made with `git format-patch -1 -U1` on its `feat/<name>`
branch. The build applies the patches first, then the overlay.

## What runs every hour

[`catalog.yml`](.github/workflows/catalog.yml), at :47 (upstream syncs its catalogs at :17),
on every push to `otari`, and on demand:

1. `sync` force-pushes upstream's `dev` to ours.
2. `build` checks out `dev` and `otari`, runs `scripts/apply-patches.sh` and
   `scripts/apply-overlay.sh`, then
   `bun validate` and upstream's own build.
3. `deploy` publishes the JSON endpoints to GitHub Pages. `version.json` names the
   upstream and overlay commits the site was built from.

Pages has no worker, so each `?type=` variant is its own file (`api-all.json`,
`api-embedding.json`, and so on); the v2 document lists every model by default.
A failed build leaves the previous deployment live, so Otari always has a catalog.

Pull requests to `otari` run the same build without the deploy.

## The drift check

`apply-overlay.sh` decides per overlay file `F`, with `U` upstream's copy and `B` the base:

| State | Meaning | Result |
|---|---|---|
| no `U`, no `B` | an addition | copied |
| `U` equals `F` | landed upstream | warning: delete `overlay/F` |
| `B` equals `U` | override still valid | copied, the overlay wins |
| `B` differs from `U` | upstream changed a file we override | **build fails**, names `F` |
| `U`, no `B`, differs from `F` | upstream has its own `F` | **build fails**, names `F` |

`apply-patches.sh` applies each patch that applies cleanly. A patch that applies
in reverse has landed upstream: the build warns `delete patches/<name>`. A patch
that does neither fails the build: delete it if upstream merged a changed version,
else rebase its `feat/<name>` branch on `dev` and regenerate it.

A failure means a person looks at the file once: re-check the override and run
`scripts/override.sh <path>` to refresh its base, or delete the override.

## Day to day

- **Add a model upstream lacks:** write `overlay/<path>.toml` (and its lab file under
  `overlay/models/<lab>/` when the provider file names a `base_model`), open a PR to
  `otari`. Upstream's `AGENTS.md` and `bun validate` are the rules.
- **Change a model upstream has:** `scripts/override.sh <path>`, edit `overlay/<path>`, PR.
- **Change upstream code:** commit on a `feat/<name>` branch cut from `dev`, open
  the upstream PR, and add `git format-patch -1 -U1 --stdout > patches/<name>.patch`
  to `otari` by PR. After the merge, delete the patch.
- **Send it upstream:** `scripts/contribute.sh <name> "<PR title>" <path>...`. Keep PRs
  small, one provider or model family each. After the merge, the next hourly run warns
  `landed upstream, delete overlay/<path>`; deleting it is the whole follow-up.

## Secrets

`UPSTREAM_SYNC_TOKEN`: a fine-grained personal access token on this repo with
**Contents: read and write** and **Workflows: read and write**. Set 2026-11-10,
expires 2027-11-10. Before it expires, replace it with an org-owned GitHub App
(same two permissions, an `actions/create-github-app-token` step, `APP_ID` and
`APP_PRIVATE_KEY` secrets), so the sync does not depend on one person's account.
