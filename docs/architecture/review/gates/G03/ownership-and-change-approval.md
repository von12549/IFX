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

## Open assignment condition

Only one current accountable repository maintainer can be established from repository evidence.
A genuinely independent backup owner has not been authorized. The catalog records this as
`required-before-active-or-gate-close`; it must be supplied by the repository owner before any
Proposed protocol is promoted or G03 is approved closed. Inventing or silently assigning a backup
would not be valid governance evidence.
