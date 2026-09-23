# V4 P10.1 C1c — scoped PackageReference candidate

Status: `C1c CANDIDATE SLICE VALIDATED — no production acceptance`

The C1b direct Domain reference candidate is not full C1 coverage. This child
Plan adds a separate read-only Pre extension for the raw `PackageReference`
part of V3 `L3.4` and the same package policy where it applies to Domain,
Contracts, Application and Presentation. The authority is
`docs/guards/V3_ifx/stages/post/policy/layerguard.json` at SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`;
`L3.4.json` is SHA-256
`c2383c2bc47bc56ab60afa99fe9ddea46572282a9790b7d26832bf0cdf6d265e`.

The candidate uses the public PowerShell module contract only. Its frozen
policy projection preserves the exact ring patterns, allowed packages,
forbidden packages and V3 precedence: a forbidden match emits
`RING-PACKAGE-FORBIDDEN` once; otherwise a non-allowed package emits
`RING-PACKAGE`. A ring absent from the allowed list is unchecked; an empty
allowed list allows no package. Scan only raw `src/**/*.csproj`, never
`guard/**`; require `src` and at least one project in each named policy ring.
Reject unsafe paths, links, invalid XML, duplicate ring assignment and
source-policy hash drift. Do not evaluate MSBuild or run TargetRoot code.

Fixtures cover clean, explicit deny precedence, allow-list miss, missing
`src`, zero applicable ring, invalid XML and link/path escape. Assert exact
finding identity, ordering, coverage and TargetRoot byte invariance. The
capability ceiling is read PackageRoot/TargetRoot, write none, process `pwsh`,
network false, timeout 30 seconds. Verify manifest/schema/authority hashes,
the unchanged published V4 Package hash, isolated `ifx-package-test`, Formal
Pre before candidate edits, and exact Formal Diff after the candidate files.

Acceptance is limited to a candidate raw-project package-reference slice.
`RING-PACKAGE-IMPORT`, `SYMBOL-FORBIDDEN`, other L3.4 source predicates,
compiled/build evidence, real IFX Profile, bundle review and composition
remain open. No V4 core/release/installed-tree bytes or V3 runtime code may
be changed or imported. If Host or loader changes prove necessary, stop and
open a separate compatibility Plan.

Formal Pre passed before candidate edits. The candidate matched the V3 policy
projection, manifest/config/result schemas and all declared hashes. Eight
direct fixtures passed, including policy-hash drift and TargetRoot byte
invariance. Against the receipted published 1.1.2 base, synthetic-test-only
composition and receipt verification passed; the real Host returned expected
Pre clean, explicit-deny and zero-Domain verdicts. Direct scanning of current
IFX `src` passed with nonzero policy-ring coverage and zero findings. Evidence:
`artifacts/guards/p10-ifx-c1c/test-runs/95af927302d94ed38732565322549fb9`.
The isolated IFX package positive and negative regression passed with explicit
NuGet configuration after an approved restore-capable run; evidence:
`artifacts/guards/v3-ifx-package-test-739d8a20483b4a66b548b45baa68123a`.
The published base Package check still returns hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
These results establish this raw-project candidate only; source-import,
declaration, payload, compiled and other C1 obligations remain open.
