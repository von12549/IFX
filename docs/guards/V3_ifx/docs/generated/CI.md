# IFX CI contract

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `5ba437bd13daa7fe1596eb957f288b7831a0814a5d2918fa1335084a84641fe5`

Sources:

- `.github/workflows/v3-ifx-guardrails.yml` — ci-contract
- `docs/guards/V3_ifx/shared/commands.json` — command-contract
- `docs/guards/V3_ifx/stages/ci/required-checks.json` — ci-contract
- `docs/guards/V3_ifx/stages/ci/stage.json` — trust-contract

Workflow: `.github/workflows/v3-ifx-guardrails.yml`. Merge enforcement: github-ruleset-required-checks. Ruleset strict: True. Trusted-base execution: active.

| Required check | Mode | Gate | Trigger | Blocking |
| --- | --- | --- | --- | --- |
| v3-pre-diff | diff |  | pull-request | True |
| v3-architecture | architecture |  | pull-request-and-main | True |
| v3-specialized-g03 | specialized | g03 | pull-request-and-main | True |
| v3-specialized-g04 | specialized | g04 | pull-request-and-main | True |
| v3-specialized-g05 | specialized | g05 | pull-request-and-main | True |
| v3-specialized-plan04 | specialized | plan04 | pull-request-and-main | True |
| v3-specialized-database | specialized | database | pull-request-and-main | True |
| v3-quality-solution | quality | solution | pull-request-and-main | True |
| v3-quality-assembly | quality | assembly | pull-request-and-main | True |
| v3-quality-frontend | quality | frontend | pull-request-and-main | True |
| v3-historical-integrity | historical-integrity |  | pull-request-and-main | True |
| v3-cross-platform-ubuntu-latest | validate |  | pull-request-and-main | True |
| v3-cross-platform-windows-latest | validate |  | pull-request-and-main | True |

CI Stage dependencies: pre, post, diff.
