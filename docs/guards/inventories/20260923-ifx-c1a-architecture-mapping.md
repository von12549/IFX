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
| `L1.2` `584007ec88e47dcdbe92796745ce107f557cac8d033c3c71a0418f29d7cc3e06` | `PROJECT-NAME-FORBIDDEN`, blocking via policy for in-scope Ring projects; Plan04 separately checks Abstractions retirement across repository artifacts | No built-in project-name predicate / missing; direct IFX Ring scope may not include an Abstractions-named project | Defer direct-rule semantics to C1 follow-up and Plan04 retirement to C4a; do not claim C1b coverage |
| `L2.2` `3061250248352bc621763df6ed6f087e2795104ee642244081858fdd90892145` | `RING-DIRECTION`, `IMPORT-DIRECTION`; Domain reference/import scope | `ARCH.PROJECT_REFERENCE`, `ARCH.SOURCE_IMPORT` Pre / subset: global forbidden lists lack ring context | C1 scoped policy extension; C5 assembly cross-cover |
| `L2.3` `f79c575925632d65653af3b48375160f0c9124657699b14fbe37221a1fe48473` | `OWNERSHIP-REFERENCE`; Application/Contracts provider ownership | Global project-reference list / subset, owner relation missing | C1 scoped ownership extension |
| `L2.4` `cafdf0eb9c8186fbe3f55c22a201a0513a80420bc1f53c504e8f1a5b3fccd12d` | `PROVIDER-CONTRACT`, `PROVIDER-CYCLE`, `EMBEDDED-ADAPTER-PROVIDER` | No provider graph/cycle built-in / missing | C1 provider-graph extension; G03 binding dependencies |
| `L2.9` `c9a324509e022949ca4f18f0857fe9063dcfdeab4d2fd4809fbdbf59bb9675e0` | `OWNERSHIP-UNKNOWN`; V3 infers a module from policy patterns or the project folder's parent, then fails only if no module string exists for an in-scope non-Host/non-Test project | No built-in owner-inference predicate / missing; not a catalog-membership test | Defer to C1 semantic characterization; do not claim C1b coverage |
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

## C1b correction and first implementation decision

The earlier suggestion to start with `L1.2`/`L2.9` was not an equivalence
proof. Source inspection of V3 `OwnershipRules.For`, `Ruleset.ModuleOf` and
`Analyzer.Analyze` establishes the scope and parent-folder fallback above.
Plan04's `Test-AbstractionsRetirement.ps1` is an independent, broader
obligation. A new strict catalog/name checker might be useful, but would
change policy rather than simply port these rules; no such expansion is
authorized here.

C1b instead takes one non-vacuous slice of `L2.2`: a direct raw csproj
ProjectReference from a Domain project to a Contracts project. The proposed
`ifx-domain-reference` Pre extension may enforce that slice with nonzero
Domain-project coverage and negative fixtures. V3's transitive reference
reachability and `IMPORT-DIRECTION` remain uncovered, as do `L1.2`/`L2.9`.
The exact candidate paths, capabilities and stop conditions are in the
separate `20260923-v4-ifx-c1b-domain-reference-slice` formal Plan. No
candidate module or Profile is accepted by this mapping document.
