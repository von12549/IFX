# G03 -> Plan 03 LayerGuard policy-binding handoff

## Accountability and revisit

- Recorded accountable owner: `xiaolong-feng` / repository handle `@von12549`, acting for the
  catalog and repository-maintainer roles.
- Delivery owner: Plan 03 L5.1 implementer, approved by the accountable owner. Junxi /
  `@jimkeecn` is the authorized backup owner recorded by G03.
- Revisit trigger: immediately when Plan 03 L5.1 begins, again after Plan 01 (B2) and Plan 02 (B3),
  and before strict B4/zero-unwaived-debt mode is enabled.

## Authoritative inputs

- [`contract-event-catalog.yaml`](../contract-event-catalog.yaml) is the only editable governance
  source.
- [`layerguard-governance-input.json`](../generated/layerguard-governance-input.json) is a
  deterministic generated view containing the catalog SHA-256, not a second authority.
- `scripts/Export-G03LayerGuardGovernance.ps1` generates the view and
  `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate G03` rejects drift.

The handoff includes module ownership/roles, four admitted provider-consumer Adapter edges, the
shared primitive projects, default BCL-only dependencies, forbidden runtime/framework types, waiver
expiry, and unwaivable categories.

## Required implementation and returned evidence

1. Make LayerGuard L5.1 directly load the catalog or verify and consume the generated view plus its
   catalog hash. Do not duplicate ownership or Adapter allowlists in `layerguard.json`.
2. Fail closed for an unreadable/unknown catalog, unknown role, unregistered provider edge, runtime
   leakage, new Abstractions, expired waiver, and every unwaivable category.
3. Preserve separation of checks: LayerGuard checks static dependency/declaration boundaries;
   G03/G05 validators and behavior tests check fields, runtime values, security, and compatibility.
4. Save B1 after Gate policy binding, B2 after Contracts migration, B3 after Events migration, and
   compare B4 under the same target semantics before enabling strict CI.
5. Return positive/negative fixtures, report links, catalog hash, and proof that G03 CI and the main
   LayerGuard workflow cannot silently skip a scan failure.

## 03-A1 return — 2026-09-08

Plan 03 L5.1 returned direct generated-view/catalog reconciliation, catalog hash verification,
provider projection and backup-owner checks, Gate-bound positive/negative tests, B1 and CI evidence:
[`03-a1-layerguard-policy-binding.md`](../../../evidence/03-a1-layerguard-policy-binding.md). G03-DD07
is now satisfied. G03 remains PRE-READY because physical V1 sources, Active provider/consumer
evidence, Messaging runtime separation, B2/B3 and final multi-role approvals remain open.
