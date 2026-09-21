# P11.5 cleanup preparation bridge

This checkpoint closes the last active dependencies on Plan 06 compatibility paths before their authorized removal.

- Move the IFX Architecture implementation from the legacy `scripts/` location to `engine/Invoke-IFXArchitecture.ps1` and expose the stable `commands/Invoke-IFXArchitecture.ps1` facade.
- Keep `scripts/Invoke-IFX.ps1` temporarily as a deprecation wrapper so the following deletion PR can be judged by this base.
- Point active manifests, CI cost declarations, generated documentation, tests and architecture guides at canonical `commands/` entries.
- Remove the obsolete non-executable P11.4 pre-layout compatibility block from the workflow template and regenerate the activated workflow without changing its jobs, required-check names or executable command path.
- Tighten manifest tests so the canonical command layout is required while still proving that a declared missing compatibility path fails closed.

This bridge deletes no legacy entry. The following P11.5 authorization/change pair removes the nine wrappers only after this checkpoint is merged and has passed all required checks.
