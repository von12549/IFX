# CP10 CI activation lifecycle authorization

This authorization-only checkpoint pre-authorizes the exact CP10 candidate `2c907369` against the verified base-compatibility bridge `aeed75e2`. It changes no workflow, policy or activation target.

The `change-trusted-base` record covers the six affected trusted components and 22 exact paths, with the invariant that all 13 required check names, DAG, triggers, trusted-base verdict ownership and fail-closed behavior remain unchanged. Its sole allowed `Validate` difference is the stale generated-documentation view caused by these authorization-only plan files; every other validation check and all five verdict parity modes remain explicit. The `weaken-policy` record binds ten registered policy/configuration changes to their exact blob hashes, schemas/formats and JSON pointers. The `delete` record covers only the removal of `ci/jobs.json`, whose authority moves to `stages/ci/required-checks.json`.

The CP10 change must delete all three records in the same diff. Remote ruleset writes and activation Install remain outside this authorization.
