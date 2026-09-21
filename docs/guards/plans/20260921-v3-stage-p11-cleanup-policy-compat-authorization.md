# P11.5 authorized policy projection compatibility authorization

This authorization-only checkpoint publishes one immutable `change-trusted-base` record for prepared compatibility commit `e1d049f3`. It contains no trusted-runner implementation change.

The record binds the single changed path in `tcb.engine.trusted-base` and its base validation suite. Its parity contract permits only the exact four-entry legacy-to-canonical Architecture declaration, requires both named P11.5 preparation authorizations to be consumed by the exact candidate head, and keeps rendering and every verdict base-owned and fail-closed.

After this authorization merges into `codex/guards-principles-plan`, the compatibility candidate will consume the record and pass all 13 required checks. The bridge is temporary and will be removed by the final P11.5 cleanup.
