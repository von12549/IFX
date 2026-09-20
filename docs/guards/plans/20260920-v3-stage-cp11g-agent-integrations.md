# CP11g — Agent integration relocation

This checkpoint moves the two IFX-specific Agent skills from the legacy package-root `skills/` directory into `integrations/agents/`. The skill contents remain behaviorally unchanged apart from the relative link required by the deeper ownership path, and the package README names the canonical integration location.

The legacy internal directory receives no compatibility copy. The move is pre-authorized against the frozen candidate and consumed exactly once by this change. Runtime guard commands, trusted components, policy authorities, CI activation and required check names are unchanged.
