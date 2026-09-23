# V4 P10.1 C1j — scoped forbidden project-name candidate

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

Port only V3 `L1.2` / `PROJECT-NAME-FORBIDDEN` for in-scope project
declarations under `src`. The effective IFX `layerguard.json` is SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`;
`L1.2.json` is SHA-256
`584007ec88e47dcdbe92796745ce107f557cac8d033c3c71a0418f29d7cc3e06`.
Freeze its ring patterns, forbidden name patterns and blocking binding in a
hashed candidate policy. Do not confuse this with Plan04's wider retirement
rule over non-project artifacts.

Create one read-only V4 Pre extension on the published 1.1.2 public contract.
It enumerates exact `.csproj` subjects under `src`, excludes guard/generated
subtrees, assigns the first matching V3 ring pattern in policy order, and
judges only in-scope project names against `*.Abstractions`. Coverage counts
eligible in-scope projects, not violations; require at least one. Reject
missing root, invalid project XML, linked paths and policy hash drift. Emit
deterministic rule/evidence/coverage identities. No target execution,
network or write capability; read PackageRoot/TargetRoot, process `pwsh`,
timeout 30 seconds.

Fixtures: clean in-scope project, forbidden in-scope project, forbidden
outside-ring project, guard/generated exclusion, missing root, zero eligible
projects, malformed XML, linked path, hash drift and deterministic repeat.
Assert TargetRoot byte invariance, source policy projection, V4 schemas and
manifest locks. Run the real IFX scan and synthetic-only published Host Pre
clean/violation/zero cases using the C1i-verified base ZIP. Then run isolated
`ifx-package-test`, unchanged installed Package check and exact Formal Diff.
Formal Pre precedes executable candidate edits.

This tranche does not claim `L2.9` ownership-unknown, direct
`PROVIDER-CONTRACT`, Plan04 retirement, compiled/evaluated dependencies,
production Profile, bundle review or C1 closure. Any Host or built-in change
requires the separate V4 compatibility Plan and patch process.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c1j/formal-pre` before candidate
edits. The source-bound policy, module manifest, schemas and dependency lock
passed direct checks. Seven fixtures passed, including an in-scope
`IFX.Platform.Foo.Infrastructure.Abstractions` violation and an out-of-scope
`IFX.Modules.CRM.Abstractions` non-finding; hash drift, linked path and
deterministic repeat controls also passed. The real IFX `src` scan matched
51 in-scope projects with zero findings and unchanged bytes. Synthetic-only
composition against the C1i-verified 1.1.2 base, receipt verification and
Host Pre clean/violation/zero-coverage cases passed. Evidence:
`artifacts/guards/p10-ifx-c1j/test-runs/5213edb65cb84f9790f06982fbd4d0bb`.
The isolated IFX package positive and negative regression passed, evidence:
`artifacts/guards/v3-ifx-package-test-1e9baa939a554738a4904c8c33f7450c`.
The installed base Package hash remains
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
This is candidate behavior only, not final C1 acceptance.
