# CP11a — maintenance tool relocation

This checkpoint is the first physical-migration group in Plan 06 P10. It moves the internal policy projection tool from `scripts/` and the history manifest regenerator from `history/` into `maintenance/`. Internal paths receive no wrapper: every live repository caller and command/TCB manifest is updated in the same change.

The policy tool replaces mutating `Generate` with `Apply -AcceptMaintenance`, adds read-only `Preview`, and retains `Validate` and drift-failing `Check`. Preview writes only an artifact report. Trusted-base projection into its isolated candidate package uses explicit Apply acceptance; ordinary architecture validation continues to use Check.

The history tool gains the same explicit lifecycle: Preview writes a candidate only below `artifacts/`, Check compares the declared manifest without writing, and Apply requires `-AcceptMaintenance`. Tests prove Preview does not alter the tracked manifest, unaccepted Apply fails before writing, accepted Apply matches Preview byte-for-byte, and existing historical-integrity positive/negative behavior remains intact.

The physical moves, affected trusted components and zero-comparator policy/config changes require separate `move`, `change-trusted-base` and `weaken-policy` authorization records. The change consumes every record in its own diff. Workflow activation, required check names, projection authorities and generated projection bytes remain unchanged.

Prerequisite base-owned bridges are already part of the trusted base: maintenance path selection was authorized/consumed by `e9d6d0d4` → `8719ae8b`, and the current public-facade workflow negative fixture was authorized/consumed by `0b0bf325` → `91f8041f` after the first relocation rehearsal exposed the stale anchor.
