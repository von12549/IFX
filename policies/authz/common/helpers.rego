package authz.common.helpers

import future.keywords

# Default deny — all policies must explicitly allow
default allow := false

# Check if a permission is present in subject permissions
has_permission(perm) if {
    perm in input.subject.permissions
}
