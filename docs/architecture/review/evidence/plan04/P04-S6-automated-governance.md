# P04-S6 — Automated governance and negative proof

## Result

The unified repository gate passed with the bounded result
`repository-passed-approvals-and-production-not-claimed`.

`Test-Plan04Governance.ps1` executes all six Plan 04 slice validators as
independent checks. It then verifies the frozen LayerGuard B4 graph, G03
catalog, G04 module manifest and Plan 04 decision artifacts against
[`plan04-governance-lock.json`](../../policies/plan04/plan04-governance-lock.json).
Missing files, hash drift, validator exceptions and failed scans cannot produce
a green unified report.

Run locally:

```powershell
./scripts/Test-Plan04Governance.ps1
```

Machine result: [`phase6-governance-status.json`](phase6-governance-status.json).

## Negative proof coverage

The unified boundary fixtures reject:

- an unregistered cross-module edge;
- a dependency cycle;
- an unknown or ownerless module; and
- authority hash drift.

The DP6 fixtures separately reject missing owners, shared ACID, hard-gate score
override, missing rollback and invalid state transitions. DB8 fixtures reject a
missing tenant predicate, nullable/default tenant and ordinary bypass flags.
GOV3 fixtures reject cross-DbContext/table joins, unregistered projections,
duplicate effects, rebuild drift and sensitive-field supersets. Each fixture
records its expected error set, so a validator that stops detecting the intended
failure also fails the test.

## Complementary enforcement

LayerGuard owns project/namespace dependency direction. Dedicated validators own
authority drift, tenant-query semantics and projection lifecycle/registration.
Behaviour tests own authorization, tenant isolation, durable delivery and
idempotent business effects. The unified gate requires all three categories; a
clean LayerGuard result cannot conceal a tenant or projection failure.

The workflow [`plan04-governance.yml`](../../../../../.github/workflows/plan04-governance.yml)
runs the unified gate for pull requests and pushes to `main`, then uploads the
machine reports even when validation fails.

Named functional approvals, production RLS, production reporting and an actual
Microservice extraction remain expressly unclaimed.
