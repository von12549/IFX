# IFX V3 stage profile

`project-map.json` owns Pre path classification, area/owner hints, nearby examples, focused validation command IDs and risk triggers. Keep unknown modules unmapped until their ownership is reviewed. `tech-stack.json` defines each command ID; the Pre runner checks references and suggests commands but does not execute them. `rules/*.json` defines each rule's `appliesTo` paths. Update these files together when the architecture or test layout changes, then run `Validate`, Pre positive/negative fixtures and stage tests.

The [generated Markdown index](views/README.md) links the readable project map, tech stack, each rule, and a V3 stage-only coverage matrix. Profile JSON remains authoritative. The Markdown is read-only: edit JSON, use `Invoke-V3Docs.ps1 -Mode Render`, then `-Mode Check` to catch drift. Human reasoning belongs outside generated `views/`.

All nine LayerGuard numbered rule IDs are automatically associated with matching Plan paths. `L2.2.json` is a narrow blocking project-file detector with a positive and negative fixture. The other eight are `kind: none` and advisory **in the V3 stage runner** because it has no detector for those rule families; they remain blocking in the independent `../../scripts/Invoke-IFX.ps1` post-code architecture gate. `ARCH.SEMANTIC.json` records an uncovered semantic concern. The complete migrated rules are in `../../policy/layerguard.json` and are never imported by the stage profile at runtime.

The map's named owners follow the local `../../policy/g03/governance.json` snapshot. `codeowners` is a routing hint, not proof that a named person approved a change. A new rule may become blocking in this stage runner only after an implemented detector and a violating fixture exist.
