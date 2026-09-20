# Guardrails V3 source package

V3 is a portable source package for guiding coding agents before they edit code and generating an independent .NET test gate after a project profile is configured. It contains no target-project policy, copied gate rule, or generated production test project. Existing guard projects remain authoritative and unchanged. `Init` creates an explicitly unreviewed profile; `Analyze` inventories target evidence under `artifacts/guards/<package>/analysis/`. `Review` compares reviewed architecture inputs with repository evidence and the current profile; explicit `Adopt` writes a new profile for normal generation and tests. A reviewed profile can also produce read-only human-readable Markdown views.

## Design

The [architecture](architecture/ARCHITECTURE.md) separates lightweight Plan/Pre guidance from Post/Diff checks. A [profile](contracts/profile.schema.json), [project map](contracts/project-map.schema.json), [tech stack](contracts/tech-stack.schema.json) and [rules](contracts/rule.schema.json) describe a target repository. The map declares areas, owners, nearby examples, focused command IDs and risk triggers; each rule declares applicable paths. The [Plan template](templates/plan/README.md) and [Agent skill](skills/guard-plan/SKILL.md) guide planning. Pre writes a machine-readable [result](contracts/pre-result.schema.json) with an input hash. The deterministic generator uses [C# templates](templates/dotnet/) to create a .NET test project. Rule text without a supported detector is never promoted to a blocking check. The optional [ArchUnitNET compiled-code detector](architecture/ARCHUNITNET.md) is generated only when a profile declares an assembly rule and explicit Debug manifest.

## Directory

| Path | Role |
| --- | --- |
| `architecture/` | Stage boundaries, technical design, coverage, portability constraints and the optional ArchUnitNET role |
| `contracts/` | Machine-readable profile, project map, rule, Plan and Pre-result schemas |
| `examples/minimal/` | Synthetic sample profile only; no target-project configuration |
| `rules/` | Rule-authoring guidance; real rule JSON lives in a selected profile |
| `templates/plan/` | Human-readable Plan and machine-readable sidecar examples |
| `templates/dotnet/` | Deterministic test-project source templates |
| `skills/` | Optional Agent bootstrapping and planning skills, installed explicitly by the host |
| `hooks/` | Optional Pre trigger adapter and host installation guidance |
| `commands/` | Stable public Validate, Pre, Generate, Check, Test, Diff, Setup/Analysis and Docs entry points |
| `scripts/` | Internal engines plus deprecated public-path wrappers |
| `commands/Invoke-V3Setup.ps1` | Fail-closed profile scaffold and read-only target inventory |
| `scripts/Invoke-V3Architecture.ps1` | Target architecture draft, evidence/profile review, and explicit adoption to a new profile |
| `commands/Invoke-V3Docs.ps1` | Render/check read-only Markdown views and aggregate documents |
| `tests/Test-V3Tools.ps1` | Synthetic setup, inventory and read-only Markdown drift tests |
| `tests/Test-V3ArchUnit.ps1` | Compiled dependency, implementation placement and fail-closed synthetic tests |
| external generation root | Untracked Stage Gate output at `<generation-root>/v3/gates/stage/{ProjectId}.Guards.StageGate.Tests/` |

See [DEPLOYMENT.md](DEPLOYMENT.md) for every command and its expected result. `Analyze` defaults to `artifacts/guards/<package>/analysis/`; a separate reviewed evidence directory is read-only during analysis. `Review` writes a proposal/report in the runtime directory; `Adopt` requires explicit acceptance and refuses to overwrite a profile. `Render` writes dedicated generated-document directories, never authored documentation. Generate requires an out-of-repository generation root and writes only the project-specific Stage Gate below it. Activating a GitHub workflow or registering a host Skill/Hook is a separate installation step because those hosts read configuration outside this directory.

## Support boundary

The project detector checks forbidden .NET `ProjectReference` edges. The optional ArchUnitNET detector checks compiled namespace dependencies and interface implementation placement after fresh Debug builds, then writes `artifacts/guards/v3-assembly.json`. Neither proves uncompiled source, reflection, DI behavior or all architecture rules. Without assembly rules, the generated project has no ArchUnitNET package reference. Both detectors require a .NET SDK.
