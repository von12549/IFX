# V4 P10.1 C1 R1b — compiled type evidence bridge

Status: `EXACT IMPLEMENTATION TRANCHE — C1 CANDIDATE ONLY`

R1a proved the installed 1.1.3 `ARCH.TYPE_DEPENDENCY` adapter can inspect
the real CRM Domain/Contracts compiled type pair: four clean matches and
blocking zero/missing/altered controls. This tranche binds that execution
to fresh controlled Solution/Assembly provenance, without modifying the
built-in module or running a build inside V4 Post. The controlled producer
must copy the exact CRM Domain, CRM Contracts and required closure DLLs to
a run-scoped evidence directory, write a SHA-256 assembly manifest and a
short-lived evidence lock, and link C5b/C5c locks, source tree, commit,
Release/net8.0 and policy bytes. A new read-only Post extension independently
verifies that bridge. A synthetic-only composed Profile selects both the
published built-in `ARCH.TYPE_DEPENDENCY` claim and the provenance module;
the two must agree on the same manifest and DLL bytes.

Clean real IFX direct/dependency Host Post, synthetic forbidden type-edge,
zero type subject, missing/stale/tampered evidence, wrong assembly/source
binding, wrong TFM and immutable TargetRoot/PackageRoot controls are
required. Preserve distinct claim IDs and zero baseline references. This
does not close C1: evaluated references and C1 identity integration remain
R2/R3. Any requirement to change installed Host/schema/loader/built-in
bytes stops this tranche for a separate compatibility patch.

Formal Pre must pass before executable edits. The exact paths below are
the only candidate changes; after tests, run isolated package regression
and exact committed Formal Diff. No release, installed Package, source
project or production Profile may be edited.

## Verification record

Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r1b/formal-pre/summary-pre.json`.
The controlled producer bound fresh C5b/C5c locks, source-tree hash,
four exact Release/net8.0 DLLs and a one-hour manifest. The published
1.1.3 synthetic-only Host composed the built-in type rule and read-only
provenance module. Direct Post and dependency-enabled Stages passed on
real IFX with four compiled type matches and seven provenance matches.
An isolated EvidenceRoot was required by the Host and both locations were
hash-checked. Missing/stale locks, wrong TFM, altered external manifest,
zero type subjects and a compiled forbidden CRM Domain→Contracts edge
blocked. Package and protected DLL/manifest bytes remained unchanged.
Evidence:
`artifacts/guards/p10-ifx-c1-r1b/test-runs/6637eb1a6e3f45ccb12f3a1e03fa39fb/summary.json`.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-295e92de67504e11890972abd617377a`.
Exact Formal Diff follows the scoped implementation commit.
