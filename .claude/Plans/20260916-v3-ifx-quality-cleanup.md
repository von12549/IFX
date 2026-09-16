# V3_ifx quality backlog cleanup

## Objective

Resolve CIQ-01 through CIQ-10 from `docs/guards/plans/TODO.md`, strengthen the V3 quality gate after the warning baseline is clean, and record an evidence-based disposition for the upstream-only CIQ-09 warning.

## Scope and phases

1. **Dependency security and deterministic restore (CIQ-01–CIQ-04)**
   - Upgrade all five AutoMapper consumers to 15.1.3, remove the discontinued DI package, adapt registration to the current API, and validate every mapping profile.
   - Align Transaction and Holdings MemoryCache with 8.0.1.
   - Pin Cognito to the verified 3.7.402.11 package.
   - Refresh frontend packages within declared compatible ranges, preserve full and production-only audit reports as CI artifacts, and require zero high/critical findings.
2. **Application and frontend warning cleanup (CIQ-05–CIQ-07)**
   - Retire password processing from `POST /api/v1/auth/login` while retaining an explicit `410 Gone` compatibility response that directs callers to the OAuth authorization endpoint.
   - Reject successful-but-incomplete refresh responses, normalize missing IP addresses to `Unknown`, and test both behaviors.
   - Stabilize the four page reload callbacks and test tenant/route changes without duplicate requests.
3. **Regression gates (CIQ-08)**
   - Make NU1603 and NU1903 fatal during restore, make any ESLint warning fatal, and run the full npm audit at high severity.
   - Add V3 package tests that mechanically assert these checks remain in the quality runner.
4. **Upstream action tracking (CIQ-09)**
   - Recheck the current `actions/download-artifact` release and upstream issue.
   - Keep the current latest major if no fixed release exists; record owner, review date, evidence, and the rule against suppressing Node warnings.
5. **Central package security (CIQ-10)**
   - Move active product, test, and tool projects to NuGet Central Package Management while keeping generated documentation projects and LayerGuard fixtures independently versioned.
   - Align the EF Core package family and repository `dotnet-ef` tool on 8.0.31.
   - Remediate the additional high/critical Hangfire, Testcontainers, WireMock, Newtonsoft.Json, System.Net.Http, and System.Text.RegularExpressions dependency chains proven by the full audit.
   - Run a direct/transitive audit for all active projects and make high or critical advisories blocking in V3 Solution quality.

## Security and compatibility decisions

- AutoMapper 15.1.3 is a fixed release above the backlog minimum and keeps Microsoft.Extensions dependencies on the repository's .NET 8 line. AutoMapper 16.1.1 was rejected after restore proved it requires Microsoft.Extensions 10 and creates NU1605 downgrades. The DI API is in the core package. License discovery remains external through `AUTOMAPPER_LICENSE_KEY` or `LUCKYPENNY_LICENSE_KEY`; no key or suppression is committed.
- Cognito remains on the 3.7 API line to avoid an unrelated AWS SDK v4 migration.
- The legacy login route no longer accepts or processes credentials. A stable 410 response avoids silently changing POST semantics or redirecting a credential-bearing request.
- npm updates stay inside the existing major-version declarations unless a direct dependency must be raised to a patched compatible release.
- Central Package Management is the version authority for active projects. V3 generated projects and fixtures opt out where their local versions are part of the test contract.

## Validation

- `dotnet restore IFX.sln --force-evaluate -warnaserror:NU1603,NU1903`
- `dotnet build IFX.sln --configuration Release --no-restore`
- `dotnet test IFX.sln --configuration Release --no-build --no-restore`
- `npm ci`
- `npm audit --audit-level=high`
- `npm run lint -- --max-warnings=0`
- `npm run test:run`
- `npm run build`
- `./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Validate`
- `./docs/guards/V3_ifx/quality/Invoke-IFXPackageAudit.ps1`
- `./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate Database`
- V3 Pre/Diff, package tests, architecture, quality, specialized, and historical integrity checks.
