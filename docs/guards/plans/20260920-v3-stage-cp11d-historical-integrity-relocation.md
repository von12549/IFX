# CP11d — Historical Integrity relocation

This checkpoint consumes the CP11d relocation bridge and moves the Historical Integrity engine and its manifest together from the legacy `history/` directory into the Post-stage gate tree. The public IFX dispatcher, command catalog, Post trust contract, maintenance default, policy registry and trusted-component manifest all name the stage-owned location in the same change.

The manifest bytes remain unchanged by the move. The engine changes only its location-derived repository-root default so direct invocation still resolves the repository; explicit `-RepositoryRoot` behavior is unchanged. Base-owned bridge selectors continue to accept exactly one complete layout so the current base can judge this candidate and the relocated package can judge future candidates. The temporary destination-directory policy entry is removed and replaced by the exact final manifest path; no runtime fallback remains in the production dispatcher.

Frozen refactor-baseline snapshots, historical plans, decisions and review evidence retain their original paths as historical records.
