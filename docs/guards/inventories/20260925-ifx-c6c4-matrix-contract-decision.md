# IFX C6c4 matrix contract remediation decision — technical pass, C6c pending

Status: `REMEDIATION TECHNICAL PASS / C6c NOT YET CERTIFIED`.

This record closes the matrix-contract incompatibilities exposed by the blocked
C6c3 Windows run. It does not promote that candidate, issue Xiaolong Feng's
accepted review, authorize release, pass C6d/C6e, or claim native Linux and
confinement certification. Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c6c4/formal-pre/summary-pre.json` (SHA-256
`4694a416b7fe7c60cb3f29b1ddc71a9023059c0b3c4ae08b954611c29761f6fc`).

## Bound contract and implementation

The implementation checkpoints are `10e4d5bc`, `176f792b`, `ef7703e4`,
`e2841733`, `74f5f9a2`, `ecc9a4ac` and `8604b750`. The machine-readable
contract covers the frozen C6b0 inventory's 37 modules, 80 blocking rules and
three advisory rules:

- matrix contract:
  `docs/guards/candidates/ifx-gate-coverage-c6c4/matrix-contract.json`
  (`0a00e68657769404b027014c295a2786539db7f56ce0379206737c525443b19c`);
- contract verifier:
  `docs/guards/candidates/ifx-gate-coverage-c6c4/Test-IFXC6MatrixContract.ps1`
  (`3defe64cb395b403d80de000aee868b4ad38d5bc510a26f7d591be935567751a`);
- complete fixture specification:
  `docs/guards/candidates/ifx-gate-coverage-c6c4/fixture-spec.json`
  (`fdc3c0c5820eba86736844c9b5bab50b8c3d329d6498a16106de8ae008550053`);
- supplemental suite:
  `docs/guards/candidates/ifx-gate-coverage-c6c4/Test-IFXC6SupplementalFixtures.ps1`
  (`6fafe5dc1b0837af960982533e868ea7680fb4b4a7553c318e31c1b813a56664`);
- remediated matrix runner:
  `docs/guards/candidates/ifx-gate-coverage-c6c3/Test-IFXC6IndependentMatrix.ps1`
  (`23d73582903285029c2a3a02fcd02b1f58c90411fa81c9c771972352f30edde1`).

The contract replaces the structurally impossible universal `matched = 0`
requirement with adapter-bound `enumerated-zero`, `fixed-checklist-zero` and
`integrity-zero` semantics. Fixed-checklist cases bind an exact rule, subject,
evidence kind and detector identity while retaining nonzero evaluation
coverage. Minimal coupled rule sets are allowed only where the frozen adapter
makes the companion finding unavoidable. No detector, producer, module,
published 1.1.3 byte, baseline or waiver was changed.

## Diagnostic proof

The supplemental suite executed 25 frozen composed-package adapter calls. It
includes disposable source-policy authorities, real compiled architecture
assemblies, G04/G05 authority sets, and a copied C5-to-C1 evidence lineage
whose time and run-path fields were refreshed before the frozen adapters
revalidated every source hash, evidence hash and lineage edge. Its capture is:

`artifacts/guards/p10-ifx-c6c4/supplemental-prototype-r18/captures.jsonl`
(`66651d3f311e718fe5d00e9723548a238b4e61ff299e4743b0aaa0671c6c354d`).

Applying the verified contract to the blocked C6c3 run's 500 historical
captures plus those 25 supplemental captures proves all 191 required core rows
and projects all three advisory rules. The result has zero gaps:

`artifacts/guards/p10-ifx-c6c4/matrix-contract/reclassification-r18.json`
(`82e2dfa8eaba3070b2b4dd4fe602b4fa4fe79f7defd4205863dd249ce328ff85`).

This is deliberately labeled `historical-captures-diagnostic-only`. It proves
that the remediated contract and frozen-adapter fixtures can satisfy the full
matrix; it does not turn the source commit `29f4cd99` candidate or its expired
locks into current certification evidence.

## Decision and required continuation

C6c4 matrix remediation is technically complete. C6c remains pending. The
next run must regenerate the C6b0 inventory, all seven short-lived evidence
locks, the 0.3.0 bundle and synthetic review from the current implementation
commit. It must then execute the remediated 191-row Windows matrix, the full
seven-lock negative matrix, capability-broadening, overlap/traversal/link and
attempted immutable-root write controls, native pinned-offline Linux semantic
parity, direct Pre `10/22`, direct Post `27/57`, dependency Post `37/79`, the
isolated Package regression, Formal Pre and exact committed Formal Diff.

The C6c4 isolated Package regression passed its positive case and all six
negative classes at
`artifacts/guards/v3-ifx-package-test-773930eb85894f678976154a4cd6b7bd`.
Exact committed Formal Diff for the eight declared C6c4 paths passed at
`artifacts/guards/p10-ifx-c6c4/formal-diff/summary-diff.json`. These checks
close the remediation plan's validation obligations; they do not substitute
for the fresh candidate and certification continuation listed above.

No C6c3 lock, candidate, review, matrix summary or case manifest is promoted by
this decision. G04 remains `PRE-READY`; P10.2/P10.3 and V3 retirement remain
out of scope.
