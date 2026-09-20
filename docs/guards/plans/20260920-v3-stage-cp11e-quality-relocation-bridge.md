# CP11e — quality relocation bridge

The three Quality gate scripts currently form one complete legacy layout under `quality/`. Base-owned Assembly, Package and manifest tests name that location directly, so a physical move to the Post gate tree would make the current base unable to validate the candidate.

This bridge makes those tests select exactly one complete legacy or stage-owned Quality layout and fail closed for missing, partial or ambiguous layouts. It changes no production dispatcher, command manifest, Post trust contract or trusted-component ownership path.
