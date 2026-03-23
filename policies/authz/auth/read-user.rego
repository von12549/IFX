package authz.auth.read_user

import future.keywords
import data.authz.common.tenant

# Default deny
default allow := false

# Allow: reading own profile (self-read)
allow if {
    tenant.same_tenant
    input.subject.id == input.resource.id
}

# Allow: user with 'users.read' permission reading any profile in same tenant
allow if {
    tenant.same_tenant
    "users.read" in input.subject.permissions
}
