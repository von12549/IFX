# CP11b V3_backup retirement bridge authorization

This authorization-only checkpoint permits the exact base-owned bridge prepared at `e18894b5` against CP11a base `9add404e`.

The candidate replaces `V3_backup`-dependent protected-change fixtures with the canonical V3 tree, makes manifest fixtures valid in both explicit transition states, and checks consistency between backup presence and the compatibility manifest. It does not change production policy, required checks, workflow behavior or protection scope.

The bridge change must delete `cp11b-v3-backup-bridge-trusted-base.json` in the same diff before becoming the trusted base used to authorize the physical 41-file deletion.
