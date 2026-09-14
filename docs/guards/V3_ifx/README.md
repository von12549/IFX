# IFX Guardrails V3 migration package

Pre now accepts an ordinary path summary or a formal Plan. The local `profiles/ifx/project-map.json` classifies paths into areas, owners, examples, focused validation commands and risk triggers; `rules/*.json` declares applicability for all nine numbered LayerGuard rules. A successful Pre result is advisory and written under `artifacts/guards/` with a profile-input hash. Risk paths require a formal Plan and covering decision. Unknown modules remain unmapped and fail closed.

`V3_ifx` is the IFX-configured fork of the portable V3 source package. `V3_backup` is the validated reusable source snapshot. This directory owns its own configuration, .NET source, fixtures, baseline, and generated projects; its commands do not invoke `mcp/LayerGuard`, `src/layerguard.json`, or the existing guard scripts. The old gate remains in place for later comparison.

The [IFX target inventory](analysis/ifx/INVENTORY.md) records repository project, CI and guidance evidence with file hashes. It seeds editable [target architecture](analysis/ifx/ARCHITECTURE.md) and [technical](analysis/ifx/TECHNICAL.md) drafts; their [review report](analysis/ifx/ARCHITECTURE-REVIEW.md) compares structured intent with the current profile and observed source. The drafts are proposals and have not rewritten the IFX profile or architecture policy. The [profile views](profiles/ifx/views/README.md) give a readable map, tech stack, rules and V3 stage coverage. JSON remains authoritative; the coverage view deliberately describes only the narrow stage runner, while the independent LayerGuard gate below retains its own policy.

## What is enforced

The lightweight V3 stage runner maps an ordinary path summary or validates a formal Plan before coding, checks the final Diff against declared paths, and tests the `L2.2` Domain-to-Contracts project-reference detector plus a compiled CRM boundary pilot (`ARCH.BINARY.DOMAIN.CONTRACTS`) after coding. Its IFX profile maps all nine numbered LayerGuard rule IDs to applicable paths; the other eight are advisory only **within the narrow stage runner** and remain blocking in the separate architecture gate. The independent IFX LayerGuard project runs the complete migrated architecture policy: layer and ownership boundaries, direct/transitive references, package/import/source rules, declaration and payload rules, G03 provider graph, G04 runtime binding, G05 context binding, and the strict zero-entry Plan 05 baseline. Its 190 .NET tests include positive and negative cases. `policy/layerguard.json` maps these checks to `L1.2`, `L2.2`, `L2.3`, `L2.4`, `L2.9`, `L3.1`, `L3.4`, `L3.5`, and `L3.6`.

The G03/G04/G05 files under `policy/` are **local LayerGuard inputs**. This migration does not replace the separate G03/G04/G05, Plan 04, database, frontend, or CI validators. They remain separate gates in the existing repository. In particular, the local LayerGuard binding checks their static policy facts and hashes; it does not perform each specialized validator's full behavior tests. The standalone `V3_ifx` package is therefore a complete independent **LayerGuard architecture gate**, not a replacement for every IFX CI job.

## Directory and editing contract

| Path | Purpose |
| --- | --- |
| `profiles/ifx/` | Editable V3 Plan/Pre/Diff profile, `L2.2` project-reference detector and compiled CRM boundary pilot |
| `profiles/ifx/views/` | Generated Markdown index, map, tech stack, rule pages and V3 stage coverage |
| `analysis/ifx/` | Target evidence, editable architecture/technical drafts, review report and generated profile proposal |
| `policy/layerguard.json` | Editable IFX architecture rules, copied from the existing policy with only the three Gate paths made local |
| `policy/g03/`, `policy/g04/`, `policy/g05/` | Local policy facts and G04-bound artifacts; edit together with their verified hashes |
| `policy/baselines/plan05.json` | Local strict baseline, bound to the composite policy hash; never silently update after a rule edit |
| `templates/ifx-layerguard/` | Local .NET implementation, tests, and fixtures used by the IFX generator |
| `generated/dotnet/LayerGuard/` | Generated independent .NET project, byte-checked against the template |
| `generated/stages/` | Generated V3 Plan/Post/Diff test project |
| `contracts/`, `templates/plan/`, `skills/`, `hooks/` | V3 input contracts and optional Agent planning integration |
| `scripts/Invoke-IFX.ps1` | Generate, check, test, and strict-scan the independent IFX LayerGuard project |
| `scripts/Invoke-V3.ps1` | Validate, generate, check, test, Pre, and Diff for the V3 stage profile |
| `scripts/Invoke-V3Setup.ps1`, `Invoke-V3Architecture.ps1`, `Invoke-V3Docs.ps1` | Analyze/Init, architecture draft/review/adopt and Markdown render/check/import tools copied from V3 |

Agent workflow: read this README and [deployment commands](DEPLOYMENT.md), compare the architecture drafts with evidence and current profile, then edit a reviewed profile or local policy. Review changed rules and bound hashes, regenerate both projects, run Check, run positive/negative tests and strict scan, then run Pre/Diff against the task Plan. `Invoke-IFX -Mode Validate` checks the nine numbered stage/policy rule IDs for drift. A policy hash change requires an explicit baseline review. Do not treat a refreshed hash alone as proof that a weakened rule is acceptable.

The [migration record](architecture/IFX-MIGRATION.md) identifies what was copied and what was changed to make the gate independent. No CI workflow or branch-protection setting is installed by this package; CI activation is a separate deployment step. The [all-module Inbound Adapter target](architecture/INBOUND-ADAPTER-TARGET.md) is a future proposal, not a current IFX policy change.
