# IFX guard system overview

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `79de6489b16113189857361386f577a1d9777b1e9a5dfaa8ec46c6b97eb0c1a9`

Sources:

- `docs/guards/V3_ifx/guard-system.json` — authority
- `docs/guards/V3_ifx/shared/commands.json` — command-contract
- `docs/guards/V3_ifx/stages/analysis/stage.json` — trust-contract
- `docs/guards/V3_ifx/stages/bootstrap/stage.json` — trust-contract
- `docs/guards/V3_ifx/stages/ci/stage.json` — trust-contract
- `docs/guards/V3_ifx/stages/diff/stage.json` — trust-contract
- `docs/guards/V3_ifx/stages/post/stage.json` — trust-contract
- `docs/guards/V3_ifx/stages/pre/stage.json` — trust-contract

Package `v3-ifx` is an `overlay` package using engine `docs/guards/V3`. Authority/configuration, generated candidates, activated copies and runtime evidence are distinct lifecycle layers.

| Stage | Enforcement | Execution class | Dependencies | Commands |
| --- | --- | --- | --- | --- |
| analysis | advisory | authoring | bootstrap | v3-setup, v3-architecture-review, ifx-analysis-evidence, ifx-refactor-baseline |
| bootstrap | advisory | authoring |  | v3-setup |
| ci | blocking | orchestration | pre, post, diff | ifx-guardrails, ifx-ci-contract, ifx-manifest-check, ifx-trusted-base, ifx-tcb-candidate |
| diff | blocking | gate | pre | ifx-guardrails, v3-runner, ifx-trusted-base-authorization |
| post | blocking | gate |  | ifx-guardrails, v3-runner, v3-docs, ifx-architecture, ifx-specialized, ifx-quality, ifx-historical-integrity, ifx-policy-sync, ifx-history-manifest |
| pre | advisory | authoring |  | ifx-guardrails, v3-runner, v3-docs |
