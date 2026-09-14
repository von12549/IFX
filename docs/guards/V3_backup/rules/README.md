# Rule authoring guide

This directory is a **guide**, not an active rule source. The runner reads one JSON file per stable ID from the selected profile's `rules/` directory (`Invoke-V3.ps1 -ProfileDirectory ...`). The generic package's `examples/minimal/rules/ARCH.SAMPLE.json` is synthetic. A real target profile belongs outside this reusable default. `contracts/rule.schema.json` is the machine contract.

## Rule framework

| Field | Meaning | Review question |
| --- | --- | --- |
| `id`, `title` | Stable Plan/report identifier and human label | Does the ID survive wording changes? |
| `appliesTo` | Repository-relative globs used by Pre to associate changed paths with a Plan | Do they include all intended paths without covering unrelated areas? |
| `authority` | Human-readable source of the intended policy | Has that source been reviewed? The runner does not verify its truth. |
| `kind` | Implemented detector adapter or `none` | What concrete evidence can code test? |
| `enforcement` | `blocking` or `advisory` in this **V3 stage** | Is there a tested detector for a blocking claim? |
| `coverage` | `partial` or `none` | What violations remain outside the detector? |
| `sourcePattern`, `forbiddenTargetPattern` | Input and forbidden target globs for `forbidden-project-reference` | Do they match actual project paths and intended direct edges? |
| `negativeFixture` | Deliberately violating source project and `ProjectReference Include` | Does the test fail for the intended reason? |
| `sourceAssembly`, `sourceNamespace`, `forbiddenAssembly`, `forbiddenNamespace` | Exact assembly and namespace groups for `forbidden-type-dependency` | Are both type groups nonempty and declared in the manifest? |
| `interfaceAssembly`, `interfaceType`, `implementationAssembly`, `implementationNamespace` | Public interface and the only permitted concrete implementation location | Does every relevant implementation live there? |
| `minimumMatches` | Minimum source and target types, or concrete implementations, for compiled rules | Would a renamed or removed group fail closed? |

`appliesTo` controls Plan association, not Post scanning. Post uses the detector fields. `authority` is provenance for review, not an automatic import of another policy. A rule ID in a Plan does not prove code complies with it.

## Supported and uncovered examples

The source package implements `forbidden-project-reference` and two optional compiled-rule kinds. This blocking example checks direct `.csproj` declarations; it does not evaluate MSBuild conditions, transitive edges or C# symbols:

The [ArchUnitNET detector](../architecture/ARCHUNITNET.md) supports `forbidden-type-dependency` and `interface-implementation-location` when `tech-stack.json:assemblyGate` lists every checked assembly. Both require exact namespaces and `minimumMatches >= 1`; missing or empty scope fails. Continue to state project-reference rules separately.

```json
{
  "formatVersion": 1,
  "id": "ARCH.NO-LEGACY",
  "title": "Application does not reference Legacy projects",
  "kind": "forbidden-project-reference",
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "Reviewed architecture decision ARCH-001",
  "appliesTo": ["src/App/**"],
  "sourcePattern": "src/App/*.csproj",
  "forbiddenTargetPattern": "**/Legacy/*.csproj",
  "negativeFixture": {
    "sourceProject": "src/App/App.csproj",
    "referenceInclude": "../Legacy/Legacy.csproj"
  }
}
```

An optional compiled dependency rule uses exact namespaces and assembly identities. The target tech stack must declare the corresponding `assemblyGate` manifest. The implementation-location rule uses the same common fields and replaces the four dependency fields with the interface and implementation fields from the table above. `minimumMatches` must be positive. See [the multi-project fixture](../tests/Test-V3ArchUnit.ps1) for complete examples and expected negative outcomes.

```json
{
  "formatVersion": 1,
  "id": "ARCH.APP-PORT",
  "title": "Application types do not depend on public port types",
  "kind": "forbidden-type-dependency",
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "Reviewed target architecture",
  "appliesTo": ["src/App/**"],
  "sourceAssembly": "App",
  "sourceNamespace": "Demo.App",
  "forbiddenAssembly": "Ports",
  "forbiddenNamespace": "Demo.Ports",
  "minimumMatches": 1
}
```

When the rule is meaningful for planning but no detector exists, keep it visible without claiming enforcement:

```json
{
  "formatVersion": 1,
  "id": "ARCH.NO-ENTITY-LEAK",
  "title": "Public payloads do not expose internal entities",
  "kind": "none",
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "Reviewed architecture decision ARCH-002",
  "appliesTo": ["src/Contracts/**"]
}
```

## Promotion to a hard gate

1. Confirm target scope, owner, policy authority and current violations using `Analyze` and the architecture review. Record unresolved semantics rather than guessing a detector.
2. Add a rule file named exactly `<ID>.json` to the selected profile. Keep its ID unique. Use `kind: none` while no adapter exists.
3. For a blocking rule, implement the detector in a versioned template and add a compliant fixture, a deliberately violating fixture, and a non-vacuous target-scope check. The current supported kind already has these tests.
4. Run profile `Validate`, Markdown `Render`/`Check`, `Generate`/`Check`/`Test`, and a target-specific violating fixture. Confirm the observed failure carries the intended rule ID. Run Diff separately for Plan scope.
5. Add the checks to CI and require the job only after the local positive and negative evidence is reviewed. A generated project alone does not activate CI.

Changing a rule's prose, `appliesTo`, or `authority` does not change an independent gate's policy. If another gate owns the full rule, maintain an explicit ID/authority mapping and test it for drift.
