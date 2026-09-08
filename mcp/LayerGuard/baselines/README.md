# LayerGuard migration baselines

Baseline entries suppress only an exact historical finding fingerprint. Every entry must name
an owner, reason, creation date, expiry date, and removal criteria. Missing metadata, duplicate
fingerprints, expired entries, and any finding absent from the baseline fail the check.

`b0.5.json` preserves the 03-A0 bootstrap snapshot and is not the formal comparison baseline.
`b1.json` is the 03-A1 pre-migration baseline. Its hash covers `src/layerguard.json` plus every
bound G03/G04/G05 artifact, and its entries are constrained by the G03 maximum lifetime and
unwaivable categories. B2/B3/B4 must reuse the same target policy semantics.
