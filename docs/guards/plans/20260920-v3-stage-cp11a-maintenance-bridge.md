# CP11a — maintenance relocation compatibility bridge

This checkpoint starts Plan 06 P10 with the base-owned test bridge required before internal maintenance tools can move. The current policy projection tool remains at `scripts/Sync-IFXPolicyInputs.ps1`; the next physical-migration checkpoint will replace it with `maintenance/Sync-IFXPolicyInputs.ps1` and replace mutating `Generate` with explicit `Apply -AcceptMaintenance` while retaining read-only `Check` and `Preview` behavior.

The bridge deliberately accepts exactly one of the legacy or maintenance paths. It uses `Generate` only for the legacy implementation and `Apply -AcceptMaintenance` only for the relocated implementation. Both paths present, neither path present, or an unsuccessful maintenance invocation fail closed, so this is not a silent fallback and does not create a permanent internal compatibility surface.

This checkpoint changes no production runner, authority, projection, workflow or required check. Its only trusted-component change is the base-owned authority projection test. The exact candidate is authorized by a separate authorization-only checkpoint and consumes that record in the change diff before it can become the base for the maintenance relocation.
