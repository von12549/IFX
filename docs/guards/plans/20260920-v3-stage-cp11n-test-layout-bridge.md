# CP11n — Stage-oriented test layout bridge

This expand checkpoint removes the package tests' dependency on being direct children of `tests/`. Each test resolves the IFX guard package root from the package manifest at either the legacy flat location or one Stage-oriented subdirectory below it, then fails closed if neither layout is present.

The checkpoint changes no test selection, fixture, assertion, verdict, or production entry point. It prepares the previous trusted base to validate the subsequent protected move into `tests/ci/`, `tests/pre/`, `tests/post/`, and `tests/support/`.
