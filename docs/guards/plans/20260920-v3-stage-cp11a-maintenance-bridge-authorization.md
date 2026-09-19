# CP11a maintenance bridge authorization

This authorization-only checkpoint permits the exact base-owned test change prepared at `8b7cd709` against CP10 final base `2929bd87`. It covers only `tcb.validation.package-tests` and the old/new blob tuple of `Test-IFXAuthorityProjection.ps1`.

Production policy projection behavior, authorities and files are unchanged. The bridge grows assertions to select exactly one legacy or maintenance entry point, reject both or neither, and use the explicit mutating mode associated with that path. The authorization-only Plan files make the base generated-documentation view stale, so `Validate` records that narrow allowed difference; all other validation checks and all five verdict modes remain subject to parity.

The bridge change must delete this record in the same diff before becoming the trusted base for physical maintenance relocation.
