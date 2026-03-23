# OPA Authorization Policies

This directory contains the OPA (Open Policy Agent) Rego policies for IFX ABAC authorization.

## Structure

```
policies/
  authz/
    common/           # Reusable cross-cutting rules
      helpers.rego    # Default deny, has_permission helper
      tenant.rego     # same_tenant rule (defense-in-depth tenant isolation)
      mfa.rego        # mfa_satisfied rule
      network.rego    # internal_network / external_network rules
    auth/             # Auth module policies
      read-user.rego  # User profile read authorization
      manage-role.rego
  tests/
    auth/             # Rego unit tests
      read_user_test.rego
  README.md           # This file
```

## Prerequisites

Install the OPA CLI:

```bash
# Windows (winget)
winget install OpenPolicyAgent.OPA

# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/
```

## Running Policy Tests

```bash
# From the repository root — runs all tests
opa test policies/ -v

# Run a specific test file
opa test policies/tests/auth/read_user_test.rego policies/authz/auth/read-user.rego policies/authz/common/ -v
```

## Evaluating a Policy Locally

```bash
# Evaluate the read-user policy with inline input
opa eval \
  -d policies/ \
  -I \
  --format pretty \
  'data.authz.auth.read_user.allow' <<'EOF'
{
  "subject": {
    "id": "user-1",
    "tenant_id": "tenant-a",
    "departments": [],
    "roles": [],
    "permissions": ["users.read"],
    "mfa": false
  },
  "resource": { "type": "user", "id": "user-2", "tenant_id": "tenant-a" },
  "action": "read",
  "environment": { "ip": "127.0.0.1", "network": "internal", "time": "2026-03-23T00:00:00Z" }
}
EOF
```

## Fail-Closed Behavior

OPA is called after the coarse-grained RBAC check passes. If OPA is unreachable:
- `Opa:FailClosed = true` (default) → request is **denied** with 403
- `Opa:FailClosed = false` → request is **allowed** (use only in development)

To run without OPA locally, set `Opa:Enabled = false` in `appsettings.Development.json`.
This switches to `NullOpaPolicyClient` which always allows.

## Adding a New Policy

1. Create `policies/authz/{module}/{resource-action}.rego`
2. Import `data.authz.common.tenant` and add `same_tenant` check
3. Add tests under `policies/tests/{module}/`
4. Call `IResourceAuthorizationService.AuthorizeAsync(permission, "authz/{module}/{resource_action}", resource, action)` in the Application handler
