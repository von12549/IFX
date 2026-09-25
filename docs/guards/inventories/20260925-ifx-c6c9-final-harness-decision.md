# V4 P10.1 C6c9 final harness-collision decision

Decision: `ACCEPTED FOR C6c RE-CERTIFICATION`

Remediation commit evaluated: `84d64501baf1b43c96a1223f272e8c4575119543`

This decision accepts two final harness-only collision repairs. It does not
certify C6c; certification still requires a fresh commit-bound parallel pass.

## Diagnostic result

The C6c8 Windows matrix at
`artifacts/guards/p10-ifx-c6c8/final-certification/e0c09f7da0914d419ed2d937a5141d91/windows/summary.json`
proved all 191 required core cases. Its only remaining gap was the compiled-
Type owning suite: the wrapper correctly supplied mandatory lineage paths to
the suite, then appended the same paths a second time when intercepting the
producer command. Controls completed the 180 capability variants before
PowerShell rejected assignment to its read-only `$Host` automatic variable.

Linux again failed closed on a package-reference timeout during the concurrent
positive run. No timeout, lock lifetime, process allowance, detector or policy
was changed. The next execution uses the separate writable C: workspace root
for certification outputs to reduce contention with the D: source mount.

## Implemented repair

The matrix producer interceptor now appends each lineage parameter only when
that parameter is not already present. The control runner's local executable
path is named `$hostPath`; the invoked command and all expected outcomes are
unchanged.

Both changed scripts pass PowerShell parser validation. Static collision checks
prove both `-cnotcontains` guards and the absence of a `$host` assignment, while
the explicit 42 lock-control and 180 capability-variant assertions remain.
Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c6c9/formal-pre/summary-pre.json`, SHA-256
`8add1cd7c186833cb027537d50fb27e2f4cdb22435237d866f3baf565d7424da`.

Published 1.1.3 bytes, detectors, producers, cases, classifications, reviewed
capabilities, timeouts, policies, baselines, waivers and G04 governance remain
unchanged.

## Remaining boundary

Committing this record changes HEAD, so all earlier locks and candidates remain
diagnostic. Re-certification must regenerate C6b0, seven locks, bundle and
review, then pass Windows/Linux 191/191 semantic equality plus all 42 lock and
180 capability controls. A repeated Linux timeout remains fail-closed.

C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope; G04 remains
`PRE-READY`.
