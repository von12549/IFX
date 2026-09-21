# Plan 06 final documentation clarity

This documentation-only checkpoint resolves the two non-runtime findings from the final Plan 06 review.

The active V3 technical design now names the canonical `commands/Invoke-V3.ps1` entry point instead of the P11.5-retired compatibility path. The Plan 06 closeout now states explicitly that implementation is complete with P4.4 deferred under D23, records the conservative fail-closed zero-comparator behavior, and records the completed revocation-only cleanup from PR #106.

No command, trusted component, policy, compatibility registry, generated document, historical record or CI contract changes. Historical references to retired paths remain unchanged where they describe prior states or exact authorization tuples.
