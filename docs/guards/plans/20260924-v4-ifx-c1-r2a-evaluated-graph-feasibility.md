# V4 P10.1 C1 R2a — MSBuild evaluated-graph feasibility

Status: `BOUNDED FEASIBILITY TEST — NOT C1 CLAIM ACCEPTANCE`

Probe the exact 58 current `src` projects with .NET SDK 10
`dotnet msbuild -getProperty:TargetFramework -getItem:ProjectReference`
under Release/net8.0, without invoking build targets. Record project and
evaluated-edge counts, TFM and defining-project roots. In isolated temporary
fixtures, prove that `Directory.Build.props` and an explicit `<Import>` can
add an evaluated edge absent from raw project XML, and that a conditional
reference changes with Configuration. The eventual R2b producer must lock
this graph and a read-only V4 Post module must judge policy; R2a itself
does neither. Missing/escaping imports, evaluation failures and external
effects remain fail-closed design requirements, not waived by clean IFX.

Only this Plan pair and one test script may change. Formal Pre precedes
the script; package regression and exact Formal Diff follow. No V4 Host,
installed Package, source project or production Profile is edited.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r2a/formal-pre/summary-pre.json`.
All 58 current `src` projects evaluated Release/net8.0 under SDK 10.0.303;
the graph has 155 references defined by 48 projects and no unresolved or
external defining project. Synthetic `Directory.Build.props` and explicit
`<Import>` each added an evaluated-only edge, a Configuration condition
made an edge Release-only, and a missing import stopped evaluation. The
`-getItem` probes created no build outputs in the fixtures. Evidence:
`artifacts/guards/p10-ifx-c1-r2a/test-runs/24bdf9c7f0bb4e04b25f675026d871d5/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-51b2dfaab7074df6b8076cb826e643e3`.
Exact Formal Diff follows the scoped commit.
