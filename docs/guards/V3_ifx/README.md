# IFX Guardrails V3 migration package

Pre now accepts an ordinary path summary or a formal Plan. The local `profiles/ifx/project-map.json` classifies paths into areas, owners, examples, focused validation commands and risk triggers; `rules/*.json` declares applicability for all nine numbered LayerGuard rules. A successful Pre result is advisory and written under `artifacts/guards/` with a profile-input hash. Risk paths require a formal Plan and covering decision. Unknown modules remain unmapped and fail closed.

`V3_ifx` is the IFX-configured fork of the portable V3 source package. `V3_backup` is the validated reusable source snapshot. This directory owns IFX guard orchestration, architecture scanning, specialized validation, compiled assembly checks, solution/frontend quality and frozen-history integrity. Its production architecture command does not invoke `mcp/LayerGuard` or root guard scripts. GitHub ruleset `IFX V3 Required Checks` requires all 13 stable V3 jobs on the default branch and `codex/guards-principles-plan`. The replaced workflows, root validators, duplicate policy and non-V3 guard documentation were removed after the required-check cutover.

The [IFX target inventory](analysis/ifx/INVENTORY.md) records repository project, CI and guidance evidence with file hashes. It seeds editable [target architecture](analysis/ifx/ARCHITECTURE.md) and [technical](analysis/ifx/TECHNICAL.md) drafts; their [review report](analysis/ifx/ARCHITECTURE-REVIEW.md) compares structured intent with the current profile and observed source. The drafts are proposals and have not rewritten the IFX profile or architecture policy. The [profile views](profiles/ifx/views/README.md) give a readable map, tech stack, rules and V3 stage coverage. JSON remains authoritative; the coverage view deliberately describes only the narrow stage runner, while the independent LayerGuard gate below retains its own policy.

## What is enforced

The V3 stage runner maps an ordinary path summary or validates a formal Plan before coding. CI Diff resolves explicit base/head commits, requires a real merge base and nonempty changed set, includes both sides of renames, and rejects undeclared paths and protected guard deletion. Its IFX profile maps all nine numbered LayerGuard rule IDs to applicable paths. The independent IFX LayerGuard project remains the complete architecture detector: layer and ownership boundaries, direct/transitive references, package/import/source rules, declaration and payload rules, Gate bindings, and the strict zero-entry Plan 05 baseline.

The G03/G04/G05 files under `policy/` are deterministic LayerGuard projections. `policy/authorities.json` identifies their domain-owned sources, and `scripts/Sync-IFXPolicyInputs.ps1` generates or checks LF-normalized local copies and binding hashes. Specialized detectors live under `specialized/`; they write reports under `artifacts/guards/v3-ifx/` and do not repeat LayerGuard or full solution tests. `quality/` owns the one-time solution regression, all five compiled Domain assembly boundaries, and frontend install/lint/test/build. `history/` protects frozen Plan00/B1/B4 and LayerGuard baselines without treating their old blocker counts or next-step text as current readiness.

## Directory and editing contract

| Path | Purpose |
| --- | --- |
| `profiles/ifx/` | Editable V3 Plan/Pre/Diff profile, `L2.2` project-reference detector and compiled CRM boundary pilot |
| `profiles/ifx/views/` | Generated Markdown index, map, tech stack, rule pages and V3 stage coverage |
| `analysis/ifx/` | Target evidence, editable architecture/technical drafts, review report and generated profile proposal |
| `policy/layerguard.json` | Editable IFX architecture rules, copied from the existing policy with only the three Gate paths made local |
| `policy/g03/`, `policy/g04/`, `policy/g05/` | Local policy facts and G04-bound artifacts; edit together with their verified hashes |
| `policy/baselines/plan05.json` | Local strict baseline, bound to the composite policy hash; never silently update after a rule edit |
| `policy/authorities.json` | Registry of editable domain authorities and deterministic V3 projections |
| `specialized/` | V3-owned G03, G04, G05, Plan04 and Database runners and detectors |
| `quality/` | Solution, five-module compiled Domain assembly and frontend quality runners |
| `history/` | Frozen evidence manifest, validator and explicit regeneration command |
| `templates/ifx-layerguard/` | Local .NET engine, IFX facade (`src/LayerGuard.Ifx`), engine and IFX policy binding tests, and fixtures |
| `generated/stages/` | Generated V3 Plan/Post/Diff test project |
| `contracts/`, `templates/plan/`, `skills/`, `hooks/` | V3 input contracts and optional Agent planning integration |
| `scripts/Invoke-IFX.ps1` | Check, test, and strict-scan the IFX LayerGuard project directly from `templates/ifx-layerguard/`; `Generate` is read-only during the transition |
| `scripts/Invoke-IFXGuardrails.ps1` | Stable Validate/Pre/Diff/Architecture/Specialized/Quality/HistoricalIntegrity/All dispatcher |
| `scripts/Invoke-V3.ps1` | Validate, generate, check, test, Pre, and Diff for the V3 stage profile |
| `scripts/Invoke-V3Setup.ps1`, `Invoke-V3Architecture.ps1`, `Invoke-V3Docs.ps1` | Analyze/Init, architecture draft/review/adopt and Markdown render/check/import tools copied from V3 |

Agent workflow: read this README and [deployment commands](DEPLOYMENT.md), compare the architecture drafts with evidence and current profile, then edit a reviewed profile or local policy. Review changed rules and bound hashes, regenerate both projects, run Check, run positive/negative tests and strict scan, then run Pre/Diff against the task Plan. `Invoke-IFX -Mode Validate` checks the nine numbered stage/policy rule IDs for drift. A policy hash change requires an explicit baseline review. Do not treat a refreshed hash alone as proof that a weakened rule is acceptable.

The [migration record](architecture/IFX-MIGRATION.md) identifies the ownership and cutover boundary. `.github/workflows/v3-ifx-guardrails.yml` is the sole PR/main guard workflow. Ruleset `23459908` enforces its 13 jobs with strict up-to-date checking, pull-request-only updates, conversation resolution, deletion protection and force-push protection. The [deletion manifest](analysis/ifx/legacy-deletion-manifest.json) records every retired path and the pre-deletion restore commit.
