# IFX Guardrails V3 migration package

Pre now accepts an ordinary path summary or a formal Plan. The local `profiles/ifx/project-map.json` classifies paths into areas, owners, examples, focused validation commands and risk triggers; `rules/*.json` declares applicability for all nine numbered LayerGuard rules. A successful Pre result is advisory and written under `artifacts/guards/` with a profile-input hash. Risk paths require a formal Plan and covering decision. Unknown modules remain unmapped and fail closed.

`V3_ifx` is the IFX-configured fork of the portable V3 source package. `V3_backup` is the validated reusable source snapshot. This directory now owns IFX guard orchestration, architecture scanning, specialized validation, compiled assembly checks, solution/frontend quality and frozen-history integrity. Its production architecture command does not invoke `mcp/LayerGuard`, `src/layerguard.json`, or the root guard scripts. The old workflows and root scripts remain temporarily for parallel CI comparison until required checks are switched.

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
| `templates/ifx-layerguard/` | Local .NET implementation, tests, and fixtures used by the IFX generator |
| `generated/dotnet/LayerGuard/` | Generated independent .NET project, byte-checked against the template |
| `generated/stages/` | Generated V3 Plan/Post/Diff test project |
| `contracts/`, `templates/plan/`, `skills/`, `hooks/` | V3 input contracts and optional Agent planning integration |
| `scripts/Invoke-IFX.ps1` | Generate, check, test, and strict-scan the independent IFX LayerGuard project |
| `scripts/Invoke-IFXGuardrails.ps1` | Stable Validate/Pre/Diff/Architecture/Specialized/Quality/HistoricalIntegrity/All dispatcher |
| `scripts/Invoke-V3.ps1` | Validate, generate, check, test, Pre, and Diff for the V3 stage profile |
| `scripts/Invoke-V3Setup.ps1`, `Invoke-V3Architecture.ps1`, `Invoke-V3Docs.ps1` | Analyze/Init, architecture draft/review/adopt and Markdown render/check/import tools copied from V3 |

Agent workflow: read this README and [deployment commands](DEPLOYMENT.md), compare the architecture drafts with evidence and current profile, then edit a reviewed profile or local policy. Review changed rules and bound hashes, regenerate both projects, run Check, run positive/negative tests and strict scan, then run Pre/Diff against the task Plan. `Invoke-IFX -Mode Validate` checks the nine numbered stage/policy rule IDs for drift. A policy hash change requires an explicit baseline review. Do not treat a refreshed hash alone as proof that a weakened rule is acceptable.

The [migration record](architecture/IFX-MIGRATION.md) identifies the ownership and cutover boundary. `.github/workflows/v3-ifx-guardrails.yml` is installed for parallel validation, while branch-protection switching remains an external step. The old workflows cannot be removed until real PR/main runs and required-check enforcement satisfy Plan 05's deletion threshold.
