# CP11f — specialized gate relocation bridge

The Specialized dispatcher, detector scripts and result contracts currently form one legacy layout under `specialized/`. Base-owned contract, manifest and target-root-separation tests name that location directly, so a physical move to the Post gate tree would prevent the current base from validating the candidate.

This bridge makes those tests select exactly one complete legacy or stage-owned Specialized layout and fail closed for missing, partial or ambiguous layouts. It changes no production dispatcher, command manifest, Post trust contract or trusted-component ownership path.
