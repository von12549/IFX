# CP11d — history candidate report-root fix

The relocation bridge correctly materializes the candidate Historical Integrity manifest and its referenced evidence under an isolated temporary repository root. Its report path, however, was placed beside that root. The base Historical Integrity engine correctly rejects any output path outside `-RepositoryRoot`, so even a valid changed manifest could not pass candidate validation.

This checkpoint places the transient report inside the same isolated history root and adds a positive trusted-base fixture for a semantically changed but valid history manifest. The existing tampered-manifest negative remains unchanged. Production inputs, active paths and verdict behavior are otherwise unchanged.
