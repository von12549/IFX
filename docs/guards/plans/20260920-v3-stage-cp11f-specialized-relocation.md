# CP11f — Specialized gate relocation

This checkpoint consumes the CP11f test bridge and moves the Specialized dispatcher, two result contracts and all detector scripts together from `specialized/` to `stages/post/gates/specialized/`. The dispatcher, command catalog, Post trust contracts, trusted-component manifest, policy registry, authored guidance and generated documentation all name the stage-owned location in the same change.

Gate behavior is unchanged. Location-derived repository and package-policy paths are adjusted for the deeper directory, and the two contracts are explicitly registered now that they reside under the policy-scanned `stages/` root. Base-owned tests retain their exactly-one-layout transition selector; the production dispatcher has no legacy fallback.

Frozen refactor-baseline snapshots, historical decisions and evidence keep their original path text.
