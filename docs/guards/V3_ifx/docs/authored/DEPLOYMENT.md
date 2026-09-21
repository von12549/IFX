# Deploy and run the IFX V3 guard package

Run PowerShell 7 commands from the IFX repository root. The required SDK is .NET 10, including support for the target's .NET 8 projects. The NuGet feed/cache must provide pinned `TngTech.ArchUnitNET` 0.13.4 for the stage compiled fixture. The package is already configured for IFX; no old guard file is read by the commands below.

The stable dispatcher is `commands/Invoke-IFXGuardrails.ps1`. Its modes write a schema-validated summary under `artifacts/guards/v3-ifx/`:

```powershell
pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Validate
pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Architecture
pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate G03
pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Quality -QualityTarget Assembly
pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode HistoricalIntegrity
```

Package code, configuration and generated projects are read from the copy the dispatcher runs from; target data is read from `-TargetRoot` (default: the repository containing the package). A trusted package copy outside the repository can therefore run against a checked-out head with `-TargetRoot <head>`. Domain authorities that detectors read are registered with their trust roles in `shared/authorities/authorities.json` and declared as trust-contract inputs in `stages/*/stage.json`; `Invoke-IFXManifestCheck.ps1` rejects an unregistered or undeclared read (Plan 06 D18).

## Trusted base execution

Plan 06 §11 requires CI verdicts to come from the base commit. `trusted-base/Invoke-IFXTrustedBase.ps1` must itself start from a clean worktree of the verified base SHA, created outside the head checkout. CI runs every required check this way: each job creates `$RUNNER_TEMP/guard-base` at the pull request base SHA (or the pushed commit) and runs the runner from there with `-GateId <check name>`. Run it locally the same way:

```powershell
git worktree add --detach $env:TEMP/guard-base <base-sha>
pwsh -NoProfile -File "$env:TEMP/guard-base/docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1" -TrustedBase -TargetRoot . -BaseSha <base-sha> -Mode Specialized -SpecializedGate G03 -GateId v3-specialized-g03
```

The public command forwards this explicitly trusted invocation to the internal base runner. The runner does the following:

1. Verifies the worktree's SHA, cleanliness and location.
2. Compares head domain authorities with base by their registered D18 roles (`Test-IFXDomainAuthorityCandidates.ps1`). A governing-policy change or a widened exception fails closed until P4 provides `weaken-policy`.
3. Regenerates the package projections from head authorities in a generation directory outside head and base.
4. Runs the dispatcher from that base-derived copy with head as `-TargetRoot`.
5. Builds the trusted guard projects with `GUARD_BUILD_ROOT` pointing into the generation directory, so their restore, build and test output never reaches head or base.
6. Writes `artifacts/guards/v3-ifx/trusted-base/summary-<mode>[-<gate>].json`, which includes the gate's trust type and guarantee, and checks that the base worktree is still clean.

The guarantee scope and the break-glass procedure are in `docs/authored/trusted-base.md`.

Trusted component changes are checked by `trusted-base/Test-IFXTrustedBaseCandidate.ps1` from the same base worktree, in the `v3-cross-platform-ubuntu-latest` job of every pull request once the base commit's `stages/ci/required-checks.json` declares `trustedBase.tcbCandidateVerification: active`. They need a base `change-trusted-base` authorization that the change PR deletes; see `stages/diff/authorizations/README.md`.

## CI activation lifecycle

`stages/ci/required-checks.json` is the machine authority for the 13 stable check names, trigger contract, trusted-base activation, cost controls and GitHub ruleset identity. The workflow candidate is rendered from `stages/ci/workflow.template.yml` plus the two stable values in `workflow.variables.json`; the CODEOWNERS guard routing is a managed block rendered from `codeowners.template`. `activation.json` maps both candidates to their activated targets.

```powershell
$deploy = 'docs/guards/V3/commands/Invoke-V3Deployment.ps1'
$activation = 'docs/guards/V3_ifx/stages/ci/activation.json'
pwsh -NoProfile -File $deploy -Mode Generate -ActivationPath $activation -TargetRoot .
pwsh -NoProfile -File $deploy -Mode Check -ActivationPath $activation -TargetRoot .
pwsh -NoProfile -File $deploy -Mode Preview -ActivationPath $activation -TargetRoot . -ReportPath artifacts/guards/v3-ifx/activation-preview.json
```

