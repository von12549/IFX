# Deploy Guardrails V3

Commands are PowerShell 7 commands run from the target repository root. `V3` is the copied package path; use an explicit output directory for an isolated capability test. The sample profile is synthetic and must be replaced before protecting real code.

## Prerequisites and configuration

Install PowerShell 7, Git, and an SDK matching `tech-stack.json`. Copy `docs/guards/V3/` into the target repository. Create a project-specific profile with `Init` (or copy `examples/minimal/`), then replace its project map, owners, nearby examples, focused commands, risks, tech stack and rules with reviewed facts. The [bootstrap Skill](skills/guard-bootstrap/SKILL.md) guides this review. Do not copy production policies into the reusable default package. Review the [rule contract](contracts/rule.schema.json) and [coverage boundary](architecture/ARCHITECTURE.md).

## Trusted build baseline

`build/` is the package-local build and security baseline (Plan 06 D14). `Invoke-V3.ps1 -Mode Test|Diff` builds the generated gate through `build/GuardBuild.psm1`, which runs `dotnet` from `build/` (so `build/global.json` selects the SDK), restores only from `build/NuGet.config`, imports `build/V3.Build.props` explicitly and disables every `Directory.Build.*`, `Directory.Packages.props` and `Directory.Solution.*` discovery. Output goes to `artifacts/build/<package>/stage-gate/`, never into the package tree.

Restore is locked: the reviewed lock file `<lock root>/<ProjectName>.packages.lock.json` must exist, must not change during restore, and must agree with `project.assets.json` and each package's content hash. The effective imports are checked before the build (`msbuild -pp`) and after it (MSBuild import log) against an allowlist of the SDK, `build/V3.Build.props`, restore-generated `*.nuget.g.props/targets` and locked packages; reports are written to `artifacts/guards/<package>/build/stage-gate/`. The lock root defaults to `build/locks/`; create or refresh a lock only as a reviewed change with `-LockMode Update`, and pass `-LockRoot` for disposable fixtures. `tests/Test-V3BuildBaseline.ps1` proves the package runs from an isolated copy surrounded by hostile host configuration.

## Initialize, analyze and review

`Init` refuses to overwrite an existing profile. It creates a schema-valid but unreviewed scaffold: a placeholder path and owner, one placeholder command and an advisory rule with no detector. Real source paths remain unmapped by Pre, and generated Post tests require a supported blocking rule. `Validate` therefore means the files are well formed, not that the guard is ready to protect code.

```powershell
$v3 = 'docs/guards/V3'
$profile = 'docs/guards/profiles/my-project'
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Setup.ps1" -Mode Init -TargetRoot . -ProfileDirectory $profile -ProjectId my-project -TargetFramework net10.0
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Setup.ps1" -Mode Analyze -TargetRoot . -OutputDirectory 'artifacts/guards/target-analysis' -ProfileDirectory $profile -ExcludePaths 'docs/guards/**'
```

`Analyze` inventories literal `.csproj` frameworks/references, package scripts, solution/build manifests, CI workflows and Agent/owner guidance. Its `inventory.json`, `INVENTORY.md` and `PROPOSAL.md` contain source paths and SHA-256 evidence. It also creates target-specific `ARCHITECTURE.md` and `TECHNICAL.md` drafts in the analysis directory; passing `-ProfileDirectory` seeds their structured blocks from the current profile. Without a profile, the draft uses explicitly unreviewed candidates. Repeat analysis refreshes evidence but preserves edited drafts. It does not evaluate MSBuild conditions, infer owners or create blocking rules. Adjust `-ExcludePaths` to omit copied packages and fixtures; the tool also skips transient `bin`, `obj`, `node_modules`, `artifacts` and `generated` directories.

Read the drafts as an architecture proposal. Revise the prose and the fenced JSON blocks for the intended profile, map, stage rules and technical commands. The deterministic reviewer parses **only the structured blocks**; an Agent or human must translate a prose-only architectural change into those blocks. It validates the proposal, checks source evidence freshness, compares the proposed profile to the current profile and reports unmapped projects, unsupported detector scope and observed forbidden direct references. It does not rewrite the current profile or independent policies.

```powershell
$analysis = 'artifacts/guards/target-analysis'
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Architecture.ps1" -Mode Review -TargetRoot . -AnalysisDirectory $analysis -ProfileDirectory $profile
```

