# V4 P10.1 C6c7 certification-runner rebind decision

Decision: `ACCEPTED FOR C6c RE-CERTIFICATION`

Remediation commit evaluated: `9f86515eeb0ca1efc598913cd706205c8a6f8bb7`

This decision accepts the bounded C6c7 harness repair. It does not by itself
certify C6c: the C6c5 control and native Windows/Linux matrix run must still
pass with a fresh inventory, seven locks, bundle and review bound to the final
committed HEAD.

## Implemented repair

The independent-matrix contract now binds the C6c6 inventory projection and
the five adapters changed by target-commit enforcement. The supplemental
fixture specification binds the resulting contract plus the five owning suite
files. No module, rule, fixture recipe, expected classification or matrix
cardinality changed.

The certification-control runner copies the byte-identical candidate bundle
and review into its external temporary work root before positive composition,
so its roots are disjoint while the original candidate remains immutable. The
Linux wrapper applies `core.autocrlf=true` and `core.filemode=false` only to its
read-only tracked-file status check, matching the frozen native Linux runner's
treatment of a Windows-mounted checkout.

Published 1.1.3 bytes, detectors, policies, baselines, waivers, reviewed
capabilities and G04 governance were not changed.

## Pre-certification evidence

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c6c7/formal-pre/summary-pre.json`. PowerShell parser
validation passed for both modified runners, all three modified JSON documents
parsed successfully, and the independent matrix contract passed against the
final C6c6 inventory at
`artifacts/guards/p10-ifx-c6c7/contract/summary.json`.

The verified contract remains 37 modules, 80 blocking rules and 3 advisory
rules. The certification-control source retains its explicit 42 lock-control
and 180 capability-variant assertions.

## Remaining certification boundary

Because committing this decision changes HEAD, all prior inventory, locks,
bundle and review are diagnostic evidence only. C6c re-certification must now
regenerate them at the final commit, run the C6b1 same-candidate checks, and
pass the C6c5 controls plus identical native Windows and pinned offline Linux
191-row matrices with zero gaps and equal normalized semantics.

C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope; G04 remains
`PRE-READY`.