`Generate` writes only below `artifacts/generated/v3-ifx/activation/`. `Check` rejects template drift and runs the declared public CI-contract command, including schema, job DAG, stable check names, trusted-base first verdict entry and ruleset declaration. `Preview` is read-only; `legacy-equivalent` means the activated body is identical but predates the source-path/SHA header or managed-block markers. Installation is intentionally separate and requires an explicit acceptance switch:

```powershell
pwsh -NoProfile -File $deploy -Mode Install -ActivationPath $activation -TargetRoot . -AcceptDeployment
pwsh -NoProfile -File $deploy -Mode Verify -ActivationPath $activation -TargetRoot .
```

`Install` writes the exact generated workflow (with source path and composite SHA-256 header) and replaces only the marker-owned CODEOWNERS block, preserving all unmanaged lines. Do not use it merely because a candidate was generated: review `Preview`, obtain the required activation authorization, then install in a separate activation change. `Invoke-IFXCiContract.ps1 -Remote` remains GET-only and compares ruleset `23459908`, all 13 contexts, enforcement and strict up-to-date mode. It never writes remote settings.

`SpecializedGate` also accepts `G04`, `G05`, `Plan04`, `Database`, and `All`. `QualityTarget` accepts `Solution`, `Assembly`, `Frontend`, and `All`. Database validation requires the EF Core 8 CLI and Docker for the SQL Server Testcontainers matrix. Frontend validation runs `npm ci`, lint, `test:run`, and build.

```powershell
$v3 = 'docs/guards/V3_ifx'
$engine = 'docs/guards/V3'
$profileLayout = "$v3/shared/profile-layout.json"
$generation = Join-Path ([IO.Path]::GetTempPath()) 'v3-ifx-generation'
$stage = Join-Path $generation 'v3-ifx/gates/stage'
New-Item -ItemType Directory -Force -Path $generation | Out-Null

# Refresh runtime analysis and check human-readable generated docs.
pwsh -NoProfile -File "$engine/commands/Invoke-V3Setup.ps1" -Mode Analyze -TargetRoot . -PackageId v3-ifx -ProfileLayoutPath $profileLayout -EvidenceDirectory "$v3/stages/analysis/evidence" -ExcludePaths 'docs/guards/**'
pwsh -NoProfile -File "$engine/scripts/Invoke-V3Architecture.ps1" -Mode Review -TargetRoot . -AnalysisDirectory 'artifacts/guards/v3-ifx/analysis' -EvidenceDirectory "$v3/stages/analysis/evidence" -ProfileLayoutPath $profileLayout
pwsh -NoProfile -File "$engine/commands/Invoke-V3Docs.ps1" -Mode Check -TargetRoot . -ProfileLayoutPath $profileLayout -PackageDirectory $v3

# Recreate and byte-check the two independent .NET projects.
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Validate -ProfileLayoutPath $profileLayout -TargetRoot .
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Generate -ProfileLayoutPath $profileLayout -TargetRoot . -GenerationRoot $generation -PackageId v3-ifx -OutputDirectory $stage
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Check -ProfileLayoutPath $profileLayout -TargetRoot . -GenerationRoot $generation -PackageId v3-ifx -OutputDirectory $stage
pwsh -NoProfile -File "$v3/commands/Invoke-IFXArchitecture.ps1" -Mode Validate
pwsh -NoProfile -File "$v3/commands/Invoke-IFXArchitecture.ps1" -Mode Generate
pwsh -NoProfile -File "$v3/commands/Invoke-IFXArchitecture.ps1" -Mode Check

# Run the V3 detector self-tests/Post check and the full IFX LayerGuard tests/strict scan.
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Test -ProfileLayoutPath $profileLayout -TargetRoot . -GenerationRoot $generation -PackageId v3-ifx -OutputDirectory $stage
pwsh -NoProfile -File "$v3/commands/Invoke-IFXArchitecture.ps1" -Mode Test -ReportPath artifacts/guards/v3-ifx-layerguard.json
pwsh -NoProfile -File "$engine/tests/Test-V3.ps1"
pwsh -NoProfile -File "$engine/tests/Test-V3ArchUnit.ps1"
pwsh -NoProfile -File "$v3/tests/pre/Test-IFXPre.ps1"
pwsh -NoProfile -File "$v3/tests/post/Test-IFXPackage.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXTargetRootSeparation.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXDomainAuthorityCandidates.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXTrustedBase.ps1"
pwsh -NoProfile -File "$v3/tests/post/Test-IFXAssemblyGuard.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXAuthorityProjection.ps1"
pwsh -NoProfile -File "$v3/tests/post/Test-IFXSpecializedContracts.ps1"
pwsh -NoProfile -File "$v3/tests/post/Test-IFXHistoricalIntegrity.ps1"
pwsh -NoProfile -File "$v3/tests/ci/Test-CutoverPreservation.ps1"
pwsh -NoProfile -File "$v3/tests/ci/Test-IFXCiContract.ps1"
pwsh -NoProfile -File "$v3/tests/ci/Test-IFXDeployment.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXManifests.ps1"
pwsh -NoProfile -File "$engine/tests/Test-V3Tools.ps1"
pwsh -NoProfile -File "$v3/tests/support/Test-IFXTools.ps1"

# Read-only CI and manifest contracts (both also run inside Invoke-IFXGuardrails.ps1 -Mode Validate).
pwsh -NoProfile -File "$v3/commands/Invoke-IFXCiContract.ps1"
pwsh -NoProfile -File "$v3/commands/Invoke-IFXCiContract.ps1" -Remote   # GET only; requires an authenticated GitHub CLI
pwsh -NoProfile -File "$v3/engine/Invoke-IFXManifestCheck.ps1"          # internal diagnostic; Validate is the public surface
```

