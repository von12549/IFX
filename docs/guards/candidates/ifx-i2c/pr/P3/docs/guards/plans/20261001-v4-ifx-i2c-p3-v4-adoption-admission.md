# Admit `docs/guards/v4-adoption`

Formal V3 plan for the change pull request of IFX I2-C step C7 (Plan `20261001-v4-ifx-i2c-main-promotion` on the
development branch `codex/v4-development-base`; operator decision 2B of the IFX I2 program).

`V3_ifx/tests/ci/Test-CutoverPreservation.ps1` allows only `plans`, `V3` and `V3_ifx` at the top of `docs/guards`.
IFX's V4 Guards adoption needs one reviewed location for its trusted inputs (the exact `ifx_profile` bundle and review,
the V4-native evidence producers, the P10.3 aggregate, the proposal and receipts). This change admits exactly one entry,
`v4-adoption`:

- the expected set becomes `plans`, `V3`, `V3_ifx`, `v4-adoption`, and the comparison becomes case-sensitive, so the
  assertions only grow: an additional entry, a differently cased entry and a missing `v4-adoption` all fail;
- decision `20261001-v4-ifx-i2c-v4-adoption-admission` records the admission and is registered in the
  `decision-history` entry of `shared/policy-config.json`;
- `docs/guards/v4-adoption/README.md` creates the entry; the package content arrives in later reviewed pull requests.

The test (`tcb.validation.package-tests`) and `policy-config.json` are trusted components, and registering a decision
changes the `trust-meta-policy` decision history. The change therefore consumes two base records:
`i2c-v4-adoption-admission-trusted-base` (`change-trusted-base`, with the parity contract below) and
`i2c-v4-adoption-admission-policy` (`weaken-policy`). Both were merged alone in the preceding authorization pull request
and are deleted here.

Parity contract: every cutover-preservation assertion is unchanged except the top-level allowlist, which admits exactly
one additional entry, `v4-adoption`, compared case-sensitively; any other, differently cased or missing entry still
fails. The decision-history registry of `policy-config.json` gains exactly one entry,
`20261001-v4-ifx-i2c-v4-adoption-admission`; nothing else in `policy-config.json` changes.
