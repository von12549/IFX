# CP11m — Relocate the frozen refactor baseline

This checkpoint moves the reviewed Plan 06 P0 baseline from the legacy `analysis/ifx/` tree into Analysis Stage evidence. The frozen data and archived CI evidence retain their historical meaning, while their update and archive tools move to `maintenance/refactor-baseline/`.

The baseline evidence is excluded from active policy enumeration because it records migration-time facts rather than current verdict policy. The generator continues to emit its original P0 `generatedBy` value so `-Check` remains byte-identical after relocation.
