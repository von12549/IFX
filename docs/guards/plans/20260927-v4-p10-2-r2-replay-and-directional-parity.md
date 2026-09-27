# V4 P10.2-R2 replay-contract and directional-parity repair

Status: authorized execution

## Authorization and predecessor

The user authorized the next repair and continuation step on 2026-09-27.
The predecessor is
`artifacts/guards/p10-ifx-114/p10-2-r1-parity-042/p10-2-decision.json`,
SHA-256
`ea01dbb5560a4893ec482b65b4f26f1e517343fdb6e314ff41753b5512aadaa7`.
It closed P10.2-R1 with 13 gap records, protected-root equality and P10.3
false.

## Goal

Repair the P10.2 evidence runner and independent comparator without changing
the frozen V3/V3_ifx authority, receipted V4 installation, certified C6c
fixtures or prior evidence. Bind the complete executable provider for
supplemental fixtures, compare module-owned semantics directionally for a V3
to V4 migration, retain every V4 strengthening visibly, and rerun P10.2 once
on new absent paths. Stop before P10.3 regardless of outcome.

## Diagnosed defects

1. Four certified V4 replays used the installed module policy instead of the
   certified suite-local policy fixture. C6c4 copied byte-identical receipted
   adapters beside disposable policies for three Provider Cycle cases and one
   Source Policy case. The R1 corpus bound only TargetRoot and therefore did
   not bind the complete provider fixture.
2. The R1 comparator treated unrelated V3 findings on module-specific clean
   fixtures as a regression. For example, the domain-reference clean fixture
   had V3 `OWNERSHIP-REFERENCE` and `RING-REFERENCE` findings, neither owned
   by the `ifx-domain-reference` module under comparison.
3. The R1 comparator treated V4 fail-closed behavior absent from V3 as exact
   disagreement. P10.2 permits an explicit, visible V4 strengthening when it
   is not weaker than V3; this mapping must cover missing-input, zero-match
   and deliberate violation cases, not only zero-match.
4. A real V4 violation correctly exited 16 and wrote its structured result to
   stderr. R1 parsed stdout only and recorded a false engine failure.

## Repair design

### Complete provider binding

- Each projected corpus row binds TargetRoot and the executable provider.
- When a certified capture's executed adapter still exists, require its bytes
  to equal the corresponding receipted installation adapter and bind the
  complete local module-root fingerprint. Use its local policy SHA-256, or
  the certified all-zero missing-policy hash when absent.
- Otherwise use the receipted installation adapter and Profile config.
- Recompute every bound provider and Target fingerprint after execution.
- Current V4 output must remain semantically equal to the certified capture;
  any drift is blocking.

### Directional non-weakening comparator

- Derive each module's owned blocking rule set from the certified violation
  rows; do not infer it from unrelated V3 findings.
- Clean: V4 must pass with no findings. A V3 finding blocks only when its rule
  is owned by the module under comparison. Unrelated V3 rules remain visible
  but do not fail that module's clean row.
- Missing: V4 must return `prerequisite-missing`. Matching V3 failure is
  equivalent; V3 acceptance is recorded as visible
  `v4-fail-closed-strengthening`.
- Zero: V4 must block with explicit zero coverage. V3 acceptance is recorded
  as visible non-vacuity strengthening.
- Violation: V4 must emit the expected blocking rule with subject,
  evidence-kind and detector identity. A matching V3 rule is equivalent;
  absence in V3 is recorded as visible rule-coverage strengthening.
- V4 acceptance, weakened severity, missing expected rule, empty subject or
  evidence kind, provider drift, stale input, or an owned V3 rule missed by V4
  remains a blocking gap. Strengthenings are counted separately and never
  erased.

### Real-run result channel

Parse stdout first and then stderr as the structured result channel. Exit 0
is required for clean and exit 16 is required for the deliberate violation.
Any other exit or unparseable result remains an engine failure.

## Frozen inputs

All P10.2-R1 frozen identities remain unchanged, including Target commit
`40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`, package hash
`739e2035b24f42a0d09719bd78d010de9320452086109fbdd95c064f67e5a6c1`,
Profile SHA-256
`b7aac25f5cefbaf4d99023a71e29130da283debbe7446e160b42d7f1cb385023`,
C6c case-manifest SHA-256
`22d3b8b4ed018bfcfa1456402c6fefc2e53ce730795ed573f77022fb1e247eae`
and the 52 restored Target fingerprints. Frozen engines and evidence are
read-only.

## New paths

- repair evidence:
  `artifacts/guards/p10-ifx-114/p10-2-r2-repair-042/`;
- parity evidence:
  `artifacts/guards/p10-ifx-114/p10-2-r2-parity-042/`;
- external build:
  `D:/IFX-Root/guard-runtime/build/p10-2-r2-parity-042`;
- external runtime evidence:
  `D:/IFX-Root/guard-runtime/evidence/p10-2-r2-parity-042`.

All paths must be absent before use. R1 paths are immutable.

## Execution sequence

1. Validate this Plan and commit it before implementation.
2. Patch only the P10.2 runner and independent comparator. Add a self-test
   covering provider selection, stderr exit-16 parsing, unrelated V3 rules,
   matching parity, visible strengthening and real weakening.
3. Record code hashes and self-test evidence under the new repair path;
   commit before formal execution.
4. Require all frozen hashes, 52 Target fingerprints and new paths.
5. Execute P10.2 once using the new repository, build and runtime paths.
6. Preserve either an accepted decision with a zero blocking-gap count and
   explicit strengthening count, or a stopped decision with all gaps.
7. Reconfirm P10.3 and every activation/cutover boundary remain false.

## Acceptance criteria

- supplemental provider adapters equal receipted adapter bytes and provider
  fixtures are fingerprint-bound before and after;
- all 52 V4 replays equal their certified semantics;
- all 52 V3 results remain visible with module-owned rule scoping;
- the independent matrix has zero weakening or unresolved gaps and separately
  reports every fail-closed strengthening;
- clean and real-violation host runs return their expected exit/result pairs;
- all protected roots are byte-invariant; and
- P10.3, activation, publication, V3 retirement and IFX cutover remain false.

## Stop conditions

Stop on any frozen identity drift, provider adapter mismatch, incomplete
provider fixture, Target mutation, certified V4 drift, V4 weakening, missing
expected blocking semantics, engine failure or unclassified difference. Do
not alter V3/V3_ifx, V4 package/Profile, C6c fixtures or prior evidence. Do
not repair or rerun in place after R2 evidence closes.

