# P11 activation trusted-base authorization

This authorization binds the separately prepared activation commit `076a2b58` to base `61de7200`. It covers exactly the two activated targets and their canonical workflow template across `tcb.activation.ci` and `tcb.manifest`.

The rendered workflow body, all 13 required checks, trigger and Windows coverage semantics, and CODEOWNERS rule lines are unchanged. The later activation PR must delete this record while introducing exactly the recorded blobs.
