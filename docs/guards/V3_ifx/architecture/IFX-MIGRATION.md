# IFX LayerGuard migration record

This file records the construction of the independent package. It does not claim parity of future CI runs; that comparison is a separate exercise.

## Input and code ownership

- At migration time `V3_backup` was left unchanged while the IFX fork received the non-vacuous detector and input-safety fixes. Later upgrades synchronize the tested generic V3 source to `V3_backup`; compare its full file set and hashes with `V3` instead of relying on a historical file count. The old production gate was not changed by these package steps.
- `templates/ifx-layerguard/` contains all 173 tracked .NET source, test, fixture, and solution files used by the existing LayerGuard project. Only `GatePolicyBindingTests.cs` was adjusted: it now loads policy from this package while still scanning the target repository's `src`. The other 172 files are byte-identical to their original counterparts at migration time.
- `policy/layerguard.json` is semantically identical to the old LayerGuard policy after normalizing the three `gatePolicies` paths. All nine `ruleRefs` and all rule settings are present. The three paths now resolve to `policy/g03/governance.json`, `policy/g04/runtime-manifest.json`, and `policy/g05/context-protocol-v1.json` inside this directory.
- The G03 catalog, G03 governance projection, G05 context policy, and all eight G04-bound artifacts were copied into `policy/`. The G03 projection source and G04 manifest binding paths were made local and their SHA-256 values recalculated over local LF bytes. The .NET loader still checks catalog projection, runtime bindings, context constraints, and composite hash.
- `policy/baselines/plan05.json` retains a zero-entry strict baseline and uses the new local composite policy hash. A change to any bound policy file invalidates it until someone reviews the changed rules and updates the local baseline explicitly.
- `profiles/ifx/` configures the portable V3 Plan/Pre/Diff runner for IFX and names all nine LayerGuard rule IDs for Agent Plans. The additional `L2.2` project-reference detector has its own violating fixture. The other eight rules are stage-level advisory metadata; the full nine-rule LayerGuard architecture policy is enforced by `Invoke-IFX.ps1`, not approximated by the narrower V3 detector.

## Generated and runtime boundary

`scripts/Invoke-IFX.ps1 -Mode Generate` copies only package-owned templates into `generated/dotnet/LayerGuard/`; `-Mode Check` compares every generated source byte and rejects missing or extra non-build files. `-Mode Test` runs its .NET tests and then the strict target scan. It does not execute a script or read a policy from `mcp/LayerGuard`, `scripts/Invoke-LayerGuard.ps1`, or `src/layerguard.json`. The target's application projects and C# files under `src/` remain the subject of analysis.

The G03/G04/G05 inputs here are snapshots for LayerGuard's policy loader. They do not make the full G03/G04/G05 specialized validators or their behavior tests part of this project. The old independent jobs remain active. No root CI workflow, branch protection, or old gate file was changed by this package migration.

## Migration verification

The generated independent .NET suite passed 190/190 tests and strict scanning of the current IFX `src`; the V3 stage project passed its five detector/Post tests and the generic V3 synthetic positive/negative suite passed. An IFX Plan with all nine architecture rule IDs and a covering synthetic decision passed Pre; omitting `L2.2` from a planned Domain project-file change failed Pre. The repeatable `tests/Test-IFXPackage.ps1` fixture contains only tracked `src` files and `V3_ifx` (no old LayerGuard project or `src/layerguard.json`): it passed 190/190 tests and strict scanning, then made a CRM Domain-to-Contracts reference fail with `L2.2` findings and a G04 binding outside the package fail local input validation. These checks establish that the migrated LayerGuard architecture gate can run without the old gate files. They do not prove the specialized G03/G04/G05 or CI outcomes are equivalent.
