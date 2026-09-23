# V4 P10.1 C1k — direct IntegrationAdapter provider-reference candidate

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

V3 `L2.4` binds `PROVIDER-CONTRACT` alongside the previously covered
provider-cycle and embedded source-use rules. Port only its direct raw
ProjectReference predicate to a read-only V4 Pre extension. Freeze the IFX
ring and ownership facts from `layerguard.json` SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
G03 `providerContracts` from `governance.json` SHA-256
`b8f259f02179c48558bd36fd9ccc5f37ce486bbf14f92e9d4c9ada826e4f518c`,
`L2.4.json` SHA-256
`cafdf0eb9c8186fbe3f55c22a201a0513a80420bc1f53c504e8f1a5b3fccd12d`,
and V3 `OwnershipRules.cs` source hash. Do not import V3 runtime code.

Enumerate scoped `src` projects, excluding guard/generated subtrees, and
assign V3 ring/module identities with its pattern-then-parent fallback.
For each IntegrationAdapter project, inspect direct XML ProjectReferences
to Contracts projects. A foreign provider absent from the G03 allow-list
emits blocking `PROVIDER-CONTRACT`; own-module and approved providers do not.
Require at least one IntegrationAdapter project as nonvacuous coverage.
The current IFX has none, so its real scan must be a zero-coverage **block**,
not a green result. The module is a candidate implementation; no operational
Profile may select it until the absence condition is explicitly resolved.

Reject missing `src`, malformed XML, unsafe/missing reference targets,
linked paths and authority/config hash drift. Fixtures cover approved,
own, unapproved, outside-ring, missing, zero-adapter, malformed, unsafe,
deterministic and target-byte-invariance cases. Validate V4 contracts,
synthetic-only published Host Pre clean/violation/zero controls, isolated
`ifx-package-test`, Package hash, Formal Pre before executable edits and exact
Formal Diff. Capability ceiling: read PackageRoot/TargetRoot, write none,
process `pwsh`, network false, timeout 30 seconds.

This does not approve a zero-subject waiver, production Profile, bundle,
compiled/evaluated cross-cover or C1 closure. C2 remains responsible for G03
governance validity. Host/built-in changes require the separate compatibility
Plan and 1.1.x patch process.

## Verification record

Formal Pre passed before candidate edits at
`artifacts/guards/p10-ifx-c1k/formal-pre`. The hashed IFX/G03 projections,
V3 implementation, module manifest, schemas and lock passed direct checks.
Nine fixtures passed: approved, own, unapproved, outside ring, missing root,
zero adapter, malformed project, missing reference target and unsafe reference.
Linked-path, hash-drift, deterministic repeat and TargetRoot byte-invariance
controls passed. The real IFX scan found **zero** IntegrationAdapter projects
and returned a blocking coverage finding, not a clean verdict. Synthetic-only
composition and receipt verification against the C1i-verified 1.1.2 base,
then Host Pre approved/unapproved/zero cases, passed. Evidence:
`artifacts/guards/p10-ifx-c1k/test-runs/876e8401fad144faaf833b23b5fac4e5`.
The isolated IFX package positive and negative regression passed, evidence:
`artifacts/guards/v3-ifx-package-test-c50b212e6b1f40c28463ea92b8c170ed`.
The installed base Package hash remains
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
