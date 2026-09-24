# V4 P10.1 C1 R1a — published compiled-type feasibility

Status: `BOUNDED FEASIBILITY TEST — NOT C1 CLAIM ACCEPTANCE`

Test the *installed, receipted* 1.1.3 `architecture-conformance`
`ARCH.TYPE_DEPENDENCY` Post adapter against the current CRM Domain and
Contracts Release/net8.0 DLLs, with their explicit local assembly closure.
Bind the exact V3 `ARCH.BINARY.DOMAIN.CONTRACTS` assembly, namespace and
minimum-match facts; do not substitute C5c's assembly-name allowlist.
Run clean, absent-namespace zero-match and missing/altered DLL controls.
Read the current C5b/C5c locks but do not yet treat this probe as the
fresh locked evidence bridge or a Host/Profile acceptance. A later R1b
tranche must implement that bridge, violating fixture, Host direct/dependency
tests and immutable-root checks.

Only this Plan pair and one test script may change. Formal Pre precedes
the test script; package regression and exact Formal Diff follow its commit.
No source, installed Package, release or production Profile may change.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r1a/formal-pre/summary-pre.json`.
The installed 1.1.3 adapter inspected the real Release/net8.0 CRM
assembly closure and reported four matched source/forbidden type pairs.
Zero subject, missing DLL and altered SHA-256 blocked with
`findings-blocking`, `prerequisite-missing` and `integrity-failure`,
respectively. Evidence:
`artifacts/guards/p10-ifx-c1-r1a/test-runs/a10e82437b6248daab99068fc0f06b31/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-a70db4d57ff040439bab63f5ee29195b`.
Exact Formal Diff follows this committed candidate.
