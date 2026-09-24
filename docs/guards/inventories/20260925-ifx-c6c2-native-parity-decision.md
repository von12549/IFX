# IFX C6c2 native parity decision — technical pass, certification pending

Status: TECHNICAL PARITY PASS / C6c NOT CERTIFIED. This is a synthetic
candidate execution record, not Xiaolong Feng's accepted review, a release
authorization, or an installed Web UI verdict. Formal Pre passed before
runner edits at
artifacts/guards/p10-ifx-c6c2/formal-pre/summary-pre.json.

The final candidate is bound to source commit
063f77703a53abcea7ca6aa507b4c4bfa9fc537c and published V4 base
1.1.3, archive SHA-256
28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e.
The C6b0 inventory at
artifacts/guards/p10-ifx-c6c2/inventory-runs/cbcd49e5b4c34d929afcdcf4515a7548/ordinal-inventory.json
(SHA-256 82c3526205536e8ac45fa8e08868139fdff6a39faafe1d449ba31505a5e22207)
contains 37 modules, 83 rules and 79 distinct claims. All seven controlled
Frontend, Database, Solution, Generated, Assembly, Type and Graph locks were
fresh and bound to that commit when the candidate run began. Windows and
pinned offline Linux SDK 10.0.303 evaluated graphs matched exactly on the
commit, 58 projects, project states, 60 input identities, 155 edges and
reference counts.

The frozen bundle contains 256 files with sorted path/hash/size inventory
SHA-256
35b8a2f2177ded757e3d78493e5246ff82125826f1cb4af90e9de4caa42222c8.
Bundle manifest SHA-256 is
86ba48f9a5bd8c82f6ddd897af0900bbe6a1311c816b72c6a681a7b1fc770e91;
Profile SHA-256 is
b647c8fb6df282cca045abcfb97ce37747f81231fff53ca371a13af217b60cd5.
The synthetic-only review fixture SHA-256 is
0288d2b9ba38866e130387df31baaf9c56153d546e28c6f27997f3061406f9c9;
its authority explicitly cannot issue a candidate Host verdict.

Windows report
artifacts/guards/p10-ifx-c6c2/windows-candidate-runs/d4376ef141904e278f968b2e9e044dae/summary.json
(SHA-256 3f16ebdd8b4ff7527b272d3d7c99e7c405667623316a10d1e1366b9050a501b7)
passed direct Pre (10 modules/22 claims), direct Post (27/57) and dependency
Post (37/79), all with nonzero coverage, zero findings and unchanged Package,
tracked TargetRoot and evidence-lock bytes. Manifest tampering, baseline
injection and missing Type lock were blocked.

The exact same bundle bytes passed native Linux direct Pre (10/22), direct
Post (27/57) and dependency Post (37/79), with nonzero coverage, zero
findings and unchanged Package, tracked TargetRoot and locks. The report is
artifacts/guards/p10-ifx-c6c2/linux-candidate-summary-final.json
(SHA-256 0734fc83c2e2883084662649bae1b7ce33514dbae96be9247737ea7b4b2d25ba).
The runner used the previously pinned Ubuntu image
sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773
with network disabled. The unmodified public installer produced a Linux
native 1.1.3 receipt whose id, archive, distribution-manifest and complete
path/hash/size file inventory equal the published Windows receipt. Receipt
bytes differ because absolute installation roots differ.

This round exposed one further Linux fail-closed result before the final
pass. A first candidate on commit 64506b5a67f5f9dd81ab054aa9c774bd11261024
passed Windows but Linux direct Post stopped at Database Evidence with
"Database source tree changed after evidence generation":
artifacts/guards/p10-ifx-c6c2/linux-failure-direct-post.json. The Database
producer includes 540 Git-ignored npm metadata files among its 1,692
source-tree inputs. Native Git clone omitted them. The committed runner now
transports precisely the Database producer's scanned file set and recomputes
the lock's count and SHA-256 before Host. Independent Linux transport
preflight passed with 1,692/1,692 files and equal hash at
artifacts/guards/p10-ifx-c6c2/linux-database-transport-preflight.json.
No published base, Host, module, producer or evidence lock was weakened.
The broad Database source inventory's dependence on ignored npm files should
be reviewed for long-term hermeticity; this run proves only byte-for-byte
reproduction of the current lock.

The isolated IFX Package positive and negative regression passed at
artifacts/guards/v3-ifx-package-test-bc2dd63ea8b5482aa97bbc845d9aa89e.
Exact committed Formal Diff for the four declared source paths is a
post-commit check recorded under
artifacts/guards/p10-ifx-c6c2/formal-diff.

C6c remains blocked on the independent clean, deliberate-violation,
missing-input and zero-match matrix across every detector family, including
the built-in Architecture detector; stale/changed-lock,
capability-overreach and cross-root write controls; and a final fresh
source-bound candidate after those checks. An expired lock or a governance
note commit does not extend the validity of this commit-bound candidate.
G04 remains PRE-READY with seven blockers; G05 Phase 9 and Diff/CI remain
P10.3-deferred. C6d human review and C6e installed Web UI have not begun.
