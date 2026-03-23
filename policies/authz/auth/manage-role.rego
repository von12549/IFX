package authz.auth.manage_role

import future.keywords
import data.authz.common.tenant

# Default deny
default allow := false

# Allow: user with 'roles.manage' permission operating on a role in the same tenant
allow if {
    tenant.same_tenant
    "roles.manage" in input.subject.permissions
}
