# IFX gate coverage C0 — active V3_ifx inventory

Status: `SOURCE INVENTORY — NOT A V4 ACCEPTANCE OR PARITY RESULT`

This is the human-readable view of
`docs/guards/inventories/20260923-ifx-v3-gate-inventory.json`. The source
snapshot is Git commit `851a7b6f4305ca7037aae5533a36c3d43c7da988`.
The JSON records the individual paths, SHA-256 values, authority roles,
Stage gate contracts, detector families and proposed V4 destinations. A
subsequent source change requires a new inventory, not an implicit update of
these bytes. The published V4 base remains 1.1.2; its Package hash is
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.

## Gate-by-gate disposition

The six Stage manifests declare 13 gate IDs. Bootstrap, Analysis and Pre have
no declared gates. Post declares ten; these are the direct P10.1 target. Diff
declares one and CI two; these remain active V3 governance obligations but are
explicitly deferred to the separate P10.3 trusted-base/workflow transition.
“Destination” is a proposed implementation workstream, not coverage already
delivered.

| Active gate | Source trust / evidence | V4 disposition |
| --- | --- | --- |
| `v3-architecture` | Mixed; base architecture engine and IFX policy binding judge csproj XML and C# text | C1: partial; only scoped `ARCH.GRAPH_COMPLETENESS` exists in the historical 0.2.0 draft. Review all other architecture claims and compiled cross-coverage. |
| `v3-specialized-g03` | Judging; G03 catalog, governance projection and snapshots | C2: missing G03 governance module. |
| `v3-specialized-g04` | Judging; deployment manifests, bindings, schemas and policy | C3: missing G04 module. |
| `v3-specialized-g05` | Judging; context/event, security and conformance authorities | C4: missing G05 module. |
| `v3-specialized-plan04` | Judging; projection, extraction and tenant-query policy/registries | C4a: missing Plan04 governance module. |
| `v3-specialized-database` | Executes head and consumes generated head artifacts; migration/release safety | C4b: missing; execution capabilities and fresh evidence need separate review. |
| `v3-quality-solution` | Executes head solution build/tests and audit thresholds | C5: missing quality/prerequisite module. |
| `v3-quality-assembly` | Judges head-built assembly artifacts; cross-covers MSBuild-evaluated references | C5: missing compiled claim and exact build provenance. |
| `v3-quality-frontend` | Executes head npm lint/tests/audit | C5: missing frontend quality module. |
| `v3-historical-integrity` | Judges immutable history against a 15-entry base manifest | C5: missing history audit. |
| `v3-pre-diff` | Judging; Diff Stage trusted-base contract | C5g: P10.3-deferred, not counted as P10.1 runtime parity. |
| `v3-cross-platform-ubuntu-latest` | Executes head in CI | C5g: P10.3-deferred required-check transition. |
| `v3-cross-platform-windows-latest` | Executes head in CI | C5g: P10.3-deferred required-check transition. |

The Post manifest's detector list, policy/target inputs, `executesHead`,
`consumesHeadArtifacts`, known gaps and cross-cover are frozen by its SHA-256
in the JSON. No V3 script is authorized to be loaded as a V4 module. The
architecture policy has 24 top-level sections and 11 rule files; nine IDs are
referenced by `layerguard.json.ruleRefs`. `ARCH.SEMANTIC` and
`ARCH.BINARY.DOMAIN.CONTRACTS` are additional rule files, not proof of V4
coverage. The V3 architecture evaluator is blind to MSBuild-evaluated
references and generated sources; the current V3 cross-cover is respectively
`v3-quality-assembly` and `v3-quality-solution`. Neither cross-cover is yet
ported. C1 must produce claim-level rule IDs, scope, thresholds and
clean/violation/missing/zero-match fixtures before implementation closure.
Several standalone `L*` rule files describe advisory/none enforcement while
their referenced rules are blocking in the IFX evaluator. The inventory pins
both file contracts and the nine policy bindings; porting the standalone file
label alone would weaken the gate. `ARCH.BINARY.DOMAIN.CONTRACTS` is separately
blocking with `minimumMatches=1`.

The published V4 architecture module exposes 12 claims, but its Pre
`ARCH.PROJECT_REFERENCE` and `ARCH.PACKAGE_REFERENCE` configuration is a global
forbidden-list test over raw project XML. The IFX V3 policy varies allowed
references and packages by ring, owner and provider. Therefore switching on
those V4 claims with one global list is not, by itself, an equivalent port of
`L2.2`/`L2.3`/`L2.4`/`L3.4`. C1 must prove a precise subset or use a reviewed
Profile extension; it must not declare the whole `v3-architecture` gate covered
from claim-name resemblance.

## Authority, command and exception graph

The 0.2.0 candidate map named eight anchors: profile, project map, toolchain,
LayerGuard policy, G03/G04/G05 projections and Plan05 baseline. Its three
“partial” and five “missing” labels remain historical; its selected claim was
only `ARCH.GRAPH_COMPLETENESS`. It binds an earlier local base archive, so it
cannot be composed unchanged with the published 1.1.2 release. The eight
anchors do not enumerate all active gates or authorities.

The active registry contains 36 domain authority entries: G03 has four, G04
ten, G05 eleven, Plan04 eight and Database three. Each entry's default role,
path and file hash is in the JSON. Pointer-level role overrides in the
registry remain authoritative: particularly waiver/field-exception,
compatibility-adapter, reviewed-migration and tenant-query approval pointers.
The registry also declares four source-to-package projections (G03 catalog and
governance, G04 runtime, G05 context) and eight G04 bindings. Source/target
paths and target hashes are pinned in the JSON; projection transforms must be
reviewed, not replaced with naive file-copy assumptions. The project-map owner
for these domain paths is `codeowners`; individual policy approval ownership
is not inferred from that label.

The package registers 19 commands (seven public, seven internal, five
maintenance) and 17 trusted components. The toolchain declares 11 commands:
two `pwsh` guard/package checks, seven `dotnet` test invocations, and two
frontend `npm` checks. Target languages are C#/.NET 8, TypeScript/React 19 and
PowerShell 7. The assembly gate names two CRM assemblies built from the head;
its artifact trust cannot be reduced to checking a path exists. C1/C5 must
specify tool versions, fixed arguments, freshness, exact output evidence and
default-deny capabilities in their child Plans.

Exception state is not empty merely because Plan05 baseline has zero entries
and G03 governance has zero waivers. The Plan04 tenant bypass registry has five
entries; G05 open-items contains seven blockers and eight field exceptions.
These are authority/exception inputs for review, not auto-approved V4
baselines. A V4 baseline or weakening requires its own exact-byte review and
must fail on stale or unused entries.

## Next boundary

C0 closes only the source and destination inventory. The first C1 child Plan
must choose a bounded architecture/toolchain claim set, enumerate source
hashes, fixture matrix, expected blocking categories, paths and capabilities,
then pass Formal Pre before any runtime or bundle edits. C2–C5 require their
own child Plans. Final bundle review by Xiaolong Feng, receipted composition,
installed Web UI exercise, P10.2 parity and P10.3 activation are not outcomes
of this inventory.
