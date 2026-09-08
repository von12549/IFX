# G03 ownership and change approval

Repository routing is enforced by `.github/CODEOWNERS`, currently mapped to the GitHub identity
proved by the configured remote and maintainer Git history. Business approval is stricter than
file ownership: the catalog's reviewer matrix requires the provider and affected consumers, plus
Platform Messaging/architecture review when shared or breaking semantics are involved. ApiHost is
never substituted for a business owner.

Every public change updates source/schema, catalog, Change Record, and tests in one pull request.
The Contract/Event PR template makes the checks visible. An identity cannot become Active without
provider and first-consumer approvals plus its source, snapshot, and compatibility evidence.

External consumers are reconfirmed at least every 90 days. An overdue confirmation alerts and
blocks retirement; it does not erase the consumer. Emergency security/regulatory work still
records affected identities/consumers, coordinates release and rollback, assigns a post-incident
ADR, and uses a new identity for incompatible semantics.

## Backup assignment

Xiaolong Feng / `@von12549` remains the accountable owner. On 2026-09-08 the repository owner
designated and authorized Junxi / `@jimkeecn` as the backup owner for all governed modules,
Platform Messaging, the G03 catalog, and its guard scripts. The GitHub identity has repository
write permission and is routed through `.github/CODEOWNERS`; the dated assignment is recorded in
[`G03-backup-owner-assignment.md`](../../evidence/gates/G03/G03-backup-owner-assignment.md).

Backup review does not replace the Provider and Consumer approvals required for Active admission.
