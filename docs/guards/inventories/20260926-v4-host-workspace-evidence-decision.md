# V4 Host workspace evidence decision

Status: `IMPLEMENTATION ACCEPTED FOR A 1.1.4 RELEASE CANDIDATE; NOT PUBLISHED`

## Decision

Shared workspace evidence is now a generic V4 Host capability in development
source, rather than an IFX-only diagnostic convention. The final release must be
versioned **1.1.4** because the change adds Host behavior, an optional Profile
property and a public evidence contract. Published and installed 1.1.3 bytes
remain unchanged.

Publication is deliberately deferred. A separate 1.1.4 release tranche must
update product/assembly metadata and release notes, run the exact clean-commit
Windows-full and offline Linux-complete certification suites, build the
deterministic archive, certify its supply chain, publish it and install it as a
new sibling release. Only then may the IFX bundle declare `workspaceEvidence`,
rebind to 1.1.4 and start a new C6c certification.

## Implemented trust boundary

- `workspaceEvidence` is optional Profile configuration; the CLI has no path or
  hash override.
- The Host enumerates configured TargetRoot-relative roots once per run, rejects
  links/reparse points and escapes, applies explicit directory exclusions,
  extension filters, maximum file count and maximum file size, and uses ordinal
  duplicate-free path order.
- The evidence document records raw and normalized SHA-256, cached UTF-8 text,
  tree identity and target commit under
  `EvidenceRoot/projects/{projectId}/runs/{runId}/workspace-evidence.json`.
- Its file SHA-256 is included as `authorityHashes.workspaceEvidence`.
- The path/hash/commit binding is injected only into a module whose reviewed
  `readRoots` includes `EvidenceRoot`. A synthetic negative proves a module
  without that capability receives none of the three fields.
- Profiles without `workspaceEvidence` preserve the previous behavior.

The seven current IFX consumers accept scope `v4-workspace-evidence-v1`, retain
their direct-scan fallback for older Hosts and focused use, and declare
`EvidenceRoot` in their reviewed read capability. G03 authority locks and the
C6c independent matrix lock were refreshed to the new exact bytes.

## Focused validation

- Formal Pre passed at
  `artifacts/guards/p10-ifx-c6c23/formal-pre-final/summary-pre.json`; Formal Diff
  matched the exact Plan at
  `artifacts/guards/p10-ifx-c6c23/formal-diff/summary-diff.json`.
- V4 Host compiled with zero warnings and zero errors.
- `Test-V4Package.ps1` passed with 122 authority files; the final development
  package hash before release metadata is
  `43f7afa7a04ddb4a901eb05f2d159f773b5147324d1d66d121af57f622892cc1`.
- P0 contracts passed: 36 schemas and 38 bound contract files.
- P3 Stage passed direct Bootstrap/Analysis/Pre/Post, evidence schema/hash/tree/
  commit/authority checks, one document per run, default-Profile absence, and
  positive plus capability-gated injection paths.
- P3 orchestration, P4 composite architecture, P1 package fail-closed and P8
  compatibility-baseline suites passed; the compatibility baseline now binds
  23 CLI/configuration/report authorities.
- All seven affected IFX focused suites passed on the immutable published 1.1.3
  Host fallback: domain reference, project name, G03 source reconciliation,
  G03 snapshots, Database evidence, G05 inventory and Plan05 security.
- The generic diagnostic producer projected 1,152 real IFX files in 0.628 s and
  satisfied `workspace-evidence.schema.json`. With that exact evidence,
  `ifx-domain-reference` passed in 0.997 s and `ifx-project-name` passed in
  0.912 s.

## Remaining boundary

This result is sufficient to start a 1.1.4 release candidate; it is not a
release certification and does not authorize reusing any old C6c bundle,
capability review, package hash or certification verdict. The next tranche must
publish and install 1.1.4 first, then regenerate/review the IFX Profile and run
the single planned C6c certification against those new immutable bytes.
