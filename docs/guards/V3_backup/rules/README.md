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

`appliesTo` controls Plan association, not Post scanning. Post uses the detector fields. `authority` is provenance for review, not an automatic import of another policy. A rule ID in a Plan does not prove code complies with it.

## Supported and uncovered examples

The initial source package implements only `forbidden-project-reference`. This blocking example checks direct `.csproj` declarations; it does not evaluate MSBuild conditions, transitive edges or C# symbols:

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
