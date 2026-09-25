# IFX C6c15 G03 source reconciliation scan decision

Date: 2026-09-25
Status: implementation complete; final C6 certification rerun required

## Trigger

The C6c14 final certification at
`%TEMP%/ifx-c6c14-final/c6c14ee5e2c149389d7f043b9c101418`
completed the Windows suite outputs and did not report a Controls failure.
Linux failed only because `ifx-g03-source-reconciliation` exceeded its
existing 60-second module ceiling.

## Decision

The adapter's two independent source snapshots now use a queue of safe
directories backed by `System.IO.Directory` enumeration. Directory and file
reparse points are rejected before traversal or reading, `bin` and `obj` are
pruned, and only top-level `.cs` and `.csproj` semantic inputs are materialized
from each safe directory.

The two-snapshot determinism check, all G03 reconciliation logic, exact counts,
findings, coverage, and the 60-second capability ceiling are unchanged. The
module manifest, combined G03 authority lock, and C6 matrix contract are bound
to the new adapter bytes.

## Verification

- Formal Pre passed at
  `artifacts/guards/p10-ifx-c6c15/formal-pre/summary-pre.json`.
- C2c1 passed 14 fixtures, integrity and link controls, repeat determinism, and
  the real IFX scan at
  `artifacts/guards/p10-ifx-c6c15/owning-c2c1/cf786c5755bc449599042813399401cd`.
- The real repository scan passed inside the locked Linux image in 49.188
  seconds with all three claims matched and zero findings.
- Combined C2e passed seven Host cases, four Profile rejection controls, and a
  fresh V3 Phase 9 run at
  `artifacts/guards/p10-ifx-c6c15/combined-c2e/21157622c7b64a45907ba06236c413dc`.

## Certification consequence

C6c remains open until the committed C6c15 HEAD receives fresh inventory,
same-commit locks and candidate evidence, followed by Windows/Linux 191/191,
42 lock controls, 180 capability variants, semantic parity, zero gaps, and
formal Diff.

