# IFX CI contract

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `4ff074f7b022b6e0ea6aa1914ce99ce7fd5757467c13e6ab2f9d2b2a0f0a3cfc`

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
