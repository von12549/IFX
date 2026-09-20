# CP11p — Contract ownership layout bridge

This expand checkpoint prepares the package contract split. Trusted-base and package consumers resolve IFX-only schemas from exactly one legacy or owned Shared/Stage path; absence and ambiguity fail closed. Portable schemas resolve to canonical V3, and a temporary IFX copy is accepted only while its bytes are identical.

The checkpoint does not move or delete schemas. It widens base-owned path resolution and records D32 so the following protected relocation can be judged by the previous trusted base without silent fallback.
