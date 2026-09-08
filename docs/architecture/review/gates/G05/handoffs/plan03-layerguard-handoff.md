# G05 -> Plan 03 LayerGuard policy-binding handoff

Date: 2026-09-08  
State: `delivered-repository-inputs / pending-03-A1-return`

## Ownership boundary

- Accountable owner: `xiaolong-feng` / `@von12549`.
- Delivery owner: Plan 03 L5.1/L5.2 owner.
- Revisit trigger: 03-A1 policy binding, then each B1/B2/B3/B4 comparison.

## Structural rules to bind

- `IFX.Platform.Context.Contracts` and `IFX.Platform.Messaging.Contracts` remain BCL-only Contracts
  projects with no framework, transport, runtime-composition or module dependency.
- Contract/Event context types use only the G03-admitted primitive set; caller authorization and
  framework types remain forbidden.
- Runtime accessors, HTTP middleware, producer/dispatcher/inbound adapters, telemetry sinks and
  compatibility implementations remain outside Contracts.
- The generated G03 governance input must be consumed directly and its catalog SHA-256 verified. Do
  not copy ownership, provider/consumer or primitive policy into a second LayerGuard configuration.

## Rules that must stay outside LayerGuard

Field classification/purpose/consumer/retention, runtime values, trace validity, tenant membership,
EventId preservation, redaction output and replay behavior remain catalog/schema/runtime/security-test
responsibilities. LayerGuard must link these reports but must not claim semantic coverage.

## Required return evidence

- L5.1 direct catalog consumption and hash verification tests.
- L5.2 Context/Messaging declaration and forbidden-framework rules.
- B1/B4 reports showing no policy bypass and the explicit semantic not-checked list.
- Resolution of G03 `approvalPolicy.backupOwner` before Proposed-to-Active promotion.
