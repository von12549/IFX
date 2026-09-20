# CP11i — Authored documentation and Plan example relocation

This checkpoint removes three remaining documentation-oriented legacy roots. The deployment guide and generated-output lifecycle guide move under `docs/authored/`; the IFX Plan examples move from `templates/plan/` to `examples/plan/` because they are examples rather than generator inputs.

Stage documentation declarations, package guidance and Agent integrations are updated in the same change. The Stage manifests remain semantically equivalent apart from their documentation paths. Runtime guard behavior, CI activation and required check names are unchanged.
