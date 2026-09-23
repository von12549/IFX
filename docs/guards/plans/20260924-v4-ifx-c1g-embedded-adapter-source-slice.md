# V4 P10.1 C1g — embedded adapter source-use candidate

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

C1f proved the G03 provider graph but not use of foreign Contracts inside
Infrastructure source. The current IFX project set contains five
`IFX.Modules.*.Infrastructure` projects and no project matching the V3
`IntegrationAdapter` ring. C1g therefore implements the active V3
`EMBEDDED-ADAPTER-LOCATION` and `EMBEDDED-ADAPTER-PROVIDER` source-use
predicates; it does not claim the dormant direct `PROVIDER-CONTRACT` project
predicate. Authorities are V3 IFX `layerguard.json` SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
G03 `governance.json` SHA-256
`b8f259f02179c48558bd36fd9ccc5f37ce486bbf14f92e9d4c9ada826e4f518c`,
`L2.4.json` SHA-256
`cafdf0eb9c8186fbe3f55c22a201a0513a80420bc1f53c504e8f1a5b3fccd12d`,
and the V3 semantic reference implementation `EmbeddedAdapterRules.cs`
SHA-256 `5bf9a39b4f595568e0c85c7200a6d1fca1d3065ea61b1bda7f1b1b1f5b2a35d6`.

Build an independent read-only V4 Pre PowerShell extension using the
published V4 pattern for loading Roslyn from a compatible installed .NET 10
SDK, with the published host-compatible PowerShell Roslyn fallback when SDK
assemblies cannot load into that process. The dependency lock and
prerequisites declare both dependency routes; do not
copy or import V3 runtime code. Freeze exact ring/module, embedded namespace,
provider graph and shared primitive facts. Enumerate `.csproj` entries only
under `src`, assign each non-generated `.cs` file to its nearest project,
and inspect Roslyn `NameSyntax` nodes in active syntax. Exclude generated
files and `src/guard` or `src/guards` subjects. For Infrastructure
files only, resolve a name to the longest loaded project-name prefix.
Foreign Contracts uses (except shared primitives) must occur in an approved
embedded adapter namespace and have a registered provider. Match V3's
outermost-name suppression and file/root namespace fallback. Each source
claim requires at least one foreign Contracts name use; zero-match blocks.
No `guard/**` subject discovery, target code execution, network use or
TargetRoot/PackageRoot writes are permitted. Capability ceiling: read
PackageRoot/TargetRoot, write none, processes `pwsh` and `dotnet`, timeout
30 seconds.

Fixtures cover clean registered/located use, unapproved provider, wrong
location, both violations, shared-primitive and own-Contracts exceptions,
missing `src`, zero foreign use, malformed project/source, unsafe links and
policy hash drift. Assert exact rule/evidence IDs, deterministic order,
nonvacuous coverage, source authority projections and TargetRoot byte
invariance. Validate with a real IFX scan, published 1.1.2 synthetic-only
Host Pre clean/violation/zero controls, isolated `ifx-package-test`,
unchanged V4 Package hash, Formal Pre before candidate edits and exact
Formal Diff.

This remains a candidate source slice. It does not validate G03 governance
(C2), direct IntegrationAdapter project references, all V3 source rules,
compiled evidence, Linux-complete certification, a production Profile or
bundle, or C1 closure. Host/loader changes require the separate V4
compatibility process.

## Verification record

Formal Pre passed before candidate module edits at
`artifacts/guards/p10-ifx-c1g/formal-pre`. The candidate test asserts the
V4 module and result schemas, frozen V3/G03 projections and source hashes,
authority digests, deterministic rule results, nearest-project ownership,
generated-file and guard-subtree exclusions, malformed input, unsafe link,
hash drift, TargetRoot byte invariance, and real IFX nonvacuity. The real
IFX scan observed seven foreign Contracts source uses, with no LOCATION or
PROVIDER finding. This clean result is specific to the two C1g predicates,
not an architecture or C1 pass. The installed SDK has Roslyn assemblies but
they cannot load into this PowerShell process; the declared host-compatible
Roslyn fallback was exercised. Synthetic-only 1.1.2 composition and Host Pre
cases cover clean, LOCATION, PROVIDER and zero-match paths; the published
Package hash remains `922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The final candidate/Host evidence is
`artifacts/guards/p10-ifx-c1g/test-runs/fa786d17ec994df6b57f69d4a2bc1d58`.
The isolated IFX package regression passed with the repository NuGet
configuration; evidence:
`artifacts/guards/v3-ifx-package-test-7c191d20c0694141814b99b0c780aa64`.
