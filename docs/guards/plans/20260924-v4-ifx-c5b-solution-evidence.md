# V4 P10.1 C5b — Solution Quality locked evidence

The C5a matrix classifies Solution Quality as a controlled, toolchain-executing
producer followed by read-only V4 Post verification. This tranche implements
that mapping only; Assembly, Frontend, combined Stages and final Profile
acceptance remain separate work.

Run the independent V3 Solution gate outside the V4 Host, fail before issuing
a lock if restore, audit, build or tests fail, and bind the result to source,
authority, time and exact evidence hashes. The V4 Post module must recheck
the lock, 81-project direct/transitive NuGet audit and non-vacuous passing TRX
test results without launching dotnet or using network/write capabilities.
Missing, malformed, stale, tampered, zero-project, zero-test and failed-summary
controls must block. Real IFX and published 1.1.3 synthetic Host Post must
pass with immutable TargetRoot and PackageRoot. No historical record or
candidate fixture constitutes production acceptance.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5b/formal-pre/pre.json`.
The controlled producer reran the V3 Solution gate and issued
`artifacts/guards/p10-ifx-c5b/solution-runs/7e653152cd764804bf3e2b989fd97276/evidence-lock.json`
with 81 audited projects, a passing Release build and non-vacuous passing
TRX evidence. Real IFX read-only Post and published 1.1.3 synthetic Host
Post passed 4/4 mapped checks at
`artifacts/guards/p10-ifx-c5b/test-runs/055172cf128c4dcb9b0d41818e5e4f46/summary.json`.
Tampered and missing lock, zero tests, failed summary and expired evidence
blocked. PackageRoot and isolated TargetRoot remained byte-invariant.
The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-0f02307dc62349329333eb297b617d30`.
Exact committed Formal Diff follows.
