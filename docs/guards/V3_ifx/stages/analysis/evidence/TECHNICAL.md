# Proposed technical gate design

Guard review status: DRAFT

Review target languages, commands, .NET gate framework, existing CI and independent validators. Edit the structured block for machine configuration; describe detector limits and CI activation decisions in prose.

## Candidate commands

| ID | Command | Working directory |
| --- | --- | --- |
| ifx-layerguard | pwsh -NoProfile -File docs/guards/V3_ifx/scripts/Invoke-IFX.ps1 -Mode Test | . |
| ifx-package-test | pwsh -NoProfile -File docs/guards/V3_ifx/tests/post/Test-IFXPackage.ps1 | . |
| iam-tests | dotnet test tests/IFX.Modules.IAM.Application.Tests | . |
| crm-tests | dotnet test tests/IFX.Modules.CRM.Application.Tests | . |
| registry-tests | dotnet test tests/IFX.Modules.Registry.Application.Tests | . |
| holdings-tests | dotnet test tests/IFX.Modules.Holdings.Application.Tests | . |
| transaction-tests | dotnet test tests/IFX.Modules.Transaction.Application.Tests | . |
| authentication-tests | dotnet test tests/IFX.Platform.Authentication.Tests | . |
| authorization-tests | dotnet test tests/IFX.Platform.Authorization.Tests | . |
| frontend-lint | npm run lint -- --max-warnings=0 | src/Frontend/IFX.FrontEnd |
| frontend-test | npm run test:run | src/Frontend/IFX.FrontEnd |

## Existing CI evidence

- `.github/workflows/v3-ifx-guardrails.yml`

## Desired tech stack

<!-- guard-config: tech-stack.json -->
```json
{
  "formatVersion": 1,
  "targetLanguages": [
    "C# / .NET 8 application",
    "TypeScript / React 19 frontend",
    "PowerShell 7 gate scripts"
  ],
  "commands": [
    {
      "id": "ifx-layerguard",
      "executable": "pwsh",
      "arguments": [
        "-NoProfile",
        "-File",
        "docs/guards/V3_ifx/scripts/Invoke-IFX.ps1",
        "-Mode",
        "Test"
      ],
      "workingDirectory": "."
    },
    {
      "id": "ifx-package-test",
      "executable": "pwsh",
      "arguments": [
        "-NoProfile",
        "-File",
        "docs/guards/V3_ifx/tests/post/Test-IFXPackage.ps1"
      ],
      "workingDirectory": "."
    },
    {
      "id": "iam-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Modules.IAM.Application.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "crm-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Modules.CRM.Application.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "registry-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Modules.Registry.Application.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "holdings-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Modules.Holdings.Application.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "transaction-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Modules.Transaction.Application.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "authentication-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Platform.Authentication.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "authorization-tests",
      "executable": "dotnet",
      "arguments": [
        "test",
        "tests/IFX.Platform.Authorization.Tests"
      ],
      "workingDirectory": "."
    },
    {
      "id": "frontend-lint",
      "executable": "npm",
      "arguments": [
        "run",
        "lint",
        "--",
        "--max-warnings=0"
      ],
      "workingDirectory": "src/Frontend/IFX.FrontEnd"
    },
    {
      "id": "frontend-test",
      "executable": "npm",
      "arguments": [
        "run",
        "test:run"
      ],
      "workingDirectory": "src/Frontend/IFX.FrontEnd"
    }
  ],
  "testProject": {
    "targetFramework": "net10.0",
    "framework": "xunit"
  },
  "assemblyGate": {
    "buildTarget": "src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj",
    "configuration": "Debug",
    "assemblies": [
      {
        "projectPath": "src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj",
        "assemblyPath": "src/Modules/CRM/IFX.Modules.CRM.Domain/bin/Debug/net8.0/IFX.Modules.CRM.Domain.dll",
        "assemblyName": "IFX.Modules.CRM.Domain"
      },
      {
        "projectPath": "src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj",
        "assemblyPath": "src/Modules/CRM/IFX.Modules.CRM.Contracts/bin/Debug/net8.0/IFX.Modules.CRM.Contracts.dll",
        "assemblyName": "IFX.Modules.CRM.Contracts"
      }
    ]
  }
}
```
