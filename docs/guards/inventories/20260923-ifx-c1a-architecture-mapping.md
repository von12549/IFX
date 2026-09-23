# IFX C1a — architecture claim and prerequisite mapping

Status: `DESIGN EVIDENCE — NO V4 GATE ACCEPTED`

Source: C0 inventory at Git `851a7b6f4305ca7037aae5533a36c3d43c7da988`;
published V4 base 1.1.2, Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
Rule-file hashes below are exact SHA-256. The effective V3 policy is
`docs/guards/V3_ifx/stages/post/policy/layerguard.json`, SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`.
The published V4 rule plan has 12 claims (seven Pre, five Post), each requiring
at least one match. A similar claim name is not a semantic equivalence proof.

## Rule-by-rule destination

“Subset” means the V4 predicate might cover some instances but cannot stand
in for the V3 binding. “Missing” means no published built-in predicate
expresses the obligation. All gate-level equivalence is unproved until C1b+
fixtures and Stage runs. The active binding IDs and their detector rule names
are pinned in the C0 JSON's `layerguardRuleBindings`.

| V3 rule file / SHA-256 | Effective obligation and evidence | Published V4 candidate / classification | Destination |
| --- | --- | --- | --- |
| `ARCH.BINARY.DOMAIN.CONTRACTS` `d5dadf455b9a4b252d3b795c6e34469c0c42d6775473dcae1dd4ea7484b07f4b` | Blocking CRM Domain-to-Contracts type dependency; compiled artifact, minimum one match | `ARCH.TYPE_DEPENDENCY` Post / subset: predicate looks relevant, exact assembly provenance and same-commit build not yet established | C5 compiled-evidence review, then C1 claim activation |
| `ARCH.SEMANTIC` `606eaacc82bdb2ea227738d58bfef076f81d444410bc0451c0948c6c95b21e7f` | Advisory/none standalone descriptor; active semantic verdict lives in IFX policy bindings | No standalone V4 rule needed / metadata, not evidence of coverage | C1 map each bound rule below |
| `L1.2` `584007ec88e47dcdbe92796745ce107f557cac8d033c3c71a0418f29d7cc3e06` | `PROJECT-NAME-FORBIDDEN`, blocking via policy; reject new `*.Abstractions` project | No built-in project-name predicate / missing | C1b project-topology extension |
| `L2.2` `3061250248352bc621763df6ed6f087e2795104ee642244081858fdd90892145` | `RING-DIRECTION`, `IMPORT-DIRECTION`; Domain reference/import scope | `ARCH.PROJECT_REFERENCE`, `ARCH.SOURCE_IMPORT` Pre / subset: global forbidden lists lack ring context | C1 scoped policy extension; C5 assembly cross-cover |
| `L2.3` `f79c575925632d65653af3b48375160f0c9124657699b14fbe37221a1fe48473` | `OWNERSHIP-REFERENCE`; Application/Contracts provider ownership | Global project-reference list / subset, owner relation missing | C1 scoped ownership extension |
| `L2.4` `cafdf0eb9c8186fbe3f55c22a201a0513a80420bc1f53c504e8f1a5b3fccd12d` | `PROVIDER-CONTRACT`, `PROVIDER-CYCLE`, `EMBEDDED-ADAPTER-PROVIDER` | No provider graph/cycle built-in / missing | C1 provider-graph extension; G03 binding dependencies |
| `L2.9` `c9a324509e022949ca4f18f0857fe9063dcfdeab4d2fd4809fbdbf59bb9675e0` | `OWNERSHIP-UNKNOWN`; IFX policy requires known module for `IFX.Modules.{module}.*` and `IFX.Platform.{module}.*` | No built-in owner-recognition predicate / missing | C1b project-topology extension |
| `L3.1` `afef5fcdcf2f09f0f3ae2c850c0807876682d694e35cd511310b23d416c31a3a` | `DECLARATION-NAMESPACE` in public Contracts/Events | `ARCH.DECLARATION_PLACEMENT` Pre / subset: global forbidden namespace, not provider placement | C1 scoped declaration extension |
| `L3.4` `c2383c2bc47bc56ab60afa99fe9ddea46572282a9790b7d26832bf0cdf6d265e` | `RING-PACKAGE`, `RING-PACKAGE-FORBIDDEN`, `RING-PACKAGE-IMPORT`, `SYMBOL-FORBIDDEN` in Contracts | `ARCH.PACKAGE_REFERENCE`, `ARCH.SOURCE_IMPORT`, `ARCH.FORBIDDEN_SYMBOL` / subset: global policy and mixed Pre/Post evidence | C1 scoped package/import/symbol extension or proved per-claim configuration |
| `L3.5` `166192cf788c72b3b2e87703d4350ca10e10b184fe7efcae62fec04a19135f4f` | `DECLARATION-FORBIDDEN`; implementation declarations in Contracts | `ARCH.DECLARATION_PLACEMENT` / subset: namespace placement is not declaration-kind prohibition | C1 declaration-kind extension |
| `L3.6` `768c8f06aa99353fd9a2d76b466d55db3f75c5d3c2b65ee41472ee19bc6e1f0d` | `PAYLOAD-TYPE-FORBIDDEN`; integration payload must not expose internal entities | `ARCH.MEMBER_PAYLOAD` Post / subset: global forbidden namespace list lacks exact event/member scope | C1 payload extension or proved constrained configuration |

For the V3 bindings, a file's `advisory`/`none` standalone declaration does
not downgrade its blocking IFX policy rule. V4's raw csproj and syntax claims
also do not cover MSBuild-evaluated references or generated sources. V3
cross-covers these respectively with `v3-quality-assembly` and
`v3-quality-solution`; C5 must restore both before claiming full architecture
parity. The V4 compiled claim requires a reviewed fresh build manifest and
same-source provenance. No C1b fixture may count a zero-project/zero-match
result as a pass.

## Project map and command ownership

The pinned V3 Pre project map has 30 areas and 21 risk triggers. Its area IDs
are `IAM`, `CRM`, `Registry`, `Holdings`, `Transaction`, `Authentication`,
`Authorization`, `PlatformOther`, `Frontend`, `ApiHost`, `DatabaseMigrator`,
`BuildingBlocks`, `WebUI`, `Tests`, `Database`, `GuardPackage`, `GuardDocs`,
`LayerGuardLegacy`, `GuardAuthorityInputs`, `ArchitectureDocs`,
`RepositoryDocs`, `RepositoryDependencies`, `RepositoryTools`,
`DocumentationConfig`, `McpConfig`, `RepositoryScripts`, `Deployment`, `CI`,
`RepositoryConfig`, `RepositoryIgnore`. Its risk IDs are `public-contract`,
`database-migration`, `database-migrator`, `identity-security`,
`authentication`, `authorization`, `frontend-auth`,
`frontend-auth-context`, `messaging`, `dotnet-dependency`,
`frontend-dependency`, `frontend-lockfile`, `deployment`, `gate-baseline`,
`layerguard-runtime`, `gate-input`, `gate-validator`, `guard-rules`,
`gate-review-routing`, `gate-line-endings`, `ci-workflow`.

These area/risk declarations are planning and change-routing metadata; they
are not the same as the architecture policy's module ownership predicate.
`GuardDocs` is the owner of this document, not a blanket authorization for
the other 29 areas. C1b must preserve project-scope identity under `src` and
`tests`, explicitly exclude `guard/**` as subject discovery, and fail on a
missing source root, unknown module or zero matching project set.

The 11 toolchain commands split by destination: `ifx-layerguard` and
`ifx-package-test` are C1/C6 source-policy and package-prerequisite evidence;
`iam-tests`, `crm-tests`, `registry-tests`, `holdings-tests`,
`transaction-tests`, `authentication-tests` and `authorization-tests` are C5
fresh .NET quality evidence; `frontend-lint` and `frontend-test` are C5 npm
evidence. The toolchain's fixed commands, arguments, working directories and
runtime kinds (`pwsh`, `dotnet`, `npm`) are frozen by C0's toolchain hash.
Executing head code requires a separately reviewed capability and freshness
contract; C1b's static project check needs none of those head executions.

## First implementation decision: C1b

Start with the coherent static project-topology pair `L1.2` and `L2.9`, not
with the whole `v3-architecture` gate. Proposed module ID:
`ifx-project-topology`, Stage Pre, reading only `TargetRoot`, no writes, no
network, `pwsh` only, bounded timeout. Source authorities are the pinned IFX
LayerGuard policy and project map; the latter supplies target-area boundaries,
not a substitute for the policy's known-module rule. Proposed workbench files
for the separately formalized C1b Plan are:

- `docs/guards/candidates/ifx-gate-coverage-c1b/modules/ifx-project-topology/module.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/modules/ifx-project-topology/adapter.ps1`
- `docs/guards/candidates/ifx-gate-coverage-c1b/modules/ifx-project-topology/config.schema.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/modules/ifx-project-topology/result.schema.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/modules/ifx-project-topology/dependencies.lock.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/tests/Test-IFXProjectTopology.ps1`
- `docs/guards/candidates/ifx-gate-coverage-c1b/fixtures/clean/fixture.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/fixtures/forbidden-name/fixture.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/fixtures/unknown-owner/fixture.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/fixtures/missing-root/fixture.json`
- `docs/guards/candidates/ifx-gate-coverage-c1b/fixtures/zero-match/fixture.json`

C1b must first prove that the public V4 extension contract can run this
read-only detector without a Host/schema/loader change. Required controls:
clean, forbidden-name, unknown-owner, missing-input and zero-match fixtures;
stable rule IDs and blocking categories; deterministic sorted subjects;
read-only TargetRoot/PackageRoot; no V3 runtime imports. If a core change is
needed, stop for the parent's separate compatibility Plan and patch authority.
No candidate module or Profile is accepted by this C1a document.
