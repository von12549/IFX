# Protected change authorizations

Base pre-authorizations for protected changes, following Plan 06 §12. Only records that already exist in the **base** commit count. The change PR that consumes a record must delete it in the same diff, so each record can be used only once.

P2 enables `change-trusted-base` (Plan 06 §11.5). P4 adds `move`, `delete`, `case-rename` and `weaken-policy`.

## Two-PR flow

1. Prepare the trusted component change on a branch, without merging it.
2. Generate the record against the base that the change will merge into:

   ```powershell
   pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1 `
     -Id <id> -BaseRevision <base> -HeadRevision <prepared-change> `
     -PlanPath <formal plan> -DecisionPaths <decision.json,...> `
     -ParityContract '<expected behaviour>'
   ```

3. **Authorization PR:** add only `<id>.json` to this directory.
4. **Change PR:** after the authorization merges, rebase the prepared change onto the new base, delete `<id>.json`, and open the PR.

`trusted-base/Test-IFXTrustedBaseCandidate.ps1` runs from the base worktree and checks the change PR. It verifies:

- the component set, the changed paths, and each path's base and head `mode + type + objectId` tuple;
- that the validation suite equals the base component suites;
- that the plan and decision references exist.

It then runs the base-owned validation against the head candidate, with base tests overlaid, and compares guard verdicts on the fixed corpus. A verdict difference passes only for a mode listed in `allowedBehaviorDifferences`.

Records in this directory are protected paths. `v3-pre-diff` accepts the deletion of a record only when all of the following hold (D20):

- the trusted base runner has run the verifier in authorization-only mode against the exact PR head;
- the verifier confirmed that this change consumes that record;
- the deletion is a plain deletion of exactly that path, not a rename.

Deleting an authorization that the change does not consume, for example to revoke it, remains a protected deletion until P4.

The schema is `contracts/authorization.schema.json`. Records in this directory are protocol data and are not themselves trusted component changes.
