# Guardrails V3 source package

V3 is a portable source package for guiding coding agents before they edit code and generating an independent .NET test gate after a project profile is configured. It contains no target-project policy, copied gate rule, or generated production test project. Existing guard projects remain authoritative and unchanged. `Init` creates an explicitly unreviewed profile; `Analyze` inventories target evidence without modifying policy. A reviewed profile can produce human-readable Markdown views with a controlled JSON import.

## Design

The [architecture](architecture/ARCHITECTURE.md) separates lightweight Plan/Pre guidance from Post/Diff checks. A [profile](contracts/profile.schema.json), [project map](contracts/project-map.schema.json), [tech stack](contracts/tech-stack.schema.json) and [rules](contracts/rule.schema.json) describe a target repository. The map declares areas, owners, nearby examples, focused command IDs and risk triggers; each rule declares applicable paths. The [Plan template](templates/plan/README.md) and [Agent skill](skills/guard-plan/SKILL.md) guide planning. Pre writes a machine-readable [result](contracts/pre-result.schema.json) with an input hash. The deterministic generator uses [C# templates](templates/dotnet/) to create a .NET test project. Rule text without a supported detector is never promoted to a blocking check.

## Directory

| Path | Role |
| --- | --- |
| `architecture/` | Stage boundaries, technical design, coverage and portability constraints |
| `contracts/` | Machine-readable profile, project map, rule, Plan and Pre-result schemas |
| `examples/minimal/` | Synthetic sample profile only; no target-project configuration |
| `rules/` | Rule-authoring guidance; real rule JSON lives in a selected profile |
| `templates/plan/` | Human-readable Plan and machine-readable sidecar examples |
| `templates/dotnet/` | Deterministic test-project source templates |
| `skills/` | Optional Agent bootstrapping and planning skills, installed explicitly by the host |
| `hooks/` | Optional Pre trigger adapter and host installation guidance |
| `scripts/` | Validate, Pre, Generate, Check, Test and Diff entry points |
| `scripts/Invoke-V3Setup.ps1` | Fail-closed profile scaffold and read-only target inventory |
| `scripts/Invoke-V3Docs.ps1` | Render/check Markdown views and preview/apply controlled JSON import |
| `tests/Test-V3Tools.ps1` | Synthetic setup, inventory and Markdown round-trip tests |
| `generated/` | Output created after configuration; initially has no .NET project |

See [DEPLOYMENT.md](DEPLOYMENT.md) for every command and its expected result. `Analyze` writes only its requested inventory directory. `Render` writes a dedicated `views/` directory, never the hand-written profile README or notes. Generate only writes the specified output directory. Activating a GitHub workflow or registering a host Skill/Hook is a separate installation step because those hosts read configuration outside this directory.

## Support boundary

The initial generated detector checks forbidden .NET `ProjectReference` edges. It proves a configured project-file relationship, not symbol binding, runtime behavior, or all architecture rules. New detector kinds need an implementation and positive/negative fixture tests before they can become blocking. The generic package can describe other stacks, but this initial detector requires a .NET SDK to run.
