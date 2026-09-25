# V4 P10.1 C6c7 — certification runner rebind

Status: `EXECUTION PLAN — C6c REMAINS BLOCKED`

C6c6 repaired target-commit binding and all five owning suites passed. The
first unchanged C6c5 parallel run then failed closed before executing the
matrices for three certification-harness reasons:

- the C6c4 matrix contract still binds the pre-C6c6 adapter projection;
- the C6c5 control runner composes a bundle located below TargetRoot, which the
  published composer correctly rejects as overlapping roots;
- the Linux wrapper performs its initial Windows-mounted source cleanliness
  check without disabling Git file-mode comparison.

## Exact remediation

Rebind `matrix-contract.json` to the regenerated C6b0 projection and the five
C6c6 adapter hashes. Rebind `fixture-spec.json` to the changed matrix contract
and changed owning-suite bytes; do not change any fixture recipe, case identity,
classification, count or expected outcome.

In the control runner, copy the exact candidate bundle and review record into
its existing external temporary WorkRoot before the positive composition, and
compose from those byte-identical copies. All mutation cases continue using
their existing isolated copies. In the Linux wrapper, apply
`core.filemode=false` and `core.autocrlf=true` to the initial read-only status
check, matching the already frozen native-Linux candidate runner.

No module, adapter, profile, evidence producer, lock, capability, policy,
baseline, waiver, published 1.1.3 byte, matrix case or orchestrator behavior is
changed.

## Validation and decision boundary

Run Formal Pre before executable edits; run the matrix-contract verifier and
static 42-lock/180-capability cardinality checks; reuse the still-fresh final
seven locks and exact candidate only if every byte they lock remains unchanged;
then rerun the C6c5 parallel certification into a new absent EvidenceRoot.

Certification requires controls, Windows and Linux to pass, both native
matrices to prove all 191 core cases with zero gaps and normalized semantic
equality, and every wrong-commit case to return `error/integrity-failure`.
Finally run the isolated package regression and exact committed Formal Diff.
Stop without C6c certification on any substantive detector, fixture or expected
outcome change. C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope; G04
remains `PRE-READY`.

Only this Plan pair, `matrix-contract.json`, `fixture-spec.json`, the C6c5
control runner, Linux wrapper and the C6c7 decision record are planned source
paths.
