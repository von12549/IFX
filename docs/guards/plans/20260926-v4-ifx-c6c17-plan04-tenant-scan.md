# V4 P10.1 C6c17 — Plan04 tenant scan repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c16 final certification completed all 37 Windows suites and all C6c5
controls. Linux advanced beyond both repaired G03 modules and then timed out
only in `ifx-plan04-tenant`. The adapter currently materializes recursive
PowerShell file objects and rereads the same source files across tenant checks.

## Exact remediation

1. Replace recursive PowerShell source enumeration with queue-based .NET
   enumeration that rejects reparse points, prunes `bin` and `obj`, and reads
   only `.cs` files.
2. Cache each accepted source file's text once and reuse it for repository,
   contract, endpoint, handler, registry, and aggregate checks.
3. Preserve the complete source-tree hash, all 12 checks, five negative
   fixtures, findings, coverage, and the existing 60-second capability ceiling.
4. Rebind the module manifest, C6 matrix contract, and fixture specification.

No rules, claims, policies, authorities, baselines, waivers, capability
ceilings, published 1.1.3 bytes, or G04 governance state change.
