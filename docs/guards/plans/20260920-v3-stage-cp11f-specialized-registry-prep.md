# CP11f — Specialized contract registry prep

The Specialized result contracts will move beneath the policy-scanned `stages/` root. This expand checkpoint registers their future stage-owned directory before it exists, so the later physical relocation can be evaluated by the current base without an unregistered-policy gap.

No runtime entry point, detector, contract file or active gate path changes here. Manifest validation continues to pass while the registered directory is absent, and the subsequent relocation must populate it and remove the legacy tree in one authorized change.
