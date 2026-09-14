# IFX rule authoring guide

This directory is a **guide**, not a second active rule source. `Invoke-V3.ps1` reads `profiles/ifx/rules/*.json` for Plan/Pre association and the narrow V3 stage detector. `Invoke-IFX.ps1` reads `policy/layerguard.json` for the independent, full LayerGuard architecture gate. The nine numbered IDs appear in both systems so Agents can name the same concern, but their coverage differs. `examples/minimal/rules/` is synthetic.

## Two rule paths

| Source | Consumer | Responsibility |
| --- | --- | --- |
| `profiles/ifx/rules/<ID>.json` | V3 Pre and generated stage project | Applies rule IDs to planned paths; `L2.2` checks direct project references and `ARCH.BINARY.DOMAIN.CONTRACTS` checks compiled CRM type dependencies. |
| `policy/layerguard.json` | Independent LayerGuard .NET project | Owns complete architecture policy and maps findings to the nine numbered `ruleRefs`. |
| `rules/README.md` | Human or Agent author | Explains how to change and verify either path; it is never parsed as policy. |

The stage's `L2.2` and `ARCH.BINARY.DOMAIN.CONTRACTS` are `blocking` with `partial` coverage. The other eight numbered rules use `kind: none`, `advisory`, `coverage: none` **in the stage runner**; their architecture checks remain in the independent gate. `ARCH.SEMANTIC` records an uncovered concern. `contracts/rule.schema.json` constrains the stage JSON shape. An `authority` string names the policy location for review; it does not make the stage runner import that policy.

## Stage rule fields and example

`id` and filename must match. `title` is the Plan-facing label. `appliesTo` globs decide which Plan paths must list the ID; they do **not** run Post. `kind`, `enforcement`, and `coverage` describe the actual stage detector. `sourcePattern`, `forbiddenTargetPattern`, and `negativeFixture` are required for `forbidden-project-reference`; Post fails when a project rule matches no source project or a compiled rule misses its declared Debug assembly/type group.

For example, [L2.2](../profiles/ifx/rules/L2.2.json) applies to Domain paths and rejects a Domain `.csproj` referencing Contracts. Its negative fixture adds that edge deliberately. The check is limited to declared direct `ProjectReference` values. [ARCH.BINARY.DOMAIN.CONTRACTS](../profiles/ifx/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json) adds compiled CRM type evidence using the explicit `tech-stack.json:assemblyGate` manifest; the independent LayerGuard policy covers the larger architectural rule. [L2.3](../profiles/ifx/rules/L2.3.json) shows the other pattern: an applicable Plan rule with `kind: none` and stage-level advisory status, while `policy/layerguard.json` maps it to the full ownership-reference detector.

```json
{
  "formatVersion": 1,
  "id": "ARCH.NEW-CONCERN",
  "title": "Describe the reviewed concern",
  "kind": "none",
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:reviewed-location",
  "appliesTo": ["src/Modules/*/SomeArea/**"]
}
```

This example is Plan metadata only. Do not switch it to `blocking` by changing JSON alone. First implement a supported detector and positive/negative fixtures; for a new detector kind, update the template and schema and prove it fails on a deliberately violating target. Review the corresponding independent policy separately.

## Change procedure and consistency

1. Read the relevant `profiles/ifx/rules/*.json`, `policy/layerguard.json` entry, current source paths, and [IFX architecture review](../analysis/ifx/ARCHITECTURE-REVIEW.md). State which gate proves each part of the concern.
2. Keep numbered rule IDs aligned with `policy/layerguard.json:ruleRefs`; run `Invoke-IFX.ps1 -Mode Validate`. The alignment check verifies IDs and stage authority markers, not full semantic equivalence.
3. Run V3 `Validate`, `Pre` positive/negative, Markdown `Render`/`Check`, generated stage `Generate`/`Check`/`Test`, and independent `Invoke-IFX -Mode Test` with a deliberate violation. Run Diff for Plan scope.
4. If the independent policy changes, review local G03/G04/G05 bindings and the strict baseline before updating any hash. Preserve existing CI gates until a replacement is verified and required.

Rule prose and stage `appliesTo` can drift from the independent policy even when IDs match. Treat that as a review item; the ID check cannot prove semantic parity.
