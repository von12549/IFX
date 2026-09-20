# CP11q — Verifier layout base-test bridge

This checkpoint prepares the base-owned manifest verifier fixtures for the Plan 06 P10 verifier relocation. The fixture resolves exactly one legacy `scripts/` or final `engine/` implementation, so the same base assertion set runs before and after the move and fails if both implementations become authoritative.

It also records D33: the CI contract remains a public command and keeps a legacy wrapper through P11.5, while the manifest verifier is internal and receives no compatibility path.
