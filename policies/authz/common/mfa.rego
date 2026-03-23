package authz.common.mfa

import future.keywords

# True when the subject has completed MFA
mfa_satisfied if {
    input.subject.mfa == true
}
