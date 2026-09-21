# P11.5/P11.6 compatibility cleanup authorization

This authorization-only checkpoint permits the exact candidate at `6f3eaafaee72ba87820eff3e6730fd73a684b358` to retire the Plan 06 compatibility surface from base `d97a2a5b1f015ca82efc42c9e8a6a8ced40e7b24`.

Nine independent `delete` records bind each legacy wrapper to its base tree-entry tuple. One `change-trusted-base` record covers the complete candidate TCB component/path set as a single non-composable authorization. One `weaken-policy` record covers the exact semantic compatibility-registry and policy-registry changes. The records do not authorize any other head revision or path.

After this PR passes all 13 required checks and merges, the implementation branch must merge the new base, delete all eleven single-use records, pass the base-owned trusted Diff and trusted-component candidate verifier, and pass all 13 checks before merge.
