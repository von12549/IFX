# IFX C6c12 generated-source binding decision

Date: 2026-09-25
Status: binding repaired; final C6 certification rerun required

## Trigger

The first C6c11 generated-input run stopped before rebuilding generated files
with `Frozen generated-source exclusion implementation drift.` The preceding
solution, frontend, and database producers had passed, so this was an explicit
integrity rejection rather than a build, test, database, or rule failure.

The producer froze the pre-C6c11 SHA-256 of
`ifx-source-policy/adapter.ps1`. C6c11 changed that adapter's enumeration
implementation and rebound its module manifest and independent matrix contract
without changing its generated-source exclusions.

## Decision

Replace only the producer's frozen C1h SHA-256 with
`e93e591b361c3cd6e88dce753cb819f123e9d0d42de760565b5b7af8b7bfca16`,
which is the C6c11 adapter SHA-256 bound by the module manifest. Retain the
separate structural assertion for `(guard|guards|bin|obj)` exclusions and every
generated-file classification, generator-output hash, count, and negative
fixture unchanged.

Formal Pre passed at
`artifacts/guards/p10-ifx-c6c12/formal-pre/summary-pre.json`.

## Certification consequence

All same-commit locks must be regenerated from the committed C6c12 HEAD. C6c
remains open until the generated-input producer, draft bundle, full
Windows/Linux matrix, 42 controls, 180 capability variants, semantic parity,
zero-gap assertions, and formal Diff gate pass.
