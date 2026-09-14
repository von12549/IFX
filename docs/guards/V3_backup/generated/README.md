# Generated output

This directory intentionally contains no .NET project in the source package. After a target profile is configured, `scripts/Invoke-V3.ps1 -Mode Generate` creates `dotnet/` here by default. `Check` verifies its source files against the profile and templates. CI activation remains a separate host-specific step.
