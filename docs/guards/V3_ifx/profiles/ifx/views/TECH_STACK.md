# Tech stack

Generated view of `tech-stack.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: tech-stack.json sha256: 94c15db893ba44f90e4b1410ee16fe4b30f765287012fb988d181477d4525b7d -->

| Languages | .NET gate target | Framework |
| --- | --- | --- |
| C# / .NET 8 application, TypeScript / React 19 frontend, PowerShell 7 gate scripts | net10.0 | xunit |

## Commands

| ID | Executable | Arguments | Working directory |
| --- | --- | --- | --- |
| ifx-layerguard | pwsh | -NoProfile, -File, docs/guards/V3_ifx/scripts/Invoke-IFX.ps1, -Mode, Test | . |
| ifx-package-test | pwsh | -NoProfile, -File, docs/guards/V3_ifx/tests/Test-IFXPackage.ps1 | . |
| iam-tests | dotnet | test, tests/IFX.Modules.IAM.Application.Tests | . |
| crm-tests | dotnet | test, tests/IFX.Modules.CRM.Application.Tests | . |
| registry-tests | dotnet | test, tests/IFX.Modules.Registry.Application.Tests | . |
| holdings-tests | dotnet | test, tests/IFX.Modules.Holdings.Application.Tests | . |
| transaction-tests | dotnet | test, tests/IFX.Modules.Transaction.Application.Tests | . |
| authentication-tests | dotnet | test, tests/IFX.Platform.Authentication.Tests | . |
| authorization-tests | dotnet | test, tests/IFX.Platform.Authorization.Tests | . |
| frontend-lint | npm | run, lint | src/Frontend/IFX.FrontEnd |
| frontend-test | npm | run, test:run | src/Frontend/IFX.FrontEnd |

```json
{
  "formatVersion": 1,
  "targetLanguages": [
    "C# / .NET 8 application",
    "TypeScript / React 19 frontend",
    "PowerShell 7 gate scripts"
  ],
  "commands": [
    { "id": "ifx-layerguard", "executable": "pwsh", "arguments": ["-NoProfile", "-File", "docs/guards/V3_ifx/scripts/Invoke-IFX.ps1", "-Mode", "Test"], "workingDirectory": "." },
    { "id": "ifx-package-test", "executable": "pwsh", "arguments": ["-NoProfile", "-File", "docs/guards/V3_ifx/tests/Test-IFXPackage.ps1"], "workingDirectory": "." },
    { "id": "iam-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Modules.IAM.Application.Tests"], "workingDirectory": "." },
    { "id": "crm-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Modules.CRM.Application.Tests"], "workingDirectory": "." },
    { "id": "registry-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Modules.Registry.Application.Tests"], "workingDirectory": "." },
    { "id": "holdings-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Modules.Holdings.Application.Tests"], "workingDirectory": "." },
    { "id": "transaction-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Modules.Transaction.Application.Tests"], "workingDirectory": "." },
    { "id": "authentication-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Platform.Authentication.Tests"], "workingDirectory": "." },
    { "id": "authorization-tests", "executable": "dotnet", "arguments": ["test", "tests/IFX.Platform.Authorization.Tests"], "workingDirectory": "." },
    { "id": "frontend-lint", "executable": "npm", "arguments": ["run", "lint"], "workingDirectory": "src/Frontend/IFX.FrontEnd" },
    { "id": "frontend-test", "executable": "npm", "arguments": ["run", "test:run"], "workingDirectory": "src/Frontend/IFX.FrontEnd" }
  ],
  "testProject": {
    "targetFramework": "net10.0",
    "framework": "xunit"
  }
}
```
