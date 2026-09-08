# LayerGuard evidence

This directory stores immutable architecture-check checkpoints. `B0` records the legacy
0.2.0 capability baseline; `B0.5` records the 03-A0 bootstrap engine and its migration baseline.
These files are evidence, not the formal B1/B4 architecture comparison.

On 2026-09-07, G01 explicitly approved `IFX.BuildingBlocks.Application` as a shared
Application/RuntimeHost dependency. The policy hash and B0.5 migration baseline were regenerated
after review while retaining the same 116 historical findings. The resulting G01 check is
`baseline-clean` with 116 matched, 0 new, and 0 stale findings; see
[`G01-layerguard-policy.md`](../gates/G01/G01-layerguard-policy.md).

`B1-report.json` and `B1-dependency-graph.json` are the formal 03-A1 pre-migration checkpoint.
The B1 report freezes LayerGuard `0.4.0-a1`, the complete target configuration, 12 directly bound
G03/G04/G05 artifacts and their composite hash, 116 historical findings grouped into real
dependency-edge clusters, the G03 90-day waiver policy, explicit semantic exclusions, and runtime
performance. B2/B3/B4 must retain this target policy semantics or record and regenerate an approved
baseline after a policy change.
