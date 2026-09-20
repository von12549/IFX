# CP11c — profile authority split

This checkpoint consumes the profile-layout bridge and physically assigns IFX profile identity and toolchain to Shared, project/risk mapping to Pre, and stage rules to Post. The generated Markdown views remain under `profiles/ifx/views/` as the P8 read-only compatibility location; `shared/profile-layout.json` is the only active binding between those authorities and generic V3 commands.

All active callers, candidate validators, protected-change fixtures, manifests, authored guidance and generated views move in the same change. No legacy internal data fallback is retained. `ProfileRepositoryRoot` is explicit for package/target separation and defaults to `TargetRoot` for ordinary repositories.

The move preserves JSON authority bytes except for the compiled-rule authority path, which now names its Post location. The corresponding reviewed architecture evidence and generated views are updated deterministically. CI activation, required checks and remote settings are unchanged.
