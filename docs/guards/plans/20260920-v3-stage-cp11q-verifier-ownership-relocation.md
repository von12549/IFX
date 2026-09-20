# CP11q — Verifier ownership relocation

This checkpoint assigns the two remaining package-root verifier implementations to their final Plan 06 P10 owners.

- The public CI contract verifier moves to `commands/Invoke-IFXCiContract.ps1`; the old `ci/` path becomes a deprecation wrapper that forwards all arguments and the exit code until P11.5.
- The internal manifest verifier moves to `engine/Invoke-IFXManifestCheck.ps1`; its old `scripts/` path is deleted without a wrapper.
- The dispatcher, command registry, TCB manifest, compatibility registry, authored documentation and generated command reference point at the final authorities.

The preceding base-owned bridge makes the unchanged manifest corpus execute against exactly one old or new internal verifier layout.
