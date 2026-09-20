# P11.4 final TCB authorization r7

This authorization-only checkpoint binds candidate `b87beb1c12f60aa8177402e4b0360e20227cddb3` against base `2ded801e9b2d72b1b1b970a69253d3e458160e74` after real PR run `35543003668` exposed that the trusted-base executable scanner read legacy command examples from the closed, non-executable `PRE-LAYOUT CI CONTRACT` comment.

The candidate makes trusted-base executable discovery match the already-reviewed manifest checker rule: it excludes only the exact syntactically closed compatibility comment. A malformed or unclosed block and every executable reference outside the block remain visible and fail closed. The trusted-base suite proves both the positive compatibility case and the negative unregistered-executable case. Production verdicts, command coverage, required-check identities and smoke/full selection remain unchanged. The record covers the complete single P11.4 TCB obligation: 19 components and 753 changed paths.

All earlier P11 final TCB records remain immutable and unconsumed. Only this r7 record is consumed by the final aggregate candidate.

The authorization record cites D35-D38 at their final shared candidate paths; this authorization PR's formal plan cites the corresponding pre-layout decision authorities available to its base-owned validator.
