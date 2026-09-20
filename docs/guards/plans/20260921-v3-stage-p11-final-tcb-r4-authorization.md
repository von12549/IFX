# P11.4 final TCB authorization r4

This authorization-only checkpoint replaces the unconsumable r3 TCB authorization for P11.4 candidate `5e65345b9bc611c61523e2d5ab634812d3ef0bc4` against base `9642dc6cd3c6370e1ba122aef0845857e14fe15b`.

The r3 record bound the intended TCB tuple but referenced decision paths from the pre-layout tree; those paths no longer exist in the candidate. This r4 record uses the immutable decisions at their final shared locations. The candidate invokes the pre-layout base's own `trusted-base/Invoke-IFXTrustedBase.ps1` for every required-check verdict and `trusted-base/Test-IFXTrustedBaseCandidate.ps1` for candidate TCB verification, while head-only candidate suites use the new commands facade. The record covers the complete single TCB obligation: 19 components and 753 changed paths.

The original, r2, and r3 TCB records remain immutable in the base and will remain unconsumed in the final candidate. Only this r4 record is consumed.
