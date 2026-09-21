# P11.5 cleanup-prep replacement authorization

This authorization-only checkpoint republishes `p11-cleanup-prep-trusted-base` after its D22 revocation in PR #91. It contains no implementation change and leaves the still-valid `p11-cleanup-prep-policy` record untouched.

The new immutable record is generated from base `93a41635bc958e2809c28e5df3955fec9c742bb1` and corrected candidate `e50d34832159a10f958f0174c3487efe3937caeb`. It binds exactly 18 trusted-component paths. Compared with the revoked instance, the material correction is the `docs/guards/V3_ifx/commands/Invoke-IFXCiContract.ps1` head tuple: the transition verifier rejects both the legacy `scripts/` dispatcher and non-candidate use of the canonical `commands/` dispatcher from an untrusted head workflow.

The identifier is intentionally retained because the explicitly authorized one-time compatibility bridge binds that exact consumed authorization ID. The old record was deleted in a separate revocation-only base commit; this file is a new single-use instance with new exact tuples and authorization history.

After merge, PR #88 must merge the new base, delete both `p11-cleanup-prep-policy` and this replacement record, pass the base-owned trusted Diff and all 13 required checks.
