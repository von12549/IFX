# G03 identity, version, and compatibility policy

The machine-readable rules live in `contract-event-catalog.yaml`; this document explains how to
apply them.

Sync identities name a provider-owned business capability; event identities name a provider-owned
past-tense fact. Major version is part of the stable identity and maps to `Contracts.VN` (and
`.Events` for event schemas). CLR renames never rename an Active identity. Retired identities and
their Change Records remain reserved permanently.

Every public change is classified Compatible, Conditional, Breaking, or Internal using the catalog
matrix. Optional additions are Compatible only when C# construction has a default, serialization
is additive, consumers tolerate unknown fields, and public value fallback is tested. Otherwise the
change is Conditional or Breaking. Removals, renames, type/meaning changes, new required fields,
interface breaks, stable error-code changes, and changes to an event's fact or occurrence point are
Breaking by default.

Breaking work publishes V+1 alongside V, switches consumers at their own adapters, observes both
versions, and retires V only after every consumer has migrated, two successful production
releases, at least 30 calendar days, zero old traffic, and no old-schema backlog/dead-letter/replay
liability. The latest condition wins. Rollback retains V and the adapter switch point and never
abandons already-created V+1 messages.

The current Abstractions surface is a migration input, not a formal compatibility baseline. An
identity remains Proposed until Plans 01/02 provide the physical `Contracts.V1` source, snapshots,
provider/consumer tests, catalog reconciliation, and approvals. After that Active marker, an
unversioned silent break is forbidden.
