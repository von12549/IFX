# IFX V4 P10.1 C1 final adjudication

Status: `C1 CLOSED for the exact reviewed source snapshot and synthetic 1.1.3 Profile`

The reviewed source snapshot is commit
`23eafae6b157b98e78e1db944cb6652ee4736eaa`; the published base is
1.1.3 (archive SHA-256
`28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`,
Package hash `9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`).
The candidate Profile is synthetic-only, has no baselines and is not a human
bundle review or installation authorization. The final machine-readable
identity/coverage matrix and exact lock hashes are in the R3 summary below.

## Canonical rule ownership

Each row names the authority for an active claim. The three repeated V3 rule
IDs intentionally retain both distinct claim/evidence scopes; the named
primary owns the canonical rule mapping, while the supplementary detector is
still blocking and must pass. They are not merged into a single coverage
number.

| Scope | Canonical rule and claim | Owner |
| --- | --- | --- |
| Direct Domain→Contracts project edge | `RING-DIRECTION` / `IFX.L2.2.DIRECT_DOMAIN_CONTRACTS` | C1b supplementary to C1d |
| Raw ring graph | `RING-DIRECTION` / `IFX.C1.RING_GRAPH_RAW` | C1d primary |
| Raw package allow/deny | `RING-PACKAGE` / `IFX.C1.PACKAGE_ALLOW_RAW`; `RING-PACKAGE-FORBIDDEN` / `IFX.C1.PACKAGE_DENY_RAW` | C1c primary for package references |
| Raw ownership graph | `OWNERSHIP-REFERENCE` / `IFX.C1.OWNERSHIP_GRAPH_RAW` | C1e primary |
| Provider graph | `PROVIDER-CYCLE` / `IFX.C1.PROVIDER_CYCLE` | C1f |
| Embedded adapters | `EMBEDDED-ADAPTER-LOCATION` / `IFX.C1.EMBEDDED_ADAPTER_LOCATION_SOURCE`; `EMBEDDED-ADAPTER-PROVIDER` / `IFX.C1.EMBEDDED_ADAPTER_PROVIDER_SOURCE` | C1g |
| Source imports | `IMPORT-DIRECTION` / `IFX.C1.IMPORT_DIRECTION_SOURCE`; `OWNERSHIP-REFERENCE` / `IFX.C1.IMPORT_OWNERSHIP_SOURCE`; `RING-PACKAGE-FORBIDDEN` / `IFX.C1.IMPORT_PACKAGE_SOURCE` | C1h (ownership/package import supplementary to C1e/C1c) |
| Source declarations | `DECLARATION-NAMESPACE` / `IFX.C1.DECLARATION_NAMESPACE_SOURCE`; `DECLARATION-FORBIDDEN` / `IFX.C1.DECLARATION_FORBIDDEN_SOURCE`; `DECLARATION-PLACEMENT` / `IFX.C1.DECLARATION_PLACEMENT_SOURCE`; `DECLARATION-IMPLEMENTS` / `IFX.C1.DECLARATION_IMPLEMENTS_SOURCE` | C1h |
| Source symbols/payload | `SYMBOL-FORBIDDEN` / `IFX.C1.SYMBOL_FORBIDDEN_SOURCE`; `PAYLOAD-TYPE-FORBIDDEN` / `IFX.C1.PAYLOAD_TYPE_SOURCE` | C1h |
| Forbidden project name | `PROJECT-NAME-FORBIDDEN` / `IFX.C1.PROJECT_NAME_FORBIDDEN` | C1j |
| Raw project reference/cycle | `RING-REFERENCE` / `IFX.C1.RING_REFERENCE_RAW`; `CONTRACT-CYCLE` / `IFX.C1.CONTRACT_CYCLE_RAW` | C1n |
| Forbidden injection syntax and origin | `FORBIDDEN-DEPENDENCY` / `IFX.C1.FORBIDDEN_DEPENDENCY_SOURCE`; `FORBIDDEN-DEPENDENCY-ORIGIN` / `IFX.C1.FORBIDDEN_DEPENDENCY_ORIGIN_SOURCE` | C1o |
| Compiled CRM type dependency | `ARCH.TYPE_DEPENDENCY` / `ARCH.TYPE_DEPENDENCY` | Published built-in, bound by R1b provenance |
| Compiled-type provenance | `C1-COMPILED-TYPE-PROVENANCE` / `IFX.C1.COMPILED_TYPE_PROVENANCE` | R1b Post |
| Evaluated reference/ownership graph | `C1-EVALUATED-RING-REFERENCE`, `C1-EVALUATED-OWNERSHIP` / `IFX.C1.EVALUATED_REFERENCE_GRAPH` | R2b Post; raw Pre retained |

