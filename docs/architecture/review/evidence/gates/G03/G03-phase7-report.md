# G03 Phase 7 waiver, LayerGuard, and CI handoff

The catalog now owns the 90-day waiver maximum, earlier named-milestone rule, new-review renewal,
required accountability fields, and six unwaivable categories: missing owner, missing consumer,
internal-model exposure, C4, unapproved C3, and identity reuse. Approved C3 state transfer is a
controlled admission, not a waiver. There are currently zero G03 waivers.

`Export-G03LayerGuardGovernance.ps1` deterministically derives module ownership, roles, four
provider/consumer adapter edges, the shared primitive project allowlist, dependency policy, and
waiver policy directly from the catalog. The generated handoff input carries the catalog SHA-256;
no ownership relationship is manually duplicated in LayerGuard configuration. The full compile-
time consumption remains Plan 03 L5.1 and is not falsely marked complete here.

The unified CI workflow runs the G03 catalog/source/snapshot/waiver/handoff guard followed by
LayerGuard and uploads both reports. Negative tests prove expired and unwaivable waivers, orphan
Active protocols, C4, duplicate identity, broken references, and invalid lifecycle fail.

Verification: Phase 7 guard and deterministic handoff passed; LayerGuard ran 179 tests and remained
B0.5 `baseline-clean`; solution build passed with 0 errors; all 904 solution tests passed.
