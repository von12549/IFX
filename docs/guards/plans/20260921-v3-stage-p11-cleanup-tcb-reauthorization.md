# P11.5 cleanup replacement trusted-base authorization

This authorization-only checkpoint republishes `p11-compatibility-cleanup-trusted-base` after its D22 revocation in PR #102. It contains no implementation change and leaves the nine wrapper deletion authorizations and `p11-compatibility-cleanup-policy` unchanged.

The new immutable record is generated from base `07e3dd0928a0436f2044bb57ce8536a8fa989982` and cleanup candidate `953c77e4200f895600f822cc2570da6332d5df9d`. It binds exactly 16 paths across seven trusted components. Compared with the revoked instance, `Test-IFXTrustedBase.ps1` is absent because its fixture correction is already part of the base; all remaining tuples describe the actual compatibility cleanup.

The identifier is intentionally retained because the cleanup plan consumes that required authorization ID. The prior instance was deleted in a separate revocation-only base commit, so this file is a new single-use record with exact current tuples.

After merge, the cleanup candidate must merge the new base, consume this record together with the still-valid deletion and policy records, and pass base-owned trusted Diff, trusted-component candidate verification, and all 13 required checks.
