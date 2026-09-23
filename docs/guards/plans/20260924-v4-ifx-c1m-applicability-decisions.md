# V4 P10.1 C1m — L2.9 and IntegrationAdapter applicability decisions

Status: `AUTHORIZED DECISION TRANCHE — not a production Profile`

The user selected `L2.9=A` and `IntegrationAdapter=A` on 2026-09-24.
Retain V3 `OWNERSHIP-UNKNOWN` exactly: it requires a null inferred module
for an in-scope non-Host/non-Test project. The current `src` project layout
and V3 parent-folder fallback make that condition structurally unreachable.
Record this as a bounded equivalence/applicability exception, **not** as a
passing detector and not as a stronger catalog-membership rule.

Permit the absent IntegrationAdapter subject only as a reviewed exception
for the exact current `src` project inventory. Freeze every project path and
file hash, the V3 policy and predicate-source hashes, and the current
zero-adapter observation. A verifier must block added, removed or changed
projects, policy/source drift, an adapter match, missing input and unsafe
links. A newly matching IntegrationAdapter project immediately voids the
exception and requires direct C1k `PROVIDER-CONTRACT` enforcement. C1k itself
retains its fail-closed zero-coverage result; this is a Profile-owned
applicability decision for later C6 composition, not a detector bypass.

Formal Pre precedes executable edits. Test clean and altered inventories,
adapter addition, source drift, missing input and linked paths, then run
isolated package regression, Package hash verification and exact Formal Diff.
Do not edit PATH-repair files, the published base, the installed tree or a
production Profile. C1 still needs the four active rule families and C5
fresh compiled/MSBuild-evaluated evidence.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c1m/formal-pre`. The frozen project set is 58
`src` projects with inventory SHA-256
`6662b88492c9c5c2f124e499c6255e857cfaa5953aa67ddd14db532dc8a41ce5`;
none matches the current IntegrationAdapter patterns. The decision file records
all 58 path/hash pairs and the exact V3 source/policy hashes. Ten controls
passed: real and copied clean inventories, changed/removed/added projects,
new adapter, missing `src`, zero projects, copied authority and source drift.
Evidence: `artifacts/guards/p10-ifx-c1m/tests/ff105add088e4635a171cbfc2a88d970`.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-82ef51ae6ead45809396ae2b4105989c`.
The receipted 1.1.2 Package check remains `pass` with hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The C1k direct candidate remains unchanged and zero-subject blocking.
