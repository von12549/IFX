# G01 LayerGuard policy checkpoint

Date: 2026-09-07

## Approved change

The architecture owner explicitly approved adding `IFX.BuildingBlocks.Application` to the
Application and RuntimeHost `allowedReferences` lists. This is the process-local transaction and
pipeline protocol required by G01-D16 through G01-D18; it does not expose a module DbContext,
repository, external contract, or cross-module transaction.

Because LayerGuard binds a migration baseline to the exact policy hash, the approval also covered
regenerating `mcp/LayerGuard/baselines/b0.5.json`. The regenerated baseline retains the same 116
historical findings, owner, 2026-12-31 expiry, and removal criteria. No G01 finding was added as
historical debt.

## Verification result

- LayerGuard tool tests: 178 passed, 0 failed.
- Verdict: `baseline-clean`.
- Historical findings matched: 116.
- New findings: 0.
- Stale findings: 0.
- G01 transaction guard: passed.

The machine-readable result is [`G01-layerguard-report.json`](G01-layerguard-report.json). The
policy is `src/layerguard.json`; the reviewed migration baseline is
`mcp/LayerGuard/baselines/b0.5.json`.
