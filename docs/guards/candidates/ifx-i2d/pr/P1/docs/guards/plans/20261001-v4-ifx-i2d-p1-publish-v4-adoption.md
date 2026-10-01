# Publish the curated V4 Guards adoption package

Formal V3 plan for the publication pull request of IFX I2-D (Plan `20261001-v4-ifx-i2d-publish-trusted-inputs` on the
development branch `codex/v4-development-base`; operator decision 2B of the IFX I2 program).

`docs/guards/v4-adoption` was admitted by decision `20261001-v4-ifx-i2c-v4-adoption-admission` and so far holds only its
README. This pull request publishes the trusted inputs of the inactive V4 workflow. Every file is byte-identical to its
source blob on the development branch at `2c82d6e8`, except the README, which is its `main` edition:

| Directory | Files | Content |
| --- | --- | --- |
| `extensions/ifx/0.5.2/` | 264 | the exact `ifx_profile` 0.5.2 bundle (manifest `a2f619a3…`, certified by C6c, accepted by human review) and its production review `38eb775a…` |
| `producers/` | 23 | the V4-native evidence producers, pinned by the lock consumers, with `origins.json` |
| `ci/` | 2 | the staging script and the aggregate the workflow runs from the trusted base |
| `integrations/github/` | 2 | the inactive workflow specimen and the inactive cutover proposal |
| `migration/` | 7 | the adoption receipts |

Nothing is activated: no workflow is installed, no required context or ruleset changes, and no V3 path changes.
`docs/guards/v4-adoption` is not a V3 protected path, so the change carries no protected-change obligation. The
`guard-rules` risk of these paths is covered by the admission decision.
