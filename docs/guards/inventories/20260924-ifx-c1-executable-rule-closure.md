# IFX C1 — executable V3 architecture rule closure audit

Status: `C1 INCOMPLETE — FOUR ADDITIONAL ACTIVE RULE FAMILIES IDENTIFIED`

Source checkpoint: `Analyzer.cs` SHA-256
`a028869bacb3927e4cf30f1816b855f747a2289206bf11ea9ca91cd3e7240e15`,
`Cli.cs` SHA-256
`6477d6b257dee26a440a890d9c6f4ab5f0690e20877831133e7733b404c18568`,
IFX `layerguard.json` SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`.
The Analyzer calls `ReferenceRules.Named`, `InjectionRules.For` and
`OwnershipRules.Graph` independently of the nine numbered `ruleRefs`.
It counts every resulting violation. CLI `check` exits nonzero for an
unbaselined violation, or for new/stale baseline findings; a null numbered
rule `Ref` does not make the finding non-executable.

| Executable rule | IFX policy activation | C1 destination and state |
| --- | --- | --- |
| `RING-DIRECTION`, `OWNERSHIP-REFERENCE`, `RING-PACKAGE`, `RING-PACKAGE-FORBIDDEN`, `RING-PACKAGE-IMPORT`, `IMPORT-DIRECTION` | Ring, graph, package and source facts populated | Bounded C1b–C1e/C1h candidates exist; raw versus evaluated/compiled cross-cover remains C5. |
| `DECLARATION-NAMESPACE`, `DECLARATION-FORBIDDEN`, `DECLARATION-PLACEMENT`, `DECLARATION-IMPLEMENTS`, `SYMBOL-FORBIDDEN`, `PAYLOAD-TYPE-FORBIDDEN` | Source-policy facts populated | C1h source candidate exists; generated/compiled cross-cover remains C5. |
| `PROVIDER-CYCLE`, `EMBEDDED-ADAPTER-LOCATION`, `EMBEDDED-ADAPTER-PROVIDER` | G03/provider facts populated | C1f/g candidates exist; G03 governance validity remains C2. |
| `PROJECT-NAME-FORBIDDEN` | `forbiddenProjectNames=["*.Abstractions"]` | C1j candidate exists; 51 in-scope real projects, zero findings. Out-of-ring Abstractions names are outside this V3 predicate; Plan04's wider retirement check is C4a. |
| `PROVIDER-CONTRACT` | IntegrationAdapter ring and G03 provider map populated | C1k direct-reference candidate exists and synthetic controls pass. C1m records an exact-58-project zero-subject applicability exception, with a verifier that blocks project/inventory drift or any new IntegrationAdapter project. C1k itself still blocks a direct zero-subject run; C6 must bind and review the exception before Profile use. |
| `OWNERSHIP-UNKNOWN` | `ownership.requireKnown=true` | C1m records the user-selected V3-equivalent applicability exception: parent-folder fallback makes null ownership structurally unreachable for the frozen `src` inventory. It is not a detector pass or a strengthened ownership rule; source, policy or scope drift requires re-review. |
| `RING-REFERENCE` | `allowedReferences` names ten ring lists, including an explicitly empty Contracts list | C1n raw direct-reference candidate exists. It preserves shared-primitive and already-forbidden-direction exceptions; 13 fixture cases and synthetic published-Host Pre controls passed. Real IFX scan covered 147 direct references with zero findings. MSBuild-evaluated reference cross-cover remains C5. |
| **`FORBIDDEN-DEPENDENCY`** | Presentation forbids parameter type names `I*Repository` and `*DbContext` | **Missing.** `InjectionRules.For` inspects constructor, primary-constructor and method parameter type syntax. Next source candidate needs exact name/generic/nullable/member-kind and zero-match fixtures. |
| **`FORBIDDEN-DEPENDENCY-ORIGIN`** | Application forbids parameter type names declared in Infrastructure, except same-ring declaration | **Missing.** Requires a cross-project declaration index, origin and same-ring exception fixtures, plus nonvacuous coverage. C1h has an index for different claims, but does not judge injection origins. |
| `CONTRACT-CYCLE` | `OwnershipRules.Graph` calls Contracts-cycle detection unconditionally | C1n Contracts-only direct-graph candidate exists with clean, two-/multi-node cycle, missing and zero-project controls. Real IFX scan covered ten Contracts projects with zero cycles. Provider-policy cycles in C1f remain a separate claim. |
| `FORBIDDEN-REFERENCE` | No effective `forbiddenReferences` entry in the IFX policy | Inactive in this policy checkpoint; record hash drift if it becomes configured. |
| `RING-MISSING` | `requireRings=false` | Inactive by policy; do not claim active coverage or silently enable the stricter structure rule. |

The two bold rows remain blocking implementation gaps not captured by a
numbered-`ruleRefs`-only inventory. C1o should cover syntax-injection and
declaration-origin checks, with an exact child Plan, Formal Pre and
source-hash/fixture/Host tests.
No production Profile may silently treat C1k's direct zero-subject block as
a pass. C1m's two decisions are bounded applicability records; C6 must bind
their exact bytes and revalidate the frozen inventory before composition.
Even after the two missing rule candidates, C1 closure still depends on C5
fresh compiled/MSBuild-evaluated evidence. C2/C6 must later govern and
compose the complete Profile; none of those steps is authorized by this audit.
