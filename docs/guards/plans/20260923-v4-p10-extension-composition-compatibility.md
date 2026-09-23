# V4 P10.1 entry — extension composition compatibility Plan

Status: `WINDOWS + OFFLINE LINUX SYNTHETIC PROTOTYPE PASS — certification pending; release not authorized`

Predecessor: `20260923-v4-ifx-profile-validation-program` and P10.0 operator evidence in
`docs/guards/v4/plans/07-p10-0-baseline-acceptance.md`.

Durable design and gates: `docs/guards/v4/plans/08-p10-1-extension-composition-compatibility.md`.

## Goal

Add a public, deterministic, receipted, offline local-extension composition boundary to the
next unique V4 Guards `1.1.x` source baseline. This closes the installation/identity gap that
currently prevents a separately reviewed `ifx_profile` and declared extension modules from
being practiced without modifying the published 1.1.0 installation.

## Scope and ordering

1. Use the recorded H1–H4 `A` selections and `human-review` authority
   `xiaolong-feng`. The JSON pair now declares exact prototype source, contract and test paths.
   Pass Formal Pre on this revision before editing those source paths.
2. Implement bundle/receipt schemas, an explicit local composer and receipt verifier, and
   installed-launcher enforcement. Prefer standard Host-consumable composed PackageRoots over a
   parallel loader. Keep browser input, IFX policy and remote access out of the composer.
3. Prove synthetic positive/negative matrix, output determinism, root immutability and consistent
   Host/query/Web Companion behavior on Windows and network-disabled Linux.
4. After the prototype passes, amend or create an exact candidate-version Plan for `plugin.json`,
   Host/Companion versions, compatibility baseline, CI test hash bindings and fixed-version tests.
   Release publication, actual `ifx_profile` composition, IFX Stage/UI practice and parity each
   require their later gates; none is completed by this Plan.

## Acceptance and evidence

- 1.1.0 archive, PackageRoot and external receipt remain byte-identical to P10.0 evidence.
- A base installation and explicit reviewed bundle reproduce the same composed package hash and
  full-file inventory on both supported platforms, independent of output path.
- H1–H4 selections and the eligible bundle-review authority are recorded. Each real bundle
  requires its own later hash- and capability-bound human acceptance record; candidate V4
  output cannot approve itself.
- The external composition receipt binds both provenance layers and its read-only verifier rejects
  modified, missing or extra output files before P10 execution.
- Package Check, prerequisites, Host Stage/query projections and installed Web Companion operate
  against the composed synthetic installation with no second verdict authority.
- All malicious/invalid inputs in the durable design fail before promotion; no PackageRoot or
  TargetRoot writes, auto-discovery, download or remote installation occur.
- Formal Pre, exact Diff and the full V4 platform/lifecycle/compatibility suites pass before any
  release-publication proposal.

## Current planning validation

The initial documentation-only pair passed the V3 formal Plan schema and Formal Pre advisory.
This revision froze 18 local synthetic prototype paths. Formal Pre returned `advisory`, zero
unmapped paths, before source edits; report: `artifacts/guards/p10-extension-composition-pre.json`.
The Windows and network-disabled Linux synthetic tests now pass two deterministic compositions, standard Host
Profile/doctor/Stage/runs/evidence operations, receipted Companion session/readiness projections,
immutable base and TargetRoot checks, and selected fail-closed cases. Evidence:
Windows `artifacts/guards/p10-composition/20260923T073359Z-52950e3d7d894ec6888eacc311a68991/summary.json`;
Linux `artifacts/guards/p10-composition/linux-final/20260923T073443Z-0999f84e85a8465eadc2d1b1a5ec48df/summary.json`.
The composed Package hash is `dd6cea9679ed25966b563dea7544b62c6f74aab8f609496ec3447cce5cfbf336`, and all 134 ordinally sorted output-file inventory rows match across platforms. The expanded
negative matrix passed 24 Windows rejection cases and 25 offline Linux cases; Windows could not
create the symbolic-link fixture, while Linux verified its rejection. Both platforms passed a
real child-process kill during owned staging, a same-input retry that preserved the orphan, and
refusal of a simulated promoted output lacking its external receipt. The composed installation
also rejected a project-model zero-match control (`matched=0`, `minimum=1`) with
`prerequisite-missing`. Other IFX detector-family zero-match controls, installed-patch launcher
proof, exact Diff and full platform certification have not yet passed.
An internal base-receipt copy was found to make full-file inventories path-dependent across
platforms. The durable Plan now keeps that receipt external and requires its exact hash in the
external composition receipt, with both receipts supplied for verification. This correction
uses the same 18 planned paths; refreshed Formal Pre and both platform reruns passed.
The expanded Linux matrix later found culture-dependent ordering of otherwise identical
receipt inventory rows. The composer now uses ordinal sorting for generated registry and
inventory bytes; refreshed Formal Pre and both platform reruns passed with identical ordered
inventories. The verifier rejects non-ordinal receipt inventories.
Earlier P10.0 documentation changes remain in the same working tree and are not silently
claimed as part of this Plan's `plannedPaths`.

## Recovery and exclusions

An incomplete staged composition may be removed only after its exact path and ownership are
verified. A promoted composed installation is never repaired in place; produce a new sibling
identity or return to the prior receipted installation. No GitHub workflow/ruleset change,
required-check promotion, IFX cutover or V3 retirement is authorized.
