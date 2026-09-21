# P11.5 compatibility cleanup and P11.6 recovery proof

This checkpoint closes the Plan 06 compatibility window after P11.4 activation, full Windows certification and activation rollback verification.

P11.5 deletes exactly nine public deprecation wrappers, removes the one-time trusted-base bridge used to admit the cleanup-preparation candidate, empties the compatibility registry and removes wrapper paths from the trusted-component manifest. Canonical `commands/` entries remain the only public production paths. Current README and authored deployment/architecture documentation now names those canonical entries; immutable plans, decisions, authorization records and frozen evidence retain their historical text.

P11.6 is recorded in `stages/analysis/evidence/p11-compatibility-deletion-manifest.json`. The manifest binds every deletion to its pre-delete blob and fixes `d97a2a5b1f015ca82efc42c9e8a6a8ced40e7b24` as the selective restore commit. In a repository-external detached worktree at candidate `6e3795c1`, restoring exactly those nine paths made `Test-CutoverPreservation.ps1` exit 1 and enumerate all nine retired paths. Removing only the restored files made the same test and `Invoke-IFXGuardrails.ps1 -Mode Validate` pass with zero tracked changes. This proves that selective recovery is possible but cannot silently reactivate compatibility.

The nine deletions, trusted-base/manifest/test changes and compatibility policy closure require base-owned delete, change-trusted-base and weaken-policy authorization records. The implementation PR consumes those records and must pass local trusted Diff, trusted-component candidate validation and all 13 required checks before merge.
