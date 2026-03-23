package authz.common.network

import future.keywords

# True when request originates from an internal network
internal_network if {
    input.environment.network == "internal"
}

# True when request originates from an external network
external_network if {
    input.environment.network == "external"
}
