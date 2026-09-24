# V4 P10.1 C1 R2c — generated C# applicability disposition

Status: `EXECUTION PLAN — R2C ONLY; C1 BLOCKED`

R0 observed 175 Release/net8.0 generated C# files but could not prove their
origin or whether in-memory source generators added business syntax omitted
from the C1 Pre scanners. The first controlled `Rebuild` exposed **four**
additional `System.Text.RegularExpressions.Generator` outputs in BuildingBlocks
and Platform Contracts, for 179 files total. Some contain partial IFX types;
the zero-generated-business-syntax hypothesis is false. The frozen V3
`SourceFiles.cs` and C1h source adapter expressly exclude `obj` and `.g.cs`,
so these four are outside the active syntax-only C1 subject set. They are
also outside the CRM Domain source assembly of the R1 compiled type claim.
R2c therefore requires a controlled-output verifier, not an absence claim.

R2c performs a controlled `Rebuild` with
`EmitCompilerGeneratedFiles=true` on the pinned 58-project/81-solution
inventory and .NET SDK 10.0.303. It evaluates all 58 `Analyzer` item lists,
pins each analyzer identity and hash, captures the complete `obj/Release/net8.0`
generated C# set and hashes. It checks 175 SDK metadata shapes and the exact
four RegexGenerator paths and bytes against a frozen expected set, verifies
the V3/C1h exclusion source hashes, and fails on any new generator output,
changed file, custom analyzer or empty subject set. The distinction between
metadata, source-generator output, V3 source applicability and R1 compiled
CRM applicability is recorded explicitly. This is a bounded current-inventory
disposition, not a permanent waiver or an assertion that building enforces
architecture policy.

The controlled output lock binds source tree/commit, C5b Solution evidence,
toolchain, analyzer and generated-file hashes, count and one-hour expiry.
Positive current inventory and synthetic unknown-file, changed RegexGenerator
output, custom-analyzer and zero-subject controls must pass. No V4 runtime, source
project or published 1.1.3 Package is edited. R3 must verify this lock at
final C1 adjudication and invalidate it on any source/project/toolchain drift.
Formal Pre precedes the script; isolated package regression and exact Formal
Diff follow. This tranche alone cannot close C1 or start C6.

## Verification record

The amended Formal Pre passed at
`artifacts/guards/p10-ifx-c1-r2c/formal-pre-amended/summary-pre.json`.
The controlled Release/net8.0 Rebuild and bounded output verifier passed at
`artifacts/guards/p10-ifx-c1-r2c/output-runs/bb28664447064539b175b0ecdc6f8cf2/summary.json`.
The lock binds 58 projects, 118 Analyzer items resolving to four pinned SDK
DLLs, 179 generated C# files, the exact four RegexGenerator outputs, the
frozen V3/C1h generated-source exclusion implementations, the C5b Solution
lock and source tree. Unknown metadata/output, changed RegexGenerator bytes,
custom analyzer and zero-subject controls blocked. This is **not** a claim
that the four generated files contain no business declarations; it is the
bounded disposition that the active syntax scanner explicitly excludes them
and the R1 compiled CRM source is disjoint. R3 must verify the lock before
final adjudication.

The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-8bad2f9c056b410d977b2ca8a727b225`.
Exact Formal Diff follows the scoped commit.
