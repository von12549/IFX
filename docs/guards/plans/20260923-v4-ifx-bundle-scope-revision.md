# V4 P10.1 — IFX bundle draft revision for scoped base

Status: `LOCAL 0.2.0 DRAFT VALIDATED — not ready for human acceptance`

Predecessors are `20260923-v4-ifx-bundle-candidate` and
`20260923-v4-target-scope-compatibility`. The user authorized TargetRoot scope repair
and subsequent local work. Preserve the earlier 0.1.0 draft as history; create a new
0.2.0 draft bound to the certified but **unpublished** 1.1.2 source/archive checkpoint.

The revision may raise the selected built-in Architecture Conformance minimum version
to 1.0.1 and record that the Profile's `src`/`tests` roots are now passed by Stage Host
and enforced by that adapter. Re-hash the same eight V3_ifx source authorities, maintain
an exact sorted bundle inventory, and validate the Profile, module configuration, base
identity and manifest. It must still mark G03/G04/G05 and other unmapped IFX claims as
blocking gaps. It adds no extension module or capability ceiling and cannot be
human-accepted for production or composed into an operational sibling.

Pass Formal Pre before edits, then exact Formal Diff. No 1.1.2 tag, GitHub Release,
installation, signed review, UI exercise, workflow or cutover is authorized by this
draft revision. Any later IFX gate implementation or acceptance requires an exact
new Plan/reviewed bytes.

## Draft checkpoint (2026-09-23)

The candidate `ifx-profile-candidate` version `0.2.0` has a two-file ordinal
inventory and targets local V4 base `1.1.2`. The exact base source commit is
`46d1a99fb34c92639d2a484612fab58195903a9d`, and the local archive SHA-256 is
`7a6d1582a695d9857149da185aa8b4209addce061ab4976bcc718fbbfdd5901b`.
The bundle manifest SHA-256 is
`081dc0dcd0e8484f34c651bf4688f84d2d001cf76a8e3f770aaffee7ea92d5b9`.
The source authority map binds snapshot commit
`6da8710aec951605c8c847cafafe51c537c5db70` and eight unchanged V3_ifx
source hashes. Five are still explicitly missing, with additional partial mappings.

The extension-bundle and Profile schemas, selected module configuration, local
base/module versions, source/archive hashes and exact file inventory passed static
validation. A temporary 1.1.2 package containing the added Profile passed the V4
package check, including registry/module selection and Profile contract validation.
A direct run of the selected `ARCH.GRAPH_COMPLETENESS` claim against
the actual IFX `TargetRoot`, scoped to `src` and `tests`, passed with 80 projects
matched and zero findings. This proves only that one selected claim on that scope;
it does not prove the missing IFX gates, Stage/UI behavior or production readiness.
The declared isolated `ifx-package-test` also passed with its positive and negative
cases after access to the existing NuGet configuration was granted for that test.

The published 1.1.1 release and sibling installation remain unchanged. The 1.1.2
base is not published, and there is no Xiaolong Feng acceptance record or operational
composition. P10.1 remains blocked on the missing detector/gate implementation and
separate review of the final bytes.
