# CIQ-10 central package management and transitive dependency security

## Objective

Close CIQ-10 by moving active IFX application, test, and tool projects to NuGet Central Package Management, aligning the complete EF Core 8 package family and `dotnet-ef` on 8.0.31, and making transitive vulnerability auditing a repository-wide build policy.

## Scope and phases

1. **Central package baseline**
   - Add a root `Directory.Packages.props` for projects under `src`, `tests`, and `tools`.
   - Move existing direct package versions into the central file and preserve intentional differences with `VersionOverride`.
   - Limit non-EF upgrades to top-level dependencies whose direct or transitive high/critical advisories are proven by the repository-wide audit.
   - Add explicit CPM opt-outs below `docs` and `mcp`; V3 generated/template projects and LayerGuard fixtures are independently versioned test assets and must retain their embedded package declarations.
2. **EF Core patch alignment**
   - Set `Microsoft.EntityFrameworkCore`, `Relational`, `SqlServer`, `Design`, `Tools`, `InMemory`, and `Sqlite` to 8.0.31 in the central file.
   - Pin `dotnet-ef` 8.0.31 in the repository tool manifest and restore that manifest in the V3 database job.
   - Keep the repository on `net8.0`; do not combine this security patch with a framework or SqlClient major-version migration.
3. **Transitive audit policy and evidence**
   - Add a root `Directory.Build.props` that enables NuGet audit in `all` mode at `moderate` reporting severity and makes NU1903/NU1904 fatal.
   - Keep NU1603 fatal in the V3 solution restore and let the shared build policy own NuGet vulnerability severities.
   - Add a V3 package audit command that enumerates active tracked projects, records JSON results, and rejects high or critical direct or transitive advisories.
   - Extend V3 package tests to prevent removal of CPM, audit policy, and the audit invocation.
4. **Compatibility validation**
   - Restore, build, and test the solution in Release mode.
   - Run the V3 package, solution, database, architecture, and historical integrity checks.
   - Verify database boundary tests and migration artifact generation so the patch upgrade does not change the migration catalog or model snapshot behavior.

## Boundaries and risk decisions

- CIQ-10 fixes the shared top-level EF provider dependency graph. It must not add local direct references to Azure.Identity, Microsoft.Data.SqlClient, System.Formats.Asn1, System.IdentityModel.Tokens.Jwt, or System.Text.Json merely to override transitive versions.
- The existing ApiHost direct `Microsoft.Data.SqlClient` 5.2.2 reference remains unchanged unless compilation or usage analysis proves it redundant; it is outside the affected 5.1.1 dependency edge that triggered CIQ-10.
- Central Package Management is enabled for active product projects. `docs` and `mcp` retain local versions because their generated projects and negative fixtures intentionally model package/version violations.
- Non-EF versions are relocated without general normalization. The full audit additionally requires targeted upgrades for Hangfire, Testcontainers, and WireMock, plus explicit safe versions for Newtonsoft.Json, System.Net.Http, and System.Text.RegularExpressions where vulnerable transitive versions would otherwise remain. Broader package-version convergence is a separate maintenance concern.

## Implementation outcome

- Central Package Management now covers all 81 tracked projects under `src`, `tests`, and `tools`; `docs` and `mcp` explicitly opt out for generated projects and LayerGuard fixtures.
- The EF Core package family and repository `dotnet-ef` tool resolve to 8.0.31.
- The repository audit reports zero direct or transitive vulnerability findings across all 81 active projects.
- Release restore/build, the full solution test suite, V3 package validation, database migration checks, and V3 Solution quality all pass.

## Validation

- `dotnet restore IFX.sln --force-evaluate -warnaserror:NU1603`
- `dotnet build IFX.sln --configuration Release --no-restore`
- `dotnet test IFX.sln --configuration Release --no-build --no-restore`
- `./docs/guards/V3_ifx/quality/Invoke-IFXPackageAudit.ps1`
- `./docs/guards/V3_ifx/tests/Test-IFXPackage.ps1`
- `./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate Database`
- `./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Validate`

## Acceptance criteria

- Every active EF Core direct package resolves to 8.0.31 and the V3 database job installs `dotnet-ef` 8.0.31.
- Active projects restore through the root central package file without NU1008, NU1010, NU1603, NU1903, or NU1904.
- The tracked direct/transitive audit contains no high or critical advisory for active projects.
- Release build, solution tests, database boundary validation, migration artifact generation, and V3 guardrails pass without migration source changes.
