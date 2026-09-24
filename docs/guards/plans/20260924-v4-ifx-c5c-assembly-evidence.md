# V4 P10.1 C5c — compiled Domain Assembly Quality

The V3 Assembly gate has passed against the five Release/net8.0 module Domain
DLLs. This tranche binds a controlled Assembly report and those exact DLL
bytes to fresh C5b Solution build evidence. A read-only V4 Post module must
independently inspect each compiled reference against the frozen Domain
allowlist (`IFX.BuildingBlocks.Domain` plus trusted platform assemblies),
reject missing or source-stale DLLs, and reject missing, expired, altered or
zero-match evidence. The V4 module cannot invoke dotnet, write to TargetRoot
or import V3 runtime code. Host synthetic Post and real IFX direct Post,
isolated package regression and exact Formal Diff are required.

This is candidate coverage of the compiled Domain claim, not final C1
closure, Profile acceptance or a waiver of MSBuild-evaluated references and
the two remaining injection families.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5c/formal-pre/pre.json`.
The controlled V3 Assembly producer issued
`artifacts/guards/p10-ifx-c5c/assembly-runs/7c7808c3dfdc4a69b3ea1dd0077ddcbb/evidence-lock.json`,
binding five Domain DLLs, the Assembly report and the fresh C5b Solution
lock. Real IFX direct Post and published 1.1.3 synthetic Host Post passed
7/7 mapped checks at
`artifacts/guards/p10-ifx-c5c/test-runs/608417171eca49b6b185f529e28597b7/summary.json`.
Tampered/missing/stale locks, zero assemblies, an injected forbidden
reference and an altered DLL blocked. The isolated TargetRoot and
PackageRoot remained byte-invariant. Package regression and exact
committed Formal Diff follow. The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-57a0aa69bbde40258b8864bf60b8e65f`.
