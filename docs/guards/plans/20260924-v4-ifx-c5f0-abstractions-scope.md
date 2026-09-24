# V4 P10.1 C5f0 — Plan04 Abstractions generated-directory scope

The full C5f Post integration exposed `Abstractions source inventory drift`.
The C4a4 candidate currently inventories all `src`/`tests` directories
except `bin`/`obj`; the controlled Frontend Quality run creates ignored
`node_modules`/`dist` paths, which are not source subjects. Keep active
`.cs`/`.csproj` and their non-generated directories in scope, but exclude
`node_modules`, `dist`, `coverage` and `.vite` as well as `bin`/`obj`.
This does not loosen forbidden Abstractions detection in active source.

Update the independent test's inventory algorithm identically, add a
generated-directory positive control while preserving the legacy directory,
missing and zero negatives, then rerun real IFX, published 1.1.3 Host,
isolated package regression and exact Formal Diff. Refresh the C5f config
from new evidence rather than relabelling the earlier C4a4 fixture.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5f0/formal-pre/pre.json`.
The scope correction and new generated-directory positive control passed
the full C4a4 candidate suite, including real IFX, active legacy violation,
missing/zero controls and published 1.1.3 Host Post. Evidence:
`artifacts/guards/p10-ifx-c4a4/test-runs/4d56c9a42e7940a3a818316a085d0694/summary.json`.
The old C4a4 fixture record remains historical; C5f will select this new
passing fixture config. The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-40826a4da5e94d388eb364f8ad12f49a`.
Exact committed Formal Diff follows.
