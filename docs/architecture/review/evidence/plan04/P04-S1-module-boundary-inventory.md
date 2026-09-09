# Plan 04 P04-S1 — module and dependency fact inventory

Date: 2026-09-10

Status: Phase 1 repository inventory passed; no extraction or production capability is claimed

## Result

The reproducible inventory contains five G03/G04/G02-reconciled business modules, four Active G03
protocol edges, 120 B4 project edges and 132 B4 namespace edges. All six physical cross-module
project edges map to exactly one registered protocol. There are no unknown business-module
directories, unregistered cross-module project edges or G02 cross-schema findings.

| Module | Projects | Test projects | Physical fan-in / fan-out | Sync provided / consumed | Events provided / consumed | Frozen-history commits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Auth | 5 | 4 | 0 / 0 | 0 / 0 | 0 / 0 | 41 |
| CRM | 6 | 2 | 1 / 0 | 1 / 0 | 0 / 0 | 16 |
| Registry | 6 | 2 | 2 / 0 | 1 / 0 | 1 / 0 | 16 |
| Transaction | 6 | 2 | 1 / 2 | 0 / 2 | 1 / 0 | 18 |
| Holdings | 5 | 2 | 0 / 2 | 0 / 0 | 0 / 2 | 15 |

Physical direction is the compilation/reference direction from consumer adapter or composition to
provider Contracts. Logical protocol direction remains provider to consumer. Keeping the two views
separate prevents a reference arrow from being mistaken for business-fact ownership.

## Registered cross-module paths

- Transaction Infrastructure/Composition references CRM Contracts for
  `crm.account-compliance.v1`.
- Transaction Infrastructure/Composition references Registry Contracts for
  `registry.class-subscription-availability.v1`.
- Holdings Infrastructure references Transaction Contracts for
  `ifx.transaction.transaction-processed.v1`.
- Holdings Infrastructure references Registry Contracts for
  `ifx.registry.class-status-changed.v1`.

Auth has no registered cross-module business protocol. Registry and CRM own their published facts;
Transaction owns the processed-transaction fact; Holdings owns its resulting position/freeze state.

## Coupling interpretation

G04 still requires one five-module business release. G02 still uses one physical database while each
module owns its schema and DbContext. These are explicit runtime and resource couplings, not shared
business ownership. No module is independently releasable today.

The last-200-commit co-change window is pinned to the Phase 0 baseline commit. All ten module pairs
appear because recent Gate/Plan work intentionally changed multiple boundaries together; therefore
the counts are review signals only and are not evidence of product-change coupling or a reason to
split. A later GOV4 review must combine them with ownership, protocol, data and operational facts.

## Reproducibility and fail-closed behavior

`scripts/New-Plan04BoundaryInventory.ps1` directly consumes G02, G03, G04 and B4 and emits:

- [`module-boundary-inventory.json`](module-boundary-inventory.json), the complete auditable inventory;
- [`module-boundary-dependency-graph.json`](module-boundary-dependency-graph.json), the compact node/edge view;
- [`phase1-inventory-status.json`](phase1-inventory-status.json), validation and counts.

`scripts/Test-Plan04Phase1Inventory.ps1` regenerates both JSON artifacts twice and compares their
hashes. Unknown modules, missing G02/G03/G04 identities, ambiguous/unknown consumers, unregistered
cross-module project edges, input-hash drift and cross-schema access fail the slice.
