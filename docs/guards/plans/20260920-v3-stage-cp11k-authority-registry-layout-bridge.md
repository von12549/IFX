# CP11k — Authority registry layout bridge

This expand checkpoint lets the trusted package locate the domain-authority registry in either the legacy `policy/` layout or the target `shared/authorities/` layout. Runtime, manifest, projection and trusted-base readers require exactly one location, so a missing or duplicated registry fails closed.

The trusted Diff selects the registry independently in the base checkout and the explicit head Git tree. This preserves base-owned validation while allowing the next checkpoint to move the registry and its README as one protected directory relocation.
