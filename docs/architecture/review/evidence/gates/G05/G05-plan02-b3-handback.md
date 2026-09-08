# G05 Plan 02 / B3 event-context handback

Date: 2026-09-08

The two admitted event payloads contain no TenantId or C4 data. The producer freezes EventId,
type/version, occurred time, producer, tenant scope, correlation, causation and trace carrier into
the Outbox logical record. Dispatch retry, lease recovery, dead-letter and replay preserve that
identity. Diagnostics and logs omit payload.

The Holdings inbound adapter validates producer, type/version, tenant and payload before entering
Application, establishes an isolated ExecutionContext with EventId as OperationId, maps to a
consumer-owned command, and cleans the scope. Invalid producer/tenant/payload and bounded business
rejection are quarantined without creating a trusted Application context. Protocol, dispatcher,
SQL Server and consumer tests provide the repository conformance evidence.

Still open for final G05 closure: production broker/header normalization, authorized operator-audit
integration, alert/sentinel rehearsal, retention controls in the deployment environment, and final
Security/Operations approvals.
