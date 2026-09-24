# IFX C6b0 — ordinal module/claim preflight

Status: `SOURCE INVENTORY VERIFIED — C6b1 BUNDLE NOT YET BUILT`

The read-only inventory ran against development commit
`8801f29d3f2309c133690bd649e84f314b4bd176` and the published,
receipted V4 1.1.3 Package hash
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`.
Its machine-readable full ordinal matrix is
`artifacts/guards/p10-ifx-c6b0/inventory-runs/b423b55239cd4e729ab8e1ba007649da/ordinal-inventory.json`
(SHA-256 `61cd8def92e87506c44105d1700a61ecf53312b45be65a8061b720d6688c4eb9`);
the passing summary is in the same directory as `summary.json` (SHA-256
`b7115c869ffeeecd8a481ed04790822f594e4c7a2cd626388f79418c820001a1`).
Each external module's manifest schema, adapter and dependency lock, authority
files, rule plan, Stage and capability ceiling were verified from source
bytes. No candidate or installed Package bytes were edited.

| Stage/source | Modules | Rules | Distinct blocking-capable claims |
| --- | ---: | ---: | ---: |
| C1 Pre | 10 | 25 (22 blocking, 3 advisory) | 22 |
| C1 published built-in and R1b/R2b Post | 3 | 4 blocking | 3 |
| C2–C5 Post | 24 | 54 blocking | 54 |
| Total | 37 | 83 (80 blocking, 3 advisory) | 79 |

The three C1h advisory rules share claim IDs with blocking C1h detectors;
they are not independent waivers or promoted blocking verdicts. The only
repeated canonical rule IDs are `OWNERSHIP-REFERENCE`, `RING-DIRECTION` and
`RING-PACKAGE-FORBIDDEN`, each retained with two distinct claim/module
owners. R2b's two evaluated rule IDs belong to one blocking claim in one
module. The two C1m applicability decisions remain separate from the 79
Profile claims, and their exact decision bytes are hash-bound in the matrix.

The external capability set is read-only and network-denied. Its declared
process ceiling is limited to `pwsh`, `dotnet` and `git` as required by the
individual modules; the published built-in retains its own package-verified
capability declaration. The inventory does not approve execution of every
possible command under that ceiling. G04 remains `PRE-READY` with seven
blockers. G05 Phase 9 and Diff/CI remain P10.3-deferred.

## C6b1 handoff

This source inventory is **not** a combined 37-module Host result, final
manifest, review hash or installation. C6b1 must produce one new
`ifx_profile` draft on 1.1.3, carry forward exact C2e/C3e/C4 configuration
sources, bind the C1 built-in and external configs, refresh and join C4b/C5
and R1/R2 short-lived evidence locks, validate the full Stage graph and
resolve any cross-profile collision without dropping a detector. The R2c
generated-output lock used for C1 R3 expired at 2026-09-24 10:09:52 UTC;
it must be regenerated against the C6 frozen source before acceptance. No
Xiaolong Feng review may be requested until the final bundle's manifest,
complete byte inventory and capability ceiling are frozen and independently
certified.

Formal Pre passed at
`artifacts/guards/p10-ifx-c6b0/formal-pre/summary-pre.json`.
Isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-c3178eefc48b4560a467bb7e5f53fdbf`.
Exact post-commit Formal Diff remains required to close this preflight
tranche.
