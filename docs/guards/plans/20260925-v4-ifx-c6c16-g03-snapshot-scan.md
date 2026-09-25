# V4 P10.1 C6c16 — G03 snapshot scan repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c15 final certification proved all 37 Windows suites and advanced the
Linux direct-post path beyond `ifx-g03-source-reconciliation`. Linux then timed
out only in `ifx-g03-snapshots`. That adapter performs two deterministic
projections and currently materializes and sorts every directory entry through
PowerShell objects before filtering semantic source files.

## Exact remediation

1. Replace PowerShell item materialization with a queue-based .NET directory
   scan that rejects reparse points, prunes `bin` and `obj`, and enumerates only
   `.cs` and `.csproj` files.
2. Preserve the two independent projections, all snapshot comparisons,
   findings, coverage counts, and the existing 60-second capability ceiling.
3. Rebind the module manifest, combined G03 authority lock, C6 matrix
   contract, and its fixture specification to the optimized adapter bytes.

No rules, claims, cases, policies, snapshots, baselines, waivers, capability
ceilings, published 1.1.3 bytes, or G04 governance state change.
