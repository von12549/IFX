# CP10 registry prep authorization

This authorization-only checkpoint pre-authorizes the exact CP10 registry-prep candidate `d223e1a2` against base `630ce6d2`. It adds no policy change itself.

The trusted-base record covers the policy-config schema and registry components. The weaken-policy record binds the exact schema pointer changes and the three future CI JSON exclusions. The subsequent prep change must delete both records in the same diff; replay or unused coverage fails closed.
