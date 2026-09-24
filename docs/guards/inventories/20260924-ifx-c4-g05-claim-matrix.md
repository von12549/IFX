# IFX C4 — G05 Phase 11 and Plan05 security inventory

The fresh V3 composite replay at `artifacts/guards/p10-ifx-c4/g05-baseline`
passed 120 G05 Phase 11 checks and 13 Plan05 security checks. The separate
G05 status remains `pre-ready`, with seven named blockers and eight tracked
C3 field exceptions. Neither the replay nor this inventory grants closure.

The companion JSON maps all 133 check IDs, in V3 report order, to explicit
`C4-G05-context` (112), `P10.3-deferred-G05-verification` (8 Phase 9 IDs),
or `C4-G05-security` (13) destinations. The eight IDs are retained as
required governance obligations, not waived or counted as C4 V4 runtime
coverage. This classification follows the explicit Phase 9 option A decision:
the V4 runtime must not bind V3 verification scripts, workflow or historical
test baseline. P10.3 owns their transition and fresh verification. The matrix
locks four V3 detector hashes, twelve target policy authorities, the G05
status hash, dynamic source-scan roots, and the published 1.1.3 Package hash.
The detector scripts remain V3 reference inputs only; a V4 implementation
must independently express and test each active claim.

Context checks cover protocol primitives, execution context, HTTP and
contract/event carriers, field governance, operational security, replay,
verification, documentation and PRE-READY handoff. The Plan05 checks cover
pure authentication/authorization contracts and runtime, identity and
tenant-bound authorization, host composition and compatibility exceptions.
Tests or evidence-file presence in V3 is a source fact; fresh test execution
is not implied. Subsequent executable C4 tranches require negative, missing,
stale and zero-subject controls and must preserve this explicit boundary.
