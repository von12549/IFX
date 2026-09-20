# Generated IFX .NET projects

The Stage Gate is generated from the authorities bound by `shared/profile-layout.json` and the canonical V3 C# templates into the untracked external path `<generation-root>/v3-ifx/gates/stage/Ifx.Guards.StageGate.Tests/`. `-Mode Check` byte-checks that runtime tree; no profile snapshot or generated project is committed here.

The Architecture Conformance Gate has no generated copy since Plan 06 P6.1: `scripts/Invoke-IFX.ps1` builds, tests and scans `stages/post/gates/architecture/dotnet/` directly, and fails if `dotnet/LayerGuard/` appears again.

Edit the profile, policy, or canonical template source, then rerun `Generate`; never make durable edits only in runtime output. CI is not activated by generation alone.
