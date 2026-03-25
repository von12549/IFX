package tests.common.abac_eval_test

import future.keywords
import data.authz.common.abac_eval

# ── Helpers ───────────────────────────────────────────────────────────────────

base_subject := {
    "id": "user-1",
    "tenant_id": "tenant-a",
    "departments": ["engineering", "platform"],
    "roles": [],
    "permissions": [],
    "mfa": false
}

base_resource := {
    "type": "document",
    "id": "doc-1",
    "tenant_id": "tenant-a",
    "owner_id": "user-1",
    "departments": ["platform", "security"]
}

make_input(conditions) := {
    "subject": base_subject,
    "resource": base_resource,
    "action": "read",
    "environment": {},
    "conditions": conditions
}

# ── SameDepartment (Intersects) ───────────────────────────────────────────────

test_same_department_passes if {
    inp := make_input([{
        "left": "subject.departments",
        "operator": "intersects",
        "right_type": "field_ref",
        "right": "resource.departments"
    }])
    abac_eval.allow with input as inp
}

test_same_department_denies_when_no_overlap if {
    subject := object.union(base_subject, {"departments": ["finance"]})
    inp := {
        "subject": subject,
        "resource": base_resource,
        "action": "read",
        "environment": {},
        "conditions": [{
            "left": "subject.departments",
            "operator": "intersects",
            "right_type": "field_ref",
            "right": "resource.departments"
        }]
    }
    not abac_eval.allow with input as inp
}

# ── CreatedByMe (Equals) ──────────────────────────────────────────────────────

test_created_by_me_passes if {
    inp := make_input([{
        "left": "subject.id",
        "operator": "equals",
        "right_type": "field_ref",
        "right": "resource.owner_id"
    }])
    abac_eval.allow with input as inp
}

test_created_by_me_denies_other_owner if {
    subject := object.union(base_subject, {"id": "user-99"})
    inp := {
        "subject": subject,
        "resource": base_resource,
        "action": "read",
        "environment": {},
        "conditions": [{
            "left": "subject.id",
            "operator": "equals",
            "right_type": "field_ref",
            "right": "resource.owner_id"
        }]
    }
    not abac_eval.allow with input as inp
}

# ── SameTenant (Equals with literal) ─────────────────────────────────────────

test_same_tenant_passes_field_ref if {
    inp := make_input([{
        "left": "subject.tenant_id",
        "operator": "equals",
        "right_type": "field_ref",
        "right": "resource.tenant_id"
    }])
    abac_eval.allow with input as inp
}

test_same_tenant_passes_literal if {
    inp := make_input([{
        "left": "subject.tenant_id",
        "operator": "equals",
        "right_type": "literal",
        "right": "tenant-a"
    }])
    abac_eval.allow with input as inp
}

test_same_tenant_denies_cross_tenant if {
    resource := object.union(base_resource, {"tenant_id": "tenant-b"})
    inp := {
        "subject": base_subject,
        "resource": resource,
        "action": "read",
        "environment": {},
        "conditions": [{
            "left": "subject.tenant_id",
            "operator": "equals",
            "right_type": "field_ref",
            "right": "resource.tenant_id"
        }]
    }
    not abac_eval.allow with input as inp
}

# ── Empty conditions → deny ───────────────────────────────────────────────────

test_empty_conditions_denies if {
    inp := make_input([])
    not abac_eval.allow with input as inp
}

# ── Multiple conditions — all must pass ───────────────────────────────────────

test_multiple_conditions_all_pass if {
    inp := make_input([
        {
            "left": "subject.tenant_id",
            "operator": "equals",
            "right_type": "field_ref",
            "right": "resource.tenant_id"
        },
        {
            "left": "subject.id",
            "operator": "equals",
            "right_type": "field_ref",
            "right": "resource.owner_id"
        }
    ])
    abac_eval.allow with input as inp
}

test_multiple_conditions_one_fails_denies if {
    resource := object.union(base_resource, {"tenant_id": "tenant-b"})
    inp := {
        "subject": base_subject,
        "resource": resource,
        "action": "read",
        "environment": {},
        "conditions": [
            {
                "left": "subject.tenant_id",
                "operator": "equals",
                "right_type": "field_ref",
                "right": "resource.tenant_id"
            },
            {
                "left": "subject.id",
                "operator": "equals",
                "right_type": "field_ref",
                "right": "resource.owner_id"
            }
        ]
    }
    not abac_eval.allow with input as inp
}

# ── not_equals ────────────────────────────────────────────────────────────────

test_not_equals_passes if {
    inp := make_input([{
        "left": "subject.id",
        "operator": "not_equals",
        "right_type": "literal",
        "right": "user-99"
    }])
    abac_eval.allow with input as inp
}

test_not_equals_denies_when_equal if {
    inp := make_input([{
        "left": "subject.id",
        "operator": "not_equals",
        "right_type": "literal",
        "right": "user-1"
    }])
    not abac_eval.allow with input as inp
}
