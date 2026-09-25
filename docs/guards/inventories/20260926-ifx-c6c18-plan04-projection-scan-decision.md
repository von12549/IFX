# C6c18 Plan04 projection scan decision

Decision: keep the `ifx-plan04-projection` 60-second capability ceiling and
reduce filesystem and repeated source-read cost without changing projection
semantics.

## Failure isolated

The C6c17 parallel certification completed all 37 Windows suites, 191/191 core
cases, and the C6c5 controls. Linux passed the repaired tenant module with all
12 checks, then returned `adapter-failure` because only
`ifx-plan04-projection` timed out.

The projection adapter recursively materialized PowerShell file objects and
then reread every source file while checking for multiple module DbContexts.

## Change

The adapter now uses queue-based .NET directory enumeration, rejects
reparse-point directories and files, prunes `bin` and `obj`, and accepts only
`.cs` files. It retains the full ordered source-tree hash while caching each
accepted file's relative path, hash, and text once.

No timeout, rule, claim, policy, authority, fixture expectation, waiver, or
baseline changed.

## Verification

- Formal Pre passed:
  `artifacts/guards/p10-ifx-c6c18/formal-pre/summary-pre.json`.
- The owning C4a3 suite passed all 13 projection checks, negative fixtures,
  and the published Host Post path:
  `artifacts/guards/p10-ifx-c6c18/owning-c4a3/115782c4c4ac4beaa8f30a5e4b03e6df`.
- A direct real-repository run in locked image `ifx-c6c-sdk:10.0.303` returned
  `pass`, matched all 13 checks, and completed in 10.718 seconds, below the
  unchanged 60-second ceiling.

Final acceptance remains contingent on refreshed inventory bindings, matrix
validation, Formal Diff, and a fresh same-commit C6c parallel certification.
