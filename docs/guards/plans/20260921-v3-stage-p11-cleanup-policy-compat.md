# P11.5 authorized policy projection compatibility

This one-time bridge lets the base-owned Validate runner judge the prepared P11.5 command-path migration without trusting head implementation. The old base declaration names `scripts/Invoke-IFX.ps1`; the prepared candidate moves the two Architecture smoke/full commands to `commands/Invoke-IFXArchitecture.ps1` in the same authorized change that updates its public candidate facade.

The bridge activates only when the entire candidate declaration is exactly the four legacy-to-canonical string substitutions and the base protected-change verifier proves that both `p11-cleanup-prep-policy` and `p11-cleanup-prep-trusted-base` were consumed by the exact head. It copies only that authorized declaration into the disposable base candidate package, then uses the base renderer to derive documentation. All verifier code, schemas and verdict logic remain base-owned; every other candidate-policy difference fails closed.

The bridge exists solely for the P11.5 transition and will be removed with the final compatibility cleanup after the canonical declaration becomes part of the base.
