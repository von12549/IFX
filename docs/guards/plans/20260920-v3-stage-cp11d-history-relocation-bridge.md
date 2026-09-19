# CP11d — Historical Integrity relocation bridge

The Historical Integrity engine and manifest currently form one complete legacy layout under `history/`. The stage-oriented destination belongs to the Post gate tree, but the current trusted base and package tests name the legacy path directly and the destination is not registered as policy.

This bridge makes base-owned verification select exactly one complete legacy or stage-owned layout. It fails closed when neither or both layouts are present, and policy candidate validation selects the head manifest from the Git tree without falling back after selection. A temporary direct-child JSON registry entry recognizes the frozen destination directory so the later physical relocation can be authorized by the current base.

No production entry point, command catalog, stage manifest, trusted-component path or active Historical Integrity file moves in this checkpoint. The physical relocation must replace the temporary directory registration with the exact final manifest entry in the same change.
