# CP11c — split profile authority layout bridge

This checkpoint introduces a schema-validated profile layout manifest for generic V3 entry points before IFX authorities are physically separated. `ProfileDirectory` remains compatible, while `ProfileLayoutPath` supplies exact repository-relative locations for profile identity, project map, tech stack, rules and generated views.

The two inputs are mutually exclusive. Explicit layouts validate every path under `TargetRoot`, require all authority inputs to exist, and never fall back to the legacy directory convention. The existing directory mode and the new layout mode are exercised against the same fixture; generated gates, architecture review and read-only documentation retain their prior behavior.

This bridge does not move IFX policy, change an active IFX caller, alter CI, or broaden any gate. The next CP11c change will consume the bridge to relocate the four authority groups independently.
