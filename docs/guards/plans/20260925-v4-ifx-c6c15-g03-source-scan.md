# V4 P10.1 C6c15 — G03 source reconciliation scan repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c14 final certification completed Windows and Controls, while Linux
timed out only in `ifx-g03-source-reconciliation`. The adapter performs two
determinism snapshots and currently materializes and sorts every directory
entry through PowerShell objects before filtering semantic source files.

## Exact remediation

1. Replace PowerShell item materialization with a queue-based .NET directory
   scan that rejects reparse points, prunes `bin` and `obj`, and reads only
   `.cs` and `.csproj` files.
2. Preserve the two independent snapshots, all reconciliation logic, findings,
   coverage counts, and the existing 60-second capability ceiling.
3. Rebind the module manifest, combined G03 authority lock, and C6 matrix
   contract to the optimized adapter bytes.

No rules, claims, cases, policies, baselines, waivers, capability ceilings,
published 1.1.3 bytes, or G04 governance state change.

