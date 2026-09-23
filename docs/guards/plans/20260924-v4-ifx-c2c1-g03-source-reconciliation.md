# V4 P10.1 C2c1 — G03 fresh source reconciliation candidate

Status: `CANDIDATE VALIDATED — partial C2c only; Formal Diff pending`

Implement a read-only Post extension that derives current G03 source facts
from TargetRoot, not from a saved V3 report. It must count public Contracts,
Abstractions, Readers, methods, DTOs, events and Messaging types; exclude
generated `bin/obj`; compare pending legacy surfaces with source; verify
each catalog protocol declaration/member and consumer or handler evidence;
and reconcile non-retired legacy DTO/Event field inventories to source.
The current exact Phase 9 counts are 0 Abstractions projects, 4 Readers,
4 Reader methods, 0 DTOs, 2 integration events and 4 Messaging contract
types. The source scan and results must be deterministic and read-only.

Bind the current catalog and candidate policy via reviewed hashes and
freeze the V3 detector/authority hashes for independent review. Test clean,
violating, missing, stale, zero-source and linked-path controls, deterministic
findings, TargetRoot byte invariance, schema/authority locks, published V4
1.1.2 synthetic Host Post, isolated package regression and Formal Pre/Diff.
Formal Pre must precede executable edits. Do not alter production Profile,
published Package, or existing PATH-repair files.

C2c2 retains the deterministic sync API and serialization snapshot checks.
C2d retains docs/closeout; C2e retains combined Stage/parity and final
acceptance. C2c1 alone cannot close C2 or G03.

## Verification record

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c2c1/formal-pre`. The read-only source candidate
passed 14 clean/negative/missing/zero fixtures, hash drift, linked source,
determinism and TargetRoot byte-invariance controls. The real IFX source
scan and synthetic-only published V4 1.1.2 Host Post both passed; final
candidate evidence is under
`artifacts/guards/p10-ifx-c2c1/test-runs/316bc3d294cc4f5ba808d597499f7fb1`.
The isolated IFX package positive/negative regression passed at
`artifacts/guards/v3-ifx-package-test-228d018762514340bbc852a84e0df74b`.
Published Package identity remained `pass` at Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
Exact Formal Diff remains to be run against the committed tranche.
