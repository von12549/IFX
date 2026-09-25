# V4 P10.1 C6c9 — final harness collision repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c8 restored all 191 Windows core cases. The owning compiled-Type suite still
failed because the wrapper passed lineage parameters to the suite and then
blindly appended the same parameters to the suite's producer call. The control
runner completed its 180 capability variants and then collided with
PowerShell's read-only `$Host` automatic variable. These are harness collisions,
not detector or product failures.

## Exact remediation

1. Append Solution/Assembly producer parameters only when the intercepted
   command line does not already contain them.
2. Rename the control runner's local host-path variable without changing any
   command, case or expected outcome.

The repeated Linux package-reference timeout remains fail-closed. The next run
will place certification work/evidence on the separate writable C: workspace
root to reduce contention with the D: source mount; no timeout, capability or
policy changes are authorized.

## Validation and boundary

Formal Pre must precede executable edits. Parser and focused static checks must
prove both collisions are removed. After the implementation and decision are
committed, regenerate C6b0, seven locks, bundle and review and rerun unchanged
C6c5 parallel certification. Passing requires Windows/Linux 191/191 equality,
42 lock controls, 180 capability variants and zero gaps.

Published 1.1.3 bytes, detectors, producers, matrix cases, timeouts, reviewed
capabilities, policies, baselines, waivers and G04 governance remain unchanged.
C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope.

