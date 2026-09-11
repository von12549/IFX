# Plan 04 P04-S0 — Phase 0 baseline freeze

Date: 2026-09-10

Baseline commit: `40d3cd38505c14557567d7cc81f4ef51e8293d3c`

Status: repository baseline frozen; Phase 1–8 and all functional approvals remain pending

## Frozen authority boundaries

Plan 04 does not copy or become the owner of its source facts. The hash-bound manifest
[`phase0-baseline-inputs.json`](phase0-baseline-inputs.json) points to the following authorities:

| Authority | Sole ownership consumed by Plan 04 |
| --- | --- |
| G02 | module DbContext/schema/migration ownership and the cross-schema access prohibition |
| G03 | capability/data ownership, Contract/Event provider-consumer graph and field lifecycle |
| G04 | five required business modules, endpoint/runtime capability identity and common release boundary |
| G05 | trusted ExecutionContext/tenant scope, C0–C4 policy and unresolved production security evidence |
| LayerGuard B4 | project/namespace graph and the strict static-boundary policy |

The B4 input is LayerGuard `0.4.0-a1`, 39 in-scope projects, zero findings and zero baseline entries.
The G03 input contains five business modules and four Active protocols: CRM and Registry synchronous
Contracts into Transaction, plus Registry and Transaction Events into Holdings.

On 2026-09-11, an append-only `LayerGuard-B4` authority refresh recorded the reviewed terminology
change from `App.Abstractions` to `IFX.BuildingBlocks.Composition`. The refreshed B4 report and graph
retain the original boundary shape: 39 in-scope projects, zero findings and zero baseline entries.
The original Phase 0 hashes remain in the manifest; validators resolve the latest explicitly recorded
authority refresh and reject unrecorded drift.

## Owner and approval semantics

Xiaolong Feng / `@von12549` is the named repository delivery owner for Architecture, Database,
Security, the five module Application areas, Reporting/Data and LayerGuard in this Plan 04 workstream.
This assignment identifies who must drive repository work and route review; it does **not** grant or
substitute for a Database, Security, Reporting/Data, Operations or Architecture approval. Those
functional approvals remain `pending` until their own named, dated evidence exists. Junxi /
`@jimkeecn` remains the recorded backup repository owner where the G03 handoffs apply.

## Scope and non-goals

The only active objectives are GOV4, DP6, DB8 and GOV3. TX6, DB5–DB7, DB12, DP8, DP9, GOV6, OPS2
and OPS5 are explicitly excluded. In particular, this baseline does not authorize a Microservice
split, production RLS, a production reporting product, production SLOs or a game day.

## Completion semantics

- **Design complete** means repository decisions, schemas, fixtures and records exist.
- **Repository governance complete** additionally means source, validators and tests conform to the
  frozen inputs.
- **Production validation complete** requires immutable target-environment runtime, database,
  security, observability and named approval evidence. A repository report cannot produce this state.

## Verification

`scripts/Test-Plan04Phase0Baseline.ps1` recomputes every input hash, validates the exact authority,
owner and scope sets, verifies the B4 strict metrics, enforces the three completion meanings, and
requires every production claim to remain `not-claimed`. Its generated status deliberately reports
Phase 1–8 and named functional approvals as `pending`.
