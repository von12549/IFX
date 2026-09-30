# G03 current documentation and the retired-Auth reference scan

Formal V3 plan for the second pull request of IFX I2-C (Plan `20261001-v4-ifx-i2c-main-promotion`, step C6 on the
development branch `codex/v4-development-base`).

The development branch changed six non-lab files that never passed through V3, because V3 CI is structurally red on
that branch. They reach the protected history here, byte-identical:

- `contract-event-governance.en.md` and `.zh-CN.md` still carried four-protocol, all-Proposed prose from the Phase 9
  baseline. They now describe the current catalog (six protocols, four Active, two Proposed; all 46 legacy public
  surfaces Retired) and add a catalog-reconciled protocol table.
- `G03-closeout.md` separates a current readiness checkpoint (`closureStatus=pre-ready`, `readyForClosure=false`, three
  blocker codes with owners) from the historical 2026-09-08 evidence. It grants no closure approval.
- Decision `20260924-v4-ifx-c2d-g03-current-documentation` records the scope of that correction and is registered in
  the `decision-history` entry of `shared/policy-config.json`.
- `Plan06DependencyBoundaryTests` scans project references under `src`, `tests` and `tools` only, instead of every
  `*.csproj` in the repository, so that fixture projects outside the product cannot trip the retired-Auth assertion.
  The assertion itself is unchanged.

Catalog authority, protocol lifecycle, approval checkboxes and recorded historical evidence are unchanged (D18 roles).
`policy-config.json` is a trusted component, and registering a decision changes the `trust-meta-policy` decision
history. The pull request therefore consumes two base records, merged alone in the preceding authorization pull
request: `i2c-g03-documentation-trusted-base` (`change-trusted-base`; parity: the registry gains exactly this one entry)
and `i2c-g03-documentation-policy` (`weaken-policy`).
