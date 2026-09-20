# IFX policy authority registry

The editable, package-local IFX LayerGuard policy and its bound inputs are stage-owned under `../stages/post/policy/`. This transitional directory retains only the domain-authority registry and its ownership explanation until the Shared authority relocation checkpoint.

Change the smallest relevant authority file. If a G03 catalog fact changes, regenerate or update its projection and `catalogSha256`; if a G04 artifact changes, update the corresponding manifest SHA-256. Then run `Invoke-IFX.ps1 -Mode Test`. The strict baseline binds the entire policy graph by composite hash. Review rule changes and findings before updating `baselines/plan05.json`; do not add a waiver or change the hash merely to make a failed check green. Preserve its zero entries unless a separately reviewed migration explicitly introduces a time-bound exception.

All projection targets in `authorities.json` are package-relative and point into `stages/post/policy/`. The package must remain runnable when the old LayerGuard project and `src/layerguard.json` are absent.

Every editable policy file under `../stages/post/policy/` is registered in `../shared/policy-config.json` (Plan 06 D24); derived projections are owned by this registry instead. A semantic change of a registered file needs a base `weaken-policy` authorization that the change pull request consumes. A projection must match what the base generator produces from its authority source.
