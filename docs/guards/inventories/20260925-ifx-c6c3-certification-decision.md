# IFX C6c3 independent certification decision — blocked

Status: `BLOCKED / C6c NOT CERTIFIED`.

The Database clean-commit reproducibility defect remains technically closed by
the separate C6c3a decision. This record does not reopen that result. It records
that the wider C6c independent detector-family and confinement certification
cannot be issued from the evidence produced here. It is not Xiaolong Feng's
accepted review, a release authorization, or an installed Web UI verdict.

Formal Pre passed before implementation at
`artifacts/guards/p10-ifx-c6c3/formal-pre-final/summary-pre.json` (SHA-256
`d796aef4041863cd9cf7e6a6709191f69c52a60740ac3d9827ea746f4725aa6d`).
The independent matrix runner was introduced at `c903f084`, moved its
operational composition roots outside TargetRoot at `ecafcf6e`, normalized
sparse result objects at `a8b45430`, and isolated fixture harnesses from test
function scope and current lock injection at `29f4cd99`. Diagnostic follow-up
at `41f0abfbf1516c268f1721399d3b11cfeccc65c8` separates fixture-only checks
from obsolete Host checks and retains relative controlled-lock paths. Those
post-run diagnostic corrections are not treated as passing certification
evidence.

## Frozen Windows candidate

The last complete source-bound candidate was produced from
`29f4cd99c83b0b73213e012d95a4226c637ef55a`. Its fresh C6b0 inventory passed
with 37 modules, 83 rules, 79 claims, 80 blocking rules and three advisory
rules:

- inventory:
  `artifacts/guards/p10-ifx-c6c3/inventory-runs/67c7ba87a1a445678ff9e6ea2f9a5618/ordinal-inventory.json`
  (`c1d2f182a644f2ae225136d64ca51d4747b9db98a9d235ae59064fc524c2331f`);
- Windows candidate summary:
  `artifacts/guards/p10-ifx-c6c3/windows-candidate-runs/04c880195dd24d2aaf9a62a9e5b1195d/summary.json`
  (`06d7b7b98dd689662e006ae4f09e108ad2d61aa45b6a63328a15c1309e2dc12e`);
- bundle manifest:
  `artifacts/guards/p10-ifx-c6c3/windows-candidate-runs/04c880195dd24d2aaf9a62a9e5b1195d/bundle/bundle-manifest.json`
  (`33247da56126ba28741cf99e1d2430f521e61c7ab353fd202436101659b7f285`);
- synthetic review:
  `artifacts/guards/p10-ifx-c6c3/synthetic-review-final-r4.json`
  (`50ead07d886d539da93e25c61e31da723446b7056d141165a31ce5d431c64dbd`).

The candidate passed direct Pre `10 modules / 22 claims`, direct Post
`27 / 57`, dependency Post `37 / 79`, manifest tamper, baseline injection and
missing-lock negatives. It consumed seven freshly produced locks. Database
again passed 109 boundary tests plus 13 container-backed tests and issued lock
SHA-256 `b984c80edd68d8318c9f7d3308e74d9cfe29b15ecd510f2d66ba275b0c51b3fa`.
The first Solution attempt issued no lock after one integration timing failure;
a fresh RunId then passed all tests and issued lock SHA-256
`da023f8344bdff81e13051b4b2e94db2d33f9b85ce852b9f8d34e6a14c6a6080`.

## Independent Windows matrix result

The complete 36-suite Windows execution finished normally at:

- summary:
  `artifacts/guards/p10-ifx-c6c3/matrix-runs/5ad47f445fe44d86bc095c6cf7df2595/summary.json`
  (`54d5b871bbba4a0c652e4a82b75519ed44aa651dee5ea33472904c25250e3f0c`);
- case manifest:
  `artifacts/guards/p10-ifx-c6c3/matrix-runs/5ad47f445fe44d86bc095c6cf7df2595/case-manifest.json`
  (`3eabb0376afbbfa515890bb46ba6e740425ee733e7612afcdb1674b6a78445d4`).

The fail-closed result is `blocked`: 500 adapter captures proved only 136 of
the required 191 core cases. Proven cases were 34 clean, 33 missing-input,
57 blocking-violation and 12 zero-match cases. The report contains 64 gaps:
23 missing blocking-rule violations, 25 missing zero-match cases, four missing
input cases, three clean cases, one advisory projection, seven suite failures
and the cardinality failure.

Seven suite failures still contained harness compatibility noise. They are not
used to overstate the product gap. After excluding every gap owned by those
seven modules, excluding the seven suite rows and excluding the derived
cardinality row, 37 terminal semantic gaps remain in suites that completed:
11 blocking-rule violations, 21 zero-match cases, three missing-input cases
and two clean cases. Examples include missing zero-match evidence for
`ifx-package-reference`, `ifx-ring-graph`, `ifx-ownership-graph`,
`ifx-injection`, `ifx-g04-manifests`, `ifx-database-evidence` and several G05
modules; missing independent violations include `PROVIDER-CYCLE`,
`CONTRACT-CYCLE`, `ARCH.TYPE_DEPENDENCY`, G04 rules and G05 rules. Therefore
the harness corrections cannot raise this run to the 191-case minimum.

## Decision and required follow-up

C6c is not certified. Linux semantic parity, the complete seven-lock negative
matrix, capability-broadening controls, root-overlap/traversal/link controls
and attempted PackageRoot/TargetRoot write controls were not run after the
Windows core matrix failed. Running them cannot cure the missing Windows core
cases and would not authorize a C6c pass.

A subsequent remediation plan must add independently reviewable fixture bytes
for every missing C/M/Z/V cell without changing detector, module, policy or
published 1.1.3 product bytes; finish the remaining lock/capability/root
controls; regenerate every short-lived lock and the 0.3.0 candidate from the
new implementation commit; and then run the identical case manifest on clean
native Windows and pinned offline Linux. No lock, candidate, matrix result or
synthetic review named in this blocked decision may be reused as passing
evidence.

Exact committed Formal Diff for the declared C6c3 runner and decision paths
passed at `artifacts/guards/p10-ifx-c6c3/formal-diff/summary-diff.json`.

C6d and C6e remain unpassed. G04 remains PRE-READY, and P10.2/P10.3 plus V3
retirement remain out of scope.
