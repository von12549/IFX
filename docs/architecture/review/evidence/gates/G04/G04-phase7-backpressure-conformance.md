# G04 Phase 7 — Backpressure conformance

Status: **PRE-READY**. The policy surface and synthetic behavior are complete; E3/E6 telemetry and production calibration remain required.

The versioned `deployment/g04/backpressure-policy.json` defines freshness, warning/critical thresholds, retry timing, ownership, and eleven required per-module/event dimensions. `MessageBackpressurePolicy` evaluates age, count, rate, dead letters, and storage capacity together. Count alone cannot cause an unhealthy result.

`MessageBackpressurePolicyTests` proves transport-stall critical state, poison/dead-letter escalation, no count-only false positive, scoped blocking of only related backlog-producing commands, continued safe reads/unrelated production, and reopening after recovery.

Not claimed: no real Outbox/Inbox collector, alert rule, API command classification, or Worker readiness feed exists until Plan 02 E3/E6. Production thresholds have not been capacity-tested.
