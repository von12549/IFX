# V4 P10.1 C1a — architecture claim-equivalence design

Status: `C1a DESIGN COMPLETE — exact Formal Diff pending`

Predecessor: C0 inventory at
`docs/guards/inventories/20260923-ifx-v3-gate-inventory.json`, source commit
`851a7b6f4305ca7037aae5533a36c3d43c7da988`. This first C1 tranche
classifies the exact V3 architecture rules and project/toolchain prerequisites
against published V4 1.1.2 capabilities. It does not change any V4 package,
extension bundle, published Release, receipt or installed tree.

## Bounded output

Create `docs/guards/inventories/20260923-ifx-c1a-architecture-mapping.md` with
one row for each of the 11 V3 architecture rule files: source rule and policy
binding, V4 claim/detector candidate, equivalence (exact, subset or missing),
scope and minimum-match gap, Stage/evidence dependency, and intended first
implementation destination. Reconcile the 30 project-map areas, 21 risk
triggers, 11 toolchain commands and the two V3 architecture cross-cover gaps.
Distinguish source-authority ownership from runtime execution capabilities.

In particular, V4's globally configured `ARCH.PROJECT_REFERENCE` and
`ARCH.PACKAGE_REFERENCE` must not be treated as equivalent to V3 ring-, owner-
and provider-scoped policy without a proof. Identify a smallest coherent C1b
implementation subset, its exact prospective files and fixtures, and whether
the public extension contract suffices. If Host/schema/loader changes are
needed, stop and open the separate compatibility Plan required by the parent
program; do not modify the 1.1.2 installed package.

## Validation

Formal Pre before the mapping document, then source-hash checks and exact
Formal Diff over these three documentation paths. Maintain the published V4
Package hash and pass isolated `ifx-package-test`. C1a closes only an
evidence-backed implementation design, not the `v3-architecture` gate.

Formal Pre passed before the mapping was written. A source cross-check found
all 11 rule IDs and hashes, 30 areas, 21 risk IDs, 11 toolchain command IDs
and 12 published V4 architecture claims. The isolated IFX package test passed
its positive and negative cases; V4 Package validation still returns
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The C1b module paths in the matrix are a proposal, not approved `plannedPaths`
or accepted executable bytes. C1b needs a separate exact formal Plan and Pre.
