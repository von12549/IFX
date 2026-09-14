# Deploy Guardrails V3

Commands are PowerShell 7 commands run from the target repository root. `V3` is the copied package path; use an explicit output directory for an isolated capability test. The sample profile is synthetic and must be replaced before protecting real code.

## Prerequisites and configuration

Install PowerShell 7, Git, and an SDK matching `tech-stack.json`. Copy `docs/guards/V3/` into the target repository. Create a project-specific profile directory from `examples/minimal/`, replacing its project ID, tech stack, path patterns, risk triggers, and rule files. The optional [bootstrap Skill](skills/guard-bootstrap/SKILL.md) guides repository analysis; its findings still need real-code and violating-fixture verification. Do not copy production policies into the reusable default package. Review the [rule contract](contracts/rule.schema.json) and [coverage boundary](architecture/ARCHITECTURE.md).

## Generate and verify

The following sample commands deliberately target a disposable repository path; replace both paths for the real target. `-OutputDirectory` stays under V3 by default, but may point into an isolated test fixture. The generator refuses to write outside the target repository.

```powershell
$v3 = 'docs/guards/V3'
$profile = "$v3/examples/minimal"
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Validate -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Generate -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Check -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Test -ProfileDirectory $profile -TargetRoot .
```

`Validate` checks schemas, unique IDs, supported detectors and path safety. `Generate` writes a .NET xUnit project and a snapshot of the inputs. `Check` compares every generated file byte-for-byte without changing files; missing or extra generated files fail. `Test` runs `Check` and then `dotnet test`, including detector self-tests and the configured repository rule. Missing tooling or incomplete input is an error, never a pass. The generated project lives at `docs/guards/V3/generated/dotnet/` unless `-OutputDirectory` is supplied.

An isolated end-to-end synthetic test creates a disposable target repository and verifies compliant and violating project references, Plan risk checks and out-of-Plan Diff behavior:

```powershell
pwsh "$v3/tests/Test-V3.ps1"
```

If the local environment has a restricted user-level NuGet configuration, provide a readable package cache and project-local config. Set `NUGET_PACKAGES` to an existing cache and add `-NuGetConfig <repository-relative-config>` to `Test` or `Diff`. CI can use its normal NuGet configuration.

## Plan and Pre

For substantial or high-risk work, copy the [Plan pair](templates/plan/README.md) to a task directory. Keep the JSON and Markdown stems identical (`YYYYMMDD-short-slug`). List exact expected repository-relative paths, linked rule IDs, validation commands, and decisions. Run:

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlanPath 'docs/plans/20260914-example.plan.json'
```

Pre checks the Plan contract, its paths and risk/decision coverage. It cannot verify future code. The [hook adapter](hooks/README.md) calls the same command; installing it in an Agent host is optional.

After implementation, compare the final diff to the formal Plan:

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Diff -ProfileDirectory $profile -TargetRoot . -PlanPath 'docs/plans/20260914-example.plan.json' -BaseRef <base-commit>
```

For CI, also pass `-HeadRef <head-commit>`. Local Diff includes tracked working-tree changes and untracked files. A formal Plan's `plannedPaths` are exact paths, so expanding scope requires revising the Plan. Plan and linked decision files are allowed as part of their own change.

## Enable a hard merge gate

After the generated project passes both detector self-tests and a deliberate violating fixture, register a repository CI workflow that runs Validate, Check and Test against a clean checkout. Add a separate Diff step using the final base/head commits and the Plan scope. Register its job as a required check in repository protection. The current package does not install or change a workflow automatically; a generated project and a green local test alone do not block merges.

## Target-project capability trial

Create a target-specific profile **outside the reusable default profile** and generate into an isolated output directory. Compare discovered project references with the target's existing policy and detector reports; do not duplicate or replace their authority. Record unsupported rules as uncovered, then test compliant and deliberately violating fixtures. Keep trial inputs and outputs separate from the V3 source package so its default remains portable.
