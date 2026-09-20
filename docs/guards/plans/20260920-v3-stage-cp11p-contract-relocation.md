# CP11p — Contract ownership relocation

This checkpoint completes the package contract split defined by D32.

- Nine cross-stage schemas move to `shared/contracts/`.
- Four Diff schemas move to `stages/diff/contracts/`.
- Three CI schemas move to `stages/ci/contracts/`.
- Seven byte-identical IFX copies are deleted and all consumers use the canonical V3 schemas.

The policy registry, TCB manifest, activation contract, command inputs, generated documentation and authored path references move atomically with the schemas. The portable V3 docs renderer keeps a fail-closed legacy/owned resolver so base-owned validation works on either side of the relocation; no permanent IFX compatibility copy remains.
