# G04 Phase 3 dependency review

The versioned catalog at `deployment/g04/dependency-criticality-catalog.json` is the authoritative classification for runtime aggregation.

- Invalid Runtime Role, module/release manifest, DI graph, required module set and duplicate route identity are startup-fatal and terminate with a stable G04 reason code.
- All five module databases and their schema compatibility are readiness-critical for every role. Worker storage and future transport are readiness-critical only when their capabilities execute.
- OPA is capability-critical because the existing authorization client fails closed for covered operations, while unrelated safe paths can remain available. This decision must be re-audited when G05 supplies complete endpoint/field coverage.
- Cognito is capability-critical: identity flows degrade, but unrelated authenticated work and safe reads need not lose process liveness.
- SendGrid is optional because the repository already supports a no-op implementation; durable notification semantics remain the owning capability's concern.
- Frontend availability is operational and never a backend liveness/readiness dependency.

`StartupDependencyMonitor` runs after the web host becomes alive, invokes registered health checks with a bounded timeout, records `AliveNotReady` while dependencies fail, and retries until recovery without restarting the process. Phase 6 replaces the legacy aggregate with role- and criticality-specific contributors while retaining this non-blocking startup behavior.
