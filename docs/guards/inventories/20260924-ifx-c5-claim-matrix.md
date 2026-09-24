# C5 exact gate and evidence inventory

The [machine-readable matrix](20260924-ifx-c5-claim-matrix.json) freezes the
four V3 Post gate destinations and nine authority hashes on published V4
1.1.3. It enumerates all 15 historical files and three reference edges.
The original historical manifest remains the authority; its `passed`
historical files never become current readiness or a Profile waiver.

| Gate | C5 destination | Capability boundary |
| --- | --- | --- |
| Solution Quality | C5b controlled build/test/audit producer, then read-only Post | `dotnet restore/build/test` and NuGet audit outside V4 Post |
| Assembly Quality | C5c compiled-evidence verifier | Exactly five Domain DLLs, fresh build provenance and Domain reference policy |
| Frontend Quality | C5d controlled npm producer, then read-only Post | `npm ci/audit/lint/test/build` outside V4 Post; network prerequisites explicit |
| Historical Integrity | C5h independent read-only Post module | 15 canonical hashes, summary fields and three reference edges; no readiness promotion |

C5 integration must bind C1/C2's completed 1.1.3 revalidation, C3/C4
candidate modules, fresh controlled Quality and Database evidence, and
claim-specific V4 Profile baselines. Bootstrap/Analysis/Pre/Post ownership
is provisional until the integration child Plan tests direct and dependent
Stage routes. Compiled C1 and MSBuild-evaluated residuals remain blockers
for C1 final closure. The V3 Diff and two CI checks are P10.3 governance
deferrals, not passing C5 runtime claims.
