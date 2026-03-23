package authz.common.tenant

import future.keywords

# True when subject and resource belong to the same tenant.
# This is enforced independently of DB-level filtering as defense-in-depth.
same_tenant if {
    input.subject.tenant_id != null
    input.resource.tenant_id != null
    input.subject.tenant_id == input.resource.tenant_id
}
