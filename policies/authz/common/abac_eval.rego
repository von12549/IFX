package authz.common.abac_eval

import future.keywords

# Default deny — explicit allow requires at least one condition that all pass.
default allow := false

# Allow when the input contains at least one condition and every condition passes.
allow if {
    count(input.conditions) > 0
    every condition in input.conditions {
        condition_passes(condition)
    }
}

# ── Operator implementations ──────────────────────────────────────────────────

condition_passes(c) if {
    c.operator == "equals"
    resolve_left(c) == resolve_right(c)
}

condition_passes(c) if {
    c.operator == "not_equals"
    resolve_left(c) != resolve_right(c)
}

# Scalar left is a member of collection right
condition_passes(c) if {
    c.operator == "in"
    resolve_left(c) in resolve_right(c)
}

# Scalar left is NOT a member of collection right
condition_passes(c) if {
    c.operator == "not_in"
    not resolve_left(c) in resolve_right(c)
}

# Collection left contains scalar right
condition_passes(c) if {
    c.operator == "contains"
    resolve_right(c) in resolve_left(c)
}

# Collections left and right share at least one element
condition_passes(c) if {
    c.operator == "intersects"
    some item in resolve_left(c)
    item in resolve_right(c)
}

# ── Field path resolution ─────────────────────────────────────────────────────

# Resolve a "segment.field" dot-path against input.subject or input.resource
resolve_left(c) := resolve_path(c.left)

resolve_right(c) := c.right if { c.right_type == "literal" }
resolve_right(c) := resolve_path(c.right) if { c.right_type == "field_ref" }

resolve_path(path) := input.subject[field] if {
    parts := split(path, ".")
    parts[0] == "subject"
    field := parts[1]
}

resolve_path(path) := input.resource[field] if {
    parts := split(path, ".")
    parts[0] == "resource"
    field := parts[1]
}
