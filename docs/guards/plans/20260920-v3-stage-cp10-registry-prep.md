# CP10 registry prep — CI authority destinations

This preparatory checkpoint teaches the exclusion schema to accept exact file paths, then temporarily excludes the three not-yet-existing CI JSON authority paths under `stages/ci/`. The base policy verifier rejects any new JSON inside a registered root before a head-defined registry entry can authorize it, so CP10 needs a separately authorized expansion step. Directory exclusions keep their existing behavior; exact file exclusions cannot mask siblings.

The checkpoint creates no CI authority, candidate or activation file. The subsequent CP10 change removes all three exclusions while adding schema-bound registry entries for the exact paths. This keeps both decisions base-owned: the prep base explicitly permits the future paths to appear, and the final change must atomically replace those temporary exclusions with reviewed registrations.
