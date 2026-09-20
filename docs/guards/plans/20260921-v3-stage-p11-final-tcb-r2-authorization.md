# P11.4 final TCB authorization r2

This authorization-only checkpoint replaces the consumed TCB authorization for the fixed P11.4 candidate `1b8629b39b70bed6ba19808553c64a15f92fa8c8` against base `9dd69ea9c7add58671822499f053355f97bd3b06`.

The candidate keeps trusted execution on the base-owned legacy `scripts/Invoke-IFXGuardrails.ps1` facade during the aggregate pull request, while head-only candidate suites use the new `commands/Invoke-IFXGuardrails.ps1` facade. The CI contract and its negative controls explicitly enforce this transition. The record still covers the complete single TCB obligation: 19 components and 753 changed paths.

The original `p11-final-trusted-base.json` remains immutable in the base and will remain unconsumed in the final candidate. Only this r2 record is consumed. The existing 42 delete records and `p11-final-policy.json` remain the exact authorities for the other 648 obligations.
