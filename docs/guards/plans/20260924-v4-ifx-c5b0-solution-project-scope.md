# V4 P10.1 C5b0 — Solution test project discovery scope

The controlled V3 Solution Quality probe passed restore, an 81-project
NuGet audit and Release build, but one integration test failed while parsing
a deliberately malformed `.csproj` inside ignored guard test artifacts.
`Plan06DependencyBoundaryTests.Retired_auth_project_tree_is_absent_and_unreferenced`
currently enumerates every `.csproj` under the repository root. That is
broader than the active source project set and makes prior negative fixtures
affect current Solution Quality.

Constrain the test's project-reference scan to `src`, `tests` and `tools`,
still excluding `bin` and `obj`. Keep the retired `src/Modules/Auth` and
solution-entry assertions unchanged. A negative active source project must
still fail; a malformed ignored artifact must no longer be parsed. This is
a scope correction, not a waiver or a claim that Solution Quality passed.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c5b0/formal-pre/pre.json`.
With the pre-existing malformed guard fixture still present, the focused
integration test passed. A temporary `tools/C5ScopeNegative.csproj` referencing
the retired Auth project made the same test fail as intended; it was removed
and the focused test passed again. The negative and recovery TRX records are
`artifacts/guards/p10-ifx-c5b0/c5-scope-negative.trx` and
`artifacts/guards/p10-ifx-c5b0/c5-scope-positive.trx`.

The full controlled V3 Solution Quality gate passed at
`artifacts/guards/p10-ifx-c5b/v3-scope-fixed/quality/summary.json`:
restore, direct/transitive NuGet audit for 81 projects, Release build and
solution tests. The earlier failing 212-case IntegrationTests suite passed.
The isolated package regression passed at
`artifacts/guards/v3-ifx-package-test-3602321e159c4f38b5b2cb46371c7570`.
Exact committed Formal Diff follows.
