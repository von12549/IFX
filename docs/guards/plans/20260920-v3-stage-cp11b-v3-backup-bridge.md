# CP11b — V3_backup retirement compatibility bridge

This base-owned test bridge removes `docs/guards/V3_backup` as a prerequisite of the protected-change fixtures and isolated package copies before Plan 06 P10.5 deletes that tree.

Protected delete, move and case-rename fixtures use the canonical `docs/guards/V3` package instead. The cutover-preservation test accepts exactly the two explicit transition states: backup present with its compatibility entry, or backup absent with that entry removed. Manifest fixtures copy the legacy backup marker only when the source state still contains it. No production verdict, policy, required check, workflow or protected-path rule changes.

The bridge is a trusted-base test/utility change and therefore requires a base `change-trusted-base` authorization. Its change consumes that authorization before the physical deletion is prepared.
