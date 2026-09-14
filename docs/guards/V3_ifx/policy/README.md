# IFX policy ownership

The files here are the editable, package-local IFX LayerGuard policy and its bound inputs. `layerguard.json` is the architecture rule authority. `g03/catalog.json` is the catalog fact source, `g03/governance.json` its checked projection, `g04/runtime-manifest.json` the runtime binding manifest, `g04/bindings/` its eight local artifacts, and `g05/context-protocol-v1.json` the Context/Messaging dependency policy. The .NET loader validates these relationships and hashes before scanning code.

Change the smallest relevant authority file. If a G03 catalog fact changes, regenerate or update its projection and `catalogSha256`; if a G04 artifact changes, update the corresponding manifest SHA-256. Then run `Invoke-IFX.ps1 -Mode Test`. The strict baseline binds the entire policy graph by composite hash. Review rule changes and findings before updating `baselines/plan05.json`; do not add a waiver or change the hash merely to make a failed check green. Preserve its zero entries unless a separately reviewed migration explicitly introduces a time-bound exception.

All binding paths are relative to this `policy/` directory. The package must remain runnable when the old LayerGuard project and `src/layerguard.json` are absent.
