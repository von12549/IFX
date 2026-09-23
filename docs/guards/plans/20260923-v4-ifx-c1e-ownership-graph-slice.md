# V4 P10.1 C1e — raw project-graph ownership candidate

Status: `C1e CANDIDATE SLICE VALIDATED — no production acceptance`

C1d covers raw ring direction, not the V3 `OWNERSHIP-REFERENCE` predicate.
This child Plan implements that predicate over the same direct/transitive
`.csproj` visibility model, without changing C1d or importing V3 runtime.
The exact sources are `docs/guards/V3_ifx/stages/post/policy/layerguard.json`
at SHA-256 `b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
`docs/guards/V3_ifx/stages/post/policy/g03/governance.json` at SHA-256
`b8f259f02179c48558bd36fd9ccc5f37ce486bbf14f92e9d4c9ada826e4f518c`,
and `L2.3.json` at SHA-256
`f79c575925632d65653af3b48375160f0c9124657699b14fbe37221a1fe48473`.

Freeze exact `rings`, `allowedDependencies`, `referenceScopes`,
`ownership.modulePatterns`, `transitiveBoundaryRoles` and G03
`sharedPrimitiveProjects`. Enumerate entry projects only in `src`, follow
bounded raw ProjectReferences, and reject guard-source traversal. Module
identity comes from the V3 ownership patterns, then the parent-folder
fallback. Only an in-scope visible target with a permitted ring direction is
eligible; a forbidden direction belongs to C1d and is not double-counted.
Preserve `own`, `foreign`, `any` and `none` scope semantics, plus V3's shared
primitive exception (source is neither Domain/Outside nor itself shared,
target is shared). Preserve direct/transitive, PrivateAssets, disabled
transitivity and Composition boundaries. A disallowed relation emits blocking
`OWNERSHIP-REFERENCE` with deterministic graph-path evidence.

At least one Application project and one in-scope project must match. Fixtures
cover clean own/foreign relations, direct and transitive forbidden relations,
shared primitive exception, direction-only exclusion, flow boundaries,
missing `src`, zero Application, malformed XML, unsafe reference and hash
drift. Assert exact findings, stable sorting, V4 schemas, source projections
and TargetRoot invariance. Capabilities are read PackageRoot/TargetRoot,
write none, process `pwsh`, network false, timeout 30 seconds. Run Formal Pre
before edits, direct fixtures, real IFX scan, published 1.1.2 synthetic-only
Host composition, isolated `ifx-package-test`, unchanged Package hash and
exact Formal Diff.

This accepts only a raw-project candidate slice. Source-import ownership
findings, G03 governance validity, provider registration/cycles, evaluated
references, compiled evidence, production Profile, bundle review and complete
C1 remain open. Any required Host/loader change needs a separate V4
compatibility Plan.

Formal Pre passed before candidate edits. The exact V3/G03 policy
projections, authority hashes and V4 module/config/result schemas passed.
Nineteen direct fixtures passed, including own/foreign/none/any relations,
the shared-primitive exception and its source-side exclusion, direct and
transitive violations, flow boundaries, direction-only exclusion, multiple
finding order, missing and zero-match input, malformed XML, unsafe reference,
policy-hash drift and TargetRoot byte invariance. Current IFX `src` scanning
passed with nonzero coverage and zero findings. Published 1.1.2
synthetic-test-only composition, receipt verification and real Host Pre
clean/direct/transitive/zero-Application cases passed. Evidence:
`artifacts/guards/p10-ifx-c1e/test-runs/c75a42752b19490ba1740e52eda6c5ed`.
The isolated IFX package positive and negative regression passed with
explicit NuGet configuration in an approved restore-capable run; evidence:
`artifacts/guards/v3-ifx-package-test-131b404a403743668875ca870b6be169`.
The published base Package hash remains
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
This slice has not activated a production gate or closed source-import,
provider, declaration, payload or compiled-evidence obligations.
