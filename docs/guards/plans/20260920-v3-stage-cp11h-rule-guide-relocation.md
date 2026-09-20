# CP11h — Rule authoring guide relocation

This checkpoint moves the human-facing IFX rule authoring guide from the legacy package-root `rules/` directory into `docs/authored/RULES.md`. Machine rule authority remains exclusively under `stages/post/rules/`; the guide remains non-authoritative and its relative links are updated for the new depth.

The Agent bootstrap integration points at the canonical authored guide. Runtime guard behavior, trusted components, policy authorities, CI activation and required check names are unchanged.
