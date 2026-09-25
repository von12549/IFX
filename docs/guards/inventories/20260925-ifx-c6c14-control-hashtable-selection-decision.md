# IFX C6c14 control hashtable selection decision

Date: 2026-09-25
Status: implementation complete; final C6 certification rerun required

## Trigger

The C6c13 parallel certification at
`%TEMP%/ifx-c6c13/c6c13ff5e2c149389d7f043b9c101310` advanced the Windows
matrix through all 36 suite outputs visible before final aggregation and did
not report a Windows or Linux process failure. Aggregation stopped because the
Controls process could not choose a post-production mutation subject.

The lock documents were parsed with `ConvertFrom-Json -AsHashtable`, while the
selector tested only `PSObject.Properties`. Consequently valid dictionary keys
were treated as absent even though every governed lock exposed one of
`files`, `sourceFiles`, `assemblies`, or `inputs`.

## Decision

Certification controls now use one field-presence helper. It calls
`IDictionary.Contains` for dictionary-backed values and retains property-name
inspection for ordinary PowerShell objects. The helper governs both lock
collection selection and the `path`/`sourcePath` assembly distinction.

No evidence schema, lock lineage, rule, claim, case, finding, policy,
capability ceiling, timeout, waiver, published package byte, or governance
state changes.

## Verification

- Formal Pre passed at
  `artifacts/guards/p10-ifx-c6c14/formal-pre/summary-pre.json`.
- A focused invocation parsed each of the six non-generated evidence locks as
  both a normal PowerShell object and a hashtable. All 12 selections resolved
  an existing mutation subject, including assembly `path`, type `sourcePath`,
  and graph `inputs`.

## Certification consequence

C6c remains open until the committed C6c14 HEAD receives fresh same-commit
inventory, seven evidence locks, candidate evidence, Windows/Linux 191/191,
42 controls, 180 capability variants, semantic parity, zero gaps, and formal
Diff.

