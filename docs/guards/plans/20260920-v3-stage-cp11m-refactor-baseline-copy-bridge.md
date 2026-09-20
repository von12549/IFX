# CP11m — Refactor baseline copy-list bridge

This expand checkpoint teaches base-owned package-copy and fixture code to omit the archived CI evidence from either the legacy refactor-baseline path or its target Analysis Stage path. The exclusion remains limited to the same `ci-evidence/` archive and does not change verdict inputs.

The bridge prevents 69 immutable artifact files from being copied into every candidate fixture while allowing the previous trusted base to validate the subsequent protected relocation.
