# V4 P10.1 C1h — scoped source-policy candidate

Status: `AUTHORIZED IMPLEMENTATION TRANCHE — candidate only`

C1b–C1g cover selected project/graph predicates and the embedded adapter
source-use predicate. This tranche covers the remaining V3 source import,
declaration, forbidden-symbol and payload families in one read-only V4 Pre
extension. It is limited to `src` and nearest-project ownership, excludes
generated and guard subtrees, and parses C# with the published V4 Roslyn
dependency pattern. It does not import or execute V3 runtime code.

The exact V3 authorities are IFX `layerguard.json` SHA-256
`b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`,
G03 `governance.json` SHA-256
`b8f259f02179c48558bd36fd9ccc5f37ce486bbf14f92e9d4c9ada826e4f518c`,
and the semantic implementations `ImportRules.cs`, `SourcePolicyRules.cs`,
`DeclarationRules.cs`, `DeclarationIndex.cs` and `SourceFiles.cs`, hashed in
the candidate policy. Bound rule files L2.2, L2.3, L3.1, L3.4, L3.5, L3.6
and ARCH.SEMANTIC are hashed there as well. Freeze only the fields used by these predicates and
assert exact projection in tests.

Implement the active and disabled-preprocessor `using` checks, including
longest loaded project-prefix resolution, direction, ownership, forbidden
package first, and ring package allow-list. Declaration checks must use the
V3 type-name/kind/exception/namespace predicates and a cross-project simple
name index for `mustImplement`. Preserve the V3 distinction between the
general declaration placement/implements family and the IFX declaration
namespace family. `SYMBOL-FORBIDDEN` comprises forbidden using namespaces,
outermost Roslyn `NameSyntax` symbols, and literal value text. Payload checks
look only at member type syntax directly parented by parameter, property or
field nodes for matching declaration names. Use deterministic findings and
per-claim nonvacuous coverage; a zero-match claim blocks rather than
appearing clean. No target code, restore, network or writes under TargetRoot
or PackageRoot; capabilities read PackageRoot/TargetRoot, processes pwsh and
dotnet, 180-second timeout. The larger ceiling is explicit because the real
IFX source tree has more than 1,000 C# files and the extension must also
build a declaration index without a target build.

Fixture matrix: clean and each violation, inactive import, longest-prefix
and unscoped-project exceptions, declaration kind/exception and cross-project
index, forbidden symbol/namespace/literal, allowed/forbidden payload types,
nearest-project and guard/generated exclusions, malformed/missing/zero source,
unsafe link, hash drift and deterministic repeat. Verify schema/authority
hashes, byte invariance, real IFX scan, published 1.1.2 synthetic Host Pre,
isolated `ifx-package-test`, unchanged base Package hash and exact Formal
Pre/Diff. Any real IFX findings are reported, not silently baselined.

This candidate does not accept a production Profile or bundle and does not
close C1. Compiled and MSBuild-evaluated claims still depend on C5; direct
IntegrationAdapter-project coverage remains separately unresolved.

## Verification and base-archive note

Formal Pre passed before candidate module edits. The direct candidate suite
checks the frozen V3/G03 projections, 24 synthetic cases, deterministic repeat,
unsafe link and hash drift, and TargetRoot byte invariance. A real IFX scan
found no violations with all nine claims nonvacuous: project import 641,
ownership import 624, package import 739, declaration namespace 33,
Contracts declaration scope 64, general declaration placement 250,
implements 33, forbidden-symbol source scope 474 and payload member type 63.
This is a bounded source scan, not a parity or C1 verdict.

The original `artifacts/guards/v4/p7-distribution/out-a` ZIP currently hashes
to `9e4c0f553e198a966fc1ea7adf816c2ed10271ac737710edc60dd80682e88685`,
which does not equal the published 1.1.2 installation receipt's archive hash.
It was not modified or used for composition. The installed 1.1.2 Package,
Host and companion were independently repackaged with their receipted source
commit by the installed deterministic distribution script into
`artifacts/guards/p10-ifx-c1h/base-reconstruction`; the reconstructed ZIP
hashes to the receipted
`12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95`,
with Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The mismatch at the older artifact path remains an external-state issue to
resolve before any final bundle review; reconstruction is test evidence, not
new publication.

The isolated IFX package positive and negative regression passed with the
repository NuGet configuration; evidence:
`artifacts/guards/v3-ifx-package-test-713228fd2935436087ed1cf4497b6365`.
The final candidate run passed 24 direct fixtures, the real IFX scan, and
synthetic-only published Host composition/receipt verification with nine Pre
cases including blocking, advisory and zero-match outcomes. Evidence:
`artifacts/guards/p10-ifx-c1h/test-runs/a7661efad8a34a56beed3d67eeb29635`.
