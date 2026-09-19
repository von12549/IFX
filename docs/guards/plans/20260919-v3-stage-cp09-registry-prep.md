# CP09 registry prep — Analysis evidence paths

This preparatory checkpoint temporarily excludes the two still-empty reviewed evidence/report destination directories before CP09 moves files into the D24 policy/config registry root.

The base-owned verifier intentionally rejects an unregistered JSON file under `stages/`, even if the same candidate also registers that path. Therefore a separately authorized expand step first excludes the empty destination directories. It does not move, create, or reinterpret evidence. CP09 then atomically moves the reviewed files, removes the temporary exclusions, registers the exact JSON paths, and consumes its own tuple-bound authorizations. No candidate asks a head-defined registry entry to authorize itself.

Validation requires the policy registry schema, manifest/package tests, and trusted-base candidate verification to pass. The temporary exclusion consumes both `change-trusted-base` and `weaken-policy` authorizations because `policy-config.json` is simultaneously a trusted component and trust/meta-policy.
