# P11.5 cleanup preparation authorization

This authorization-only checkpoint publishes the two immutable records required by the prepared cleanup bridge commit `0e66fa0c`. It contains no implementation change.

The `change-trusted-base` record binds the exact 18 changed TCB paths and the affected validation suites. Its parity contract requires the canonical Architecture command and engine ownership to preserve every guard mode, exit code, required check identity, policy verdict, package validation result and temporary legacy-wrapper behavior. The `weaken-policy` record separately binds the exact semantic pointers changed in the five registered policy and configuration files.

After this authorization is merged into `codex/guards-principles-plan`, the prepared change will incorporate the new base, delete both records to consume them, and pass the full required-check set. These records authorize no protected deletion; the nine P11.5 wrapper removals require a separate deletion authorization.
