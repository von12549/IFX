# V4 Guards adoption in IFX

This directory is the one place in the protected history for IFX's adoption of V4 Guards. IFX is a **consumer**
of the V4 Guards product. The product source, releases and trusted-base CI live in the standalone repository
[`von12549/Guard`](https://github.com/von12549/Guard).

V3 decision `20261001-v4-ifx-i2c-v4-adoption-admission` admits this entry as the only top-level `docs/guards` entry
besides `plans`, `V3` and `V3_ifx` (`V3_ifx/tests/ci/Test-CutoverPreservation.ps1`). V3 keeps owning every V3 path,
workflow and required context, and no V3 verdict reads this directory.

The curated package arrives here through its own reviewed pull requests (IFX I2 program, phase I2-D onwards):

- the exact reviewed `ifx_profile` bundle and its production review, as a trusted input;
- the V4-native evidence producers and the staging and aggregate scripts;
- the P10.3 proposal and the migration receipts.

Until then this directory holds only this file. Nothing here is active: publishing the bundle, installing a V4
workflow, changing a required context or the ruleset, P10.GATE, cutover and V3 retirement each need their own exact
Plan and authorization.

The adoption lab — candidate harnesses, inventories, certification artifacts, historical V4 plans and the IFX V4
backlog (`docs/guards/TODO.md`) — stays on the development branch `codex/v4-development-base` and is referenced by
commit.
