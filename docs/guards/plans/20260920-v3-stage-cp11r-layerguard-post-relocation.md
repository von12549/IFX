# CP11r — LayerGuard Post ownership relocation

This checkpoint moves the 13 remaining IFX Architecture Conformance solution, binding, bridge-test and fixture files from `templates/ifx-layerguard/` to `stages/post/gates/architecture/dotnet/`. The relative layout inside that tree remains unchanged; solution and project references to the separately owned V3 engine are rebased for the deeper final directory. Runner, command, TCB, trust-contract and documentation references move atomically, using the preceding base-owned dual-layout bridge.
