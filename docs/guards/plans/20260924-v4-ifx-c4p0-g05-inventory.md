# V4 P10.1 C4p0 — G05 Phase 0 independent inventory

Status: `CANDIDATE VERIFIED — remaining C4 work pending`

Translate all 13 G05 Phase 0 inventory checks into a read-only V4 Post
candidate on published 1.1.3. The V3 inventory generator and report are
reference facts, not executable V4 runtime or standing current-state truth.
Create a fresh, deterministic source-location inventory in the adapter,
including current HTTP, identity, protocol, event, logging and error surfaces.
Lock and validate the historic identity/findings record separately from the
current source census; a historical identifier must not be represented as
current implementation. Require nonempty current subjects, exact reviewed
authority hashes and no runtime value collection.

Fail closed on absent/stale authority, malformed configuration, missing or
zero source subjects and deliberate semantic mutations. Validate module,
policy, rule and dependency locks; direct adapter and published 1.1.3 Host
Post; immutable TargetRoot and PackageRoot. No production Profile, security
approval, G05 closure or C4 overall completion is inferred. Formal Pre must
precede executable edits; exact Diff and isolated package regression follow.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c4p0/formal-pre/summary-pre.json`.
The 13 Phase 0 check IDs map exactly to one blocking V4 Post rule, with a
fresh source-location census separated from the locked historical inventory.
Real IFX and published 1.1.3 synthetic Host Post each matched 1,031 current
C# source files. Clean, removed-Outbox, zero-source, missing-authority and
stale-authority controls and TargetRoot/PackageRoot invariance passed at
`artifacts/guards/p10-ifx-c4p0/test-runs/f99f37ab2ed54c66aeb4cb5fe49112f6/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-fdbb3928b78b4fe99919462cc23e2e2d`.
Exact Formal Diff passed at `artifacts/guards/p10-ifx-c4p0/formal-diff/summary-diff.json`. This verifies Phase 0 candidate
coverage only, not G05 security, Plan04, Database or overall C4 closure.
