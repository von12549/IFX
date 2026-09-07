## Contract / Event governance change

- [ ] Protocol source, G03 catalog, Change Record, and tests are updated together.
- [ ] Change is classified New / Compatible / Conditional / Breaking / Internal / Deprecated / Retired.
- [ ] Provider owner approval is attached.
- [ ] Every affected consumer owner approval is attached.
- [ ] Field C0-C4 classification, purpose, retention, and log policy are complete; no C4 is exposed.
- [ ] Public API/serialization snapshots and provider/consumer compatibility tests pass where applicable.
- [ ] LayerGuard and the unified G03 guard pass.

For Breaking changes:

- [ ] ADR/version-migration plan, parallel V+1, consumer-first release order, observation, and rollback are documented.
- [ ] Old identity retirement is gated by two releases, 30 days, all consumers migrated, zero old traffic, and empty old-schema backlog.

For emergency security/regulatory changes:

- [ ] Impact inventory, coordinated release owner, rollback, and post-incident ADR due date are recorded.
- [ ] No existing identity is silently reused for incompatible semantics.
