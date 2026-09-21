# P11.5 cleanup-prep replacement authorization revocation (D22)

This D22 revocation-only plan deletes the replacement `p11-cleanup-prep-trusted-base` record introduced by PR #92 and adds only this formal plan pair.

The replacement correctly binds the corrected CI verifier blob, but its `allowedBehaviorDifferences` array is empty. Base-owned TCB parity therefore rejects the intentional `Validate` difference: the old base CI contract still compares the facade against legacy Architecture cost-control entries, while the authorized candidate changes exactly those entries and the facade to the canonical Architecture command. The one-time compatibility bridge independently proves the exact four declaration substitutions and both consumed authorizations before projecting the declaration into base validation.

Authorization records are immutable. This PR revokes the incomplete record so the next authorization-only PR can regenerate the same exact 18 TCB tuples with a single explicit `Validate` allowance and no implementation change.

The trusted Diff must report one revocation, zero protected obligations, and all 13 required checks must pass.
