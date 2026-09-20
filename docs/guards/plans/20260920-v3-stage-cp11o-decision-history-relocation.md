# CP11o — Relocate decision history into shared ownership

This protected checkpoint completes the Plan 06 section 13 decision mapping. All thirty-four reviewed decision records move byte-for-byte from `decisions/history/` to `shared/decisions/history/` after the base-owned bridge accepts exactly one layout.

The active Diff trust contract now references the shared history. Historical checkpoint plans continue to record the paths that existed when they ran; runtime code and living Plan 06 progress use the canonical shared location. No legacy internal copy or wrapper remains.
