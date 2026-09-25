# V4 P10.1 C6c13 — reference scan and control property repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c12 final certification proved Windows 191/191. Linux advanced beyond
all C6c11 adapters and then timed out in `ifx-reference-cycle`. Controls
failed independently because strict mode evaluated an absent `files` property
before reaching the lock's actual `assemblies` collection.

## Exact remediation

1. Replace `ifx-reference-cycle` PowerShell item materialization and repeated
   ancestor checks with the same one-pass, link-rejecting, `*.csproj`-only
   directory queue already proven by the graph adapters.
2. Preserve the existing 180-second module ceiling and correct the owning
   suite's stale 30-second assertions to that existing value.
3. Make post-production lock-shape selection test property existence before
   reading `files`, `sourceFiles`, `assemblies`, or `inputs`.
4. Rebind the module manifest, matrix contract, and fixture specification.

No rules, claims, findings, policies, cases, baselines, waivers, published
1.1.3 bytes, or G04 governance state change.

