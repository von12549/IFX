# P11.5 cleanup-prep split authorization revocation (D22)

This D22 revocation-only checkpoint deletes the two current trusted-base authorization records for the P11.5 cleanup-preparation candidate and adds only this formal plan pair.

The records are individually exact: `p11-cleanup-prep-trusted-base` binds the original 18 TCB paths, while `p11-cleanup-prep-bridge-scope` binds the subsequent one-path trusted-base runner correction. The base-owned verifier deliberately does not compose `change-trusted-base` records, however. Each such record must declare the complete component set changed by the candidate, so the two records are both rejected when the candidate changes 19 paths across six components.

Authorization records are immutable. This PR therefore revokes both split records. A following authorization-only PR will restore the required `p11-cleanup-prep-trusted-base` ID as one exact record covering all 19 paths and all six components, including both narrow `Validate` behavior allowances.

The trusted Diff must report two revocations, zero protected obligations, and all 13 required checks must pass.
