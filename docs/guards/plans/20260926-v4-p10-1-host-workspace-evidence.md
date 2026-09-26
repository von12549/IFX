# V4 P10.1 — Host workspace evidence provider

Status: `IMPLEMENTED AND FOCUSED-TESTED — 1.1.4 release certification pending`

Promote the C6c shared-workspace optimization into a governed V4 Host
capability. A Profile may declare one bounded source projection. The Host then
enumerates and hashes it once per run, writes immutable evidence below the
project/run EvidenceRoot, records its hash as run authority, and injects its
path, hash and target commit only into modules whose reviewed capability grants
`EvidenceRoot` read access.

## Trust and compatibility boundary

- The Host creates the evidence; callers cannot pass an arbitrary evidence path
  or hash through the CLI.
- Relative roots, extensions and excluded directory names come from the
  package-validated Profile and are covered by the Profile contract.
- Enumeration is ordinal, duplicate-free, link-safe and bounded to TargetRoot.
- Raw and normalized hashes plus cached UTF-8 text preserve the current IFX
  consumers' rule semantics while removing repeated full-tree traversal.
- Profiles without `workspaceEvidence` retain their existing behavior.
- Modules without `EvidenceRoot` do not receive the binding.
- Existing published/installed 1.1.3 bytes remain immutable. This source change
  requires a separately planned V4 patch release and complete dual-platform V4
  certification before IFX can rebind and rerun C6c.

## Validation boundary

Extend the synthetic Profile and probe to prove one evidence file per Host run,
schema validity, target-commit and content hashes, authority inclusion,
capability-gated injection, stable ordering and immutable roots. Update the
seven IFX consumers and their reviewed capability ceilings to accept the new
generic scope while retaining their direct-scan fallback for older Hosts and
focused diagnostics.
