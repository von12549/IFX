# CP11b — V3_backup retirement

This Plan 06 P10.5 physical-migration group deletes the redundant 41-file `docs/guards/V3_backup` snapshot under D2. The canonical `docs/guards/V3` source package and Git history become the only recovery boundary; no release snapshot or compatibility wrapper is retained.

The base-owned retirement bridge was authorized and consumed by `2e0e45ff` → `ff191f84`. It moved protected-change fixtures to the canonical V3 tree and made the cutover-preservation test recognize the explicit transition before this deletion.

This change removes the completed compatibility entry, removes the backup marker from isolated package inputs, tightens cutover preservation to require the backup to remain absent, updates authored/generated documentation, and consumes all directory-delete, trusted-base and policy/config authorizations. Protection of the retired path remains configured so future accidental reintroduction or manipulation stays visible to the guard system.

Acceptance requires zero tracked files under `docs/guards/V3_backup`, no live package/runtime dependency on that tree, exact authorization consumption, passing base-owned TCB validation, Validate/Docs Check and the full package suite.
