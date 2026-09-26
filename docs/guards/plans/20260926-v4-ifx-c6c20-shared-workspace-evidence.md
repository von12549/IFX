# V4 P10.1 C6c20 — Shared workspace evidence and Linux timing closure

Status: `IMPLEMENTED — DEVELOPMENT DIAGNOSTIC PASS; C6c NOT YET CERTIFIED`

The initial C6c Linux 300-second diagnostic completed all 37 module invocations
but identified three hard timeouts, two passing modules above their declared
60-second budgets, and repeated workspace traversal/hash work across the
candidate set. The remediation below is implemented. Thirty unchanged modules
from the full Linux run plus seven corrected focused Linux measurements now form
a 37/37 passing composite development diagnostic. A new composed-package run is
still required before certification.

## Exact remediation

1. Add a deterministic, read-only workspace evidence producer that enumerates
   governed source roots once, rejects links, normalizes paths, caches text and
   raw/normalized SHA-256 values, and binds the result to the target commit.
2. Add shared guard helpers for safe path handling, hashing, canonical evidence
   loading, and bounded .NET directory enumeration.
3. Migrate `ifx-domain-reference`, `ifx-project-name`, `ifx-g05-inventory`,
   `ifx-plan05-security`, and `ifx-database-evidence` to consume the locked
   workspace evidence during the Linux diagnostic while retaining a compatible
   direct-scan fallback.
4. Remove duplicate G03 reconciliation/snapshot source scans by reusing one
   immutable in-process projection.
5. Preserve all rule, finding, coverage, authority, zero-subject, and source
   inventory contracts.
6. Keep the diagnostic watchdog at 300 seconds for every module. Do not tighten
   formal timeout budgets until one complete Linux run passes and records all
   real module durations.
7. Run focused equivalence tests before exactly one complete Linux timing run.

The shared evidence path is initially exercised by the development diagnostic
runner. Promotion into the reviewed extension Profile and certification matrix
requires a separate binding decision after semantic and timing equivalence are
demonstrated.