Analysis is a runtime review artifact, not an automatic policy migration. Inventory, proposal, generated profile and review reports are written only to `artifacts/guards/v3-ifx/analysis/`. Reviewed architecture and technical inputs live under `stages/analysis/evidence/`; update those authority files only with `maintenance/Update-IFXAnalysisEvidence.ps1 -Mode Preview`, followed by `-Mode Apply -AcceptAnalysisEvidence`. Frozen snapshots live under `stages/analysis/reports/`. Review never adopts either document as policy; explicit `Adopt -AcceptDocument` writes only a new legacy-layout profile and never overwrites the active authorities bound by `shared/profile-layout.json`.

Both IFX .NET gates build through the V3 trusted build baseline (`docs/guards/V3/build/`, Plan 06 D14): SDK from its `global.json`, packages only from its `NuGet.config`, explicit `V3.Build.props`, no `Directory.*` discovery, output under `artifacts/build/v3-ifx/{stage-gate,architecture-conformance}/`, locked restore against the reviewed lock files in `build/locks/`, and pre-/post-build import allowlist reports under `artifacts/guards/v3-ifx/build/`. A missing, edited or stale lock fails the gate. When a guard project's package references change, run `Invoke-V3.ps1 -Mode Test ... -LockMode Update` or `Invoke-IFX.ps1 -Mode Test -LockMode Update`, review the lock diff and commit it with the formal Plan. No `bin/` or `obj/` directory is written under `docs/guards`.

`Invoke-IFXGuardrails.ps1 -Mode Validate` runs profile validation, LayerGuard input validation, the Markdown view check (`profile-views`), the workflow/`stages/ci/required-checks.json` contract (`ci-contract`) and the Plan 06 manifest check (`manifest-check`), so stale views, undeclared or renamed CI jobs and trusted-component gaps fail in CI. `Invoke-IFXCiContract.ps1 -Remote` additionally compares the live ruleset (required contexts, strict mode, enforcement) and is run manually because it needs GitHub API access.

`Test-IFXTools.ps1` creates fresh analysis under `artifacts/`, checks reproducibility and proves that reviewed evidence, the active profile and independent policy remain unchanged. If IFX authority JSON changes, run Docs `Render` and then `Check`; profile views and the four aggregate documents are read-only and carry source roles plus a composite hash. Keep free-form rationale under `docs/authored/`. The profile view's coverage matrix is **V3 stage-only** and does not downgrade the separate independent Architecture Conformance policy.