Read `ARCHITECTURE-REVIEW.md` and `architecture-review.json`. When the proposal has a supported blocking detector, no placeholders, and both drafts have been reviewed, change each `Guard review status` line to `REVIEWED`, rerun Review, and explicitly adopt it into a **new** profile path. `Adopt` refuses to overwrite an existing profile. The `-AcceptDocument` switch records the choice to use the reviewed document proposal; it does not make the resulting gate active.

```powershell
$adopted = 'docs/guards/profiles/my-project-reviewed'
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Architecture.ps1" -Mode Adopt -TargetRoot . -AnalysisDirectory $analysis -ProfileDirectory $profile -DestinationProfileDirectory $adopted -AcceptDocument
$profile = $adopted
```

Run the normal Validate/Generate/Check/Test commands below with this new profile. Review observed violations and add independent detectors where the V3 stage has only partial coverage. The package-level `architecture/` files remain reusable design references; the analysis drafts are target-specific proposed inputs.

## Markdown configuration views

After reviewing JSON, render a readable index, project map, tech stack, rules and **V3 stage-only** coverage matrix. JSON remains the machine authority. Tables are generated summaries; edit the fenced JSON block for semantic changes. `Import` previews changes without writing. `-Apply` requires that the Markdown source hash still matches current JSON, validates the schema and full profile, rolls back a failed import, then re-renders. Put free-form reasoning in a separate `notes/` directory outside `views/`.

```powershell
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Docs.ps1" -Mode Render -TargetRoot . -ProfileDirectory $profile
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Docs.ps1" -Mode Check -TargetRoot . -ProfileDirectory $profile
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Docs.ps1" -Mode Import -TargetRoot . -ProfileDirectory $profile
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Docs.ps1" -Mode Import -TargetRoot . -ProfileDirectory $profile -Apply
```

`Check` fails for a missing, changed or extra view. `Render` writes the profile's `views/` directory; rerun it after editing JSON. Import reads only the structured JSON blocks, not table or prose edits. The original profile README and notes remain manually editable.

## Generate and verify

Run the following commands with a reviewed project-specific profile. For a synthetic smoke test, set `$profile` to `"$v3/examples/minimal"` in a disposable repository. `-OutputDirectory` stays under V3 by default, but may point into an isolated test fixture. The generator refuses to write outside the target repository, or outside `-GenerationRoot` when the package runs from a trusted copy outside the target; the target is still read only from `-TargetRoot`.

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Validate -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Generate -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Check -ProfileDirectory $profile -TargetRoot .
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Test -ProfileDirectory $profile -TargetRoot .
```

`Validate` checks schemas, unique IDs, command/area references, supported detectors, required negative fixtures and path safety. `Generate` writes a .NET xUnit project and a snapshot of the inputs, including the project map. `Check` compares every generated file byte-for-byte without changing files; missing or extra generated files fail. `Test` runs `Check` and then `dotnet test`, including per-rule detector self-tests and the configured repository rule. A blocking rule that matches no source project fails. Missing tooling or incomplete input is an error, never a pass. The generated project lives at `docs/guards/V3/generated/dotnet/` unless `-OutputDirectory` is supplied.

For the optional [ArchUnitNET detector](architecture/ARCHUNITNET.md), add `assemblyGate` to `tech-stack.json` and one or more compiled-rule JSON files. Example paths are relative to the target repository; list **each assembly whose types are checked**. The generated test project adds pinned `TngTech.ArchUnitNET` 0.13.4 only in this case. `Test` builds `buildTarget` and each listed `.csproj` in Debug with `--no-incremental`, then checks exact DLL identities and namespaces. Use `Invoke-V3 -Mode Test` rather than invoking the generated test project directly. Its report is `artifacts/guards/v3-assembly.json`; a missing assembly, interface, source type, target type or implementation fails closed.

```json
"assemblyGate": {
  "buildTarget": "src/App/App.csproj",
  "configuration": "Debug",
  "assemblies": [
    { "projectPath": "src/App/App.csproj", "assemblyPath": "src/App/bin/Debug/net10.0/App.dll", "assemblyName": "App" },
    { "projectPath": "src/Ports/Ports.csproj", "assemblyPath": "src/Ports/bin/Debug/net10.0/Ports.dll", "assemblyName": "Ports" }
  ]
}
```

The full rule fields and exact-namespace semantics are in the [rule guide](rules/README.md). The target's SDK must support its own projects and the generated xUnit target framework. The NuGet feed or local cache must provide the pinned ArchUnitNET package. A new or renamed target project must be added to the manifest explicitly; adjacency in `bin/` does not expand checked scope.

An isolated end-to-end synthetic test creates a disposable target repository. It verifies compliant and violating project references, Plan risk checks, out-of-Plan Diff behavior, committed-range and empty-diff handling, protected deletions and renames, and authorization consumption. Guard projects restore through `build/NuGet.config` (D21):

```powershell
pwsh "$v3/tests/Test-V3.ps1"
pwsh "$v3/tests/Test-V3Tools.ps1"
pwsh "$v3/tests/Test-V3ArchUnit.ps1"
```

If the local environment has a restricted user-level NuGet configuration, provide a readable package cache and project-local config. Set `NUGET_PACKAGES` to an existing cache and add `-NuGetConfig <repository-relative-config>` to `Test` or `Diff`. CI can use its normal NuGet configuration.

## Plan and Pre

For an ordinary low-risk edit, provide exact planned paths and read `artifacts/guards/v3-pre.json` for areas, owners, applicable rules and suggested command IDs:

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlannedPaths 'src/App/Program.cs'
```

