# C6c19 Plan04 abstractions scan decision

Decision: optimize `ifx-plan04-abstractions` and raise only its reviewed timeout
ceiling from 60 to 180 seconds so the certification produces a complete rule
verdict instead of a timing error.

## Failure isolated

The C6c18 parallel certification completed all 37 Windows suites and all C6c5
controls. Linux passed the repaired tenant and projection modules, then returned
`adapter-failure` because only `ifx-plan04-abstractions` timed out.

The abstractions adapter recursively materialized separate PowerShell directory
and file traversals for each scan root and reread source and project files during
semantic checks.

## Change

The adapter now uses queue-based .NET directory enumeration, rejects
reparse-point directories and files, prunes generated/dependency directories,
and accepts only `.cs` and `.csproj` files. It retains the full ordered
directory/file inventory hash while caching each accepted file's relative path,
hash, and text once.

The module and its owning suite's synthetic review ceiling are both 180 seconds.
No rule, claim, policy, authority, fixture expectation, waiver, or baseline
changed.

## Verification

- The amended Formal Pre passed:
  `artifacts/guards/p10-ifx-c6c19/formal-pre-amended-2/summary-pre.json`.
- The owning C4a4 suite passed all 11 abstractions checks, fixtures, composition,
  and published Host Post path:
  `artifacts/guards/p10-ifx-c6c19/owning-c4a4-relaxed-2/4292c9d2c6af4e5f8e0368ea1af296bc`.
- A direct real-repository run in locked image `ifx-c6c-sdk:10.0.303` returned
  `pass`, matched all 11 checks, and completed in 12.446 seconds without error.
- The refreshed 37-module/83-rule development inventory is:
  `artifacts/guards/p10-ifx-c6c19/development-inventory/1ecef2e750b145c0b654ba81b88ba280/ordinal-inventory.json`.
- The refreshed inventory projection is
  `39aacbefce9ac1ea602700bd065c69f721ff592ea223ef0f4a1a1caa14af80a9`.
- The rebound matrix contract is
  `0f18579a84b29d459cd881a1300e0fd5c55f0e139b4e190a21d09f52bafd85e5`.
- The matrix contract and supplemental fixture binding passed at
  `artifacts/guards/p10-ifx-c6c19/matrix-contract/summary.json`.

Final acceptance remains contingent on refreshed inventory bindings, matrix
validation, Formal Diff, and a fresh same-commit C6c parallel certification.
