# CP11e — Quality gate relocation

This checkpoint consumes the CP11e test bridge and moves the three Quality gate scripts together from `quality/` to `stages/post/gates/quality/`. The dispatcher, command catalog, Post trust contracts, trusted-component manifest, authored guidance and generated documentation all name the stage-owned location in the same change.

The gate behavior is unchanged. Each script updates only location-derived repository or package-policy paths needed for direct invocation from its deeper directory. Base-owned tests retain their exactly-one-layout transition selector; the production dispatcher has no legacy fallback.

Frozen refactor-baseline snapshots and historical evidence keep their original path text.
