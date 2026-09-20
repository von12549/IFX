# CP11j — Relocate policy data into the Post stage

This checkpoint moves the Architecture Conformance policy, strict baseline and G03/G04/G05 derived policy data from the legacy `policy/` data subdirectories into `stages/post/policy/`. The domain-authority registry remains temporarily at `policy/authorities.json`; `policy/README.md` documents that narrow transition boundary.

Authority targets, stage and command manifests, policy/config registration, authored guidance and generated views are updated together. The base-owned projection generator reproduces all derived files from the explicit head authorities, and the strict architecture suite keeps the same composite policy hash, tool version, binding count and required-check identity.