`Invoke-IFX -Mode Validate` now also checks that the nine numbered stage rule IDs match `stages/post/policy/layerguard.json:ruleRefs` and that their authority markers point to the local policy. This catches ID drift, not semantic divergence. `-Mode Test` runs the independent .NET suite and then a strict scan of `src` using the local zero-entry baseline. `-Mode Scan` runs only the strict scan after checking generated files. Both fail on new/stale findings, policy-hash drift, missing bound files, or invalid G03/G04/G05 policy projections. `Test-IFXPackage.ps1` builds an isolated fixture without the old gate, proves a compliant scan, then requires rule-ID drift and an `L2.2` violation to fail and rejects a nonlocal policy binding. On a machine with a restricted user NuGet configuration, supply a repository-local `-NuGetConfig` and set `NUGET_PACKAGES` to a readable package cache; the scripts isolate `APPDATA` for that case.

For an ordinary low-risk edit, declare exact proposed paths and read `artifacts/guards/v3-pre.json` for areas, owners, applicable rules and suggested command IDs:

```powershell
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlannedPaths 'src/Modules/CRM/IFX.Modules.CRM.Domain/Example.cs'
```

For a substantial or risk-triggered task, create matching `YYYYMMDD-slug.md` and `YYYYMMDD-slug.plan.json` files using `examples/plan/`. Include a goal, acceptance criteria, exact paths, all affected area IDs, all applicable rule IDs, focused validation command IDs from `tech-stack.json`, and covering decisions. Then run:

```powershell
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlanPath docs/plans/YYYYMMDD-slug.plan.json
pwsh -NoProfile -File "$engine/commands/Invoke-V3.ps1" -Mode Diff -ProfileDirectory $profile -TargetRoot . -PlanPath docs/plans/YYYYMMDD-slug.plan.json -BaseRef <base-commit> -HeadRef <head-commit> -GenerationRoot $generation -PackageId v3-ifx -OutputDirectory $stage
```

Pre success is advisory and includes a profile-input SHA-256; it does not prove code or decision quality. For local working-tree Diff, omit `-HeadRef`; CI should supply both exact commits. The generated stage project handles Plan scope, its `L2.2` detector and the compiled CRM pilot. `Invoke-V3 -Mode Test` freshly builds the explicit CRM Domain/Contracts manifest in Debug, then writes `artifacts/guards/v3-assembly.json`. The pilot matched 12 Domain entity types and four public Contract types. The [all-module Inbound Adapter target](architecture/INBOUND-ADAPTER-TARGET.md) remains a separate future migration. Run `Invoke-IFX -Mode Test` as the full post-code architecture gate regardless of the Plan's selected paths.

`.github/workflows/v3-ifx-guardrails.yml` provides stable jobs for Diff, Architecture, five specialized gates, Solution, Assembly, Frontend and HistoricalIntegrity. It is the only guard workflow triggered by pull requests and main pushes. Diff requires exactly one changed formal `*.plan.json` and explicit PR base/head SHAs; it verifies both commits and their merge base before comparing the complete changed set with the Plan.

PR #26 runs `34978867655` and `34981819869` passed every V3 job before cleanup. Cleanup commit `2bab176` then passed all 13 V3 jobs on Linux and Windows in run `34990329905`, with no legacy workflow execution. GitHub ruleset `IFX V3 Required Checks` (`23459908`) is active for the default branch and `codex/guards-principles-plan`; it requires all 13 exact `v3-*` job names with strict up-to-date checking. Negative-control PR #27 added one undeclared path: run `34985968761` failed `v3-pre-diff`, and GitHub reported the PR as `BLOCKED`.

The seven legacy workflows, root validators, duplicate `src/layerguard.json` policy and non-V3 guard documentation are deleted. Their exact paths and restore point are recorded in `stages/analysis/evidence/legacy-deletion-manifest.json`. For rollback, create a review branch from the current commit and restore only the selected entries from commit `15b44e5c8cae5968b8cd43a9b4c2a9574727577b`; do not change or delete `mcp/LayerGuard`, its historical baselines, `docs/guards/plans`, or domain-owned authorities.
