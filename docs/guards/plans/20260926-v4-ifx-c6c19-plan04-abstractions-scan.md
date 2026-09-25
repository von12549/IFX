# V4 P10.1 C6c19 — Plan04 abstractions scan repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c18 final certification completed all 37 Windows suites and all C6c5
controls. Linux passed the repaired tenant and projection modules, then timed
out only in `ifx-plan04-abstractions`. The adapter currently materializes two
recursive PowerShell enumerations for each scan root and rereads source and
project files during semantic checks.

## Exact remediation

1. Replace recursive PowerShell enumeration with queue-based .NET enumeration
   that rejects reparse points and prunes `bin`, `obj`, `node_modules`, `dist`,
   `coverage`, and `.vite`.
2. Cache accepted `.cs` and `.csproj` relative paths, hashes, and text once;
   reuse cached text for project-reference and namespace checks.
3. Preserve the complete directory/file inventory hash, all 11 checks, six
   fixtures, findings, coverage, and the existing 60-second capability ceiling.
4. Rebind the module manifest, C6 matrix contract, and fixture specification.

No rules, claims, policies, authorities, baselines, waivers, capability
ceilings, published 1.1.3 bytes, or G04 governance state change.
