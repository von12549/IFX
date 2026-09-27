# V4 P10.3 trusted-base cutover and rollback design

Status: authorized planning and local rehearsal

## Authorization and boundary

The user explicitly authorized P10.3 on 2026-09-27. This authorizes the
documentation, inactive workflow specimen, read-only local/remote inventory
and local rollback rehearsal required by P10.3. It does **not** authorize
creating or modifying a live GitHub workflow, required check, ruleset,
protected/default branch, release asset or secret; it does not perform IFX
cutover or retire V3/V3_ifx.

## Entry authority

P10.3 may proceed only while all of these exact records remain valid:

- P10.1 C6e-R1 decision:
  `artifacts/guards/p10-ifx-114/c6e-r1-042/c6e-r1-decision.json`, SHA-256
  `94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`;
- P10.2-R2 parity decision:
  `artifacts/guards/p10-ifx-114/p10-2-r2-parity-042/p10-2-decision.json`,
  SHA-256
  `7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516`;
- C6c 1.1.4/0.4.2 certification decision:
  `artifacts/guards/p10-ifx-114/recovery-042/c6c-decision.json`, SHA-256
  `33a72d199144b1914d6d30c9f355b653aeb455fcebdd7e0143851344f995683c`;
- Windows-full exact-baseline report:
  `artifacts/guards/p10-ifx-114/c6c-recovery-042-full/windows/summary.json`,
  SHA-256
  `858b69949c0febc386557f8bb70287d2abe3a7c2af56e6f5aa20b2fbc7de9ff8`.

They bind V4 Guards 1.1.4, `ifx_profile` 0.4.2, target commit
`40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`, Package hash
`739e2035b24f42a0d09719bd78d010de9320452086109fbdd95c064f67e5a6c1`
and the accepted zero-gap 52-case parity decision. Any mismatch stops P10.3.

## Goal

Produce an evidence-bound, inactive cutover and rollback proposal for moving
IFX required verdict ownership from the active V3/V3_ifx guard to the exact
receipted V4 + `ifx_profile` baseline. Define a coexistence window, stable
always-present aggregate verdict, Architecture Conformance ownership mapping,
artifact/permission model, one-time bridge expiry, rollback triggers and exact
remote reversal order. Prove the state transitions locally without mutating
GitHub or an authority root.

## Design requirements

1. Inventory the checked-in V3 workflow/required-check contract and the live
   repository default branch, workflows and ruleset using GET-only GitHub API
   operations. Record drift rather than correcting it.
2. Keep the existing V3 13-check ruleset fully required during coexistence.
   A future activation tranche may add one V4 aggregate context only after a
   successful negative-control PR proves that it always appears and blocks.
3. The inactive V4 IFX workflow specimen uses a previously trusted base,
   read-only permissions, no repository secrets, immutable archive/bundle
   hashes and external StateRoot/EvidenceRoot. The candidate under review
   never supplies its own verdict authority.
4. The machine-readable proposal maps every V3 required context and
   Architecture Conformance detector family to its V4 owner or explicit
   coexistence-only owner. No detector family may be silently dropped.
5. Rollback restores the pre-cutover workflow/ruleset snapshot and the exact
   prior trusted source revision before removing any V4 required context.
   V3/V3_ifx remains present throughout P10.3 and the coexistence proposal.
6. The accepted IFX bundle is not currently a tracked remote-consumable
   release input. The proposal must treat immutable bundle publication as a
   separately authorized prerequisite, never fetch mutable working evidence.

## Execution sequence

1. Validate and commit this Plan pair before implementation.
2. Pass Formal Pre and verify all four entry records and their shared identity.
3. Capture the checked-in and live GitHub state read-only; stop on an
   unclassified identity or permission discrepancy.
4. Create the machine-readable transition proposal and inactive workflow
   specimen outside `.github/workflows`.
5. Implement a local verifier/rehearsal that checks identities, permissions,
   context continuity, detector ownership, bridge expiry and both forward and
   rollback transition order without network writes.
6. Record the rehearsal and final P10.3 decision under a new evidence root.
7. If accepted, update the maintained P10 plans as design-complete while
   leaving P10.GATE, activation, cutover and V3 retirement false.

## Acceptance criteria

- all P10.1, P10.2 and Windows-full identities match the same 1.1.4/0.4.2
  baseline and target commit;
- the read-only remote snapshot is explicit, reproducible and compared with
  the checked-in V3 contract;
- every current V3 required context and Architecture Conformance family has
  an explicit coexistence and final owner;
- the inactive specimen has an always-present aggregate, least privileges,
  immutable inputs, trusted-base execution and fail-closed artifact flow;
- forward/coexistence/primary/rollback transitions pass locally, including
  rollback-trigger negative controls and exact restoration order;
- immutable P10.1/P10.2 evidence, installations, bundles and Targets remain
  byte-identical; and
- no live workflow, ruleset, required check, branch setting, release, secret,
  activation, cutover or V3 retirement is changed.

## Stop conditions

Stop on entry hash drift, live/declared ruleset mismatch, missing required
context mapping, candidate self-judgment, mutable or unavailable bundle input,
permission broadening, secret dependency, missing aggregate verdict, rollback
that removes V3 before restoration proof, authority-root writes or any need for
a remote mutation. A stopped result is evidence; it is not permission to repair
or activate in place.

