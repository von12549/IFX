# IFX C1 R0 — frozen closure contract and feasibility

Status: `R0 DOCUMENTATION ONLY — R1/R2/R3 NOT IMPLEMENTED`

## Base and evidence identity

The published 1.1.3 checker passed over the local release archive,
external receipt, 137 installed files and Package check: source commit
`90aa87b5c5a8e866db3384564518377d50fe997c`, archive SHA-256
`28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`,
Package hash `9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
The checker is
`docs/guards/candidates/ifx-gate-coverage-revalidation-113/Test-PublishedV4Base113.ps1`.
The C1/C2 1.1.3 revalidation summary is SHA-256
`9ad299755ce6a3556b227cda9905fba6d8055868984395befbd7b15571e863e2`
(18/18; separate C1 Pre suites). The C5f summary is SHA-256
`6ad95f76cce837a9efc02fa941c2f8f60e470657a5698ee87415309acc3387cc`
(24 Post modules, 54 blocking claims, direct/dependency pass). Neither
contains a passed `ARCH.TYPE_DEPENDENCY` IFX selection or an evaluated
`ProjectReference` verifier. Expiring C5 evidence locks must be regenerated
for implementation and cannot be treated as durable C6 approval.

The V3 `ARCH.BINARY.DOMAIN.CONTRACTS` rule is SHA-256
`d5dadf455b9a4b252d3b795c6e34469c0c42d6775473dcae1dd4ea7484b07f4b`;
its exact source is `IFX.Modules.CRM.Domain` / namespace
`IFX.Modules.CRM.Domain.Entities`, forbidden target is
`IFX.Modules.CRM.Contracts` / namespace
`IFX.Modules.CRM.Contracts.V1`, and its minimum is one matched type pair.
The effective IFX LayerGuard policy is SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`.
C5c's `IFX.C5.ASSEMBLY_QUALITY` validates five Domain assembly-reference
allowlists and provenance; it is a separate claim and cannot satisfy the
CRM compiled **type** rule.

## Active C1 rule ownership at R0

All entries below are blocking unless explicitly marked advisory. Existing
C1 candidates use V4 Pre and source/raw-project evidence; R1 is compiled
Post, R2 is evaluated-input Post, and R3 resolves final identity and
applicability. The authoritative predicate and policy classifications are
the pinned `20260924-ifx-c1-executable-rule-closure.md` and C1a mapping;
the table does not broaden V3 semantics.

| Active rule(s) | Current destination | Remaining closure action |
| --- | --- | --- |
| `RING-DIRECTION` | C1b and C1d Pre (duplicate ID) | R3 chooses one authoritative owner and proves retained direct/transitive coverage; R2 overlays evaluated edges. |
| `OWNERSHIP-REFERENCE` | C1e and C1h Pre (duplicate ID) | R3 resolves identity; R2 overlays evaluated edges. |
| `RING-PACKAGE`, `RING-PACKAGE-FORBIDDEN`, `RING-PACKAGE-IMPORT` | C1c/C1h Pre; forbidden ID overlaps | R3 resolves owner and preserves package/import scopes. |
| `IMPORT-DIRECTION` | C1h Pre | R3 final selection; R2 generated-input disposition. |
| `DECLARATION-NAMESPACE`, `DECLARATION-FORBIDDEN`, `DECLARATION-PLACEMENT`, `DECLARATION-IMPLEMENTS` | C1h Pre | R3 final selection; R2 generated-input disposition. C1h also has separate advisory variants, not blocking substitutes. |
| `SYMBOL-FORBIDDEN`, `PAYLOAD-TYPE-FORBIDDEN` | C1h Pre | R3 final selection; R2 generated-input disposition. |
| `PROVIDER-CYCLE` | C1f Pre | R3 final selection, bound to C2 G03 facts. |
| `EMBEDDED-ADAPTER-LOCATION`, `EMBEDDED-ADAPTER-PROVIDER` | C1g Pre | R3 final selection, bound to C2 G03 facts. |
| `PROJECT-NAME-FORBIDDEN` | C1j Pre | R3 final selection; Plan04 broader retirement remains C4a. |
| `PROVIDER-CONTRACT` | C1k Pre, zero current IntegrationAdapter subjects | R3 binds the exact C1m absence decision; direct C1k zero-match remains blocking. |
| `OWNERSHIP-UNKNOWN` | C1m applicability decision | R3 binds bounded V3-equivalent structural exception, not a detector pass. |
| `RING-REFERENCE`, `CONTRACT-CYCLE` | C1n Pre | R3 final selection; R2 evaluated-edge overlay for reference only. |
| `FORBIDDEN-DEPENDENCY`, `FORBIDDEN-DEPENDENCY-ORIGIN` | C1o Pre | R3 final selection; preserve V3 syntax-name semantics, do not claim semantic-symbol binding. |
| `ARCH.BINARY.DOMAIN.CONTRACTS` | No IFX V4 type claim active | R1 activates exact compiled-type Post claim with fresh same-source closure; C5c is not equivalent. |

