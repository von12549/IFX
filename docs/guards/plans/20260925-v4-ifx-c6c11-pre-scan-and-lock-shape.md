# V4 P10.1 C6c11 — pre-scan and lock-shape repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c10 removed the first Linux direct-pre timeout and the Windows long-path
checkout failure. The unchanged final runner then advanced to the next
full-tree pre adapter, `ifx-ring-graph`, and timed out for the same NTFS bind
mount reason. Controls advanced beyond clone and exposed an invalid assumption
that every assembly entry uses `sourcePath`; the assembly lock uses `path` and
the compiled-Type lock uses `sourcePath`.

## Exact remediation

1. Replace whole-tree item materialization in the remaining affected pre
   adapters with extension-filtered `*.csproj` and, where required, `*.cs`
   enumeration. Preserve per-input ancestor link checks before parsing.
2. Resolve assembly source paths from the schema-specific `sourcePath` or
   `path` property in both Controls mutation selection and shadow copying.
3. Rebind every changed module manifest plus the matrix-contract and fixture
   specification hashes.
4. Correct four stale owning-suite assertions from 30 seconds to the already
   shipped 180-second module ceilings; this records the existing budget and
   does not broaden it.

## Validation and boundary

Formal Pre precedes executable edits. All five owning suites, the matrix
contract, parser checks, focused Linux real-source scans and focused lock-shape
selection must pass before fresh locks and certification are generated.

Timeouts, claims, rules, findings, policies, capabilities, cases, baselines,
waivers, published 1.1.3 bytes and G04 governance remain unchanged. Final C6c
still requires Windows/Linux 191/191 equality, 42 lock controls, 180 capability
variants and zero gaps.
