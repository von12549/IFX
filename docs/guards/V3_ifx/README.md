# IFX Guardrails V3 migration package

Pre now accepts an ordinary path summary or a formal Plan. `shared/profile-layout.json` binds the split authorities: `stages/pre/project-map.json` classifies paths into areas, owners, examples, focused validation commands and risk triggers, while `stages/post/rules/*.json` declares applicability for all nine numbered LayerGuard rules. A successful Pre result is advisory and written under `artifacts/guards/` with a profile-input hash. Risk paths require a formal Plan and covering decision. Unknown modules remain unmapped and fail closed.

`V3_ifx` is the IFX overlay on the canonical portable `V3` source package. The redundant `V3_backup` snapshot was retired in Plan 06 P10.5; recovery uses Git history. This directory owns IFX profile and policy, guard orchestration, architecture scanning, specialized validation, compiled assembly checks, solution/frontend quality and frozen-history integrity. Its production architecture command does not invoke `mcp/LayerGuard` or root guard scripts. GitHub ruleset `IFX V3 Required Checks` requires all 13 stable V3 jobs on the default branch and `codex/guards-principles-plan`. The replaced workflows, root validators, duplicate policy and non-V3 guard documentation were removed after the required-check cutover.

Analysis writes inventory, proposal and review output only to `artifacts/guards/v3-ifx/analysis/`. Reviewed [target architecture](stages/analysis/evidence/ARCHITECTURE.md) and [technical](stages/analysis/evidence/TECHNICAL.md) inputs are long-lived evidence updated only through the maintenance Preview/Apply command. The [profile views](profiles/ifx/views/README.md) and [aggregate docs](docs/generated/OVERVIEW.md) are read-only generated Markdown. JSON remains authoritative; the coverage view deliberately describes only the narrow stage runner, while the independent Architecture Conformance gate retains its own policy.

## What is enforced

The V3 stage runner maps an ordinary path summary or validates a formal Plan before coding. CI Diff resolves explicit base/head commits, requires a real merge base and nonempty changed set, includes both sides of renames, and rejects undeclared paths and protected guard deletion. Its IFX profile maps all nine numbered LayerGuard rule IDs to applicable paths. The independent IFX LayerGuard project remains the complete architecture detector: layer and ownership boundaries, direct/transitive references, package/import/source rules, declaration and payload rules, Gate bindings, and the strict zero-entry Plan 05 baseline.

The G03/G04/G05 files under `policy/` are deterministic LayerGuard projections. `policy/authorities.json` identifies their domain-owned sources, and `maintenance/Sync-IFXPolicyInputs.ps1` previews, applies or checks LF-normalized local copies and binding hashes with explicit acceptance for writes. Specialized detectors live under `stages/post/gates/specialized/`; they write reports under `artifacts/guards/v3-ifx/` and do not repeat LayerGuard or full solution tests. `stages/post/gates/quality/` owns the one-time solution regression, all five compiled Domain assembly boundaries, and frontend install/lint/test/build. `stages/post/gates/historical-integrity/` protects frozen Plan00/B1/B4 and LayerGuard baselines without treating their old blocker counts or next-step text as current readiness; regeneration is an explicit Preview/Apply operation under `maintenance/`.

## Directory and editing contract

| Path | Purpose |
| --- | --- |
| `shared/profile-layout.json` | Exact binding for the split profile, project-map, toolchain, rules and generated-view locations |
| `shared/profile.json`, `shared/toolchain.json` | Shared identity and command/assembly authority |
| `stages/pre/project-map.json` | Pre path, owner, risk and focused-command authority |
| `stages/post/rules/` | Stage rule applicability, project-reference detector and compiled CRM boundary pilot |
| `profiles/ifx/views/` | Generated Markdown index, map, tech stack, rule pages and V3 stage coverage |
| `stages/analysis/evidence/`, `reports/` | Reviewed long-lived inputs and frozen report snapshots; runtime output is under `artifacts/guards/v3-ifx/analysis/` |
| `policy/layerguard.json` | Editable IFX architecture rules, copied from the existing policy with only the three Gate paths made local |
| `policy/g03/`, `policy/g04/`, `policy/g05/` | Local policy facts and G04-bound artifacts; edit together with their verified hashes |
| `policy/baselines/plan05.json` | Local strict baseline, bound to the composite policy hash; never silently update after a rule edit |
| `policy/authorities.json` | Registry of editable domain authorities and deterministic V3 projections |
| `stages/post/gates/specialized/` | V3-owned G03, G04, G05, Plan04 and Database runners and detectors |
| `stages/post/gates/quality/` | Solution, five-module compiled Domain assembly and frontend quality runners |
| `history/` | Frozen evidence manifest, validator and explicit regeneration command |
| `templates/ifx-layerguard/` | The IFX policy binding and host (`src/LayerGuard.Ifx`) and the IFX binding tests with their own fixture; the generic engine, its tests and their synthetic fixtures live in `../V3/stages/post/gates/architecture/dotnet/` |
| external generation root | Untracked IFX Stage Gate at `<generation-root>/v3-ifx/gates/stage/Ifx.Guards.StageGate.Tests/` |
| `contracts/`, `templates/plan/`, `skills/` | IFX input contracts and optional Agent planning integration; generic hooks and templates live in `../V3/` |
| `scripts/Invoke-IFX.ps1` | Check, test, and strict-scan the IFX LayerGuard projects directly from `templates/ifx-layerguard/`; the scan runs the IFX host, which registers the IFX policy binding; `Generate` is read-only during the transition |
| `scripts/Invoke-IFXGuardrails.ps1` | Stable Validate/Pre/Diff/Architecture/Specialized/Quality/HistoricalIntegrity/All dispatcher |
| `commands/` | Stable public command entry points; legacy `scripts/` paths are deprecation wrappers |

Agent workflow: read this README and [deployment commands](DEPLOYMENT.md), compare the architecture drafts with evidence and current profile, then edit a reviewed profile or local policy. Review changed rules and bound hashes, regenerate both projects, run Check, run positive/negative tests and strict scan, then run Pre/Diff against the task Plan. `Invoke-IFX -Mode Validate` checks the nine numbered stage/policy rule IDs for drift. A policy hash change requires an explicit baseline review. Do not treat a refreshed hash alone as proof that a weakened rule is acceptable.

The [migration record](docs/authored/architecture/IFX-MIGRATION.md) identifies the ownership and cutover boundary. `.github/workflows/v3-ifx-guardrails.yml` is the sole PR/main guard workflow. Ruleset `23459908` enforces its 13 jobs with strict up-to-date checking, pull-request-only updates, conversation resolution, deletion protection and force-push protection. The [deletion manifest](stages/analysis/evidence/legacy-deletion-manifest.json) records every retired path and the pre-deletion restore commit.
