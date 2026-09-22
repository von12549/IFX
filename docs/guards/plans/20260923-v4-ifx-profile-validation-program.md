# V4 P10 — IFX Profile validation program planning

Status: planning authorized after V4 Guards 1.1.0 publication. This Plan defines checkpoints and
test topology only; it does not install `ifx_profile`, run parity, create `guard/`, publish a patch,
activate a workflow/ruleset or perform IFX cutover.

Predecessor: `20260923-v4-v1-1-release-publication`

Durable roadmap: `docs/guards/v4/plans/06-ifx-profile-validation-program.md`

## Goal

Turn V4-TODO-001, V4-TODO-002 and V4-TODO-003 into a fail-closed validation program that starts from
the immutable V4 Guards 1.1.0 release, practices an IFX Profile through public V4 contracts, compares it
with the active V3/V3_ifx reference on one fixed corpus, and produces a cutover/rollback design without
performing remote activation.

## Confirmed 1.1.0 constraint

V4 1.1.0 loads Profiles only from `PackageRoot/profiles/catalog`, loads modules only from the declared
package registry and includes those bytes in the package hash. It has no implemented package-external
Profile/extension install or composition command. Therefore the released installation must not be
edited to inject `ifx_profile`.

P10.0 must first prove the released baseline unchanged. P10.1 may proceed only through an existing
declared composition path or, if none exists, through a separately planned V4 compatibility patch in
the `1.1.x` line. A copied, hand-edited 1.1.0 package is not admissible test evidence.

## Planned topology

- Canonical source authority: `D:\IFX\docs\guards\v4` in the current repository. All V4 fixes are
  authored, reviewed and certified here first.
- Read-only target under test: `D:\IFX` at an explicitly recorded Git commit.
- Released installation root: `D:\IFX\guard\releases\v4-guards-1.1.0`, extracted from the GitHub
  Release only after verifying archive SHA-256
  `d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd` and its distribution receipt.
- Later patch installations: sibling versioned directories such as
  `D:\IFX\guard\releases\v4-guards-1.1.1`; never overwrite or hot-patch an earlier installation.
- Mutable StateRoot: `D:\IFX.guard-runtime\state`.
- Mutable EvidenceRoot: `D:\IFX.guard-runtime\evidence`.

StateRoot and EvidenceRoot are deliberately outside `D:\IFX`, because V4 rejects mutable roots that
overlap PackageRoot or TargetRoot. PackageRoot may reside below TargetRoot, but `ifx_profile` must
explicitly exclude `guard/**` from project discovery and prove that the installed guard cannot enter
its own target evidence.

## Checkpoints

1. **P10.0 — Baseline installation and topology proof.** Create the ignored `guard/` hierarchy,
   download or copy only the published assets, verify tag/archive/package/receipt provenance, prove
   `version`, package check, prerequisites, read-only TargetRoot and external mutable roots, and record
   that unmodified 1.1.0 exposes only its released Profiles.
2. **P10.1 — V4-TODO-001 IFX Profile practice.** Inventory current IFX project map, toolchain,
   policies, baselines and specialized gates; map each item to Profile configuration or a declared
   extension module; implement only through public schema/capability contracts. Any required Host,
   schema, loader, installer or built-in module change stops the checkpoint and becomes an explicit
   compatibility Plan and next `1.1.x` patch release.
3. **P10.2 — V4-TODO-002 parallel parity.** Freeze one IFX commit and one test corpus. Run the active
   V3/V3_ifx reference and V4 plus `ifx_profile` independently against clean, deliberate-violation,
   missing-input and zero-match controls. Compare blocking verdicts, exit/failure categories, reports,
   policy and authority hashes, prerequisites, and every Architecture Conformance claim/evidence kind.
4. **P10.3 — V4-TODO-003 cutover/rollback design.** Only after P10.2 and a full Windows certification,
   define trusted-base selection, candidate self-judgment prevention, required contexts, workflow and
   ruleset transition, detector-family ownership, compatibility bridges, rollback trigger and exact
   restore procedure. This checkpoint produces a reviewed proposal only.
5. **P10.GATE — adoption readiness.** Require all evidence above, a clean newly installed latest
   `1.1.x` baseline, no V3 runtime dependency in V4, no unresolved parity gaps and a rehearsed local
   rollback. Remote workflow/ruleset mutation and IFX cutover require a later exact Plan and separate
   explicit authorization.

## Version and defect policy

- V4 1.1.0 remains immutable as the initial comparison baseline.
- Every correction discovered by this program that changes the V4 distributed test baseline uses the
  next unique `1.1.x` product/Host/Companion release, full package certification and a fresh install.
- `ifx_profile` may retain its own component version, but every validated combination records both the
  V4 release and Profile version; no Profile edit silently reuses an earlier evidence label.
- A failure is first reproduced under `guard/`, then fixed only in canonical source, tested and
  certified there, published, and installed into a new versioned directory. The installed copy is never
  the source of truth.
- Policy mismatch, missing coverage and zero-match results are failures to investigate, not baselines
  to accept automatically.

## Validation for this planning checkpoint

1. Formal Pre accepts this Plan pair and all exact documentation paths.
2. Exact Diff contains planning authorities only and leaves the certified V4 package hash unchanged.
3. The durable roadmap records the confirmed external-extension gap, root topology, checkpoints,
   version policy, evidence matrix and authorization boundary.
4. TODO-001/002/003 remain unchecked but point to P10 as active planning; no completion is claimed.
5. V3 Validate and isolated V4 package validation still pass.

## Recovery

Revert this documentation-only checkpoint. The published 1.1.0 tag, Release and package remain
unchanged. No `guard/` installation, mutable test state, Profile authority, remote workflow, ruleset or
cutover state is created by this Plan.
