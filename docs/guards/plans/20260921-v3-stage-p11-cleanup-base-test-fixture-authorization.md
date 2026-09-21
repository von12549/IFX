# P11.5 base-owned fixture correction authorization

This authorization-only checkpoint permits candidate `b3f684b7be0eb32fe75539833c576c1da50f7e44` to remove the base-owned trusted-component test's incidental dependency on the legacy `V3_ifx/scripts/` directory.

The single generated `change-trusted-base` record covers the complete one-component, one-path TCB change. The candidate must consume the record, pass the base-owned trusted Diff and TCB candidate verifier, and pass all 13 required checks before merge.
