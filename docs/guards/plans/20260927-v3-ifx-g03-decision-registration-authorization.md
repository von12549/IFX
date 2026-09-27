# V3_ifx G03 documentation decision registration authorization

This authorization-only checkpoint permits the exact candidate at `c3a5c81f`
(Plan `20260927-v3-ifx-g03-decision-registration`) to register the C2d
decision record `20260924-v4-ifx-c2d-g03-current-documentation.json` in
`shared/policy-config.json`, from base `af2bd603`.

One `weaken-policy` record covers only `shared/policy-config.json`, from base
SHA-256 `8a566d43...317bb18e` to candidate SHA-256 `9d876448...5ad63e40`, at the
single pointer `/entries/24/paths/41` (the appended `decision-history` path),
with the exact head blob tuple. One `change-trusted-base` record covers the same
single path of component `tcb.manifest` and declares one allowed behavior
difference: `Validate` changes from fail to pass, because base fails only its
manifest-check on the unregistered record. Neither record authorizes any other
policy file, pointer, component or head revision.

After this checkpoint merges into the base, the registration change must merge
the new base, delete both single-use records, and pass the base-owned trusted
Diff and IFX V3_ifx `Validate` before merge.
