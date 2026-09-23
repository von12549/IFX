# V4 P10.1 C1d — raw project-graph ring direction candidate

Status: `C1d CANDIDATE SLICE VALIDATED — no production acceptance`

C1b checks one direct Domain-to-Contracts reference. C1d extends the raw
`.csproj` ProjectReference detector to every IFX ring pair and to V3-style
compile-time transitive visibility. Its authority is
`docs/guards/V3_ifx/stages/post/policy/layerguard.json` at SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
with `L2.2.json` at SHA-256
`3061250248352bc621763df6ed6f087e2795104ee642244081858fdd90892145`.

Freeze the exact `rings`, `allowedDependencies` and
`transitiveBoundaryRoles` policy projection. Enumerate entry projects only
under `src`; follow their raw ProjectReferences inside TargetRoot to build
the graph, but never discover `guard/**` as subjects. A direct reference is
always visible. Beyond one hop, honor `PrivateAssets=all|compile`,
`DisableTransitiveProjectReferences=true` on the entry project, and the
Composition transitive boundary. Same-ring references are permitted. A
visible in-scope target whose ring is not allowed emits blocking
`RING-DIRECTION` with deterministic path evidence. At least one Domain and
one in-scope project must be matched; missing input, invalid XML, unsafe or
missing references and zero match fail closed. No MSBuild evaluation, target
code execution or V3 runtime import is authorized.

Fixtures cover clean, direct and transitive violations, each flow boundary,
same-ring exception, missing `src`, zero Domain, malformed XML and unsafe
reference escape. Assert policy projection/hash, schemas, exact finding
identity, stable sorting, coverage and TargetRoot byte invariance. Module
capabilities: read PackageRoot/TargetRoot, write none, process `pwsh`, network
false, timeout 30 seconds. Validate with real IFX direct scan, published 1.1.2
synthetic-only Host composition, isolated `ifx-package-test`, unchanged V4
Package hash, Formal Pre before candidate edits and exact Formal Diff.

Acceptance closes only the candidate raw graph part of `RING-DIRECTION`.
`IMPORT-DIRECTION`, ownership/provider graph, evaluated project references,
compiled type dependencies, other C1 detector families, real IFX Profile,
bundle review and composition remain open. If Host/loader changes are needed,
stop and open the separate V4 compatibility process.

Formal Pre passed before candidate edits. The module's source projection,
manifest/config/result schemas and authority hashes passed. Thirteen direct
fixtures passed, including direct and transitive violations, `PrivateAssets`
attribute and child forms, disabled transitivity, Composition boundary,
same-ring references, missing and zero-match input, malformed XML, unsafe
escape, deterministic multiple-findings order, policy-hash drift and
TargetRoot byte invariance. The current IFX `src` scan passed with nonzero
coverage and zero findings. Published 1.1.2 synthetic-test-only composition,
receipt verification and real Host Pre clean/direct/transitive/zero-Domain
cases passed. Evidence:
`artifacts/guards/p10-ifx-c1d/test-runs/507fb04a4a1343baa3deb25a45d70936`.
The isolated IFX package positive and negative regression passed with
explicit NuGet configuration in an approved restore-capable run; evidence:
`artifacts/guards/v3-ifx-package-test-ffe8cc1d014f4d129cc1e31f6459f16d`.
The published base Package hash remains
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
This does not activate a production gate or close the import, ownership,
source-policy or compiled-evidence gaps in C1.
