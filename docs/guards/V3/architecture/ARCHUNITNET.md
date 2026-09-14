# Optional ArchUnitNET detector

**Status: implemented, opt-in.** The generator adds `TngTech.ArchUnitNET` 0.13.4 and `AssemblyGuardTests.cs` only for configured `forbidden-type-dependency` or `interface-implementation-location` rules. Without them, the generated project has no ArchUnitNET dependency. See the [implementation plan](../../plans/04-v3-archunitnet-assembly-gate.md).

ArchUnitNET reads compiled .NET assemblies. The optional detector tests actual type dependencies, interface implementation and declaration location inside a generated xUnit project. It complements the existing `.csproj` detector: an unused but forbidden `ProjectReference` is still a project-boundary violation, while a compiled type dependency can reveal a class-level relationship inside an otherwise permitted project. The generated gate keeps rule IDs, target scope, positive/negative fixtures and non-vacuous evidence under V3 control. See the [official guide](https://github.com/TNG/ArchUnitNET/blob/main/documentation/docs/guide.md) for the library's rule model.

| Evidence | Intended owner |
| --- | --- |
| Declared project edge, missing project or unknown owner | Project/source detector; ArchUnitNET cannot infer these from a binary |
| Actual type dependency, interface implementation and namespace placement | Optional ArchUnitNET detector after a target Debug build |
| Source-only or disabled-branch text, symbol binding before emission | Source detector or a separately designed Roslyn semantic analyzer |
| Plan scope, Pre applicability, policy authority, baseline and CI activation | V3 orchestration and the target project's existing authorities |
| Dependency-injection selection, version/consumer validation order, tenant and business decisions | Integration and behavior tests |

The detector loads an explicit, reviewed list of expected target assemblies and fails if a required assembly, type group or interface group is absent. It reports expected/loaded names, matched counts and failures at `artifacts/guards/v3-assembly.json`. `bin/` discovery alone is insufficient because a new or renamed module could otherwise disappear from the test. Only exact namespaces are supported; the current rule contract has no exception/suppression list and never allows zero matches. Adjacent build dependencies may be loaded for type resolution but are not themselves checked unless listed. Run the target in Debug: the [upstream limitation](https://archunitnet.readthedocs.io/en/latest/limitations/debug_artifacts/) notes that Release optimization can hide some dependencies. Always use `Invoke-V3 -Mode Test` for the fresh build; calling the generated test project directly does not establish binary freshness.

The future architecture discussed for IFX applies to **every Module**, not one example module: a provider's Infrastructure Inbound Adapter implements its public Contract and delegates to its Application use case. A target-specific profile may then require Application types not to depend on that module's public Contract and constrain where implementations live. The exact treatment of published events and shared platform Contracts needs separate architecture review. This target rule must not be enabled against the present IFX policy merely because ArchUnitNET has been added to V3.
