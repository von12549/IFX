# P11.5 cleanup compatibility bridge scope authorization

This authorization-only checkpoint covers one trusted-base runner correction discovered by the final PR #88 Linux checks. The one-time P11.5 compatibility bridge correctly handled the real cleanup candidate, but it also recognized the same legacy-to-canonical declaration shape inside unrelated trusted-base synthetic fixtures. Those fixtures did not change the CI declaration and therefore could not consume the cleanup-specific authorization IDs.

The authorized candidate adds one further prerequisite: `docs/guards/V3_ifx/stages/ci/required-checks.json` must be present in the current verified base-to-head changed set. The real cleanup candidate satisfies that prerequisite. Authorization-only, waiver, records-and-plans, and future unrelated heads do not, so they continue through the ordinary base-owned validation path without invoking the temporary bridge.

The record binds only `docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1`, from base blob `3c9c6ea78235681c42f32000ced24aec2ebda78d` to candidate blob `23e8bd021063a31112b25889b2eead66ac04c707`. It does not overlap or alter `p11-cleanup-prep-trusted-base`, which still covers the original 18 cleanup-preparation TCB paths.

After this authorization merges, PR #88 must merge the new base, delete this record together with its two existing cleanup-preparation authorizations, and pass the trusted Diff, trusted-component candidate verification, and all 13 required checks.