C1h also retains advisory `RING-PACKAGE-IMPORT`,
`DECLARATION-PLACEMENT-ADVISORY` and
`DECLARATION-IMPLEMENTS-ADVISORY` identities. They do not substitute for
their blocking counterparts. `FORBIDDEN-REFERENCE` and `RING-MISSING` are
inactive under the pinned V3 policy and become review-required on drift.

## Bounded applicability and generated inputs

The C1m decision byte hash is
`e3a95670c96992b53438e47c6176ca3c1d6cf111cf4568a90c542cd846218b3d`.
`L2.9=A` is a V3-equivalent structural applicability exception for the exact
58-project inventory, not a detector pass. `IntegrationAdapter=A` is an
exact-inventory zero-subject exception for `PROVIDER-CONTRACT`: the C1k
detector remains fail-closed on zero matches, while C1m checks absence and
blocks project/policy/inventory drift. Neither exception applies to a new
IntegrationAdapter or changed project set without review.

R2c's controlled Rebuild found 179 generated C# files: 175 SDK metadata and
four exact RegexGenerator outputs containing compiled types. The frozen V3
source scanner and C1h adapter exclude `obj`/`.g.cs`; the four files are
outside R1's CRM Domain source. Their paths, hashes, analyzer DLLs and the
exclusion implementations are locked for this source snapshot. New or changed
generated output requires re-adjudication, not a blanket waiver.

## Final evidence and decision

R3 summary:
`artifacts/guards/p10-ifx-c1-r3/test-runs/e5dec30036424e0e89d1f5278b3b70c9/summary.json`
(SHA-256 `9ec0f8fd047f3e2fd8af96849f3d8e1844677e3b1f1e064ee0e9365dea7be159`).
It records 10 Pre and three Post modules, 25 distinct nonzero claims, two
bounded C1m applicability decisions, zero baselines, and three explicit
canonical-ID overlaps with primary/supplementary owners. Direct Pre (10/10),
direct Post (3/3), and dependency Post (13/13) pass with zero findings. The
direct C1k zero-subject control blocks as `findings-blocking`. The C1m drift
suite passes. The R1b and R2b negative suites are hash-pinned by the summary;
they include type/provenance and evaluated-only reference violations. The
prior C1/C2 18-suite result and C5f 24-module result are likewise pinned.

The R3 run binds fresh C5b/C5c, R1b, R2b and R2c locks by exact paths and
SHA-256 values in the summary, checks the short-lived locks at execution,
and verifies PackageRoot and protected TargetRoot/evidence inputs remain
immutable. The R2c lock expires at 2026-09-24 10:09:52 UTC; the conclusion is
about the tested snapshot and does not treat that lock as indefinitely valid.
Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r3/formal-pre/summary-pre.json`, and isolated
package regression passed in
`artifacts/guards/v3-ifx-package-test-fe4a54e1281d4b0eac9df215038e320c`.
The exact post-commit Formal Diff is recorded at
`artifacts/guards/p10-ifx-c1-r3/formal-diff/summary-diff.json` and is a
required condition of this closure.

On those passing checks, C1 is closed only for the stated source snapshot and
synthetic candidate. This is not an approval of a real IFX bundle, a new
published package, or a future changed source tree. C6 has not started.
P10.3 Diff/CI and G05 Phase 9 remain separate deferrals.
