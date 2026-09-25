# IFX C6c10 platform harness decision

Decision: **accepted for certification rerun; C6c remains unproven until the
fresh dual-platform report passes.**

The C6c9 parallel attempt at
`C:/Users/von12/.codex/visualizations/2026/09/24/01a0d415-07bd-75d1-b2f8-40bd6fad09ae/ifx-c6c9-final-certification/c4d7ff4e2f404db88fdb1c24b9c5baa9`
proved the Windows matrix. It failed closed in the other two branches:

- Controls could not checkout long tracked paths in its shadow clone.
- Linux direct-pre exhausted the 180-second host budget in
  `ifx-package-reference` while enumerating every item under `src`.

## Accepted repair

The controls clone now sets `core.longpaths=true` in addition to the existing
no-local and autocrlf controls. The package-reference adapter now enumerates
only `*.csproj` files, which are its complete semantic input set, and performs
the existing source-root check plus path/link validation on every selected
project and its ancestors before XML parsing. The owning test locks this
structure and the existing 180-second timeout.

The adapter, module manifest, 37-module matrix contract and supplemental
fixture specification were rebound to their new hashes. No rule, claim,
finding, policy, capability, case, baseline or waiver changed.

## Evidence

- Formal Pre passed at
  `artifacts/guards/p10-ifx-c6c10/formal-pre/summary-pre.json`, SHA-256
  `48745723a884e1438881bba7eed0f3c9e86623763a9c6e2c1a70755889b05d80`.
- The C1c owning suite passed eight fixtures, source projection, schema,
  hashes and a real IFX scan at
  `artifacts/guards/p10-ifx-c6c10/c1c-focused/acad3fbc491240448a5cf561ad97fefe`.
- The matrix contract passed at
  `artifacts/guards/p10-ifx-c6c10/matrix-contract/summary.json`, SHA-256
  `7aa603f0c015ba9cd32da40dc41fdd759b009b500e8d15d46bd4158bcdf693ae`.
- A network-disabled Linux SDK 10.0.303 run completed the real adapter scan in
  18.326 seconds with pass/success and coverage 20/15, without changing the
  180-second timeout.
- A representative Windows no-local shadow clone checked out a tracked file at
  an absolute path length of 287 characters, matched plan commit
  `2098b3e2236da6c16c44ba845f98568e9b7dfd77`, and had zero tracked status
  lines.

Fresh inventory, evidence locks, candidate bundle and unchanged C6c5 parallel
certification are still required. Passing remains Windows/Linux 191/191 equal
semantics, 42 lock controls, 180 capability variants and zero gaps.

