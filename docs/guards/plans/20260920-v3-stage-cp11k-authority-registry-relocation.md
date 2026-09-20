# CP11k — Relocate the authority registry into Shared

This contract checkpoint completes the Plan 06 Shared-authority layout by moving the remaining legacy `policy/` directory to `shared/authorities/`. The domain-authority registry keeps its content and deterministic projection contract; only its package ownership path changes.

Active manifests, trusted-component coverage, policy registration, stage trust contracts and generated documentation point to the Shared path. Historical decisions and frozen refactor-baseline evidence continue to describe the repository state they recorded.
