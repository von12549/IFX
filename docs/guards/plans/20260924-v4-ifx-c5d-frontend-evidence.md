# V4 P10.1 C5d — Frontend Quality locked evidence

The V3 Frontend Quality gate executes `npm ci`, production/full high-threshold
audits, zero-warning lint, Vitest and a production build. Keep these toolchain
and network actions outside V4 Post. A controlled producer captures a passing
run, exact source/package-lock hashes, test count, audit outputs and toolchain
identity. Its process-local short PATH isolates the known Windows command
length pollution without modifying user or machine PATH.

The V4 Post module verifies the locked report read-only, requiring fresh
source, both zero-high/critical audits and non-vacuous passing tests. Missing,
stale, altered, failed and zero-match cases block. Validate real IFX direct
and published 1.1.3 synthetic Host Post, byte-invariant immutable roots,
isolated package regression and exact Formal Diff. This is candidate coverage,
not production Profile approval.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5d/formal-pre/pre.json`.
The controlled V3 Frontend producer used a process-only short PATH and
issued `artifacts/guards/p10-ifx-c5d/frontend-runs/fc7edb09de3f44719bdf7de044810f1a/evidence-lock.json`.
Real IFX direct Post and published 1.1.3 synthetic Host Post passed 5/5
mapped checks at
`artifacts/guards/p10-ifx-c5d/test-runs/cb11dd5419e74159895a9ac536f01e1d/summary.json`.
Tampered, missing and stale locks, zero tests, high vulnerability and a
failed summary blocked. The isolated TargetRoot and PackageRoot remained
byte-invariant. The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-ddc5a5b65bb840599af479534e48f205`.
Exact committed Formal Diff follows.
