# CP10 base compatibility authorization

This authorization-only checkpoint permits the single reviewed test-harness change in candidate `d3e2f810`. The record covers only `tcb.validation.package-tests` and the exact old/new blob tuple of `Test-IFXCiContract.ps1`.

Production behavior is unchanged. The bridge change must delete the record in the same diff before it can become the base for final CP10 candidate validation.
