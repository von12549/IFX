# IFX C6c0 — dual-platform certification preflight decision

Status: `PREFLIGHT COMPLETE — C6c CERTIFICATION BLOCKED`

Current clean source commit: `1755aea0789d1fbeef94cc49439e32f206c426b9`.
The C6b1 synthetic-review bundle remains frozen at manifest SHA-256
`212e7ac2f6f7a9d146d33989069ac135014223fed0507f70839d985515e51837`
and Profile SHA-256
`6bafbb3d318d28c6ed2d29ec415635788481e6a3c797f8648a78e3731bc7f2f3`.
It is **not** a current-commit, fresh-lock C6c candidate: its one-hour locks
were generated for `05558f8bc6a8a6d1483049f5ebedb3bba216004b`.
The published 1.1.3 archive SHA-256 remains
`28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`;
the receipt matches, and the installed Package check passed with SHA-256
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.

The pinned, network-disabled Ubuntu 24.04.4 LTS container at image digest
`sha256:548d93f8a18a1acbe6cc127bc4f47281430d34a9e35c18afa80a8d6741c2adc3`
passed the approved V4 Linux-complete suite: 33/33 tests, same source commit,
same published Package hash. Its report is
`artifacts/guards/p10-ifx-c6c0/linux-complete-native.json`. The run used a
native Linux anonymous volume for a clean clone, a read-only NuGet cache and
`--network none`; the volume was auto-removed with the container. This is
platform/Product certification, not IFX bundle certification.

Windows-full has **no passing report** on this commit. The main checkout's
first run reached `Test-V4ArchitectureAuthority.ps1` but encountered an old
ignored `invalid-xml` negative fixture in `artifacts/guards` during a
repository-wide synthetic scan. A fresh managed worktree passed that test
and reached `Test-V4TrustedBase.ps1`, where its internal `git clone` checkout
failed on long tracked paths. Repeating from a still-clean worktree via
temporary `Q:` mapping produced the same P6 `Filename too long` result;
`Q:` was removed. This is a Windows Git environment/path limitation, not a
passing Windows-full suite. No test or authority bytes were altered and old
evidence was not deleted.

The existing Linux image contains .NET SDK `10.0.301`, whereas Windows has
`10.0.303` and the C1 R2b evaluated-reference producer requires exactly
`10.0.303`. Direct execution of that producer in the pinned, offline image
failed closed with `Pinned SDK drift` before writing evidence. Neither its
policy nor the lock was weakened. A Linux runner with SDK `10.0.303` and an
exact pinned, offline image identity is required for native re-production;
the released 1.1.3 platform suite's `10.0.301` result does not satisfy this
IFX prerequisite. The C6c cross-platform evaluated-graph comparison and
seven-lock refresh therefore remain unrun.

Required C6c continuation decisions:

1. Provide a Windows certification runner where Git can checkout the long
   tracked paths, or authorize a temporary, restored `core.longpaths=true`
   setting for the invoking user's Git environment, followed by a fresh
   clean-checkout Windows-full rerun. Do not modify the hash-approved test.
2. Supply or authorize preparation of a digest-pinned Linux .NET SDK
   `10.0.303` image and complete offline dependency cache, then rerun
   Linux-complete and natively regenerate the evaluated-reference lock.
3. After both runners are viable, use a separate exact C6c certification
   Plan to refresh all seven locks against one commit, freeze the resulting
   bundle manifest, and execute Windows/Linux clean, deliberate violation,
   missing-input and zero-match cases within the short-lock windows.

Formal Pre passed at `artifacts/guards/p10-ifx-c6c0/formal-pre/summary-pre.json`.
Isolated IFX Package regression passed at
`artifacts/guards/v3-ifx-package-test-4113bebd2fe049aa8d941c54731b536b`.
Exact committed Formal Diff is required after this decision note is committed.
No Xiaolong Feng exact-byte review, receipted operational composition,
installed Web UI practice, G04 closure, P10.2 parity or IFX cutover is claimed.
