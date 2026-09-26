# IFX C6c20 Linux 300-second timing result

Status: `DEVELOPMENT DIAGNOSTIC PASS — NOT CERTIFIED`

Target commit: `9097149d0b95e87e7fa6f705ae1133743b87b2b1`

The Linux watchdog remained at 300 seconds. Shared workspace evidence enumerated
1,152 governed files once in 9.515 seconds. All 37 modules have a passing Linux
measurement and no blocking findings. Their measured module time totals 627.226
seconds; adding one shared-evidence production gives a projected sequential time
of 636.741 seconds (10 minutes 36.741 seconds).

This is a composite development result, not a certification run. Thirty unchanged
modules come from the single 37-module Linux run. That run exposed a diagnostic
runner defect: development manifests were loaded, but their adapters were still
resolved from the previous C6c19 package. After fixing adapter resolution and
adding an adapter-hash check, the seven changed modules were measured in one
focused Linux run. No second 37-module run was performed.

| # | Module | Seconds | Result | Timing source |
|---:|---|---:|---|---|
| 1 | `ifx-domain-reference` | 5.576 | pass | focused optimized |
| 2 | `ifx-package-reference` | 17.889 | pass | full baseline |
| 3 | `ifx-ring-graph` | 32.037 | pass | full baseline |
| 4 | `ifx-ownership-graph` | 32.186 | pass | full baseline |
| 5 | `ifx-provider-cycle` | 0.535 | pass | full baseline |
| 6 | `ifx-embedded-adapter` | 25.714 | pass | full baseline |
| 7 | `ifx-source-policy` | 36.721 | pass | full baseline |
| 8 | `ifx-project-name` | 0.885 | pass | focused optimized |
| 9 | `ifx-reference-cycle` | 31.955 | pass | full baseline |
| 10 | `ifx-injection` | 29.637 | pass | full baseline |
| 11 | `architecture-conformance` | 1.506 | pass | full baseline |
| 12 | `ifx-c1-type-provenance` | 56.853 | pass | full baseline |
| 13 | `ifx-c1-evaluated-reference` | 55.948 | pass | full baseline |
| 14 | `ifx-g03-governance-core` | 1.488 | pass | full baseline |
| 15 | `ifx-g03-catalog-semantics` | 0.936 | pass | full baseline |
| 16 | `ifx-g03-source-reconciliation` | 1.341 | pass | focused optimized |
| 17 | `ifx-g03-snapshots` | 1.598 | pass | focused optimized |
| 18 | `ifx-g03-docs-closeout` | 16.056 | pass | full baseline |
| 19 | `ifx-g04-manifests` | 1.725 | pass | full baseline |
| 20 | `ifx-g04-runtime` | 2.307 | pass | full baseline |
| 21 | `ifx-g04-closeout` | 7.926 | pass | full baseline |
| 22 | `ifx-plan04-extraction` | 1.651 | pass | full baseline |
| 23 | `ifx-plan04-tenant` | 20.382 | pass | full baseline |
| 24 | `ifx-plan04-projection` | 9.883 | pass | full baseline |
| 25 | `ifx-plan04-abstractions` | 12.261 | pass | full baseline |
| 26 | `ifx-database-evidence` | 33.846 | pass | focused optimized |
| 27 | `ifx-g05-inventory` | 1.763 | pass | focused optimized |
| 28 | `ifx-g05-protocol` | 2.353 | pass | full baseline |
| 29 | `ifx-g05-execution-http` | 27.339 | pass | full baseline |
| 30 | `ifx-g05-carriers` | 2.640 | pass | full baseline |
| 31 | `ifx-g05-governance` | 6.174 | pass | full baseline |
| 32 | `ifx-g05-closeout` | 7.539 | pass | full baseline |
| 33 | `ifx-plan05-security` | 3.103 | pass | focused optimized |
| 34 | `ifx-solution-evidence` | 56.996 | pass | full baseline |
| 35 | `ifx-assembly-evidence` | 53.254 | pass | full baseline |
| 36 | `ifx-frontend-evidence` | 24.385 | pass | full baseline |
| 37 | `ifx-history-integrity` | 2.838 | pass | full baseline |

## Implemented

- One bounded, link-safe producer now supplies canonical paths, cached UTF-8
  text, raw SHA-256, LF-normalized SHA-256, a tree digest, and target commit.
- Seven traversal/hash-heavy adapters consume the locked evidence while retaining
  their direct-scan fallback and existing rule/finding/coverage semantics.
- Consumers verify the evidence SHA-256 and target-commit binding before use.
- G03 source projections are reused within each adapter.
- The diagnostic runner now resolves development adapters from their actual
  candidate directories and rejects adapter/manifest hash drift.

## Remaining work

- Keep shared workspace evidence as an optional, hash- and commit-bound fast
  path. The reviewed Host input contract is unchanged; every consumer retains a
  direct-scan fallback.
- Run one immutable composed-package certification using the existing Host
  contract. The composite result above must not be used as formal certification
  evidence.
- Profile the still-slower passing modules, led by Solution (56.996s), Type
  provenance (56.853s), evaluated-reference (55.948s), Assembly (53.254s),
  source-policy (36.721s), and Database (33.846s).
- Keep the 300-second diagnostic watchdog unchanged; formal certification must
  use each module's declared timeout.

## Declared-timeout fallback qualification

Before formal certification, the two fallback paths that had exceeded their
declared 60-second limit were rewritten to use bounded, link-safe .NET directory
enumeration and single-read hashing/text reuse. A Linux qualification run with
workspace evidence disabled and declared timeouts restored passed both modules:

| Module | Limit | Seconds | Result |
|---|---:|---:|---|
| `ifx-database-evidence` | 60 | 45.529 | pass |
| `ifx-plan05-security` | 60 | 9.036 | pass |

Evidence: `artifacts/guards/p10-ifx-c6c21/linux-declared-fallback-2/summary.json`.
This qualification remains diagnostic-only; the following immutable full run is
the certification authority.
