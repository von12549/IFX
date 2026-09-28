# IFX guard adoption backlog

This file is the IFX authority for guard work that IFX owns as a **consumer** of V4 Guards. The V4 Guards
product backlog (V4-TODO-005 onward, except the IFX side of V4-TODO-008) lives in the product repository:
[`von12549/Guard` `docs/plans/product/TODO.md`](https://github.com/von12549/Guard/blob/main/docs/plans/product/TODO.md).
A checked item requires a separate reviewed decision and formal Plan; appearing here is not
implementation authorization.

Origin: on 2026-09-28, before V4-TODO-008 T8 removes `docs/guards/v4`, the IFX-owned items of
`docs/guards/v4/plans/TODO.md` were moved here with their text preserved. The Guard-owned items of that
file were compared with the Guard product TODO; Guard already contains all of them word for word or in a
newer form, so nothing was lost. The identifiers V4-TODO-001 to V4-TODO-004 stay reserved for these IFX
items and are not reused in Guard. New IFX items use the `IFX-V4-` prefix.

Adoption records: [`v4-adoption/`](v4-adoption/README.md). Plan paths below that point to
`docs/guards/v4/plans/06–09` now live in `docs/guards/v4-adoption/plans/`.

## V4 adoption (moved from `docs/guards/v4/plans/TODO.md`)

- [x] **V4-TODO-001 — `ifx_profile` practice**

  Revisit after V4-P8. Package current IFX project map, toolchain, policies, baselines and selected
  specialized gates through the published profile/extension API. Treat any required V4 core change as
  an explicit compatibility decision. Do not make V4 v1 release depend on this practice.

  Planning is active under `20260923-v4-ifx-profile-validation-program` / V4-P10. The released 1.1.0
  package is the immutable entry baseline. Because 1.1.0 has no implemented package-external Profile
  installer, P10.0/P10.1 must not edit the installed package; a required composition/loader change is
  handled as the next certified `1.1.x` patch.

  P10.0 local baseline and installed Web UI practice passed on 2026-09-23; see
  `07-p10-0-baseline-acceptance.md`. The separate P10.1 entry-gap compatibility Plan is
  `20260923-v4-p10-extension-composition-compatibility` /
  `08-p10-1-extension-composition-compatibility.md`. P10.1 completed on 2026-09-27 when C6e-R1
  accepted the reviewed IFX 0.4.2 bundle against V4 Guards 1.1.4, including installed-Web-UI clean
  and blocking-violation evidence. Binding decision SHA-256:
  `94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`.

  V4-TODO-008 T7 successor (2026-09-28): the successor bundle `ifx-profile-candidate` 0.4.3 was
  certified, human-reviewed and composed on V4 Guards 1.1.5 from `von12549/Guard` (R3–R5 of Plan
  `20260928-v4-todo-008-t7-ifx-consumer-rebinding`; R5 decision `b9916376…`). The installed Web UI
  record for 1.1.5 + 0.4.3 is IFX-V4-001.

- [x] **V4-TODO-002 — IFX parallel parity**

  Revisit after V4-TODO-001. Run V3/V3_ifx and V4+`ifx_profile` against the same fixed corpus and real
  repository commit. Compare blocking verdicts, failure categories, reports, policy hashes, runtime
  prerequisites and every Architecture Conformance claim/evidence kind without activating V4. Include
  clean, deliberate-violation, missing-input and zero-match controls.

  P10.2-R2 completed and was accepted on 2026-09-27. The frozen 52-case matrix closed with zero gaps
  and 15 explicit V4 fail-closed strengthenings while the reference, installation, bundle, C6c corpus
  and Targets remained unchanged. Binding decision SHA-256:
  `7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516`.

  T7 successor (2026-09-28): replayed for 1.1.5 + 0.4.3 with 52/52 cases, zero gaps and the same 15
  strengthenings, semantically identical to R2 row by row (decision `443ffdfe…`).

- [x] **V4-TODO-003 — IFX cutover and rollback design**

  Revisit only after parity and a Windows full certification. Define trusted-base activation, GitHub
  required contexts, Architecture Conformance detector-family cutover, recovery, one-time compatibility
  bridges and exact rollback. Remote changes need separate authorization.

  Completed as V4-P10.3 design-only work on 2026-09-27. The inactive proposal, context/detector
  ownership map, coexistence topology, five negative controls and V3-first rollback rehearsal were
  accepted by decision SHA-256
  `529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964`.
  No workflow, required context, ruleset or cutover was activated; those remote mutations retain a
  separate exact Plan and explicit authorization boundary, and P10.GATE remains open.

  T7 successor (2026-09-28): `v4-adoption/plans/10-p10-3-successor-standalone-1-1-5.md`. The inactive
  specimen fetches V4 only from `von12549/Guard` with the archive SHA-256 pinned; the rehearsal passed
  with seven executed negative controls (decision `c2e432bd…`).

- [ ] **V4-TODO-004 — V3/V3_ifx freeze or retirement**

  Revisit only after a stable V4 IFX cutover. Decide whether the old packages remain frozen historical
  sources or are removed through protected deletion. LayerGuard-derived source removal is the last
  migration action. Preserve Plan 06 evidence either way and close Plan 06 §20 only after this item.

- [ ] **V4-TODO-008 (IFX side) — Standalone V4 repository**

  The product side is tracked in Guard. IFX's part: rebind IFX as a consumer (T7) and remove the
  duplicated product source (T8) only after that consumer gate.

  - T7 is done (2026-09-28): IFX consumes V4 Guards 1.1.5 from `von12549/Guard`
    (receipt `v4-adoption/migration/v4-todo-008-ifx-rebinding-receipt.json`).
  - Remaining: T8, the protected removal of `docs/guards/v4` (A-IFX-DELETE), under its own Plan and
    authorization.

## Items found during V4-TODO-008 T7

- [ ] **IFX-V4-001 — P10.GATE successor for V4 Guards 1.1.5 + `ifx_profile` 0.4.3**

  P10.GATE stays open. Before V4 can protect IFX:

  - record the installed Web UI hands-on run (clean and blocking cases) for the exact 1.1.5 + 0.4.3
    installation, as `v4-adoption/plans/06-ifx-profile-validation-program.md` §8 requires;
  - clear the activation prerequisites listed in
    `v4-adoption/integrations/github/ifx-cutover-proposal.json`:
    - promote the reviewed V3 workflow and P10 evidence to the default branch;
    - publish the exact 0.4.3 bundle as a trusted input under
      `docs/guards/v4-adoption/extensions/ifx/0.4.3`;
    - install and negative-test the V4 IFX workflow;
    - add `v4-ifx-required` to the ruleset;
    - complete the coexistence window before removing any V3 context.

  Each prerequisite needs its own exact Plan and authorization. This also covers IFX's own protection
  of its Profile, bundle, review records and workflow (see Guard V4-TODO-015).

- [ ] **IFX-V4-002 — Linux timeout of `ifx-database-evidence` (Guard checklist O20)**

  In the pinned Linux container, the `ifx-database-evidence` module of bundle 0.4.3 needs 73–85 s
  against its declared 60 s timeout (reproduced 3/3 in isolation; files are read over a Windows bind
  mount). The workload and module bytes are identical to 0.4.2, whose Linux direct-post passed. Windows,
  the IFX product platform, passes. Linux stays a non-blocking advisory, and the V3 Linux bridge
  (`v3-cross-platform-ubuntu-latest`) stays required.

  Measure the module on native Linux storage, then raise or platform-scale its timeout in a later bundle
  version under its own Plan. Evidence: `artifacts/guards/p10-ifx-115/c6d-review-043/linux-diagnostic-summary.json`.
