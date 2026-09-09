# Plan 04 P04-S3 — DP6 Microservice extraction policy

Date: 2026-09-10

Status: repository policy passed; functional approvals pending; no module approved for extraction

## Decision rule

The modular monolith is the default. An assessment can advance only when all seven hard gates pass:
one business owner, one data owner, no shared ACID requirement, versioned protocols, a known
consistency model, an independent security boundary and a named operations owner. A weighted score
ranks review-ready candidates; it has no approval threshold and cannot override a failed hard gate.

Each record must include a current baseline, expected benefit, added operating cost, Contract and data
migration, rollback and a comparable “remain modular monolith” option. Missing rollback or owner data
is a validation failure.

## State and authority

```text
retain <-> observe <-> candidate <-> approved <-> executing -> extracted
```

Every transition has explicit approver roles. Moving from `candidate` to `approved` requires
Architecture, module, Platform, Database, Security and Operations. `executing` additionally requires
Release Operations and the DP8 runtime/resilience plus DP9 package/cadence handoffs. Authentication,
discovery, timeout/retry/circuit-breaker policy, observability/on-call, independent package cadence
and a rehearsed data rollback must exist before execution.

## Automation

- [`microservice-extraction-policy.json`](../../policies/plan04/microservice-extraction-policy.json)
  is the executable policy.
- [`extraction-decision-record.schema.json`](../../policies/plan04/extraction-decision-record.schema.json)
  defines the record surface.
- `tests/Architecture/Plan04/Fixtures` contains one valid synthetic candidate and four negative
  records covering missing owner/evidence, shared ACID despite a high score, missing rollback and an
  illegal state jump.
- [`phase3-extraction-policy-status.json`](phase3-extraction-policy-status.json) records the validator
  result and each fixture's exact expected/actual error set.

The fixture approvals are explicitly synthetic and do not approve Registry or any other module.
The policy's real approvals are all pending, so ME3.8 and Phase 3 remain open and DP8/DP9 are not
triggered.
