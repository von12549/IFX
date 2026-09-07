# G04 Phase 10 — Automated acceptance

Status: **PRE-READY**. Repository automation is complete for attainable scope; downstream and production exercises remain visible.

| Concern | Automated evidence | Remaining closure evidence |
|---|---|---|
| manifests/startup | manifest validator, `StartupBoundaryVerifierTests`, runtime guard | G03 Contract registry handoff |
| runtime roles | `RuntimeProfileResolverTests`, endpoint/server static guard | target replica observation |
| multi-instance lease | real SQL Server `G04DispatcherLeaseConformanceTests` | E3 real Dispatcher and E4 Inbox rerun |
| crash points | reference claim/reclaim/conditional-complete injection | E3/E4 end-to-end no-loss/duplicate absorption |
| drain | `RuntimeDrainCoordinatorTests`, Compose validation | SIGTERM/load-balancer/forced-kill rehearsal |
| probes | `HealthEndpointTests`, `HealthSnapshotStoreTests` | G05 sensitive sentinel and network policy |
| backlog | `MessageBackpressurePolicyTests` | E3/E6 real signals and alerts |
| rollout/failure | orchestration and failure-matrix validators | target-platform execution and approvals |
| architecture | LayerGuard with b0.5 baseline | Plan 03 L5.1 final governance |

`.github/workflows/g04-deployment-runtime.yml` runs the consolidated verification script and uploads reports. The script labels its summary `repository-automation-no-production-claim` so a green CI run cannot be mistaken for production approval.
