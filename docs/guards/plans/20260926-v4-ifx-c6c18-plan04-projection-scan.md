# V4 P10.1 C6c18 — Plan04 projection scan repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c17 final certification completed all 37 Windows suites and all C6c5
controls. Linux passed the repaired `ifx-plan04-tenant` module with all 12
checks, then timed out only in `ifx-plan04-projection`. The projection adapter
currently materializes recursive PowerShell file objects and rereads every
source file while evaluating the cross-context check.

## Exact remediation

1. Replace recursive PowerShell source enumeration with queue-based .NET
   enumeration that rejects reparse points, prunes `bin` and `obj`, and reads
   only `.cs` files.
2. Cache each accepted source file's relative path, hash, and text once, and
   reuse the cached text for the cross-context check.
3. Preserve the complete source-tree hash, all 13 checks, six negative
   fixtures, findings, coverage, and the existing 60-second capability ceiling.
4. Rebind the module manifest, C6 matrix contract, and fixture specification.

No rules, claims, policies, authorities, baselines, waivers, capability
ceilings, published 1.1.3 bytes, or G04 governance state change.
