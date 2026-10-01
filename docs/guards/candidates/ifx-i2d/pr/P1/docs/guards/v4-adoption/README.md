# V4 Guards adoption in IFX

This directory is the one place in the protected history for IFX's adoption of V4 Guards. IFX is a **consumer**
of the V4 Guards product. The product source, releases and trusted-base CI live in the standalone repository
[`von12549/Guard`](https://github.com/von12549/Guard).

V3 decision `20261001-v4-ifx-i2c-v4-adoption-admission` admits this entry as the only top-level `docs/guards` entry
besides `plans`, `V3` and `V3_ifx` (`V3_ifx/tests/ci/Test-CutoverPreservation.ps1`). V3 keeps owning every V3 path,
workflow and required context, and no V3 verdict reads this directory.

## Published package (IFX I2-D)

The trusted inputs of the inactive V4 workflow, published byte-identical to their reviewed sources:

| Path | Content |
| --- | --- |
| `extensions/ifx/0.5.2/bundle/` | The exact `ifx_profile` 0.5.2 bundle for V4 Guards 1.1.6 (manifest SHA-256 `a2f619a3…`), certified by C6c and accepted by human review |
| `extensions/ifx/0.5.2/production-extension-review.json` | Its accepted production review record (`38eb775a…`) |
| `producers/` | The V4-native evidence producers; each lock consumer pins its producer's script SHA-256. `origins.json` records where each file came from |
| `ci/` | What the workflow runs from the trusted base: the staging script `Invoke-IFXEvidenceProducers.ps1` and the aggregate `Invoke-IFXV4Aggregate.ps1` |
| `integrations/github/` | The inactive workflow specimen and the inactive cutover proposal |
| `migration/` | The receipts of the adoption steps (T7, T8, I1, I2-B A1-A3, I2-C) |

The workflow reads the bundle, the review and `ci/` from the pull request **base**, never from the candidate. A
pull request that changes them takes effect only after it is merged.

Nothing here is active. Installing the workflow (I2-E), adding `v4-ifx-required` to the ruleset (I2-F), the
coexistence window and P10.GATE (I2-G), cutover and V3 retirement each need their own exact Plan and authorization.

The adoption lab — candidate harnesses, inventories, certification artifacts, the design notes and the IFX V4 backlog
(`docs/guards/TODO.md`) — stays on the development branch `codex/v4-development-base` and is referenced by commit.
