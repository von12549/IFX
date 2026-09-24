# V4 P10.1 C1 R3a — bounded Pre timeout budget

Status: `EXECUTION PLAN — C1 REMAINS BLOCKED`

R3's first real combined 1.1.3 Pre run stopped with `ifx-package-reference`
adapter timeout before a rule verdict. Its candidate module has a 30-second
ceiling while traversing the complete freshly rebuilt `src` tree; the C1h
source parser already uses 180 seconds. Raise only the nine applicable C1
Pre module manifests still at 30 seconds to a common 180-second ceiling.
No adapter, policy, rule plan, V4 Host, published Package or source project
bytes change. The synthetic review ceiling remains exactly equal to each
module manifest. This is a bounded execution budget, not a waiver or a
success claim. Re-run candidate module schema/hash checks, the integrated
Profile, isolated package regression and exact Formal Diff. If 180 seconds
still fails, investigate traversal behavior in a separate scoped Plan rather
than raising the ceiling again.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r3a/formal-pre/summary-pre.json`.
All nine changed module manifests pass the published 1.1.3 module schema;
adapter hashes, network=false and empty write roots are unchanged. The
integrated synthetic-only 1.1.3 Profile at
`artifacts/guards/p10-ifx-c1-r3/test-runs/d1c6a5e8983245a286446d008ac01a8b/summary.json`
passed real IFX direct Pre (10 modules), direct Post (3), and dependency Post
(13), including `ifx-package-reference` without timeout. Its 25 claims had
nonzero coverage; C1m separately validated two bounded applicability cases.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-236a6df15c0c4af786d1f913a6ced574`.
Exact Formal Diff follows the scoped commit. This R3a evidence does not by
itself close C1; R3's same-commit final evidence and decision remain pending.
