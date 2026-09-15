# Proposed target architecture

Guard review status: DRAFT

This draft was seeded from [inventory.json](inventory.json) and, when supplied, an existing profile. Review the prose and all structured JSON blocks against actual code. Edit the blocks to express desired policy; prose alone does not change generated configuration. Change status to REVIEWED only after inspection.

## Areas to confirm

| ID | Path | Layer | Owner |
| --- | --- | --- | --- |
| IAM | src/Modules/IAM/** | module | xiaolong-feng |
| CRM | src/Modules/CRM/** | module | xiaolong-feng |
| Registry | src/Modules/Registry/** | module | xiaolong-feng |
| Holdings | src/Modules/Holdings/** | module | xiaolong-feng |
| Transaction | src/Modules/Transaction/** | module | xiaolong-feng |
| Authentication | src/Platform/Authentication/** | platform | xiaolong-feng |
| Authorization | src/Platform/Authorization/** | platform | xiaolong-feng |
| PlatformOther | src/Platform/** | platform | codeowners |
| Frontend | src/Frontend/** | frontend | codeowners |
| DatabaseMigrator | src/DatabaseMigrator/** | database | codeowners |
| BuildingBlocks | src/BuildingBlocks/** | shared | codeowners |
| WebUI | src/WebUI/** | web | codeowners |
| SourceConfig | src/* | repository | codeowners |
| Tests | tests/** | test | codeowners |
| GuardPackage | docs/guards/V3_ifx/** | tooling | codeowners |
| GuardDocs | docs/guards/** | tooling | codeowners |
| LayerGuardLegacy | mcp/LayerGuard/** | tooling | codeowners |
| GuardAuthorityInputs | docs/architecture/review/gates/** | tooling | codeowners |
| ArchitectureDocs | docs/architecture/** | documentation | codeowners |
| RepositoryScripts | scripts/** | tooling | codeowners |
| Deployment | deployment/** | deployment | codeowners |
| CI | .github/** | ci | codeowners |
| RepositoryConfig | .gitattributes | repository | codeowners |

## Profile identity

<!-- guard-config: profile.json -->
```json
{
  "formatVersion": 1,
  "projectId": "ifx"
}
```

## Desired project map

<!-- guard-config: project-map.json -->
```json
{
  "formatVersion": 1,
  "areas": [
    {
      "id": "IAM",
      "pathPattern": "src/Modules/IAM/**",
      "layer": "module",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Modules/IAM",
      "focusedCommands": [
        "ifx-layerguard",
        "iam-tests"
      ]
    },
    {
      "id": "CRM",
      "pathPattern": "src/Modules/CRM/**",
      "layer": "module",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Modules/CRM",
      "focusedCommands": [
        "ifx-layerguard",
        "crm-tests"
      ]
    },
    {
      "id": "Registry",
      "pathPattern": "src/Modules/Registry/**",
      "layer": "module",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Modules/Registry",
      "focusedCommands": [
        "ifx-layerguard",
        "registry-tests"
      ]
    },
    {
      "id": "Holdings",
      "pathPattern": "src/Modules/Holdings/**",
      "layer": "module",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Modules/Holdings",
      "focusedCommands": [
        "ifx-layerguard",
        "holdings-tests"
      ]
    },
    {
      "id": "Transaction",
      "pathPattern": "src/Modules/Transaction/**",
      "layer": "module",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Modules/Transaction",
      "focusedCommands": [
        "ifx-layerguard",
        "transaction-tests"
      ]
    },
    {
      "id": "Authentication",
      "pathPattern": "src/Platform/Authentication/**",
      "layer": "platform",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Platform/Authentication",
      "focusedCommands": [
        "ifx-layerguard",
        "authentication-tests"
      ]
    },
    {
      "id": "Authorization",
      "pathPattern": "src/Platform/Authorization/**",
      "layer": "platform",
      "owner": "xiaolong-feng",
      "similarImplementationRoot": "src/Platform/Authorization",
      "focusedCommands": [
        "ifx-layerguard",
        "authorization-tests"
      ]
    },
    {
      "id": "PlatformOther",
      "pathPattern": "src/Platform/**",
      "layer": "platform",
      "owner": "codeowners",
      "similarImplementationRoot": "src/Platform",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "Frontend",
      "pathPattern": "src/Frontend/**",
      "layer": "frontend",
      "owner": "codeowners",
      "similarImplementationRoot": "src/Frontend/IFX.FrontEnd/src",
      "focusedCommands": [
        "frontend-lint",
        "frontend-test"
      ]
    },
    {
      "id": "DatabaseMigrator",
      "pathPattern": "src/DatabaseMigrator/**",
      "layer": "database",
      "owner": "codeowners",
      "similarImplementationRoot": "src/DatabaseMigrator",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "BuildingBlocks",
      "pathPattern": "src/BuildingBlocks/**",
      "layer": "shared",
      "owner": "codeowners",
      "similarImplementationRoot": "src/BuildingBlocks",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "WebUI",
      "pathPattern": "src/WebUI/**",
      "layer": "web",
      "owner": "codeowners",
      "similarImplementationRoot": "src/WebUI",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "SourceConfig",
      "pathPattern": "src/*",
      "layer": "repository",
      "owner": "codeowners",
      "similarImplementationRoot": "src",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "Tests",
      "pathPattern": "tests/**",
      "layer": "test",
      "owner": "codeowners",
      "similarImplementationRoot": "tests",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "GuardPackage",
      "pathPattern": "docs/guards/V3_ifx/**",
      "layer": "tooling",
      "owner": "codeowners",
      "similarImplementationRoot": "docs/guards/V3_ifx",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "GuardDocs",
      "pathPattern": "docs/guards/**",
      "layer": "tooling",
      "owner": "codeowners",
      "similarImplementationRoot": "docs/guards",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "LayerGuardLegacy",
      "pathPattern": "mcp/LayerGuard/**",
      "layer": "tooling",
      "owner": "codeowners",
      "similarImplementationRoot": "mcp/LayerGuard",
      "focusedCommands": [
        "ifx-layerguard"
      ]
    },
    {
      "id": "GuardAuthorityInputs",
      "pathPattern": "docs/architecture/review/gates/**",
      "layer": "tooling",
      "owner": "codeowners",
      "similarImplementationRoot": "docs/architecture/review/gates",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "ArchitectureDocs",
      "pathPattern": "docs/architecture/**",
      "layer": "documentation",
      "owner": "codeowners",
      "similarImplementationRoot": "docs/architecture",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "RepositoryScripts",
      "pathPattern": "scripts/**",
      "layer": "tooling",
      "owner": "codeowners",
      "similarImplementationRoot": "scripts",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "Deployment",
      "pathPattern": "deployment/**",
      "layer": "deployment",
      "owner": "codeowners",
      "similarImplementationRoot": "deployment",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "CI",
      "pathPattern": ".github/**",
      "layer": "ci",
      "owner": "codeowners",
      "similarImplementationRoot": ".github",
      "focusedCommands": [
        "ifx-package-test"
      ]
    },
    {
      "id": "RepositoryConfig",
      "pathPattern": ".gitattributes",
      "layer": "repository",
      "owner": "codeowners",
      "similarImplementationRoot": ".github",
      "focusedCommands": [
        "ifx-package-test"
      ]
    }
  ],
  "riskTriggers": [
    {
      "id": "public-contract",
      "pathPattern": "src/**/IFX.*.Contracts/**",
      "reason": "Public contract or protocol change"
    },
    {
      "id": "database-migration",
      "pathPattern": "src/**/Migrations/**",
      "reason": "Database migration or schema change"
    },
    {
      "id": "database-migrator",
      "pathPattern": "src/DatabaseMigrator/**",
      "reason": "Database release boundary"
    },
    {
      "id": "identity-security",
      "pathPattern": "src/Modules/IAM/**",
      "reason": "IAM and tenant boundary"
    },
    {
      "id": "authentication",
      "pathPattern": "src/Platform/Authentication/**",
      "reason": "Authentication boundary"
    },
    {
      "id": "authorization",
      "pathPattern": "src/Platform/Authorization/**",
      "reason": "Authorization boundary"
    },
    {
      "id": "frontend-auth",
      "pathPattern": "src/Frontend/IFX.FrontEnd/src/**/auth/**",
      "reason": "Frontend sign-in and registration flow"
    },
    {
      "id": "frontend-auth-context",
      "pathPattern": "src/Frontend/IFX.FrontEnd/src/contexts/AuthContext.tsx",
      "reason": "Frontend authentication session context"
    },
    {
      "id": "messaging",
      "pathPattern": "src/Platform/Messaging/**",
      "reason": "Message delivery and contract boundary"
    },
    {
      "id": "dotnet-dependency",
      "pathPattern": "**/*.csproj",
      "reason": ".NET project or package dependency change"
    },
    {
      "id": "frontend-dependency",
      "pathPattern": "src/Frontend/**/package.json",
      "reason": "Frontend dependency or script change"
    },
    {
      "id": "frontend-lockfile",
      "pathPattern": "src/Frontend/**/package-lock.json",
      "reason": "Locked frontend dependency change"
    },
    {
      "id": "deployment",
      "pathPattern": "deployment/**",
      "reason": "Deployment and runtime boundary"
    },
    {
      "id": "gate-baseline",
      "pathPattern": "mcp/LayerGuard/baselines/**",
      "reason": "Architecture waiver baseline"
    },
    {
      "id": "layerguard-runtime",
      "pathPattern": "mcp/LayerGuard/**",
      "reason": "Legacy LayerGuard validator or test change"
    },
    {
      "id": "gate-input",
      "pathPattern": "docs/architecture/review/gates/**",
      "reason": "Gate authority or derived input"
    },
    {
      "id": "gate-validator",
      "pathPattern": "scripts/**",
      "reason": "Repository validation or operational script change"
    },
    {
      "id": "guard-rules",
      "pathPattern": "docs/guards/**",
      "reason": "Guard rules, scripts or profiles"
    },
    {
      "id": "gate-review-routing",
      "pathPattern": ".github/CODEOWNERS",
      "reason": "Required owner review routing"
    },
    {
      "id": "gate-line-endings",
      "pathPattern": ".gitattributes",
      "reason": "Checkout byte normalization"
    },
    {
      "id": "ci-workflow",
      "pathPattern": ".github/workflows/**",
      "reason": "CI enforcement configuration"
    }
  ]
}
```

## Desired stage rules

### ARCH.BINARY.DOMAIN.CONTRACTS.json

<!-- guard-config: rules/ARCH.BINARY.DOMAIN.CONTRACTS.json -->
```json
{
  "formatVersion": 1,
  "id": "ARCH.BINARY.DOMAIN.CONTRACTS",
  "title": "CRM Domain compiled entity types do not depend on CRM public contract types",
  "kind": "forbidden-type-dependency",
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "profiles/ifx/rules/L2.2.json (parallel compiled-type evidence)",
  "appliesTo": [
    "src/Modules/CRM/IFX.Modules.CRM.Domain/**"
  ],
  "sourceAssembly": "IFX.Modules.CRM.Domain",
  "sourceNamespace": "IFX.Modules.CRM.Domain.Entities",
  "forbiddenAssembly": "IFX.Modules.CRM.Contracts",
  "forbiddenNamespace": "IFX.Modules.CRM.Contracts.V1",
  "minimumMatches": 1
}
```

### ARCH.SEMANTIC.json

<!-- guard-config: rules/ARCH.SEMANTIC.json -->
```json
{
  "formatVersion": 1,
  "id": "ARCH.SEMANTIC",
  "title": "Semantic symbol ownership review",
  "kind": "none",
  "appliesTo": [
    "src/**/*.cs"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs"
}
```

### L1.2.json

<!-- guard-config: rules/L1.2.json -->
```json
{
  "formatVersion": 1,
  "id": "L1.2",
  "title": "No legacy Abstractions project",
  "kind": "none",
  "appliesTo": [
    "src/**/*.csproj"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L1.2] (blocking in Invoke-IFX)"
}
```

### L2.2.json

<!-- guard-config: rules/L2.2.json -->
```json
{
  "formatVersion": 1,
  "id": "L2.2",
  "title": "Domain projects must not reference Contracts projects",
  "kind": "forbidden-project-reference",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Domain/**"
  ],
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "policy/layerguard.json:allowedReferences.Domain",
  "sourcePattern": "src/Modules/*/IFX.Modules.*.Domain/*.csproj",
  "forbiddenTargetPattern": "**/*.Contracts/*.csproj",
  "negativeFixture": {
    "referenceInclude": "../IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj",
    "sourceProject": "src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj"
  }
}
```

### L2.3.json

<!-- guard-config: rules/L2.3.json -->
```json
{
  "formatVersion": 1,
  "id": "L2.3",
  "title": "Application does not depend on module Contracts",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Application/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L2.3] (blocking in Invoke-IFX)"
}
```

### L2.4.json

<!-- guard-config: rules/L2.4.json -->
```json
{
  "formatVersion": 1,
  "id": "L2.4",
  "title": "Adapters use registered provider Contracts",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.IntegrationAdapter/**",
    "src/Modules/*/IFX.Modules.*.Infrastructure/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L2.4] (blocking in Invoke-IFX)"
}
```

### L2.9.json

<!-- guard-config: rules/L2.9.json -->
```json
{
  "formatVersion": 1,
  "id": "L2.9",
  "title": "Unknown module ownership fails closed",
  "kind": "none",
  "appliesTo": [
    "src/Modules/**",
    "src/Platform/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L2.9] (blocking in Invoke-IFX)"
}
```

### L3.1.json

<!-- guard-config: rules/L3.1.json -->
```json
{
  "formatVersion": 1,
  "id": "L3.1",
  "title": "Contracts and events live in provider namespaces",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Contracts/**",
    "src/Modules/*/IFX.Modules.*.Events/**",
    "src/Platform/**/*.Contracts/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L3.1] (blocking in Invoke-IFX)"
}
```

### L3.4.json

<!-- guard-config: rules/L3.4.json -->
```json
{
  "formatVersion": 1,
  "id": "L3.4",
  "title": "Contracts exclude framework and transport implementation",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Contracts/**",
    "src/Platform/**/*.Contracts/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L3.4] (blocking in Invoke-IFX)"
}
```

### L3.5.json

<!-- guard-config: rules/L3.5.json -->
```json
{
  "formatVersion": 1,
  "id": "L3.5",
  "title": "Contracts do not contain implementation declarations",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Contracts/**",
    "src/Platform/**/*.Contracts/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L3.5] (blocking in Invoke-IFX)"
}
```

### L3.6.json

<!-- guard-config: rules/L3.6.json -->
```json
{
  "formatVersion": 1,
  "id": "L3.6",
  "title": "Integration payloads do not expose internal models",
  "kind": "none",
  "appliesTo": [
    "src/Modules/*/IFX.Modules.*.Contracts/**",
    "src/Modules/*/IFX.Modules.*.Events/**",
    "src/Platform/Messaging/**"
  ],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs[L3.6] (blocking in Invoke-IFX)"
}
```
