# V4 P10.1 C6c5 certification decision

Decision: `BLOCKED — C6c NOT CERTIFIED`

Source commit evaluated: `2f748482a719657286cd3fff7b38ab2abf8e8f9b`

## Implemented control surface

C6c5 added the planned read-only certification-control runner, native Linux
entry point and Windows parallel orchestrator. Their SHA-256 identities are:

- `Test-IFXC6CertificationControls.ps1` —
  `08a812779cefbb6b6d053911d60de53ff6045d1927c28a258670e20f600aa850`
- `Invoke-IFXC6LinuxCertification.ps1` —
  `8dff2724977c4001eb0455c3fc3a03b7717b27dcab7714434b705a16f70855ba`
- `Invoke-IFXC6ParallelCertification.ps1` —
  `bdeb262d22142f1745c35cc9af96660300867b40b9067be8c51e30fab239da81`

The control contract contains 42 seven-lock cases, 180 schema-valid capability
broadening variants, immutable-root overlap/traversal/link cases and forbidden
PackageRoot/TargetRoot write declarations. The parallel entry point binds the
pinned Linux image digest, `--network none`, the read-only offline NuGet cache,
the same candidate inputs and normalized equality of both 191-row manifests.
All three scripts passed PowerShell parser validation and the planned cardinality
checks. Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c6c5/formal-pre/summary-pre.json`, SHA-256
`5345045e2a73c02f04178bb7892a3279efdc9568adffe2222743ceb1c541f9fc`.

## Fail-closed blocker

The targeted `Solution` wrong-commit control changed the candidate lock's
`targetCommit` to `0000000000000000000000000000000000000000`, rebound the
configuration to the mutated lock SHA-256 and invoked the frozen owning
`ifx-solution-evidence` adapter against the unchanged TargetRoot and evidence.
Expected outcome was `error/integrity-failure`; actual outcome was
`pass/success`.

Evidence:

- report:
  `artifacts/guards/p10-ifx-c6c5/targeted-controls/13cb9aad3df843078c3d8d58491fdf1f/summary.json`
- report SHA-256:
  `ef40d10d376b69d74a894add746de4c01171d61446ea68264b9cc1a947249edf`
- original lock SHA-256:
  `6d8175162de1c7de8e066e0dd3c21f004131f74902c943fc6d36b418f87b863f`
- mutated lock SHA-256:
  `2773dd99865bb05dcb0fb572d3250d3175169b626075703ce8901ce2cb9112e5`
- frozen adapter commit-equality check count: `0`

The adapter validates only that `targetCommit` has a 40-hex shape. Static
inspection shows the same missing current-HEAD equality binding in the frozen
Assembly, Frontend, Database and compiled-Type adapters; the evaluated-Graph
adapter does perform `git rev-parse HEAD` equality validation. One executed
false acceptance is sufficient to block certification, so the remaining fresh
lock production and full parallel run were deliberately not started.

## Boundary and next action

No timeout, timestamp, product byte, policy, baseline, waiver, published 1.1.3
artifact or reviewed capability ceiling was weakened. The C6c5 Plan explicitly
requires stopping without C6c certification when a detector change is needed;
repairing the frozen adapters is therefore outside this Plan and requires a new
exact remediation Plan.

The isolated `ifx-package-test` passed its positive path and all protected
negative classes at
`artifacts/guards/v3-ifx-package-test-292011538c1742179d1625ee71a16c35`.
Exact committed Formal Diff for the six declared C6c5 paths passed at
`artifacts/guards/p10-ifx-c6c5/formal-diff/summary-diff.json`. These validation
results close the control-plan implementation obligations; they do not override
the wrong-commit false acceptance or certify C6c.

C6d human acceptance, C6e installed composition, P10.2/P10.3 and V3 retirement
remain out of scope. G04 remains `PRE-READY`.
