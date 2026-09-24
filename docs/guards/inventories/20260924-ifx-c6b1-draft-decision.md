# IFX C6b1 — combined 0.3.0 draft decision

Status: `TECHNICAL DRAFT VALIDATED — NOT HUMAN-APPROVED`

The candidate is built on the published, receipted V4 1.1.3 base. It selects
the 36 external C1–C5 modules plus the built-in Architecture Conformance
module, reconciled to C6b0's 37-module, 83-rule, 79-claim ordinal matrix.
The draft `ifx_profile` version is 0.3.0; baseline references are empty.
Seven fresh locks were regenerated for development source commit
`05558f8bc6a8a6d1483049f5ebedb3bba216004b` (Solution, Assembly,
Frontend, Database, compiled type, evaluated graph and generated input).
The bundle manifest includes every contributed file hash, reviewed module
capability ceiling, the full ordinal authority map and lock lineage.

Synthetic fixture composition and its receipt passed. This is a technical
test only: the fixture review record is not acceptance by Xiaolong Feng.
Targeted controls confirm manifest tampering and an undeclared baseline are
rejected by composition. A schema-valid, nonexistent compiled-type lock
path is rejected by the Host at `ifx-c1-type-provenance` with blocking
`prerequisite-missing`; this is distinct from an invalid config path.

The full same-snapshot report is
`artifacts/guards/p10-ifx-c6b1/draft-runs/fc2a3a528cbd4719b375893a3c2a741c/summary.json`.
Its bundle manifest SHA-256 is
`212e7ac2f6f7a9d146d33989069ac135014223fed0507f70839d985515e51837`,
and Profile SHA-256 is
`6bafbb3d318d28c6ed2d29ec415635788481e6a3c797f8648a78e3731bc7f2f3`.
Real IFX Host passed direct Pre (10 modules, 22 claims, `pre`), direct Post
(27 modules, 57 claims, `post`), and dependency Post (37 modules, 79 claims,
`bootstrap,analysis,pre,post`). All claims met their nonzero minima, with no
findings. The missing-lock negative was blocked by Host with
`prerequisite-missing`; manifest tamper and undeclared baseline were blocked
at composition. The composed Package and evidence-lock bytes were unchanged.
The isolated V3 IFX Package regression passed at
`artifacts/guards/v3-ifx-package-test-ad13c149288749cc9f2d2b0c15839011`.
The final script's tightened lineage, negative-phase and tracked-root
immutability assertions were also exercised in composition/negative-only
mode at
`artifacts/guards/p10-ifx-c6b1/draft-runs/59f18dae9613492daaa76672fd98159f/summary.json`;
that report is deliberately `partial`, not a second full Host pass.

The seven locks are bound to the development source snapshot, not permanent
certification artifacts. An initial full attempt found that later producer
builds had rewritten a DLL after the compiled-type lock; the final passing
run regenerated Solution, generated-input, Assembly and compiled-type locks
in dependency order, and asserts that lineage. No baseline was added to
mask this failure. Exact committed Formal Diff passed at
`artifacts/guards/p10-ifx-c6b1/formal-diff/summary-diff.json`; it matched the
four declared Plan paths.

C6c Windows and offline Linux certification, independent violation/zero-match
testing, Xiaolong Feng's exact-byte review, receipted operational composition
and installed Web UI practice remain undone. G04 remains `PRE-READY` with
seven blockers; G05 Phase 9 and Diff/CI remain P10.3-deferred. No production
approval, P10.2 parity or IFX cutover is claimed.
