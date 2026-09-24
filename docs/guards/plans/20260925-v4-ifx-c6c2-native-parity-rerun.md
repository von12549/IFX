# V4 P10.1 C6c2 — native Linux parity rerun

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c1 at commit `64506b5a67f5f9dd81ab054aa9c774bd11261024` passed the
Windows 1.1.3 same-bundle run but Linux failed closed at Plan04 Abstractions
source inventory. The Linux runner has since been amended to reproduce the
clean Windows tracked file bytes and the C4a4-scanned directory topology in
an ephemeral native checkout. The earlier candidate and short-lived locks
cannot be reused as final evidence.

This tranche regenerates the C6b0 inventory and all seven lock families on
one current committed source snapshot. Producer order is frontend, database,
solution, generated-input, assembly, type, then evaluated graph; the
solution/assembly relationship and Type DLL bytes must not be invalidated by
later builds. Re-evaluate the graph on pinned offline Linux SDK 10.0.303 and
compare its semantic projection to Windows. Build a new 0.3.0 synthetic-review
bundle from the unchanged 36 external modules plus published built-in
Architecture Conformance; freeze manifest, Profile, archive, receipt, seven
lock identities and complete bundle inventory.

Run Windows direct Pre/Post and dependency Post, then Linux against the exact
same bundle bytes using a platform-native 1.1.3 receipt from the same
published archive. Require 10/27/37 modules, 22/57/79 claims, nonzero
coverage and zero findings; verify unchanged Package, TargetRoot and locks.
Any mismatch must fail closed and be recorded by module and input, not
converted into a baseline, timeout increase or replacement candidate. The
Linux runner may be edited only to correct evidence transport/reproduction,
not the published Host, installer, modules or 1.1.3 base.

Only the Plan pair, the existing C6c1 Linux runner and a C6c2 decision note
are planned source paths. Formal Pre must pass before runner/decision edits;
the isolated IFX Package regression and exact committed Formal Diff are
required before closure. Evidence under `artifacts/guards/p10-ifx-c6c2` is
ignored and never becomes approval. Independent detector-family
clean/violation/missing/zero-match and the remaining capability/cross-root
controls stay explicit C6c blockers, not certified by a dual-platform green
run. C6d human review and C6e installed Web UI remain out of scope.
