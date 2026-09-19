# CP09 authorization r3 — commands, docs, and analysis lifecycle

This checkpoint pre-authorizes raw CP09 candidate `0fa43780` on the independently verified dual-layout base `2b45b48a`.

The record set covers one trusted-component upgrade, one semantic policy/config change, seven protected moves, and six protected deletions. Every record is bound to the exact base/head tree entries or semantic hashes and to the CP09 plan/decision set. The following change commit must consume all 15 records exactly once; unused, mismatched, or replayed records remain invalid.
