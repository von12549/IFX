# CP11c — profile authority registry prep

The split-authority candidate adds JSON files under `shared/`, `stages/pre/` and `stages/post/rules/`. D24 correctly treats those destinations as unregistered when judged by the current base registry, so the physical move cannot authorize its own routing change.

This prep registers only those three direct-child destination directories with conservative `json` validation. It creates no authority file and changes no production caller. The base-owned policy candidate verifier also gains a bounded transition: if the explicit head `shared/profile-layout.json` exists it validates that layout; otherwise it validates the legacy directory. It never falls back after selecting a mode.

The physical migration must replace these temporary directory entries with the exact final profile entries in the same change.
