# V4 P10.1 C1i — published-base identity and residual C1 audit

Status: `BOUNDED C1 CHECKPOINT VALIDATED — C1 STILL OPEN`

The local `artifacts/guards/v4/p7-distribution/out-a/v4-guards-1.1.2.zip`
is a later C1g-source build, not the published 1.1.2 archive. Its valid
sidecar proves only its own bytes. The C1h reconstruction matches the
published release and installed receipt. Do not replace either archive,
relabel the later-source ZIP as a release, or change the installed 1.1.2 tree.

This checkpoint adds a fail-closed local base-identity verifier and a C1
residual-claim matrix. The verifier must pin the released archive digest,
sidecar, source commit, Package hash, installed receipt, complete installed
file inventory and local Package check. It must reject the stale `out-a` ZIP.
Record the exact current hashes and the authority decision in the inventory.

Review C1's remaining direct `PROVIDER-CONTRACT`, `PROJECT-NAME-FORBIDDEN`,
`OWNERSHIP-UNKNOWN`, compiled and MSBuild-evaluated obligations against the
source implementation and current IFX project set. Distinguish an absent
subject from passing coverage. Identify the next exact implementation tranche
and C5 prerequisites. Do not declare C1 complete or compose a production IFX
bundle from this checkpoint.

Formal Pre precedes the verifier and inventory edits. Run the verifier's
positive published-base case and negative stale-archive case, verify the
unchanged V4 Package hash, and run the isolated IFX package regression. An
exact Formal Diff is required before a committed closure. The nine previously
uncommitted PATH repair files remain untouched and outside this Plan.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c1i/formal-pre` before the
verifier and inventory were written. The published-base verifier passed over
the locally reconstructed ZIP and its sidecar, installed receipt, all 136
receipted files and installed Package check. The old `out-a` ZIP failed at
the pinned published archive SHA-256, as intended. The C1 residual matrix
records the still-unimplemented direct project identity/provider predicates
and the C5 compiled/evaluated evidence dependency.

The first isolated `ifx-package-test` attempt could not restore from NuGet
because sandbox socket access was denied (`NU1301`); it never reached test
assertions. The same declared command passed after a controlled network
retry, including positive and negative cases, with evidence under
`artifacts/guards/v3-ifx-package-test-cf23a427184342c58df69bf4848d2d01`.
No Release asset, published tag, installed base or PATH-fix file was changed.
