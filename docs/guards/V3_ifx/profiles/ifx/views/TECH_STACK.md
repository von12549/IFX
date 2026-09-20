# Tech stack

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `aacf4ce253cd4a2e2fd25b95938d3fdde15ed1567f38843ae73b75abe4c755a9`

Sources:

- `docs/guards/V3_ifx/shared/toolchain.json` — authority

| Languages | .NET gate target | Framework |
| --- | --- | --- |
| C# / .NET 8 application, TypeScript / React 19 frontend, PowerShell 7 gate scripts | net10.0 | xunit |

## Commands

| ID | Executable | Arguments | Working directory |
| --- | --- | --- | --- |
| ifx-layerguard | pwsh | -NoProfile, -File, docs/guards/V3_ifx/scripts/Invoke-IFX.ps1, -Mode, Test | . |
| ifx-package-test | pwsh | -NoProfile, -File, docs/guards/V3_ifx/tests/post/Test-IFXPackage.ps1 | . |
| iam-tests | dotnet | test, tests/IFX.Modules.IAM.Application.Tests | . |
| crm-tests | dotnet | test, tests/IFX.Modules.CRM.Application.Tests | . |
| registry-tests | dotnet | test, tests/IFX.Modules.Registry.Application.Tests | . |
| holdings-tests | dotnet | test, tests/IFX.Modules.Holdings.Application.Tests | . |
| transaction-tests | dotnet | test, tests/IFX.Modules.Transaction.Application.Tests | . |
| authentication-tests | dotnet | test, tests/IFX.Platform.Authentication.Tests | . |
| authorization-tests | dotnet | test, tests/IFX.Platform.Authorization.Tests | . |
| frontend-lint | npm | run, lint, --, --max-warnings=0 | src/Frontend/IFX.FrontEnd |
| frontend-test | npm | run, test:run | src/Frontend/IFX.FrontEnd |
