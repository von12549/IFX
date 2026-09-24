# V4 P10.1 C6c4 — independent matrix contract remediation

Status: `EXECUTION PLAN — C6c REMAINS BLOCKED`

C6c3 executed 500 adapter calls against one source-bound Windows candidate but
proved only 136 of its required 191 core rows. Its blocked decision correctly
refused certification. Subsequent analysis also showed that part of the gap is
in the certification contract itself rather than absent fixture bytes: several
fixed-checklist and locked-evidence adapters increment coverage for every
check performed after prerequisites succeed, so a valid blocking result with
`matched = 0` is structurally impossible without changing module semantics.
Some rules are similarly coupled by implication and cannot truthfully be the
only rule ID emitted by a violating input.

This child repairs that incompatibility before further certification work. It
does not certify C6c, change a detector, external module, policy, producer,
published 1.1.3 byte, baseline or waiver, and does not reuse the blocked C6c3
candidate as passing evidence.

## Frozen contract and classifications

Add one machine-readable matrix contract covering all 37 modules, all 80
blocking rules and all three advisory rules from the C6b0 ordinal inventory.
For every module it records exactly one non-vacuity strategy:

1. `enumerated-zero`: syntactically valid input selects no governed subject;
   the adapter must return `fail/findings-blocking`, every owned blocking claim
   must report `matched = 0` with its positive minimum, and an explicit
   non-vacuity finding must be present.
2. `fixed-checklist-zero`: prerequisites remain valid and a minimized or empty
   governed authority/evidence population triggers an explicit blocking
   non-vacuity finding; coverage must show that the fixed checklist was
   evaluated and may not be rewritten to zero. The contract names the exact
   allowed rule, subject and evidence-kind identity.

The second strategy is allowed only when static review of the committed adapter
shows that coverage counts performed checks rather than selected subjects. The
contract records the adapter SHA-256 and the exact source facts supporting that
classification. A missing classification, stale adapter hash, unowned claim or
unexplained departure from `enumerated-zero` fails closed.

For every blocking rule the contract also records either `isolated` or a
minimal `coupled` rule set. A coupled set is permitted only where the committed
detector makes the target rule logically imply the companion finding. Each
rule still requires its own fixture identity and exact target finding; a case
may contain no blocking rule outside its declared coupling set. Coverage for
the target claim must remain nonzero. This does not permit ignored findings or
rule-level waivers.

## Runner and fixture remediation

Add a contract verifier that proves complete ordinal coverage, exact ownership,
fresh adapter hashes, valid non-vacuity identities, symmetric coupling and no
unknown fields. Amend the C6c3 runner to consume only a verified contract and
to emit the strategy and allowed coupling beside every Z/V row. C and M keep
their existing strict definitions. The runner must continue to require exact
finding subject/detector/evidence identities, process exit zero, immutable
TargetRoot/PackageRoot and a complete 191-row core manifest.

Add one supplemental fixture suite and machine-readable fixture specification
only for rows that remain genuinely absent after applying the verified
contract. Supplemental cases execute the frozen composed package adapters;
they may copy or minimize reviewed fixture bytes into disposable roots but may
not edit or substitute module bytes. Every fixture records source paths,
content hashes, expected stage/input, expected rule/claim/finding identities
and the matrix row it alone supplies. Existing tranche test results remain
cross-checks, not authorities.

First run a diagnostic Windows matrix on current committed runner/candidate
inputs to freeze the residual gap list. If a residual row cannot be created
without changing detector/module/policy bytes, stop with a new blocked
decision. Otherwise commit the runner, contract and fixture implementation,
then regenerate the C6b0 inventory, all seven short-lived locks, the 0.3.0
candidate and synthetic review from that implementation commit. No C6c3 lock,
bundle, matrix result or review may be promoted.

## Certification continuation

Only after the remediated Windows core matrix proves all 191 rows may the same
candidate continue through the seven-lock negative matrix, capability
broadening, root overlap/traversal/link and attempted immutable-root write
controls required by C6c3. The identical case manifest and fixture bytes must
then pass on pinned offline native Linux with matching semantic projections.
Direct Pre `10/22`, direct Post `27/57` and dependency Post `37/79`, published
1.1.3 receipt/archive identity, PackageRoot/TargetRoot/lock/evidence invariance,
isolated `ifx-package-test`, Formal Pre and exact committed Formal Diff remain
mandatory.

The final decision must distinguish contract remediation from C6c technical
certification. C6d human acceptance and C6e installed composition remain
unpassed; G04 remains `PRE-READY`; P10.2/P10.3 and V3 retirement are out of
scope.

Only this Plan pair, the matrix contract/verifier, supplemental fixture
specification/suite, the existing C6c3 runner and the C6c4 decision note are
planned source paths. Evidence under `artifacts/guards/p10-ifx-c6c4` is
ignored. Formal Pre must pass before executable edits.
