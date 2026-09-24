# V4 P10.1 C5h — Historical Integrity candidate

Implement an independent read-only V4 Post module for the 15 historical
files and three reference edges locked by C5a. Copy the V3 manifest's
facts into an extension-owned policy; do not execute or import V3 runtime
code. The policy retains each expected canonical-text hash and selected
JSON summary fields. A historical `passed` value proves only that a frozen
record is unchanged; it is never current readiness or a waiver.

The candidate must reject a missing, stale, malformed or altered record,
changed summary fields, missing reference, zero-subject scan or policy
drift. Validate real IFX direct Post and published 1.1.3 synthetic Host
Post with TargetRoot and PackageRoot immutable. No production Profile or
bundle approval follows from this tranche.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5h/formal-pre/summary-pre.json`.
The extension policy maps all 15 V3 manifest entries, their hashes and
summary fields, plus all three reference edges exactly. Real IFX direct
Post and published 1.1.3 synthetic Host Post passed at
`artifacts/guards/p10-ifx-c5h/test-runs/78523d7db294403885910796751f02a7/summary.json`.
Tampered, missing and malformed files, changed historical summary,
missing reference, zero-subject target and policy drift blocked; canonical
CRLF/LF normalization remained equivalent. TargetRoot and PackageRoot were
byte-invariant. The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-378b2da2895140d99f03df6cb0625752`.
Exact Formal Diff passed at
`artifacts/guards/p10-ifx-c5h/formal-diff/summary-diff.json`.
