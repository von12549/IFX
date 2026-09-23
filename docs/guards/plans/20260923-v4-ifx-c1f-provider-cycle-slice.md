# V4 P10.1 C1f — provider-cycle candidate

Status: `C1f CANDIDATE SLICE VALIDATED — no production acceptance`

L2.4 binds `PROVIDER-CONTRACT`, `PROVIDER-CYCLE` and
`EMBEDDED-ADAPTER-PROVIDER`. The current IFX `src` contains no project
matching the V3 `IntegrationAdapter` ring patterns, so a zero-finding direct
adapter scan cannot establish non-vacuous coverage. This tranche implements
only the policy-graph `PROVIDER-CYCLE` claim. The sources are the V3 IFX
`layerguard.json` at SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
G03 `governance.json` at SHA-256
`b8f259f02179c48558bd36fd9ccc5f37ce486bbf14f92e9d4c9ada826e4f518c`,
and `L2.4.json` at SHA-256
`cafdf0eb9c8186fbe3f55c22a201a0513a80420bc1f53c504e8f1a5b3fccd12d`.

Freeze G03 `providerContracts` in a hashed candidate policy. Detect directed
cycles case-insensitively using V3's sorted-cycle-key deduplication behavior
(the repeated start node is retained, so rotations can remain distinct);
report each resulting cycle as blocking `PROVIDER-CYCLE` with policy-graph
evidence. Require
at least one provider edge, and fail closed on missing policy, bad config,
hash drift, malformed graph, zero edges or unsafe authority paths. No
TargetRoot project/source discovery, target code execution or V3 runtime
import is authorized. Capability ceiling: read PackageRoot only, write none,
process `pwsh`, network false, timeout 30 seconds.

Fixtures cover the exact clean G03 graph, two-node and longer cycles,
duplicate-path deduplication, zero-edge, missing policy, malformed policy,
config hash drift and TargetRoot byte invariance. Validate V4 manifest,
config/result schemas, G03 authority hash and projection, direct adapter
results, real published 1.1.2 synthetic-only Host Pre, isolated
`ifx-package-test`, unchanged Package hash, Formal Pre before candidate
edits and exact Formal Diff.

This is a policy-cycle candidate only. It does not validate G03 governance
consistency (C2), direct adapter project references, embedded-adapter source
uses, Contracts project cycles, production Profile, bundle review or C1
closure. The empty real IntegrationAdapter project set remains a blocking
coverage question for a later L2.4 tranche, not a pass.

Formal Pre passed before candidate edits. The frozen G03 provider projection,
V3 source hashes, V4 schemas, module hashes and rule execution plan passed.
Eleven direct fixtures passed: clean graph, two- and three-node cycle
rotations, repeated-path deduplication, zero edges, malformed list/provider,
missing/invalid policy, config-hash drift and unsafe authority path; each
preserved TargetRoot bytes. Published 1.1.2 synthetic-test-only composition,
receipt verification and real Host Pre clean execution passed. Evidence:
`artifacts/guards/p10-ifx-c1f/test-runs/ad6cd72a638544ce8eda2e5cf9e64649`.
The isolated IFX package positive and negative regression passed with
explicit NuGet configuration in an approved restore-capable run; evidence:
`artifacts/guards/v3-ifx-package-test-c03660a9ae8b480e8de918803d257f6d`.
The published Package hash remains
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
No provider-reference or embedded-adapter claim is accepted by these checks.
