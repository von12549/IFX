# Plan 06 final trusted-base authorization revocation (D22)

This D22 revocation-only checkpoint removes the six superseded P11 final trusted-base authorization records and adds only this formal plan pair.

The records authorized the initial P11 aggregate candidate and revisions r2 through r6. The accepted P11 compatibility cleanup used and consumed the later r7 authorization. All 753 base tuples in each retained record differ from the current base, so the records are not consumable against the current tree; they are nevertheless obsolete live authorization records and should not remain in the active authorization namespace.

No implementation, policy, compatibility path, generated document, historical evidence, or current authorization is changed. The trusted Diff must classify all six deletions as revocations, report zero protected-change obligations, and all 13 required checks must pass.
