# V4 P10.1 C6c14 — control hashtable selection repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

The C6c13 final certification advanced both platform matrices through the
evidence suites, but Controls failed before its 42 lock-mutation cases. The
control parser intentionally uses `ConvertFrom-Json -AsHashtable`; its path
selector checks only `PSObject.Properties`, so valid hashtable keys such as
`files`, `sourceFiles`, `assemblies`, and `inputs` are not discovered.

## Exact remediation

1. Add one property/key-presence helper that supports both dictionaries and
   ordinary PowerShell objects.
2. Use it for post-production collection selection and assembly source-path
   selection.
3. Exercise all six governed lock shapes as both parsed hashtables and normal
   PowerShell objects before rebuilding the candidate and final certification.

No rules, claims, findings, policies, cases, baselines, waivers, capability
ceilings, published 1.1.3 bytes, or G04 governance state change.

