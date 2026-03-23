## Make a plan for the following requirements
## Create a branch for the future implement
## Save the plan before implement
## Analysis the requirements and give some advices

# Refactor the solution to introduce OPA + ABAC authorization without replacing the existing RBAC model.

# Step 0
Goals:
- Keep the current RBAC model (RoleGroup, Role, Permission) as the coarse-grained permission assignment layer.
- Introduce OPA as the policy decision engine for fine-grained ABAC/resource-level authorization.
- Preserve current authentication and RBAC behavior.
- Add the new authorization flow incrementally.

Architecture rules:
- Domain projects must not depend on OPA, Rego, HttpClient, or any infrastructure concerns.
- Resource-level authorization must be performed in Application layer after loading the target resource.
- OPA integration must be implemented as shared cross-cutting infrastructure, not owned by the Auth module.
- ApiHost / Composition should wire the concrete services.
- Fail closed by default if OPA is unavailable for protected operations.

# Step 1
Create a new project under src/BuildingBlocks named:

IFX.BuildingBlocks.Security

This project will host shared cross-cutting authorization primitives and OPA integration.

Create the following folder structure:

Authorization/
  Abstractions/
  Models/
  Opa/
  Exceptions/

Do not move existing Auth domain entities into this project.
Do not place business-specific authorization logic in this project.
This project should contain only reusable authorization contracts, models, exceptions, and OPA infrastructure primitives.

# Step 2
In the shared authorization project, add the following abstractions and models.

Abstractions:
- ICurrentUser
- IPermissionChecker
- IOpaPolicyClient
- IResourceAuthorizationService

Models:
- OpaAuthorizationEnvelope<TResource>
- OpaSubjectAttributes
- OpaEnvironmentAttributes
- OpaResourceAttributesBase
- OpaDecisionResponse
- OpaDecisionResult

Exceptions:
- ForbiddenException

Behavior requirements:

1. ICurrentUser exposes:
- UserId
- TenantId
- Department
- Roles
- Permissions
- MfaEnabled

2. IPermissionChecker checks coarse-grained RBAC permission for the current user.

3. IOpaPolicyClient sends a strongly typed envelope to OPA and returns a normalized decision result.

4. IResourceAuthorizationService performs:
- RBAC permission check
- OPA policy decision
- throws ForbiddenException if authorization fails

The shared OPA input contract must use the canonical top-level fields:
- subject
- resource
- action
- environment

# Step 3
Implement a canonical OPA authorization envelope.

Use this JSON shape as the standard contract:

{
  "subject": {
    "id": "...",
    "tenant_id": "...",
    "department": "...",
    "roles": [],
    "permissions": [],
    "mfa": true
  },
  "resource": {
    "type": "...",
    "id": "...",
    "tenant_id": "...",
    "owner_id": "...",
    "status": "...",
    "sensitivity": "..."
  },
  "action": "...",
  "environment": {
    "network": "...",
    "ip": "...",
    "time": "..."
  }
}

Requirements:
- Use consistent snake_case JSON names in the payload sent to OPA.
- Keep the envelope reusable across modules.
- Allow module-specific resource mapping by composing resource DTOs per module.
- Do not create multiple incompatible authorization payload formats.

# Step 4:
Implement a lightweight OPA client in the shared authorization project.

Create:
- OpaOptions
- OpaClient
- OpaPaths (optional constants helper)

Requirements:
- use HttpClient
- configurable base URL
- configurable timeout
- support cancellation token
- structured logging
- POST to OPA data API with body:
  { "input": <authorization-envelope> }
- return a normalized OpaDecisionResult
- fail closed by default for protected operations

Do not add OPA references to Domain projects.
Do not hardcode business decision paths in the shared client.
Decision paths should be supplied by calling modules or application services.

# Step 5
Integrate the shared authorization abstractions with the existing Auth/RBAC model.

Tasks:
- Add a concrete CurrentUser implementation that maps claims/principal data to ICurrentUser.
- Add a concrete PermissionChecker implementation that resolves the current user's permissions using the existing RBAC model.

Constraints:
- Reuse current Auth application/infrastructure services wherever possible.
- Do not redesign the RoleGroup / Role / Permission domain model.
- Do not duplicate permission resolution logic if it already exists.
- If needed, expose an application query/service from the Auth module that returns resolved permissions for the current user.

# Step 6
Implement a reusable ResourceAuthorizationService in the shared authorization project.

Required flow:
1. Verify coarse-grained RBAC permission using IPermissionChecker.
2. Build the OPA authorization envelope using the current user, action, resource attributes, and environment.
3. Call IOpaPolicyClient with a supplied decision path.
4. Throw ForbiddenException if either RBAC or OPA denies access.

Design constraints:
- This service must not load business resources from the database.
- Resource loading stays in the calling Application layer.
- This service must stay generic and reusable across modules.

# Step 7
Keep the Auth module responsible for:
- users
- role groups
- roles
- permissions
- permission resolution

Do not move fine-grained ABAC resource policies into Auth.Domain.

Do not make the Auth module own the OPA client or shared authorization infrastructure.

Only add integration points from Auth to shared authorization where needed, such as:
- current user mapping
- permission resolution service/query

# Step 8
Create a top-level policies directory at the repository root.

Use this structure:

policies/
  authz/
    common/
      helpers.rego
      tenant.rego
      mfa.rego
      network.rego
    auth/
      read-user.rego
      manage-role.rego
  tests/
    auth/
      read_user_test.rego
      manage_role_test.rego

Constraints:
- Rego files must not be embedded inside Domain projects.
- Do not create one monolithic authz.rego file for the entire solution.
- Organize by module/resource/action and extract common reusable rules into authz/common.

# Step 9
Choose one pilot ABAC use case inside the Auth area.

Recommended pilot examples:
- user profile read: allow if same tenant and either self or admin
- role assignment: allow if same tenant, has base permission, and requester is in allowed department or elevated admin group
- permission management: require base RBAC permission plus stricter OPA checks

Implement the pilot authorization flow in Auth.Application with this sequence:
- load resource
- check RBAC permission
- map resource to OPA input
- call OPA
- continue only on allow

Do not attempt to convert all authorization flows at once.

# Step 10
Refactor the chosen pilot use case so that resource authorization is performed imperatively in Application layer.

Rules:
- [Authorize] attributes may remain for authentication or entry-level policies.
- Resource-level authorization must happen after the resource is loaded.
- The handler/application service must call the shared resource authorization service.

Do not rely on controller attributes alone for resource authorization.
Do not place OPA calls in controllers if the resource must be loaded by Application services.

# Step 11
Wire all shared authorization services in ApiHost or the Composition layer.

Register:
- ICurrentUser
- IPermissionChecker
- IOpaPolicyClient
- IResourceAuthorizationService
- OpaOptions

Ensure the dependency graph remains clean:
- Domain does not depend on shared OPA infrastructure
- Application depends only on abstractions
- concrete implementations are wired in Composition / ApiHost / Infrastructure

Do not introduce circular references.

# Step 12
Add local OPA runtime support for development.

Create:
- deploy/opa/config.yaml
- docker-compose integration for ApiHost + OPA

Requirements:
- ApiHost can call OPA by configured base URL
- OPA runs as a sidecar-style companion service
- Keep deployment assets outside Domain projects

# Step 13
Add initial policy engineering support.

Tasks:
- add example Rego tests under policies/tests
- add README or developer notes explaining how to run policy tests
- prepare placeholders or configuration for decision logging
- document fail-closed behavior

Do not over-engineer this phase, but establish the basic structure for future policy lifecycle management.