`FORBIDDEN-REFERENCE` and `RING-MISSING` are inactive under the pinned
policy and must be reclassified on policy drift, not counted as passing
detectors. C1m decision SHA-256 is
`e3a95670c96992b53438e47c6176ca3c1d6cf111cf4568a90c542cd846218b3d`.
Its verifier passes for the exact current 58 `src` projects, inventory
SHA-256 `6662b88492c9c5c2f124e499c6255e857cfaa5953aa67ddd14db532dc8a41ce5`,
and zero IntegrationAdapter matches. Any project, source or policy drift
voids the exception until re-reviewed.

## Project, import, TFM and generated-source scope

The current tree contains 58 `src/**/*.csproj` projects, each declaring
`net8.0`, with no `TargetFrameworks` declaration and no explicit project
`<Import>` element. There are 155 raw `ProjectReference` elements across
all 58; C1n's narrower in-scope scan reported 147. The repository has
root `Directory.Build.props` and `Directory.Packages.props`, no `src`
`.props`/`.targets` files, and an installed .NET SDK `10.0.303`.
The read-only `dotnet msbuild -getProperty:TargetFramework
-getItem:ProjectReference -p:Configuration=Release` probe on CRM Domain
returned `net8.0` and the resolved BuildingBlocks Domain edge, including
`FullPath` and `DefiningProjectFullPath`. This proves an evaluation API
exists, not a complete 58-project graph or policy verdict. R2 must freeze
all properties, imports and outputs and test injected `Directory.Build.*`,
conditional and project imports rather than infer safety from today's
zero explicit imports.

The current Release `obj` tree has 175 generated C# files: 58 global-using,
58 assembly-info, 58 target-framework-attribute and one ApiHost MVC
application-parts metadata file. These are SDK/assembly metadata outputs,
not a proven active business source generator inventory. R2 must bind a
fresh controlled build's generated-output list and contents, test any
applicable generated policy subject or prove its absence, and account for
in-memory generator outputs. A successful build is not architecture-policy
enforcement by itself.

## Installed built-in feasibility and stop condition

The installed 1.1.3 `architecture-conformance` module is version 1.0.1.
Its adapter SHA-256 is
`227512c6e44cdaf6e391282b05d164abb60e6c89584d414adec72f5cdf07ffe9`,
config schema SHA-256
`9ab04c3365adf3b316c703ecb9d86d87dc52a3e3a6016ee9fd09d70d0a7c8830`,
and dependency-lock SHA-256
`3ee21118cbc66f55a17487b7c02bd5407fe83c02d4a4600d1b16f7a83e998861`.
The schema permits `ARCH.TYPE_DEPENDENCY`, the exact source/forbidden
assembly/namespace pair, `minimumMatches`, `assemblyManifestPath`, freshness
options and expected source projects. The adapter loads a hash-locked
explicit assembly closure from EvidenceRoot/StateRoot and uses ArchUnitNET
to test forbidden **type** dependencies. Its locked ArchUnitNET 0.13.4 and
four supporting packages are present in the local NuGet cache; offline
availability on the pinned Linux runner remains a C6 certification item.

Contract feasibility is positive, **runtime feasibility is unproved**:
R1 must supply a manifest and compatible compiled closure, execute the
published Host and prove negative/zero controls. The built-in fresh mode
requires a run/project-bound manifest no older than one hour and a full
TargetRoot snapshot excluding only `.git`, `bin`, `obj`, `artifacts`; do not
silently substitute C5c's 24-hour lock or hash only selected files. If
published Host/schema/loader/built-in behavior prevents exact claim
execution, stop R1 and open a separately authorized compatibility Plan and
published `1.1.x` patch. No installed-release modification is permitted.
