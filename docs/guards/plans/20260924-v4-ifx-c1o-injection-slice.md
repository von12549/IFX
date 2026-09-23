# V4 P10.1 C1o — parameter-name and declaration-origin injection rules

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

The C1l audit identified two remaining active V3 architecture rules absent
from the numbered `ruleRefs`: `FORBIDDEN-DEPENDENCY` and
`FORBIDDEN-DEPENDENCY-ORIGIN`. Port their syntax-only behavior to a read-only
V4 Pre extension. Freeze `layerguard.json` and the V3 `InjectionRules`,
`DeclarationIndex` and `SourceFiles` implementations by hash. Use Roslyn
syntax from the installed .NET 10 SDK; do not import V3 runtime code.

For Presentation, inspect primary-constructor, declared-constructor and
method parameter type names; reject `I*Repository` and `*DbContext`, including
names nested in generic or nullable type syntax. For Application, build a
cross-project simple-name declaration index from in-scope C# sources and
reject parameter names declared in Infrastructure unless a declaration of
the same name exists in Application. Match exact case and preserve V3's
first-matching-name/parameter behavior. Do not infer semantic symbol binding.

Require nonvacuous Presentation and Application parameter coverage and at
least one Infrastructure declaration for the origin check. Missing `src`,
unsafe/linked paths, malformed project or source, missing compatible Roslyn
and zero-subject cases block. Fixtures must cover constructor/method/primary,
generic/nullable, origin and same-ring exemption, clean, missing and zero.
Check deterministic results and TargetRoot byte invariance; use synthetic
published-Host Pre, isolated IFX package regression, Package identity, Formal
Pre before executable edits and exact Formal Diff. This is not compiled
assembly/semantic-symbol coverage and does not accept a production Profile.

## Verification record

Formal Pre passed before candidate edits at
`artifacts/guards/p10-ifx-c1o/formal-pre`. V3 source hashes, policy
projections, module/config/result schemas, dependency lock and capability
ceiling passed direct checks. Fifteen fixture cases cover clean,
primary/declared constructor and method parameters, nullable/generic names,
Infrastructure declaration origin, same-ring shadow, unknown and case-sensitive
names, missing/zero subjects and malformed inputs. Policy drift, linked path,
deterministic repeat and TargetRoot byte-invariance controls passed. The real
IFX scan covered 719 Presentation and 1802 Application parameters with zero
new findings. A synthetic-only extension composed and receipt-verified against
the C1i-verified published 1.1.2 base; Host Pre clean, name violation, origin
violation and zero-subject controls passed. Evidence:
`artifacts/guards/p10-ifx-c1o/test-runs/041e6419eaa241689df7ef973b10d91d`.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-9ab609a2652e476280f31f13a39d1b30`.
The published 1.1.2 Package check remains `pass` with hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
No production Profile or final human-reviewed bundle was created.
