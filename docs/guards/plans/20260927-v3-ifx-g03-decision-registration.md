# V3_ifx G03 documentation decision registration

Status: `IMPLEMENTED LOCALLY — push pending operator approval`

C2d (`6723d465`) added
`shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json`
inside the `shared/` registry root without registering it in
`shared/policy-config.json`. Since then every `Invoke-IFXGuardrails.ps1 -Mode
Validate` run fails with exactly one manifest-check problem, recorded as open
item O5 of V4-TODO-008 and reproduced on unmodified `640c5756` and `af2bd603`.

Register the file the same way as the 41 earlier history records: append its
path, in date order, to the `paths` of the existing `decision-history` entry
(role `trust-meta-policy`, format `json`, schema
`docs/guards/V3/contracts/decision.schema.json`, candidate validation
`json-schema`). No other entry, root, exclusion or monotonicity declaration
changes. The decision record itself, the G03 documents, the C2d candidate
module, derived projections and every file under `docs/guards/v4` stay
untouched. The file already validates against the decision schema, so no new
decision is needed; registration only brings it under D24 protection.

`shared/policy-config.json` registers itself and belongs to trusted component
`tcb.manifest`. Under D24 and D23 the one-line change therefore creates two
obligations: one `weaken-policy` obligation at pointer
`/entries/<decision-history>/paths` and one `change-trusted-base` obligation for
`tcb.manifest`. Following the P11 two-step flow, the authorization-only step
`20260927-v3-ifx-g03-decision-registration-authorization` adds both base
records bound to this prepared candidate; this change then deletes both records
in the same diff so each is consumed exactly once.

Acceptance: IFX V3_ifx `Validate` passes with zero manifest problems, Formal
Pre passes for this Plan, and the trusted Diff from the authorization commit to
this change reports every obligation covered by exactly one consumed record.
Nothing is pushed without explicit operator approval.

## Verification record

Formal Pre passed before the registry edit at
`artifacts/guards/o5-g03-registration/formal-pre`. The authorization-only
commit (Plan `20260927-v3-ifx-g03-decision-registration-authorization`) adds
the `weaken-policy` record for pointer `/entries/24/paths/41` and the
`change-trusted-base` record for `tcb.manifest`, whose single allowed
behavior difference is `Validate` changing from fail to pass. This change
merges that commit and deletes both records. The base-owned trusted Diff and
trusted-component candidate verifier run from a repository-external detached
worktree of the authorization commit, and IFX V3_ifx `Validate` passes with
zero manifest problems.