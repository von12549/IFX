# CP11j — Policy layout compatibility bridge

This expand checkpoint makes every base-owned consumer needed by the Architecture, Quality, Specialized and package-validation suites accept exactly one complete policy data layout: legacy `policy/` or stage-owned `stages/post/policy/`. Missing and ambiguous layouts fail closed.

The domain-authority registry remains at `policy/authorities.json` in this checkpoint. No policy data, registry entry, Stage manifest or runtime verdict changes. This bridge exists so the following protected move can be evaluated by the previous trusted base with the same test corpus.
