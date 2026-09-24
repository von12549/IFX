# V4 P10.1 C6b0 — full module and claim preflight

Status: `EXECUTION PLAN — C6b inventory, not bundle acceptance`

C6a selected the published, receipted 1.1.3 base. Before writing a new
`ifx_profile` bundle, independently enumerate the exact reviewed C1–C5
candidate module directories and the built-in Architecture Conformance
selection. This tranche is read-only against all candidate sources, the
installed base and IFX TargetRoot. It records a deterministic ordinal
module/claim matrix with source, manifest/adapter/lock/policy hashes,
declared Stage, prerequisites and capability ceilings; it does not copy
modules into a bundle or select expiring evidence locks as durable inputs.

The expected scope is ten C1 Pre modules, the built-in compiled-type Post
selection, two C1 Post modules, and 24 C2–C5 Post modules: 37 selections,
79 distinct active blocking-capable claims (25 C1 and 54 C2–C5), represented
by 80 blocking rules and three supplementary advisory rules, plus the two
separately bounded C1m applicability decisions. Three C1 canonical rule IDs
may repeat only with their distinct primary/supplementary claim and detector
owners. C1h's three advisory rules share claim IDs with blocking rules and
must remain advisory, not be promoted or silently omitted. Zero-match,
inactive and P10.3-deferred facts remain separately classified. The seven G04
`PRE-READY` blockers remain governance facts, not accepted production
readiness.

The executable preflight must verify each selected module's public manifest
schema, adapter/dependency/authority hashes, rule-plan Stage, exact
blocking/advisory severity, nonzero minimum, absence of baseline, uniqueness
of module and claim identities, and default-deny write/network capabilities. Bind the
published 1.1.3 Package hash, C1 R3 and C5f summaries, C1m decision and
candidate source commit. Output the complete ordinal matrix under
`artifacts/guards/p10-ifx-c6b0` and record its hash in the inventory note.
Do not infer a combined Host pass: C6b1 must still construct and exercise
the actual final draft Profile and resolve all config/evidence-lineage joins.

Only this Plan pair, its read-only preflight script and the inventory note
are planned paths. Formal Pre precedes script and inventory edits. Exit
requires the preflight result, isolated `ifx-package-test`, exact committed
Formal Diff and an explicit C6b1 handoff. No final manifest, human review,
composition, installation, Web UI practice or P10.1 closure is authorized.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c6b0/formal-pre/summary-pre.json`. The read-only
inventory passed at
`artifacts/guards/p10-ifx-c6b0/inventory-runs/b423b55239cd4e729ab8e1ba007649da/summary.json`;
the full ordinal matrix hash and scope are in the inventory note. Isolated
`ifx-package-test` passed at
`artifacts/guards/v3-ifx-package-test-c3178eefc48b4560a467bb7e5f53fdbf`.
The exact post-commit Formal Diff is required at
`artifacts/guards/p10-ifx-c6b0/formal-diff/summary-diff.json`.
