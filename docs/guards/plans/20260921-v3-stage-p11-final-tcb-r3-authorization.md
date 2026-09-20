# P11.4 final TCB authorization r3

This authorization-only checkpoint replaces the consumed TCB authorization for the corrected P11.4 candidate `5751e86f0255359af6eadf1049c213c30f4987e9` against base `85d6371be22c6020b68f480fa419ffd213c793fe`.

The candidate invokes the pre-layout base's own `trusted-base/Invoke-IFXTrustedBase.ps1` for every required-check verdict and `trusted-base/Test-IFXTrustedBaseCandidate.ps1` for candidate TCB verification. Head-only candidate suites continue through the new `commands/Invoke-IFXGuardrails.ps1` facade. The CI contract and its negative controls enforce that split. The record covers the complete single TCB obligation: 19 components and 753 changed paths.

The original and r2 TCB authorization records remain immutable in the base and will remain unconsumed in the final candidate. Only this r3 record is consumed. The existing 42 delete records and `p11-final-policy.json` remain the exact authorities for the other 648 obligations.
