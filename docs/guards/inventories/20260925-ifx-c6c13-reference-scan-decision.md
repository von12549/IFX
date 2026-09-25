# IFX C6c13 reference scan and control property decision

Date: 2026-09-25
Status: implementation complete; final C6 certification rerun required

## Trigger

The C6c12 final certification at
`%TEMP%/ifx-c6c12/5f529394065d44c2b891a163ab6c7bb1` produced three independent
results:

- Windows completed and passed all 191 core cases.
- Linux advanced beyond every C6c11 adapter, then timed out in
  `ifx-reference-cycle`.
- Controls failed under strict mode while reading an absent `files` property
  before reaching a lock's actual `assemblies` collection.

## Decision

`ifx-reference-cycle` now uses a directory queue that rejects link directories
and link project files, prunes its existing excluded directory names, and
collects only top-level `*.csproj` entries in each safe directory. It no longer
materializes every source-tree item or repeats ancestor traversal for every
entry. Its 180-second timeout is unchanged; the owning suite's two stale
30-second expectations now reflect that existing manifest value.

Certification controls now test property existence before reading `files`,
`sourceFiles`, `assemblies`, or `inputs`. The existing assembly field selector
continues to distinguish `path` from `sourcePath`.

## Verification

- Formal Pre:
  `artifacts/guards/p10-ifx-c6c13/formal-pre/summary-pre.json`, SHA-256
  `553362073d8b9ff225b6595c2eeb5eebc6bebb9a38a2eab71a7219a90e4239c6`.
- C1n owning suite: 13 fixtures plus the real IFX scan passed at
  `artifacts/guards/p10-ifx-c6c13/owning-c1n/4ba8205eb74d41f3bf75911924b8b7de`;
  the real scan retained 147 direct references and 10 Contracts projects.
- Development inventory:
  `artifacts/guards/p10-ifx-c6c13/development-inventory/4a0395dee812407b92a739b6f261e038/ordinal-inventory.json`,
  SHA-256 `9041d8b889e508c6cbd7385847eae33df6f0aaabbf3009acb227671ed1f8044c`.
- Matrix contract:
  `artifacts/guards/p10-ifx-c6c13/matrix-contract/summary.json`, SHA-256
  `a03ffa279513263129a1854b38caebdea7032cc0b6c346ccf530a36045cdba68`.
- Offline Linux real-repository scan: pass in 32.172 seconds, with the same
  147/10 coverage counts and no findings.
- Focused property-shape invocation selected valid mutation subjects from
  solution `files`, database `files`, assembly `path`, type `sourcePath`, and
  graph `inputs` without missing-property access.

## Certification consequence

C6c remains open until the committed C6c13 HEAD receives fresh same-commit
locks and candidate evidence, followed by Windows/Linux 191/191, 42 controls,
180 capability variants, semantic parity, zero gaps, and formal Diff.
