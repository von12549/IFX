# Guard profile review proposal

This analysis does not change active policy. No rule, owner, command, negative fixture or CI required check is inferred as authoritative. Edit [ARCHITECTURE.md](ARCHITECTURE.md) and [TECHNICAL.md](TECHNICAL.md) as target-specific drafts, then run Invoke-V3Architecture.ps1 -Mode Review to compare their structured blocks with repository evidence and any selected profile.

## Candidate areas

- `mcp/LayerGuard/src`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/ApiHost/IFX.ApiHost`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/BuildingBlocks/IFX.BuildingBlocks.Application`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/BuildingBlocks/IFX.BuildingBlocks.Composition`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/BuildingBlocks/IFX.BuildingBlocks.Domain`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/BuildingBlocks/IFX.BuildingBlocks.EntityFrameworkCore`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/BuildingBlocks/IFX.BuildingBlocks.Security`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/DatabaseMigrator/IFX.DatabaseMigrator`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Modules/CRM`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Modules/Holdings`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Modules/IAM`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Modules/Registry`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Modules/Transaction`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/Authentication`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/Authorization`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/BackgroundJobs`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/Context`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/IFX.Platform.Shared`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/Messaging`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `src/Platform/Notifications`: confirm path boundary, layer, owner, nearby implementation and focused command.
- `tools/IFX.DatabaseInventory`: confirm path boundary, layer, owner, nearby implementation and focused command.

## Review before enforcement

1. Confirm source roots and owners against [inventory.json](inventory.json), repository guidance and maintainers.
2. Choose real build/test commands and risk paths; compare existing architecture gate and CI authority.
3. Specify rule JSON with explicit detector scope and a deliberate negative fixture. Keep unsupported rules advisory.
4. Review the comparison report. Explicitly adopt to a new profile only after confirming the document baseline; then run Validate, Render/Check, Generate/Check/Test and a violating fixture before enabling a required CI check.
