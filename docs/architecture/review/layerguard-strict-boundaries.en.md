# LayerGuard strict boundary rules (B4)

[中文](layerguard-strict-boundaries.zh-CN.md) · [B4 evidence](evidence/03-b-layerguard-strict-closure.md) · [execution plan](plans/03-layerguard-alignment.md)

## Status and scope

The repository uses the B4 strict policy from 2026-09-09. The Plan 07 scan currently covers 51
governed projects at zero findings and zero waivers; `mcp/LayerGuard/baselines/plan07.json` has no entries.
`docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Architecture` is the shared local and CI entry point. An incomplete scan, missing
or hash-drifted Gate input, a new finding, or a stale/expired baseline fails with a non-zero exit.

LayerGuard judges compile-time structure only: project references, transitive dependencies,
imports, declaration placement, framework/package leakage, ownership, and the provider graph.
G03 catalog/validators and G05 schema/security/runtime tests separately own field classification,
runtime values, tenant/trace propagation, redaction, delivery, idempotency, and replay. A green
result from either side never masks failure on the other.

## Project recognition and target matrix

| Role | Naming | Allowed dependencies |
| --- | --- | --- |
| Domain | `IFX.Modules.*.Domain` | approved Domain primitives |
| Contracts | `IFX.Modules.*.Contracts`, `IFX.Platform.*.Contracts` | BCL and G05-approved contract primitives |
| Application | `IFX.Modules.*.Application` | own Domain and approved BuildingBlocks/Context primitives; Plan 06 removes references to each module's public versioned Contracts |
| Presentation | `IFX.Modules.*.Presentation` | own Application/Domain/Contracts |
| Integration Adapter | separate Integration project or `Infrastructure.Integrations` namespace | own Application Port and G03-registered provider Contracts |
| Infrastructure | module Infrastructure and platform `Infrastructure.*` | own Application/Domain/Contracts and constrained Runtime/platform primitives |
| Client | `IFX.Modules.*.Client` | provider-owned Contracts and constrained Runtime/BuildingBlocks primitives |
| Runtime | `IFX.Platform.*.Runtime` | Contracts and constrained BuildingBlocks primitives |
| Composition | module/platform Composition | its own layers and required platform runtime projects |
| Runtime Host | `IFX.ApiHost`, `IFX.*.Worker` | Composition and approved host primitives |

Ownership comes from the generated view of the authoritative G03 catalog and is bound by
`docs/guards/V3_ifx/stages/post/policy/layerguard.json`. Runtime roles come from G04 artifacts; Context/Messaging primitive admissions
come from G05. Module/platform `*.Abstractions` is no longer recognized as Contracts and remains an
explicitly forbidden project name. Historical `App.Abstractions` is a G01/G04-approved BuildingBlocks
host primitive, not an inter-module Contract compatibility layer.

## Core rules, diagnostics, and repairs

| Rule | Valid example | Invalid example / diagnostic | Repair |
| --- | --- | --- | --- |
| own/foreign | Application → own Domain and approved Platform context primitives | Application → foreign Contracts; Plan 06 also requires zero direct references to its own public versioned Contracts | define consumer ports and provider-owned use cases, bridged to public Contracts by outer adapters |
| Domain isolation | Domain → BuildingBlocks.Domain | Domain → Contracts; `RING-DIRECTION` | keep transport shapes outside domain behavior |
| provider graph | Adapter → catalog-registered provider Contracts | undeclared provider or sync cycle; `PROVIDER-CONTRACT`/`PROVIDER-CYCLE` | correct the design and G03 catalog; never copy an allow-list bypass |
| Adapter declaration | outbound Adapter implements its own Application Port; inbound Adapter implements the provider's own Contract | Adapter in the wrong namespace or implementing the wrong layer/owner; `DECLARATION-NAMESPACE` | place the bridge in an Infrastructure/Integration `Integrations` namespace |
| provider Client | Infrastructure → IAM.Client → IAM.Contracts/Context.Runtime | Application/Domain → Client, or Client → consumer module; `RING-DIRECTION`/`OWNERSHIP-REFERENCE` | keep the consumer-owned Port and let an Infrastructure adapter fix identity before delegating to the Client |
| host boundary | ApiHost → module Composition | ApiHost → Application/Domain; `RING-DIRECTION`/`IMPORT-DIRECTION` | expose a host-safe façade/DTO from Composition |
| Contracts purity | record/DTO using string, Guid, DateTimeOffset | EF/MediatR/ASP.NET/DI/broker/JWT/ILogger; `RING-PACKAGE*`/`SYMBOL-FORBIDDEN` | move behavior and framework adapters outward |
| declaration placement | `*IntegrationEvent` in provider `Contracts.Events` | Handler/Repository/DbContext in Contracts; `DECLARATION-*` | move it to Application or Infrastructure |
| payload boundary | event payload uses approved primitives | payload exposes a Domain entity/DbContext; `PAYLOAD-TYPE-FORBIDDEN` | map to a provider-owned versioned schema |
| context boundary | Contracts use approved BCL-only context | Application uses HttpContext/Activity runtime accessors; `SYMBOL-FORBIDDEN` | create trusted context at ingress and carry it through ports/envelopes |
| legacy naming | `*.Contracts` | new `*.Abstractions`; `PROJECT-NAME-FORBIDDEN` | create Contracts/a Port; do not restore compatibility patterns |

Reports identify the source, target, rule, ownership, direct/transitive path, and repair location.
A transitive leak must be closed at the last leaking hop, not merely hidden by deleting a consumer
import.

## Exceptions and lifecycle

B4 contains no waiver. Any future temporary exception must record owner, risk reason, creation and
expiry dates, and removal criteria, and must stay within G03's 90-day maximum.
`OWNERSHIP-UNKNOWN`, `PAYLOAD-TYPE-FORBIDDEN`, and other unwaivable categories cannot enter a
baseline. Expiry, a ruleset-hash mismatch, or a stale entry all fail the gate. The scheduled CI run
rechecks the policy weekly; dependency-graph changes also require review.

## Check flow and evidence

The sequence is: G03 catalog/source reconciliation → load and hash-verify G03/G04/G05 artifacts →
discover projects and ownership → build direct/transitive project graph → analyze imports,
declarations, and types → apply rules → reconcile the current zero-entry Plan 07 baseline →
publish separate LayerGuard and Gate semantic reports. Historical B4 and Plan 06 evidence remains unchanged.

Diagrams:

- [target dependency and ownership](diagrams/plan03-layerguard-boundary.mmd) · [SVG](diagrams/plan03-layerguard-boundary.svg) · [PNG](diagrams/plan03-layerguard-boundary.png)
- [check flow](diagrams/plan03-layerguard-check-flow.mmd) · [SVG](diagrams/plan03-layerguard-check-flow.svg) · [PNG](diagrams/plan03-layerguard-check-flow.png)
- [migration-to-strict state](diagrams/plan03-layerguard-mode-state.mmd) · [SVG](diagrams/plan03-layerguard-mode-state.svg) · [PNG](diagrams/plan03-layerguard-mode-state.png)

Start new modules from the [compliant structure template](templates/layerguard-module-structure/README.md).

## Local verification

```powershell
pwsh -NoProfile -File docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Architecture
pwsh -NoProfile -File docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode HistoricalIntegrity
```

The first command runs the package-owned LayerGuard tests and current repository scan. The second verifies frozen B4 and Plan 07 evidence hashes, schemas, links, and historical labels.
