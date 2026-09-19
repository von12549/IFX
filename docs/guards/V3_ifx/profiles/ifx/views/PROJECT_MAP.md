# Project map

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `cc3dec8a99895539c25ba83ee1e6ce40fcc0e59d55b5b59beb076d3eac987459`

Sources:

- `docs/guards/V3_ifx/profiles/ifx/project-map.json` — authority

## Areas

| ID | Path | Layer | Owner | Similar implementation | Focused commands |
| --- | --- | --- | --- | --- | --- |
| IAM | src/Modules/IAM/** | module | xiaolong-feng | src/Modules/IAM | ifx-layerguard, iam-tests |
| CRM | src/Modules/CRM/** | module | xiaolong-feng | src/Modules/CRM | ifx-layerguard, crm-tests |
| Registry | src/Modules/Registry/** | module | xiaolong-feng | src/Modules/Registry | ifx-layerguard, registry-tests |
| Holdings | src/Modules/Holdings/** | module | xiaolong-feng | src/Modules/Holdings | ifx-layerguard, holdings-tests |
| Transaction | src/Modules/Transaction/** | module | xiaolong-feng | src/Modules/Transaction | ifx-layerguard, transaction-tests |
| Authentication | src/Platform/Authentication/** | platform | xiaolong-feng | src/Platform/Authentication | ifx-layerguard, authentication-tests |
| Authorization | src/Platform/Authorization/** | platform | xiaolong-feng | src/Platform/Authorization | ifx-layerguard, authorization-tests |
| PlatformOther | src/Platform/** | platform | codeowners | src/Platform | ifx-layerguard |
| Frontend | src/Frontend/** | frontend | codeowners | src/Frontend/IFX.FrontEnd/src | frontend-lint, frontend-test |
| ApiHost | src/ApiHost/** | host | codeowners | src/ApiHost | ifx-layerguard |
| DatabaseMigrator | src/DatabaseMigrator/** | database | codeowners | src/DatabaseMigrator | ifx-layerguard |
| BuildingBlocks | src/BuildingBlocks/** | shared | codeowners | src/BuildingBlocks | ifx-layerguard |
| WebUI | src/WebUI/** | web | codeowners | src/WebUI | ifx-layerguard |
| Tests | tests/** | test | codeowners | tests | ifx-layerguard |
| Database | tools/** | tooling | codeowners | tools | ifx-layerguard |
| GuardPackage | docs/guards/V3_ifx/** | tooling | codeowners | docs/guards/V3_ifx | ifx-package-test |
| GuardDocs | docs/guards/** | tooling | codeowners | docs/guards | ifx-package-test |
| LayerGuardLegacy | mcp/LayerGuard/** | tooling | codeowners | mcp/LayerGuard | ifx-layerguard |
| GuardAuthorityInputs | docs/architecture/review/gates/** | tooling | codeowners | docs/architecture/review/gates | ifx-package-test |
| ArchitectureDocs | docs/architecture/** | documentation | codeowners | docs/architecture | ifx-package-test |
| RepositoryDocs | .claude/** | documentation | codeowners | .claude | ifx-package-test |
| RepositoryDependencies | Directory.*.props | repository | codeowners | .config | ifx-package-test |
| RepositoryTools | .config/** | repository | codeowners | .config | ifx-package-test |
| DocumentationConfig | docs/Directory.Packages.props | tooling | codeowners | docs | ifx-package-test |
| McpConfig | mcp/Directory.Packages.props | tooling | codeowners | mcp | ifx-package-test |
| RepositoryScripts | scripts/** | tooling | codeowners | scripts | ifx-package-test |
| Deployment | deployment/** | deployment | codeowners | deployment | ifx-package-test |
| CI | .github/** | ci | codeowners | .github | ifx-package-test |
| RepositoryConfig | .gitattributes | repository | codeowners | .github | ifx-package-test |
| RepositoryIgnore | .gitignore | repository | codeowners | .github | ifx-package-test |

## Risk triggers

| ID | Path | Reason |
| --- | --- | --- |
| public-contract | src/**/IFX.*.Contracts/** | Public contract or protocol change |
| database-migration | src/**/Migrations/** | Database migration or schema change |
| database-migrator | src/DatabaseMigrator/** | Database release boundary |
| identity-security | src/Modules/IAM/** | IAM and tenant boundary |
| authentication | src/Platform/Authentication/** | Authentication boundary |
| authorization | src/Platform/Authorization/** | Authorization boundary |
| frontend-auth | src/Frontend/IFX.FrontEnd/src/**/auth/** | Frontend sign-in and registration flow |
| frontend-auth-context | src/Frontend/IFX.FrontEnd/src/contexts/AuthContext.tsx | Frontend authentication session context |
| messaging | src/Platform/Messaging/** | Message delivery and contract boundary |
| dotnet-dependency | **/*.csproj | .NET project or package dependency change |
| frontend-dependency | src/Frontend/**/package.json | Frontend dependency or script change |
| frontend-lockfile | src/Frontend/**/package-lock.json | Locked frontend dependency change |
| deployment | deployment/** | Deployment and runtime boundary |
| gate-baseline | mcp/LayerGuard/baselines/** | Architecture waiver baseline |
| layerguard-runtime | mcp/LayerGuard/** | Legacy LayerGuard validator or test change |
| gate-input | docs/architecture/review/gates/** | Gate authority or derived input |
| gate-validator | scripts/** | Repository validation or operational script change |
| guard-rules | docs/guards/** | Guard rules, scripts or profiles |
| gate-review-routing | .github/CODEOWNERS | Required owner review routing |
| gate-line-endings | .gitattributes | Checkout byte normalization |
| ci-workflow | .github/workflows/** | CI enforcement configuration |
