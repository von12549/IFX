# CP11n — Stage-oriented package test relocation

This protected checkpoint completes the Plan 06 §13 test-layout mapping. All fourteen IFX package tests move from the flat `tests/` directory into `tests/ci/`, `tests/pre/`, `tests/post/`, or `tests/support/` according to the Stage or cross-Stage support responsibility established by the frozen inventory and current manifests.

The public dispatcher keeps the same Architecture and CrossPlatform test selections. Trusted component paths, validation suites, the package-test toolchain command, reviewed analysis evidence, generated views, and deployment documentation move to the canonical paths. No legacy internal test wrappers remain.

Each source-to-destination move has an exact path authorization. The trusted-component and registered policy/configuration changes use independent authorizations and are consumed by the change checkpoint.
