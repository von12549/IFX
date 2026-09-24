# V4 P10.1 C4b — Database evidence, read-only Post

Decision: `A`, confirmed by the repository owner on 2026-09-24. Database
commands remain in a separate controlled V3 execution step. The V4 Post
candidate has no `dotnet`, EF, database connection, network or write
capability. It only verifies a content-locked evidence set against the
current migration catalog, release manifest, safety policy and source files.

The evidence producer must run the V3 Database specialized gate in a
non-production controlled environment. A historical `passed` summary is
not fresh evidence. The producer records its exact target commit, start/end
time, exit result and file hashes only after the gate exits successfully.
The candidate rejects absent, stale, altered, incomplete and zero-subject
evidence. Candidate fixtures exercise the Post path without a database.

This is candidate-level coverage, not production Database approval or C5
integration. The composed Host test uses a synthetic review record; no
production Profile or bundle is accepted here.

## Verification record

Formal Pre passed at `artifacts/guards/p10-ifx-c4b/formal-pre/summary-pre.json`.
The controlled V3 Database gate passed on the current IFX target and issued
`artifacts/guards/p10-ifx-c4b/database-runs/18a3881a19c24e4ba7a2ba8b089080f1/evidence-lock.json`
(SHA-256 `6a0878a46e2ea6752fba7f532560d949d690db1155b6d21cc99159946550b574`).
Its deterministic boundary tests passed 109/109 and the SQL Server matrix
passed 13/13. The lock names the starting commit, timestamps, authority
hashes, 1,152 relevant source files and 138 generated artifacts. It is not
a production signature; the reviewed V4 Profile must pin its SHA-256 before
acceptance. Locks expire
after 24 hours and must be regenerated for C5/C6 or a changed migration,
release or safety authority.

The candidate direct real IFX Post and published 1.1.3 Host synthetic Post
passed at `artifacts/guards/p10-ifx-c4b/test-runs/f637da2dc5c34def8ad8ff355729d942/summary.json`.
The test covers false SQL matrix, tampered artifact, stale evidence, missing
script, zero scripts, source drift, missing lock and immutable roots.
The isolated IFX package regression passed at
`artifacts/guards/v3-ifx-package-test-9be193b962524769ada2587e962db81f`.
Exact committed Formal Diff passed at
`artifacts/guards/p10-ifx-c4b/formal-diff/summary-diff.json`.
