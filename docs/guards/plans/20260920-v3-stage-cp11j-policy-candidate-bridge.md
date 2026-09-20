# CP11j — Policy candidate validation bridge

This expand checkpoint lets the previous trusted base validate a candidate that moves IFX policy data from `policy/` to `stages/post/policy/`. Base-owned manifest and trusted-base tests resolve exactly one complete layout, while the base policy-candidate engine reads the explicit head authority registry, materializes the head layout, and regenerates derived projections with the base generator. The projection generator computes G04 binding paths relative to the selected policy root, so the same base code produces canonical paths for either layout.

The checkpoint does not move policy data or change runtime policy. Missing or simultaneous layouts still fail closed, and the following protected move must consume its own move, trusted-component and policy/config authorizations.
