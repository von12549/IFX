# V4 P10.1 — C1 final-closure remediation plan

Status: `PLAN ONLY — C1 BLOCKED; C6 NOT STARTED`

The 1.1.3 C1/C2 revalidation passed 18/18 and C5f's 24 reviewed Post
modules passed, but neither result closes C1. C5c checks five Domain DLLs'
assembly references; it does not execute the blocking
`ARCH.BINARY.DOMAIN.CONTRACTS` CRM entity-to-public-contract **type** rule.
C1's raw `ProjectReference` candidates do not inspect the MSBuild-evaluated
graph. C1 Pre slices also have overlapping rule IDs and have only been
revalidated separately. Treat these as distinct obligations, not as one
inferred pass or a baseline. The C1m `L2.9=A` and `IntegrationAdapter=A`
decisions remain exact-inventory applicability exceptions; the current
58-project inventory verifier passes with zero IntegrationAdapter subjects.

This document authorizes planning only. It does not approve a detector,
alter the published/installed 1.1.3 Package, accept a final Profile, start
C6, or grant human bundle review. Each executable tranche below requires its
own exact child Formal Plan, `plannedPaths`, authority/claim matrix and
passing Formal Pre **before** edits. Keep V3 source/policy as hashed facts,
never import V3 runtime paths into V4. No blanket V3 waiver or silent
zero-subject success is allowed.

## R0 — freeze the closure contract and evidence provenance

1. Pin the published 1.1.3 archive, receipt, installed Package hash and
   source commit; recheck the C1/C2 revalidation and C5f evidence without
   relabelling their scopes. Freeze the V3 type-rule JSON, LayerGuard policy,
   relevant MSBuild/quality predicates, all C1 module plans and C1m decision
   bytes. List every active C1 claim once with detector, subject set, Stage,
   evidence kind, minimum match, blocking category and owner. Explicitly
   distinguish `ARCH.BINARY.DOMAIN.CONTRACTS` from C5c's
   `IFX.C5.ASSEMBLY_QUALITY`.
2. Inventory all 58 `src` projects, solution project set, import closure,
   configuration/target-framework dimensions and generated C# inputs.
   Determine which generated inputs can satisfy an active V3 C1 predicate;
   do not assume that a successful build enforces an architecture rule.
   Preserve V3's syntax-only declaration-origin semantics rather than
   silently claiming semantic-symbol equivalence.
3. Run a contract feasibility check against the installed 1.1.3 built-in
   `ARCH.TYPE_DEPENDENCY` module, its config schema, explicit assembly
   manifest, dependency lock and offline ArchUnitNET availability. If a
   Host/schema/loader/built-in change is necessary, stop that tranche and
   obtain a separate exact compatibility Plan and published `1.1.x` patch
   before continuing. Do not patch the installed tree in place.

Exit: a reviewed claim-to-detector matrix with every active C1 obligation
either assigned to R1/R2/R3 or explicitly blocked; no inferred equivalence.

## R1 — compiled CRM type-dependency claim

Configure the existing 1.1.3 `ARCH.TYPE_DEPENDENCY` Post claim if its
public contract suffices; otherwise propose a read-only extension or the
separately authorized compatibility patch identified in R0. Bind the exact
V3 source/forbidden assembly and namespace pair and `minimumMatches=1`.
Produce a fresh controlled Solution build lock and an explicit assembly
manifest for CRM Domain, CRM Contracts and their required closure, with
source commit/tree, configuration, TFM, toolchain, DLL hashes, dependency
versions and bounded expiry. The V4 Post check must inspect compiled
**types**, not merely assembly-reference names, and independently bind the
manifest to fresh C5b/C5c evidence. It must be read-only against TargetRoot
and PackageRoot and must not execute a build inside V4 Post.

Exit tests: real IFX clean with nonzero CRM source and forbidden-target type
coverage; a fixture adding the forbidden type edge blocks; absent source or
target types, missing/stale/altered DLL or manifest, wrong commit/TFM,
dependency drift and zero matches block. Direct and dependency-enabled
published-Host Post, schema/receipt checks, immutable roots, isolated package
regression and exact Formal Diff pass. Do not count C5c's five-DLL 7/7 result
as this rule's pass.

## R2 — evaluated reference graph and generated-input cross-cover

Use a controlled, isolated producer outside the V4 Host to evaluate the
complete applicable `src` project set under pinned SDK, Release properties,
TFM dimensions and import closure. Record canonical project identities,
evaluated direct `ProjectReference` edges, raw-to-evaluated deltas, source
and imported-file hashes, command/environment inputs, target commit,
toolchain and time in a fresh lock. Evaluation must run with bounded process,
filesystem and network permissions; fail if an import escapes the approved
closure or a project/TFM cannot be evaluated. Do not execute arbitrary
build targets merely to obtain an item list.

A separate read-only V4 Post verifier must validate the lock and independently
apply the effective C1 ring direction, allow-list and ownership policy to
the evaluated graph, without replacing the raw Pre rules. For generated C#,
R0 must either prove zero applicable generated subjects under a locked
inventory or define an additional controlled-output verifier for the active
source/compiled claims. A successful Solution build alone is not proof of
policy enforcement.

Exit tests: clean nonzero evaluated project/edge coverage; a synthetic
`Directory.Build.*` and a project `<Import>` that add forbidden references
both block; conditional Configuration/TFM cases, missing/escaping imports,
unresolved project, stale/altered/empty lock, project-set drift and zero
subjects block. Generated-input positive/negative/zero controls follow R0's
applicability result. Real IFX direct and dependency Host Post, immutable
roots, isolated package regression and exact Formal Diff pass. Any Windows/
Linux evaluation difference is recorded and resolved before C6 certification.

## R3 — C1 integrated identity and final adjudication

Assemble a synthetic-only 1.1.3 C1 candidate with one authoritative owner
per active rule/claim. Resolve overlapping C1 Pre rule IDs explicitly;
neither drop a detector nor count separate Pre runs as one combined Profile.
Bind the exact C1m 58-project applicability decision and fail closed on any
new IntegrationAdapter subject or source/policy/project drift. Integrate the
R1/R2 Post checks with existing C1/C2 and C5 evidence, preserving distinct
Stage ownership, fresh locks and zero Profile baselines unless individually
reviewed. Re-run real IFX clean, targeted violating, missing-input and
zero-match cases, direct/dependency Stages, published base/receipt checks,
TargetRoot/PackageRoot invariance, isolated package regression and Formal
Diff. No synthetic review record is a human final-bundle approval.

Close C1 only if the final matrix has zero uncovered active obligations,
every required subject is nonvacuous or has a still-valid bounded C1m
decision, and all blocking categories remain fail-closed. Record a formal
pass/fail decision with exact evidence hashes. If any item fails, keep C1
blocked and do not enter C6. If C1 passes, open a separate C6 exact Plan for
the final reviewed bundle, dual-platform certification, Xiaolong Feng's
approval over exact bytes, receipted composition and installed Web UI
practice. P10.3 Diff/CI and G05 Phase 9 deferrals remain explicit; C1/C6
cannot silently retire them.

## This planning checkpoint

Only this Plan pair changes. Run Formal Pre, isolated IFX package regression
and exact Formal Diff for the documentation-only scope. No executable
repair or C6 action is part of this checkpoint.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-closure-plan/formal-pre/summary-pre.json`.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-8bede9f4e77e4d7186f5e049bb9672e3`.
Exact Formal Diff follows the scoped documentation commit.
