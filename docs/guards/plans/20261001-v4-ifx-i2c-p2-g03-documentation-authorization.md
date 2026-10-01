# Authorization of the G03 documentation set

Authorization-only checkpoint of IFX I2-C (Plan `20261001-v4-ifx-i2c-main-promotion` on the development branch
`codex/v4-development-base`), following the two-PR flow of `docs/guards/V3_ifx/stages/diff/authorizations/README.md`.

The two records were generated with the base's own `New-IFXTrustedBaseAuthorization.ps1` against the prepared change
head of `20261001-v4-ifx-i2c-p2-g03-documentation` and bind its exact base and head blobs:

- `i2c-g03-documentation-trusted-base.json` (`change-trusted-base`) covers the complete trusted component change, with the parity contract of the
  change plan;
- `i2c-g03-documentation-policy.json` (`weaken-policy`) covers the semantic change of the registered decision history.

The change pull request must delete both records, pass the base-owned trusted Diff, candidate verification with parity
and policy candidate validation, and pass all 13 required checks before merge. The records are single-use.
