# V4 P10.1 — IFX TargetRoot scan-scope compatibility

Status: `AUTHORIZED FOR LOCAL IMPLEMENTATION — patch publication not authorized`

The user confirmed that the affected root is `D:\IFX-Root\IFX` as V4 `TargetRoot` and
authorized scope-compatibility repair and subsequent local follow-up. The published
1.1.1 tag, archive and installation remain immutable. This Plan prepares a distinct
1.1.2 local candidate; it does not authorize a new remote release, IFX bundle acceptance,
composition into an operational sibling, UI practice, workflow changes or cutover.

## Defect and compatible contract

The Profile schema already provides `projectIdentity.relativeRoots`, but Stage Host drops
it from the adapter input. Architecture Conformance then enumerates all projects and C#
sources beneath `TargetRoot`. The IFX draft's proposed `src` and `tests` roots therefore
do not exclude `docs/guards/v4`, and its current claim coverage is not trustworthy.

Pass the schema-validated Profile roots from Stage Host to module input. For the
Architecture Conformance adapter, an omitted/empty list or sole `.` retains the legacy
whole-TargetRoot behavior needed by existing Profiles and direct tests. Otherwise require
nonempty, existing directories strictly beneath TargetRoot, reject absolute paths,
traversal, links, case-collisions and overlapping roots, and scan only their union in
ordinal order. A project reference from an included project to a file outside the
declared union must fail the graph-completeness claim rather than silently escape scope.
Keep the complete TargetRoot integrity snapshot used for build evidence unless a separate
reviewed change proves an equivalent scoped integrity contract.

## Validation and boundaries

Add positive and negative direct/Host tests: IFX-like `src`/`tests` inputs, excluded
guard source, missing roots, traversal/absolute/link roots, overlap/case collision and
out-of-scope project references. Keep existing broad-root Profile behavior and all root
immutability checks. Refresh only the affected Package/CI hash bindings and explicit
1.1.2 version assertions, then run the relevant suites, Windows-full and pinned offline
Linux-complete on a clean source commit before any release proposal. Record exact Formal
Pre and Diff. The candidate IFX bundle must be revised for the new base only after the
source checkpoint is frozen, and still cannot be accepted until the missing IFX detector
families and specialized gates are addressed.

Stop on any need to edit 1.1.1 installed bytes, loosen root confinement, add an
unreviewed module capability, or claim that scan scoping alone completes P10.1.
