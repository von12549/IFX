# Plan 05 cutover baseline

This baseline was captured from commit `9d07faa21ba1b7f204c19c3c40b5a99d4b08fad3` on 2026-09-15 before V3_ifx became the production gate entry. The machine-readable record is `cutover-baseline.json`.

## Verified baseline

| Capability | Result | Evidence |
| --- | --- | --- |
| MCP LayerGuard | Passed, 192/192 tests, strict scan clean | `artifacts/guards/plan05-baseline/mcp-layerguard.json` |
| V3_ifx Architecture | Passed, 192/192 tests, strict scan clean | `artifacts/guards/plan05-baseline/v3-layerguard.json` |
| Coding Guardrails self-test | Passed | Console result |
| Domain assembly self-test | Passed | Console result |
| G05 aggregate | Passed, including 1270 solution tests | `artifacts/guards/plan05-baseline/g05/verification-summary.json` |
| Database pending model | Passed for five DbContexts | `artifacts/guards/plan05-baseline/database-pending.json` |
| Frontend | Lint passed with four existing warnings; 63 tests and build passed | Console result |

## Known legacy failures

| ID | Existing behavior | Migration decision |
| --- | --- | --- |
| `G03-CLIENT-EVIDENCE` | Source reconciliation looks for the provider Contract type inside the first consumer module. Current outbound adapters use provider Client projects and intentionally keep versioned Contracts out of Application and adapter source. | The V3 G03 detector will verify the registered consumer edge and Client-backed adapter instead of requiring a direct Contract type reference. |
| `G04-CANONICAL-HASH` | The G04 generator hashes raw checkout bytes. On Windows, regenerated CRLF hashes differ from the LF-bound manifest and invalidate the LayerGuard composite hash. | V3 uses canonical LF hashing for JSON/text authorities and tests the same result on Windows and Linux. |
| `P04-FROZEN-HASH` | Plan 04 binds old G04 and tenant/projection policy hashes. Its independent tenant, projection, extraction and Abstractions checks pass, while the historical bindings fail. | Current policy validators move to V3 Specialized.Plan04; frozen hashes become HistoricalIntegrity inputs rather than current readiness assertions. |

## Current duplicate execution

```text
LayerGuard full scan  <- layerguard.yml, G03 workflow, G04 aggregate, G05 aggregate
G03 catalog          <- G03 workflow, G05 aggregate, LayerGuard policy binding
Migration safety     <- G05 aggregate, Database workflow
Solution build/test  <- G04 aggregate, G05 aggregate, Database workflow
```

The cutover target runs one Architecture scan, one owner for each specialized detector, and one shared solution build/test job. Static policy binding reports are reused as evidence instead of rerunning their producer.
