# Deploy and run the IFX V3 guard package

Run PowerShell 7 commands from the IFX repository root. The required SDK is .NET 10. The package is already configured for IFX; no old guard file is read by the commands below.

```powershell
$v3 = 'docs/guards/V3_ifx'
$profile = "$v3/profiles/ifx"

# Refresh evidence and check human-readable profile views.
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Setup.ps1" -Mode Analyze -TargetRoot . -OutputDirectory "$v3/analysis/ifx" -ExcludePaths 'docs/guards/**'
pwsh -NoProfile -File "$v3/scripts/Invoke-V3Docs.ps1" -Mode Check -TargetRoot . -ProfileDirectory $profile

# Recreate and byte-check the two independent .NET projects.
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Validate -ProfileDirectory $profile -TargetRoot . -OutputDirectory "$v3/generated/stages"
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Generate -ProfileDirectory $profile -TargetRoot . -OutputDirectory "$v3/generated/stages"
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Check -ProfileDirectory $profile -TargetRoot . -OutputDirectory "$v3/generated/stages"
pwsh -NoProfile -File "$v3/scripts/Invoke-IFX.ps1" -Mode Validate
pwsh -NoProfile -File "$v3/scripts/Invoke-IFX.ps1" -Mode Generate
pwsh -NoProfile -File "$v3/scripts/Invoke-IFX.ps1" -Mode Check

# Run the V3 detector self-tests/Post check and the full IFX LayerGuard tests/strict scan.
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Test -ProfileDirectory $profile -TargetRoot . -OutputDirectory "$v3/generated/stages"
pwsh -NoProfile -File "$v3/scripts/Invoke-IFX.ps1" -Mode Test -ReportPath artifacts/guards/v3-ifx-layerguard.json
pwsh -NoProfile -File "$v3/tests/Test-V3.ps1"
pwsh -NoProfile -File "$v3/tests/Test-IFXPre.ps1"
pwsh -NoProfile -File "$v3/tests/Test-IFXPackage.ps1"
pwsh -NoProfile -File "$v3/tests/Test-V3Tools.ps1"
pwsh -NoProfile -File "$v3/tests/Test-IFXTools.ps1"
```

The analysis result is a review artifact, not an automatic policy migration. It inventories literal project declarations, workflows and guidance with SHA-256 evidence; `docs/guards/**` excludes the copied V3 packages and their fixtures. `Test-IFXTools.ps1` checks reproducibility, the existing LayerGuard project and CI workflow, unchanged independent policy, and the V3 stage coverage view. If IFX profile JSON changes, run `Invoke-V3Docs.ps1 -Mode Render` and then `-Mode Check`. To propose a semantic change from Markdown, edit only a fenced JSON block, run `-Mode Import` for a dry preview, then `-Mode Import -Apply`; source-hash conflicts and invalid profiles fail. Keep free-form rationale outside `views/`. The profile view's coverage matrix is **V3 stage-only** and does not downgrade the separate independent LayerGuard policy.

`Invoke-IFX -Mode Test` runs the independent .NET suite and then a strict scan of `src` using the local zero-entry baseline. `-Mode Scan` runs only the strict scan after checking generated files. Both fail on new/stale findings, policy-hash drift, missing bound files, or invalid G03/G04/G05 policy projections. `Test-IFXPackage.ps1` builds an isolated fixture without the old gate, proves a compliant scan, then requires an `L2.2` violation and rejects a nonlocal policy binding. On a machine with a restricted user NuGet configuration, supply a repository-local `-NuGetConfig` and set `NUGET_PACKAGES` to a readable package cache; the scripts isolate `APPDATA` for that case.

For an ordinary low-risk edit, declare exact proposed paths and read `artifacts/guards/v3-pre.json` for areas, owners, applicable rules and suggested command IDs:

```powershell
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlannedPaths 'src/Modules/CRM/IFX.Modules.CRM.Domain/Example.cs'
```

For a substantial or risk-triggered task, create matching `YYYYMMDD-slug.md` and `YYYYMMDD-slug.plan.json` files using `templates/plan/`. Include a goal, acceptance criteria, exact paths, all affected area IDs, all applicable rule IDs, focused validation command IDs from `tech-stack.json`, and covering decisions. Then run:

```powershell
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Pre -ProfileDirectory $profile -TargetRoot . -PlanPath docs/plans/YYYYMMDD-slug.plan.json -OutputDirectory "$v3/generated/stages"
pwsh -NoProfile -File "$v3/scripts/Invoke-V3.ps1" -Mode Diff -ProfileDirectory $profile -TargetRoot . -PlanPath docs/plans/YYYYMMDD-slug.plan.json -BaseRef <base-commit> -HeadRef <head-commit> -OutputDirectory "$v3/generated/stages"
```

Pre success is advisory and includes a profile-input SHA-256; it does not prove code or decision quality. For local working-tree Diff, omit `-HeadRef`; CI should supply both exact commits. The generated stage project handles Plan scope and its own `L2.2` detector. Run `Invoke-IFX -Mode Test` as the full post-code architecture gate regardless of the Plan's selected paths.

To activate this as a merge gate, add a CI job that runs Markdown `Check`, both generated-project `Check` commands, both `Test` commands, and `Diff` with the PR base/head commits in a clean checkout, then mark the job required in repository protection. Until that setup is verified, a local pass is evidence only; it does not block merges. Keep the existing specialized jobs active during this parallel migration.
