# V4 P10.1 C6c8 matrix-fixture isolation decision

Decision: `ACCEPTED FOR C6c RE-CERTIFICATION`

Remediation commit evaluated: `2c2fd1de5ffdf658a40fc29c953fc999f44212bc`

This decision accepts the bounded C6c8 harness repair. It does not certify C6c;
the full C6c5 parallel run must still pass with a fresh inventory, seven locks,
bundle and review bound to the final committed HEAD.

## Fail-closed diagnostic

The first C6c7 parallel attempt remained fail-closed at
`artifacts/guards/p10-ifx-c6c7/final-certification/3990c28cd78543b68bdd628e8b663d5d`.
Windows proved 181/191 core cases. Its only suite failures were the compiled-
Type owning suite, whose mandatory Solution/Assembly parameters were omitted
by the matrix wrapper, and the supplemental suite, whose synthetic lineage
TargetRoot lacked the detached HEAD required by C6c6.

The controls branch stopped when the next module inherited the previous
module's final capability mutation, producing a bundle-file hash drift before
the intended reviewed-ceiling rejection. Linux stopped independently when the
package-reference adapter timed out under the simultaneous workload. No
timeout, lock lifetime, capability, detector or policy was broadened in
response.

## Implemented repair

The independent-matrix wrapper now passes Solution and Assembly lock paths to
any owning suite that declares them. Supplemental synthetic targets contain a
minimal detached `.git/HEAD`; the lineage target is rebound to the candidate
lineage commit, while ordinary fixtures use the current repository commit.
The capability loop restores the tested module manifest after its five
variants, so every next module starts from exact candidate bytes.

Published 1.1.3 bytes, detectors, producers, matrix case definitions,
classifications, reviewed capabilities, timeouts, policies, baselines,
waivers and G04 governance remain unchanged.

## Focused evidence

Formal Pre passed before executable edits at
`artifacts/guards/p10-ifx-c6c8/formal-pre/summary-pre.json`, SHA-256
`1e0733868a55cd2ceb0f47f1b5f68a57421580f5f73e1ee84a8160ea5149348b`.
All three changed PowerShell files passed parser validation. The supplemental
suite then passed all 25 captured Provider, graph, Injection, Source Policy,
History, G04/G05, locked-lineage and Architecture fixtures at
`artifacts/guards/p10-ifx-c6c8/supplemental/eaed3a7bb7134e18a0dc5ce7e5c51691/capture.jsonl`,
SHA-256 `c7493bb1c2ec4b1873eb12e4a01f84caf8ad384ea1c8df6937036da7f4c78fc9`.

## Remaining certification boundary

Committing this decision changes HEAD, so every earlier inventory, lock,
bundle and review remains diagnostic only. Re-certification must regenerate
all inputs and pass the unchanged C6c5 parallel orchestration: native Windows
and pinned offline Linux at 191/191, equal semantic projections, 42 lock
controls and 180 isolated capability variants. A repeated Linux timeout must
remain fail-closed.

C6d/C6e, P10.2/P10.3 and V3 retirement remain out of scope; G04 remains
`PRE-READY`.
