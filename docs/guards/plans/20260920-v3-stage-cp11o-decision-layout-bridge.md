# CP11o — Shared decision-history layout bridge

This expand checkpoint prepares the reviewed decision history for shared package ownership. Trusted-base consumers resolve exactly one of `decisions/history/` or `shared/decisions/history/`; absence and ambiguity fail closed.

The checkpoint does not copy or move decision records. It only widens base-owned path resolution and records D31, so the following protected relocation can be judged by the previous trusted base without silent fallback.
