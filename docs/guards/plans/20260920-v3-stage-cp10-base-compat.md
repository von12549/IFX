# CP10 base compatibility — CI declaration test

This bridge makes the base-owned CI contract test understand both sides of the P9 authority replacement. When `stages/ci/required-checks.json` exists it uses that declaration, its schema and `-RequiredChecksPath`; otherwise it retains the existing `ci/jobs.json` and `-JobsPath` behavior.

The bridge changes no production verifier, workflow, required check, policy or activation file. On the current base it executes the unchanged legacy fixture matrix. When the final CP10 candidate is evaluated, the same base-owned test selects the new declaration and its schema-specific negatives. This lets the trusted component candidate verifier validate the real deletion rather than requiring a compatibility copy of `jobs.json`.
