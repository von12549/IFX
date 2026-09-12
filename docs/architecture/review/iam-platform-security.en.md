# IAM and platform security: implemented architecture

Plan 05 repository implementation, 2026-09-12. Production rollout, target data audit and live IdP validation remain pending. [中文及调用图](iam-platform-security.zh-CN.md) · [Phase evidence](evidence/plan05/README.md).

## Ownership and flow

Auth is now one IAM module with Domain, Application, Infrastructure, Presentation, Composition and Contracts projects. Identity owns trusted IdPs, issuer/subject binding, local admission and login/provisioning orchestration. Users owns profiles and activation. Access owns roles, permissions, assignments and RBAC/ABAC policy composition. Tenancy owns tenants, departments and membership invariants. These remain one IAM transaction boundary.

Platform.Authentication has Contracts, Runtime, Cognito/Auth0 adapters and Composition. It executes token verification and OIDC/PKCE, not local admission or tenant membership. Platform.Authorization has Contracts, Runtime, an OPA adapter and Composition. It validates bounded facts/conditions and normalizes Allow/Deny/Indeterminate without reading module databases or defining role privileges.

Applications define their own ports; infrastructure adapters consume foreign Contracts. IAM Composition owns platform registration for API and Worker. CRM, Registry, Holdings and Transaction supply resource facts and own restricted queries, enforcement and domain invariants. An allowed list operation does not authorize every row. BuildingBlocks.Security retains only ICurrentUser, IPermissionChecker and ForbiddenException. The [generated graph](evidence/plan05/current-dependency-graph.json) records actual project dependencies.

HTTP flows through external verification, current IAM trust/local admission and trusted execution context. HTTP and trusted User worker contexts then share current IAM facts. Business ports call IAM Access for mandatory constraints, RBAC and selected policies, which use Platform.Authorization/OPA for evaluation. The resource owner enforces the result and its domain rules.

## Security semantics

Token validation checks issuer, audience, algorithm, signature and lifetime. OIDC uses request-bound, one-use state, nonce and PKCE, with matching UserInfo subject. IAM requires a currently enabled trusted IdP and active local user; equal email addresses do not merge issuer/subject identities. External role/tenant/permission claims do not establish local grants.

VerifiedIdentityFacts is the sole production execution-facts implementation. Each authorization gate refreshes IAM user, membership and grants. User/tenant deactivation, membership removal and role revocation affect the next check despite an existing token/context; already-running work is not immediately cancelled. Anonymous HTTP cannot fall back to worker identity. Invalid actor, type, tenant, source, provenance or missing context fails closed.

Tenant authorization requires active user and membership, matching execution/resource tenant, then RBAC and applicable ABAC. Explicit self-read still receives applicable ABAC checks. Platform roles have a separate scope: PlatformAdmin receives explicit grants for known operations; other roles need named grants and all applicable role policies. Platform roles never imply tenant membership. Cross-tenant inventory retains Platform.GlobalRole:manage, currently granted to PlatformAdmin in platform scope.

Policy semantics v2 distinguish mandatory code constraints, documented defaults, tenant policies and platform role policies. Missing, disabled, invalid and unavailable states are distinct. Disabled policies, missing parameters, DB/OPA errors and unknown input never widen access; disabling OPA or using the legacy FailClosed=false option does not allow access. Tenant editors cannot remove mandatory constraints. Policy versions derive from current content/scope; no cross-request policy/decision cache needs invalidation broadcasting.

Contracts expose bounded facts and conditions, not entities, IQueryable, HttpContext or SDK/OPA types. Credentials/tokens are restricted transient authentication fields, excluded from durable messages, jobs and logs. OPA logging records decision identifiers, version, outcome and reason, not input facts or parameters.

## Data and compatibility

IAM retains IfxDbContext, auth schema, AuthDatabase and auth.__EFMigrationsHistory. UserTenants remains the unique membership source with its composite key. Ordinary role/group/department assignments require matching tenant membership; group roles must match the group tenant. UserGlobalRoles remains independent. PrimaryTenantId is a nullable membership-constrained preference.

Migration 20260912101127_EnforceActiveTenantMembership adds Tenants.IsActive, defaulting existing rows to true. Active membership requires active user and tenant. No membership is inferred from orphan grants and no policies are automatically rewritten. Serializable IAM writes plus post-write/pre-commit checks protect assignments and membership together. Tenant exit atomically removes its grants and primary preference, retaining other tenants and platform grants. Transaction conflicts require whole-use-case retry.

Original API /api/v1/auth, configuration keys and logical Auth identity remain stable. An exact persisted cleanup-job alias resolves Auth to IAM and tests execute the restored method with preserved arguments. Unknown aliases fail. See the [compatibility inventory](evidence/plan05/compatibility-identifiers.json); queued, retrying and future scheduled target jobs still need inventory.

## Release and rollback

Run the read-only membership/policy audits in scripts/sql against the target and retain counts/findings. Resolve ambiguity without inferred grants. Generate Release migration artifacts and verify manifest/hash and five model snapshots. Establish consumer compatibility before rollout: controlled Migrator apply/validate, compatible Worker, then API/readiness and traffic. An unmodified older manifest rejects the additional migration; a schema allowlist alone cannot establish semantic compatibility.

Code rollback requires compatible schema, Contracts and job types. Isolated database Down/reapply is tested only without new state and preserves membership rows. Behavior rollback must not restore stale-claim authorization, global-role bypass or OPA failure allowance. Dropping IsActive after tenant deactivation loses deny state: retain schema/denial and fix forward. Production automatic Down is not authorized by these tests.

Real SQL tests cover upgrade, repeat application, readiness before/after expansion, isolated structural rollback and the unsafe old membership-only read. Existing controlled Migrator tests cover five owners and recovery; API/Worker composition and old-job invocation are automated. Actual older target binaries, rolling deployment, restore timing and operational sign-off were not exercised.

## Remaining validation

OIDC transactions are process-local; multi-instance failover needs session affinity or shared storage. The inherited Auth0 password-login path is unimplemented; live Cognito/Auth0 validation is pending. Bearer admission propagates verified issuer/subject without claiming complete MFA propagation. Two new authorization protocols remain G03 Proposed; repository gates do not grant named admission approval. Target data audit, job inventory, DB permissions/RLS, capacity/SLO and rollout/rollback sign-off remain external work.

The separate [Platform discussion](platform-capabilities-and-tenant-connections.zh-CN.md) remains a proposal. A connection center, tenant-owned provider credentials, separate Tenancy/AccessControl modules and tenant-owned OPA were not implemented here.
