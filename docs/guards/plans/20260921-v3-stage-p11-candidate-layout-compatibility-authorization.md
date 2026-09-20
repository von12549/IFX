# P11 candidate-layout compatibility authorization

This authorization-only checkpoint publishes D37 and one immutable `change-trusted-base` record for prepared bridge commit `ef0fb03d`. It contains no runner, renderer, generator, verifier or test implementation changes.

The record binds the exact ten TCB path tuples and validation suites of `tcb.engine.architecture-runner`, `tcb.engine.trusted-base`, `tcb.engine.v3-runner`, `tcb.validation.package-tests` and `tcb.validation.v3-package-tests`. Its parity contract preserves all 13 required checks, exact Diff coverage and authorization obligations. The only intended compatibility is base-owned validation of one schema-valid split candidate layout and an explicitly suffixed aggregate plan. `allowedBehaviorDifferences` remains empty.

After this authorization merges into `codex/guards-principles-plan`, the prepared bridge will merge that base, delete the record to consume it, and pass all 13 required checks. This authorization covers no final P11 protected removal, policy weakening or trusted-component change.
