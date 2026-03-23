package authz.auth.read_user_test

import future.keywords
import data.authz.auth.read_user

# ---------------------------------------------------------------------------
# Shared test fixtures
# ---------------------------------------------------------------------------

tenant_a := "00000000-0000-0000-0000-000000000001"
tenant_b := "00000000-0000-0000-0000-000000000002"
user_id  := "00000000-0000-0000-0000-000000000010"
other_id := "00000000-0000-0000-0000-000000000011"

base_subject := {
    "id": user_id,
    "tenant_id": tenant_a,
    "departments": [],
    "roles": [],
    "permissions": [],
    "mfa": false,
}

base_resource := {
    "type": "user",
    "id": user_id,
    "tenant_id": tenant_a,
}

base_env := {
    "ip": "127.0.0.1",
    "network": "internal",
    "time": "2026-03-23T00:00:00Z",
}

# ---------------------------------------------------------------------------
# Test: self-read is allowed
# ---------------------------------------------------------------------------
test_self_read_allowed if {
    read_user.allow with input as {
        "subject": base_subject,
        "resource": base_resource,
        "action": "read",
        "environment": base_env,
    }
}

# ---------------------------------------------------------------------------
# Test: user with users.read permission can read any profile in same tenant
# ---------------------------------------------------------------------------
test_admin_read_allowed if {
    read_user.allow with input as {
        "subject": object.union(base_subject, {"id": other_id, "permissions": ["users.read"]}),
        "resource": base_resource,
        "action": "read",
        "environment": base_env,
    }
}

# ---------------------------------------------------------------------------
# Test: cross-tenant read is denied (even if self)
# ---------------------------------------------------------------------------
test_cross_tenant_denied if {
    not read_user.allow with input as {
        "subject": object.union(base_subject, {"tenant_id": tenant_b}),
        "resource": base_resource,
        "action": "read",
        "environment": base_env,
    }
}

# ---------------------------------------------------------------------------
# Test: no permission and not self is denied
# ---------------------------------------------------------------------------
test_no_permission_not_self_denied if {
    not read_user.allow with input as {
        "subject": object.union(base_subject, {"id": other_id}),
        "resource": base_resource,
        "action": "read",
        "environment": base_env,
    }
}

# ---------------------------------------------------------------------------
# Test: missing permissions field still denied for non-self
# ---------------------------------------------------------------------------
test_missing_permissions_denied if {
    not read_user.allow with input as {
        "subject": {"id": other_id, "tenant_id": tenant_a, "departments": [], "roles": [], "mfa": false},
        "resource": base_resource,
        "action": "read",
        "environment": base_env,
    }
}
