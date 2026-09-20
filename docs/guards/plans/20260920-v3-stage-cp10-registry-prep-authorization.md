# CP10 registry prep authorization

This authorization-only checkpoint pre-authorizes the exact CP10 registry-prep candidate `d223e1a2` against base `630ce6d2`. It adds no policy change itself.

The trusted-base record covers the policy-config schema and registry components. It explicitly permits one `Validate` bridge difference: the pre-bridge base renderer cannot validate exact-file exclusions, while the candidate can; all other Validate checks and all five verdict parity modes remain equal. The weaken-policy record binds the exact schema pointer changes and the three future CI JSON exclusions. The subsequent prep change must delete both records in the same diff; replay or unused coverage fails closed.
