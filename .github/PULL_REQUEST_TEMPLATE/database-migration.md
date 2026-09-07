## Database migration review

Use this template for every migration change. Link the normal pull request description rather than
removing repository-wide review sections.

### Release stages

- [ ] Expand: additive schema is readable by the currently deployed application.
- [ ] Deploy/read transition: new readers tolerate both old and new representations.
- [ ] Write transition: dual-write/backward-write behavior and cutover metrics are defined.
- [ ] Backfill: bounded batches, resume token, throttling, duration, and validation are defined.
- [ ] Contract: removal is scheduled only after old readers/writers and rollback windows expire.

### Mandatory risk review

- [ ] Drop/rename/non-null/type narrowing/large backfill signals are recorded in
      `deployment/migration-safety-policy.json`.
- [ ] Architecture approval reference is attached.
- [ ] Database approval reference is attached.
- [ ] Lock duration, log growth, query-plan and storage impact are measured or bounded.
- [ ] The release compatibility allowlist is updated only for Expand-safe migration IDs.

### Recovery and audit

- [ ] Preflight and validated backup/restore point are required before apply.
- [ ] Failure stops the release; recovery is roll-forward by default and never automatic Down.
- [ ] Any database rollback uses a separately generated, reviewed script with stated data loss.
- [ ] Manifest/SQL/report hashes and approvals will be recorded using the upgrade audit template.
