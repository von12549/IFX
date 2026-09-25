# C6c17 Plan04 tenant scan decision

Decision: keep the `ifx-plan04-tenant` 60-second capability ceiling and reduce
filesystem and repeated source-read cost without changing tenant semantics.

## Failure isolated

The C6c16 parallel certification completed all 37 Windows suites, 191/191 core
cases, 42 lock controls, and 180 capability variants. Linux advanced beyond
both repaired G03 modules and then returned `adapter-failure` because only
`ifx-plan04-tenant` timed out.

The tenant adapter recursively materialized PowerShell file objects for the
complete `.cs` tree and then reread the same source files for repository,
contract, endpoint, handler, registry, and aggregate checks.

## Change

The adapter now uses queue-based .NET directory enumeration, rejects
reparse-point directories and files, prunes `bin` and `obj`, and accepts only
`.cs` files. It retains the full ordered source-tree hash while caching each
accepted file's text once for all semantic checks.

No timeout, rule, claim, policy, authority, fixture expectation, waiver, or
baseline changed.

## Verification

- Formal Pre passed:
  `artifacts/guards/p10-ifx-c6c17/formal-pre/summary-pre.json`.
- The owning C4a2 suite passed all 12 tenant checks, negative fixtures, and the
  published Host Post path:
  `artifacts/guards/p10-ifx-c6c17/owning-c4a2/48eecf4d6b934efe80c49766274e59a7`.
- A direct real-repository run in locked image `ifx-c6c-sdk:10.0.303` returned
  `pass`, matched all 12 checks, and completed in 21.169 seconds, below the
  unchanged 60-second ceiling.

Final acceptance remains contingent on refreshed inventory bindings, matrix
validation, and a fresh same-commit C6c parallel certification.