For substantial or risk-triggered work, copy the [Plan pair](templates/plan/README.md) to a task directory. Keep the JSON and Markdown stems identical (`YYYYMMDD-short-slug`). List exact expected repository-relative paths, affected area IDs, all applicable rule IDs, focused validation command IDs, and decisions. Run:

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlanPath 'docs/plans/20260914-example.plan.json'
```

Pre blocks unmapped paths, omitted area/rule/command associations and risk-triggered paths without a covering decision. Summary mode blocks risk paths until a formal Plan exists. Its JSON report follows `contracts/pre-result.schema.json`, carries a SHA-256 of the selected profile inputs, and is advisory on success; it cannot verify future code. Use `-ReportPath` to change the repository-relative report location. The [hook adapter](hooks/README.md) calls the same command; installing it in an Agent host is optional.

After implementation, compare the final diff to the formal Plan:

```powershell
pwsh "$v3/scripts/Invoke-V3.ps1" -Mode Diff -ProfileDirectory $profile -TargetRoot . -PlanPath 'docs/plans/20260914-example.plan.json' -BaseRef <base-commit>
```

For CI, also pass `-HeadRef <head-commit>`. Local Diff includes tracked working-tree changes and untracked files. A formal Plan's `plannedPaths` are exact paths, so expanding scope requires revising the Plan. Plan and linked decision files are allowed as part of their own change.

With `-HeadRef`, Diff verifies both commits and compares from their merge base. An empty changed set fails closed, because it usually means wrong refs or incomplete history.

Protected paths come from a Diff protection configuration: `-ProtectionPath`, or by default the package's `stages/diff/protection.json`. Its schema is `contracts/protection.schema.json`. The configuration fields work as follows:

- `protectedPaths`: entries ending in `/` protect a directory prefix, and other entries protect one exact path. Matching ignores case. Diff reads changes without rename detection, so deleting or renaming a protected path fails, and so does a gitlink at a protected path.
- `authorizationDirectory`: names where a trusted verifier looks for authorization records.

A committed Diff exempts a protected deletion only through a protected change report named by `GUARD_PROTECTED_CHANGES` (schema `protected-change-report.schema.json` in the IFX package). The report must:

- have status `pass`;
- be bound to the verified base commit, merge base, head commit and the SHA-256 of the protection configuration file.

Diff then exempts exactly the report's `allowedDeletions`, and fails if any of them was not deleted. A report that does not match fails Diff instead of being ignored. Uncommitted Diff runs never honour a report. Only a trusted base runner should produce the report, after verifying base authorizations; a report written by the change itself is not evidence.

Without a configuration nothing is protected.

## Enable a hard merge gate

After the generated project passes both detector self-tests and a deliberate violating fixture, register a repository CI workflow that runs Validate, Markdown `Check`, generated-project `Check` and Test against a clean checkout. Add a separate Diff step using the final base/head commits and the Plan scope. Register its job as a required check in repository protection. The current package does not install or change a workflow automatically; a generated project and a green local test alone do not block merges.

## Target-project capability trial

Create a target-specific profile **outside the reusable default profile** and generate into an isolated output directory. Compare discovered project references with the target's existing policy and detector reports; do not duplicate or replace their authority. Record unsupported rules as uncovered, then test compliant and deliberately violating fixtures. Keep trial inputs and outputs separate from the V3 source package so its default remains portable.
