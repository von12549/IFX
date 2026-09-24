# V4 P10.1 C6c1 — same-byte IFX candidate certification

Status: `EXECUTION PLAN — BLOCKED; C6c CERTIFICATION NOT PASSED`

C6b1's 0.3.0 combined Profile is a synthetic-review draft, not Xiaolong
Feng's approval. C6c0 found and resolved two runner prerequisites without
changing the V4 1.1.3 base or module policies: Windows Git long paths can be
enabled temporarily and restored; a local Ubuntu 24.04.4 SDK 10.0.303 image
was built from Microsoft's SHA-512-checked binary over the prior digest-pinned
base. The official V4 Windows-full (34 tests) and network-disabled
Linux-complete (33 tests) reports passed against development source commit
`18566ef051dbd41c2672b8b1e5b8a14a4986f9a9`, Package SHA-256
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.

This tranche must regenerate C6b0 inventory and all seven C5/C4/R1/R2
evidence locks for that same source snapshot. Producer order must prevent
later builds from rewriting compiled-type DLLs. Regenerate the evaluated
graph natively on Linux SDK 10.0.303 and compare the project/edge/policy
projection against Windows, explaining any OS-specific drift. Construct one
new 0.3.0 bundle using only the 36 reviewed external C1–C5 modules plus the
published built-in Architecture Conformance module. Freeze its manifest,
Profile, authority map, capability ceilings, zero-baseline selection, full
file inventory and lock lineage. The Linux and Windows candidate tests must
consume identical bundle manifest bytes and the same published 1.1.3 archive.
Because an install receipt embeds its OS-specific absolute `installRoot`, Linux
must use the public 1.1.3 installer in an ephemeral native volume. Compare its
receipt `id`, archive/manifest hashes and complete file/hash/size inventory to
the published Windows receipt; only the install path and receipt bytes may
differ. Neither platform may write to the Package or IFX TargetRoot.
Run Linux Host against an ephemeral native-filesystem checkout of the same
source commit, rehydrating all tracked paths from the clean Windows worktree
and the C4a4-scanned directory topology so Git checkout EOL conversion and
Git's omission of empty directories cannot alter locked inventory hashes. Copy
only the seven bound evidence-run directories and the C1/C5 lock-listed DLLs
from the read-only Windows source mount; verify their hashes before execution.
The Docker bind mount is not an acceptable performance substitute: the first
direct-Pre attempt timed out at the unchanged 180-second module ceiling.

Run real IFX direct Pre, direct Post and dependency-enabled Post on both
platforms, proving 10/27/37 modules, 22/57/79 claims, nonzero coverage and
zero findings. Independently exercise clean, deliberate violating,
missing-input and zero-match controls for every detector family represented
in the candidate. Malformed bundle, undeclared baseline, stale/changed lock,
capability overreach and cross-root writing must fail closed. Do not convert
an integration failure into a baseline or a documentation-only pass.

Use only synthetic fixture review records for technical composition. The
frozen candidate is not an accepted review record or operational install.
Any Host/schema/loader/installer/built-in change requires a separate
compatibility Plan and newly published 1.1.x base; C6c cannot silently
change 1.1.3. G04 remains `PRE-READY` with seven blockers; G05 Phase 9 and
Diff/CI remain P10.3-deferred. C6d human review and C6e installed Web UI
are not entered by this Plan.

Only this Plan pair, a deterministic C6c1 certification script, and a
decision note are planned source paths. Formal Pre precedes script/decision
edits; isolated IFX Package regression and exact committed Formal Diff are
required. Evidence under `artifacts/guards/p10-ifx-c6c1` is ignored and
cannot itself count as an approved source change.

Execution decision: `docs/guards/inventories/20260924-ifx-c6c1-certification-decision.md`.
The Windows candidate passed, while the Linux candidate failed closed at the
Plan04 Abstractions source inventory after 14 earlier Post modules passed.
Short-lived locks must be refreshed and both platforms rerun on a new exact
candidate; the independent detector matrix and remaining tamper controls are
also open. No C6d/C6e transition is authorized.
