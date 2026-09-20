# P11 minimal compatibility bridge authorization

This authorization-only checkpoint publishes D36 and one immutable `change-trusted-base` record for the prepared bridge commit `be44a5c0`. It does not contain the workflow, verifier or trusted-base implementation changes.

The record binds the exact seven TCB path tuples and the validation suites of `tcb.activation.ci`, `tcb.engine.trusted-base`, `tcb.manifest` and `tcb.validation.package-tests`. Its parity contract names the complete compatibility boundary: unique aggregate-plan selection, recognition of the candidate public facade through the base worktree, and candidate-registry classification that remains subject to the ordinary `weaken-policy` gate. No schema-level gate verdict difference is allowed.

After this authorization is merged into `codex/guards-principles-plan`, the bridge candidate is rebased, deletes the record to consume it, and must pass all 13 required checks. The authorization does not cover any P11 protected removal or final policy/TCB change.
