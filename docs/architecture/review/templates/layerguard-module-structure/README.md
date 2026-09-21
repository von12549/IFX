# LayerGuard-compliant module structure template

Replace `ModuleName` with the new module name. Keep public provider schemas in Contracts,
consumer requirements in Application/Ports, provider adapters in Infrastructure/Integrations,
HTTP endpoints in Presentation, and registration only in Composition.

```text
IFX.Modules.ModuleName.Domain
IFX.Modules.ModuleName.Contracts
IFX.Modules.ModuleName.Application
  Ports/
IFX.Modules.ModuleName.Infrastructure
  Integrations/<Provider>/
IFX.Modules.ModuleName.Presentation
IFX.Modules.ModuleName.Composition
```

Rules:

- Domain references only approved domain primitives.
- Contracts are BCL-only except approved Context/Messaging contract primitives.
- Application references its own Domain/Contracts; a foreign capability is represented by an
  Application port.
- Infrastructure implements ports and may consume only catalog-approved provider Contracts.
- Presentation calls Application and never takes DbContext/repository dependencies.
- Composition wires its own module. Runtime hosts reference Composition, not module internals.
- Do not create an `*.Abstractions` project or namespace.

Copy the `.csproj.tmpl` files, substitute `ModuleName`, and add only references permitted by the
matrix. Run `pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Architecture` before committing the scaffold.
