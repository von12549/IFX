# V3 IFX quality backlog cleanup

This formal plan implements CIQ-01 through CIQ-10 in `TODO.md`: dependency remediation, deterministic restore, removal of the credential login surface, nullable-flow fixes, React Hook stabilization, central NuGet package management, transitive vulnerability auditing, and blocking quality checks. CIQ-09 remains an upstream-owned tracked risk until `actions/download-artifact` publishes a release that removes the Node.js `Buffer()` warning; the repository will not suppress that warning.

The detailed implementation scope, risk decisions, and validation matrix are maintained in `.claude/Plans/20260916-v3-ifx-quality-cleanup.md`.
