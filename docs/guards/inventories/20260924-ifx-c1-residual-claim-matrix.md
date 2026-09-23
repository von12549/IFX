# IFX C1 residual claims and 1.1.2 base identity — 2026-09-24

Status: `ARCHIVE RECONCILED LOCALLY; C1 NOT COMPLETE`

## Published-base archive reconciliation

The two local ZIPs have the same product filename but different provenance.
The old `artifacts/guards/v4/p7-distribution/out-a/v4-guards-1.1.2.zip`
is 1,069,435 bytes, SHA-256
`9e4c0f553e198a966fc1ea7adf816c2ed10271ac737710edc60dd80682e88685`.
Its embedded distribution manifest names source commit
`86c3cc24ac15881324a54e168fca3a48338914fe` and Package hash
`64a89a698f19d16b16846528fd0a915c09c5e3e6dcd54a668d2b284caf0d4be0`.
Its sidecar agrees with that local ZIP, but **it is not the published 1.1.2**.
It is retained only as historical local C1g build output and must not be
selected as the base of a bundle or installation.

The verified local published-base ZIP is
`artifacts/guards/p10-ifx-c1h/base-reconstruction/v4-guards-1.1.2.zip`:
1,069,199 bytes, SHA-256
`12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95`.
Its manifest names the released source commit
`5bc176f61508fd01ddceb2d4e33ee34136493a35` and Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The local checker `docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1`
passed its sidecar, manifest, ZIP-file hashes, external receipt, all 136
installed-file hashes and installed Package check. The stale `out-a` ZIP was
rejected at the pinned archive digest. This establishes local consistency
with the recorded release identity; it is not a new publication or independent
remote-asset download. The published tag/Release and installed 1.1.2 bytes
were not changed.

For subsequent C1 synthetic Host checks, pass the verified ZIP explicitly
alongside the receipted 1.1.2 installation and receipt. Re-run the checker
immediately before C6 bundle review; do not infer authority from a filename
or a self-consistent sidecar alone.

## Residual C1 matrix

| V3 obligation | Current C1 evidence | Remaining condition |
| --- | --- | --- |
| Raw project reference, package, ring direction and ownership graph | C1b–C1e scoped candidates; C1d/e include direct and transitive raw-project visibility | MSBuild-evaluated/generated reference cross-cover belongs to C5 fresh solution/assembly evidence. No production Profile has selected these candidates. |
| Provider cycle | C1f policy-graph candidate | G03 source governance and provider registration consistency remain C2. |
| Embedded adapter source use | C1g candidate; seven foreign Contracts source uses in real IFX scan | Direct `PROVIDER-CONTRACT` project references remain unimplemented. Current `src` has 58 projects, five module Infrastructure projects, but zero projects matching either configured IntegrationAdapter ring pattern. An empty direct scan cannot count as nonvacuous coverage. |
| Source import, declaration, forbidden symbol and payload | C1h candidate with all nine source claims nonvacuous in the real scan | Candidate still needs complete bundle/stage integration and independent parity; generated sources and compiled cross-cover depend on C5. |
| `L1.2` `PROJECT-NAME-FORBIDDEN` | No direct V4 candidate. Current `src` project names contain zero `*.Abstractions` matches. | Add a scoped project-name predicate with a violating synthetic fixture and nonzero *eligible-project* coverage; do not mistake zero forbidden-name findings for zero inspected projects. Plan04's wider retirement rule remains C4a. |
| `L2.9` `OWNERSHIP-UNKNOWN` | No direct V4 candidate. V3 checks in-scope non-Host/non-Test projects after module-pattern matching and the parent-folder fallback. | Under the required `src` scan root, a project's parent-folder basename is normally nonempty, so a null-owner violating fixture is not constructible without changing the V3 scope or predicate. Record this as an equivalence/coverage decision, not as a passed detector; do not substitute stricter catalog membership without review. |
| `ARCH.BINARY.DOMAIN.CONTRACTS` and evaluated dependency evidence | Published built-in `ARCH.TYPE_DEPENDENCY` is only a candidate predicate; same-source compiled provenance not proved. | C5 must provide fresh trusted build/assembly evidence before C1 can activate or claim this compiled rule. |
| Toolchain and Stage ownership | C1a mapped 11 commands; C1b–C1h are isolated Pre candidates. | C5 must bind seven .NET and two frontend commands plus build freshness. C6 must assemble the final reviewed Profile, stage dependencies and operator practice. |

Next implementation tranche: a separate exact C1j Plan for the `L1.2`
project-name predicate. A later, separately reviewed decision must settle
`L2.9`'s structurally non-triggering fallback before claiming equivalent
coverage. The direct-provider claim must remain fail-closed on the present
zero-IntegrationAdapter subject set unless an explicit, reviewed absence
policy is authorized. C1 cannot be marked done merely because current IFX
has no violating project. The C5 compiled and evaluated evidence prerequisite
is independent and remains open.
