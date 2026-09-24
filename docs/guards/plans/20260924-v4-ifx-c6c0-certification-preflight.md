# V4 P10.1 C6c0 — exact-candidate certification preflight

Status: `EXECUTION PLAN — C6c CERTIFICATION NOT YET PASSED`

C6b1 produced a 0.3.0 synthetic-review IFX bundle against published 1.1.3.
Its passing Host report is bound to development commit
`05558f8bc6a8a6d1483049f5ebedb3bba216004b`; its one-hour type,
evaluated-graph and generated-input locks are not reusable for final C6c.
This tranche checks whether the exact candidate can be certified on native
Windows and a pinned, network-disabled Linux runner without weakening any
module policy or treating synthetic review as human approval.

Verify the current clean source commit, C6b1 manifest and Profile hashes,
published 1.1.3 base/archive/receipt, pinned Linux image digest, SDK and
cached dependencies. Run the approved V4 Windows-full and Linux-complete
platform suites on one clean commit where possible. Separately determine
whether all seven IFX evidence locks can be freshly produced and consumed on
both platforms within their validity windows, including the exact SDK
`10.0.303` required by the evaluated-reference producer. Preserve any
failed or skipped result as a C6c blocker, not a substitute pass.

No C6b1 bundle, published Package, installed receipt, IFX TargetRoot
authority, module adapter, producer policy or dependency lock may be changed
in this preflight. No network download, publication, human review record or
operational composition is authorized by this Plan. A full C6c certification
child Plan follows only after runner feasibility is resolved; it must refresh
short-lived locks, freeze exact bundle bytes and run independent clean,
violation, missing-input and zero-match cases on Windows and offline Linux.

Formal Pre precedes the decision record. Only this Plan pair and its
preflight decision note are planned source paths. Isolated package regression
and exact committed Formal Diff close this bounded tranche. G04 remains
`PRE-READY` with seven blockers, and G05 Phase 9 plus Diff/CI remain
P10.3-deferred. C6d review and C6e installed Web UI are not entered.
