# Project map

Generated view of `project-map.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: project-map.json sha256: dc3e4a9e5e6681dc0d2b342457518d62ee5041fe1b7d6d7b884799ca26e43650 -->

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
| DatabaseMigrator | src/DatabaseMigrator/** | database | codeowners | src/DatabaseMigrator | ifx-layerguard |
| BuildingBlocks | src/BuildingBlocks/** | shared | codeowners | src/BuildingBlocks | ifx-layerguard |
| WebUI | src/WebUI/** | web | codeowners | src/WebUI | ifx-layerguard |
| SourceConfig | src/* | repository | codeowners | src | ifx-layerguard |
| Tests | tests/** | test | codeowners | tests | ifx-layerguard |
| GuardPackage | docs/guards/V3_ifx/** | tooling | codeowners | docs/guards/V3_ifx | ifx-package-test |
| GuardDocs | docs/guards/** | tooling | codeowners | docs/guards | ifx-package-test |
| LayerGuardLegacy | mcp/LayerGuard/** | tooling | codeowners | mcp/LayerGuard | ifx-layerguard |
| GuardAuthorityInputs | docs/architecture/review/gates/** | tooling | codeowners | docs/architecture/review/gates | ifx-package-test |
| ArchitectureDocs | docs/architecture/** | documentation | codeowners | docs/architecture | ifx-package-test |
| RepositoryScripts | scripts/** | tooling | codeowners | scripts | ifx-package-test |
| Deployment | deployment/** | deployment | codeowners | deployment | ifx-package-test |
| CI | .github/** | ci | codeowners | .github | ifx-package-test |
| RepositoryConfig | .gitattributes | repository | codeowners | .github | ifx-package-test |

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

```json
{
  "formatVersion": 1,
  "areas": [
    { "id": "IAM", "pathPattern": "src/Modules/IAM/**", "layer": "module", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Modules/IAM", "focusedCommands": ["ifx-layerguard", "iam-tests"] },
    { "id": "CRM", "pathPattern": "src/Modules/CRM/**", "layer": "module", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Modules/CRM", "focusedCommands": ["ifx-layerguard", "crm-tests"] },
    { "id": "Registry", "pathPattern": "src/Modules/Registry/**", "layer": "module", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Modules/Registry", "focusedCommands": ["ifx-layerguard", "registry-tests"] },
    { "id": "Holdings", "pathPattern": "src/Modules/Holdings/**", "layer": "module", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Modules/Holdings", "focusedCommands": ["ifx-layerguard", "holdings-tests"] },
    { "id": "Transaction", "pathPattern": "src/Modules/Transaction/**", "layer": "module", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Modules/Transaction", "focusedCommands": ["ifx-layerguard", "transaction-tests"] },
    { "id": "Authentication", "pathPattern": "src/Platform/Authentication/**", "layer": "platform", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Platform/Authentication", "focusedCommands": ["ifx-layerguard", "authentication-tests"] },
    { "id": "Authorization", "pathPattern": "src/Platform/Authorization/**", "layer": "platform", "owner": "xiaolong-feng", "similarImplementationRoot": "src/Platform/Authorization", "focusedCommands": ["ifx-layerguard", "authorization-tests"] },
    { "id": "PlatformOther", "pathPattern": "src/Platform/**", "layer": "platform", "owner": "codeowners", "similarImplementationRoot": "src/Platform", "focusedCommands": ["ifx-layerguard"] },
    { "id": "Frontend", "pathPattern": "src/Frontend/**", "layer": "frontend", "owner": "codeowners", "similarImplementationRoot": "src/Frontend/IFX.FrontEnd/src", "focusedCommands": ["frontend-lint", "frontend-test"] },
    { "id": "DatabaseMigrator", "pathPattern": "src/DatabaseMigrator/**", "layer": "database", "owner": "codeowners", "similarImplementationRoot": "src/DatabaseMigrator", "focusedCommands": ["ifx-layerguard"] },
    { "id": "BuildingBlocks", "pathPattern": "src/BuildingBlocks/**", "layer": "shared", "owner": "codeowners", "similarImplementationRoot": "src/BuildingBlocks", "focusedCommands": ["ifx-layerguard"] },
    { "id": "WebUI", "pathPattern": "src/WebUI/**", "layer": "web", "owner": "codeowners", "similarImplementationRoot": "src/WebUI", "focusedCommands": ["ifx-layerguard"] },
    { "id": "SourceConfig", "pathPattern": "src/*", "layer": "repository", "owner": "codeowners", "similarImplementationRoot": "src", "focusedCommands": ["ifx-layerguard"] },
    { "id": "Tests", "pathPattern": "tests/**", "layer": "test", "owner": "codeowners", "similarImplementationRoot": "tests", "focusedCommands": ["ifx-layerguard"] },
    { "id": "GuardPackage", "pathPattern": "docs/guards/V3_ifx/**", "layer": "tooling", "owner": "codeowners", "similarImplementationRoot": "docs/guards/V3_ifx", "focusedCommands": ["ifx-package-test"] },
    { "id": "GuardDocs", "pathPattern": "docs/guards/**", "layer": "tooling", "owner": "codeowners", "similarImplementationRoot": "docs/guards", "focusedCommands": ["ifx-package-test"] },
    { "id": "LayerGuardLegacy", "pathPattern": "mcp/LayerGuard/**", "layer": "tooling", "owner": "codeowners", "similarImplementationRoot": "mcp/LayerGuard", "focusedCommands": ["ifx-layerguard"] },
    { "id": "GuardAuthorityInputs", "pathPattern": "docs/architecture/review/gates/**", "layer": "tooling", "owner": "codeowners", "similarImplementationRoot": "docs/architecture/review/gates", "focusedCommands": ["ifx-package-test"] },
    { "id": "ArchitectureDocs", "pathPattern": "docs/architecture/**", "layer": "documentation", "owner": "codeowners", "similarImplementationRoot": "docs/architecture", "focusedCommands": ["ifx-package-test"] },
    { "id": "RepositoryScripts", "pathPattern": "scripts/**", "layer": "tooling", "owner": "codeowners", "similarImplementationRoot": "scripts", "focusedCommands": ["ifx-package-test"] },
    { "id": "Deployment", "pathPattern": "deployment/**", "layer": "deployment", "owner": "codeowners", "similarImplementationRoot": "deployment", "focusedCommands": ["ifx-package-test"] },
    { "id": "CI", "pathPattern": ".github/**", "layer": "ci", "owner": "codeowners", "similarImplementationRoot": ".github", "focusedCommands": ["ifx-package-test"] },
    { "id": "RepositoryConfig", "pathPattern": ".gitattributes", "layer": "repository", "owner": "codeowners", "similarImplementationRoot": ".github", "focusedCommands": ["ifx-package-test"] }
  ],
  "riskTriggers": [
    { "id": "public-contract", "pathPattern": "src/**/IFX.*.Contracts/**", "reason": "Public contract or protocol change" },
    { "id": "database-migration", "pathPattern": "src/**/Migrations/**", "reason": "Database migration or schema change" },
    { "id": "database-migrator", "pathPattern": "src/DatabaseMigrator/**", "reason": "Database release boundary" },
    { "id": "identity-security", "pathPattern": "src/Modules/IAM/**", "reason": "IAM and tenant boundary" },
    { "id": "authentication", "pathPattern": "src/Platform/Authentication/**", "reason": "Authentication boundary" },
    { "id": "authorization", "pathPattern": "src/Platform/Authorization/**", "reason": "Authorization boundary" },
    { "id": "frontend-auth", "pathPattern": "src/Frontend/IFX.FrontEnd/src/**/auth/**", "reason": "Frontend sign-in and registration flow" },
    { "id": "frontend-auth-context", "pathPattern": "src/Frontend/IFX.FrontEnd/src/contexts/AuthContext.tsx", "reason": "Frontend authentication session context" },
    { "id": "messaging", "pathPattern": "src/Platform/Messaging/**", "reason": "Message delivery and contract boundary" },
    { "id": "dotnet-dependency", "pathPattern": "**/*.csproj", "reason": ".NET project or package dependency change" },
    { "id": "frontend-dependency", "pathPattern": "src/Frontend/**/package.json", "reason": "Frontend dependency or script change" },
    { "id": "frontend-lockfile", "pathPattern": "src/Frontend/**/package-lock.json", "reason": "Locked frontend dependency change" },
    { "id": "deployment", "pathPattern": "deployment/**", "reason": "Deployment and runtime boundary" },
    { "id": "gate-baseline", "pathPattern": "mcp/LayerGuard/baselines/**", "reason": "Architecture waiver baseline" },
    { "id": "layerguard-runtime", "pathPattern": "mcp/LayerGuard/**", "reason": "Legacy LayerGuard validator or test change" },
    { "id": "gate-input", "pathPattern": "docs/architecture/review/gates/**", "reason": "Gate authority or derived input" },
    { "id": "gate-validator", "pathPattern": "scripts/**", "reason": "Repository validation or operational script change" },
    { "id": "guard-rules", "pathPattern": "docs/guards/**", "reason": "Guard rules, scripts or profiles" },
    { "id": "gate-review-routing", "pathPattern": ".github/CODEOWNERS", "reason": "Required owner review routing" },
    { "id": "gate-line-endings", "pathPattern": ".gitattributes", "reason": "Checkout byte normalization" },
    { "id": "ci-workflow", "pathPattern": ".github/workflows/**", "reason": "CI enforcement configuration" }
  ]
}
```
