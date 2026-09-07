# G03 Phase 4 shared Contract primitive policy

The current Messaging Abstractions inventory proves four mixed types and a DI package dependency:
event marker/base plus runtime bus and handler. The target boundary is now frozen in the catalog and
`shared-contract-primitives.md`.

Three Proposed, BCL-only Messaging Contracts primitives are admitted on uniform-infrastructure
grounds: the event marker, immutable V1 envelope, and stable schema identity. Each has a real owner,
four named module users, precise semantics, BCL type allowance, canonical serialization rule,
compatibility rule, and downstream plan reference.

The allowlist denies runtime bus/handler, dispatcher, serializer/broker and DI concerns as well as
Domain, Security, Application, `Result<T>`, EF, MediatR, and ASP.NET types. A seven-step build-green
handoff sequence is supplied to Plans 01/02. Physical project/schema migration remains downstream
and no Proposed primitive is presented as implemented.

Verification: Phase 4 catalog/guard passed; LayerGuard ran 179 tests and remained B0.5
`baseline-clean`; solution build passed with 0 errors; all 904 solution tests passed.
