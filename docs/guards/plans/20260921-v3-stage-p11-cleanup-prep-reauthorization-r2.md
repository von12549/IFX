# P11.5 cleanup-prep final replacement authorization

This authorization-only checkpoint republishes the single-use `p11-cleanup-prep-trusted-base` record after PR #94 revoked the incomplete instance. It contains no implementation change and leaves `p11-cleanup-prep-policy` unchanged.

The record is generated from base `0e91acb823835335263a56574db9d5cc12c14361` and candidate `576ad0eccede86d114886969e71681fd32839225`. It binds exactly 18 TCB paths and includes one schema-supported allowed behavior difference for `Validate`: the base CI contract still declares the legacy Architecture cost-control entries while the candidate facade and declaration use the canonical Architecture command.

The allowance is narrow and independently constrained by the already merged one-time compatibility bridge. That bridge activates only for the exact four authorized legacy-to-canonical declaration substitutions, requires both expected authorization IDs to be consumed, and then regenerates documentation and runs base-owned validators. Every other parity mode remains exact.

After merge, PR #88 must merge the new base, consume this record and `p11-cleanup-prep-policy`, pass the base-owned trusted Diff, pass TCB candidate verification with only the declared `Validate` difference, and pass all 13 required checks.
