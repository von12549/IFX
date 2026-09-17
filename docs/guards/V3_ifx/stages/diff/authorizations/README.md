# Protected change authorizations

Base pre-authorizations for protected changes, following Plan 06 §12. Only records that already exist in the **base** commit count. The change PR that consumes a record must delete it in the same diff, so each record can be used only once. Records are immutable: to change one, revoke it and add a new record.

The schema is `contracts/authorization.schema.json` and covers all five operations of §12.2. The base verifier currently enables these operations for consumption:

| Operation | Enabled | Covers |
| --- | --- | --- |
| `change-trusted-base` | yes (P2) | the trusted component change of the PR |
| `delete` | yes (CP06a) | removals of protected paths at or below `source` |
| `move` | yes (CP06a) | removals below `source`, with the `destination` result |
| `case-rename` | yes (CP06a) | the same as `move`, when source and destination differ only in letter case |
| `weaken-policy` | no, until CP06b | consuming it fails closed |

## Two-PR flow

1. Prepare the change on a branch, without merging it.
2. Generate each record against the base that the change will merge into:

   ```powershell
   # trusted component change
   pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1 `
     -Id <id> -BaseRevision <base> -HeadRevision <prepared-change> `
     -PlanPath <formal plan> -DecisionPaths <decision.json,...> `
     -ParityContract '<expected behaviour>'

   # protected deletion, move or case-only rename
   pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1 `
     -Id <id> -Operation move -SourcePath <path> -DestinationPath <path> `
     -BaseRevision <base> -HeadRevision <prepared-change> `
     -PlanPath <formal plan> -DecisionPaths <decision.json,...>
   ```

3. **Authorization PR:** add only the `<id>.json` records to this directory.
4. **Change PR:** after the authorization merges, update the prepared change with the new base, delete the records it consumes, and open the PR.

## What the trusted Diff checks (D23)

`trusted-base/Test-IFXProtectedChanges.ps1` runs from the base worktree against the committed PR head. It reads the changed set with `git diff --raw -z --no-renames` from the verified merge base, so a rename is a deletion plus an addition. The change creates **obligations**:

- each removal of a path listed in `stages/diff/protection.json`;
- one obligation for any trusted component change.

One path can carry several obligations. For example, deleting a protected engine script needs a `delete` record and a `change-trusted-base` record.

The **candidates** are the schema-valid base records that head deletes. Every obligation must be covered by exactly one candidate, and every candidate must cover at least one obligation. Uncovered, duplicate and unused coverage all fail.

Each record must also match the change exactly:

- `change-trusted-base`: the component set, changed paths, base and head tuples, base validation suite, and plan and decision references. The candidate verification job then runs the base-owned validation and parity.
- Path operations: `source` must match its tree entry at the merge base and be absent in head. `destination` must match its recorded base state and its expected head tree entry. The changed paths below source and destination must equal `changedPaths`, with matching tuples in `entries`. A `delete` cannot cover a case-only rename, and a `move` cannot be case-only; declare a `case-rename`.

Independent of records, these always fail:

- gitlinks in the protected scope;
- any `.gitattributes` change, until CP06b opens it through `weaken-policy`;
- a changed record;
- an added record that is schema-invalid or whose file name is not its id.

The verifier writes a report bound to the base commit, merge base, head commit and the SHA-256 of the base protection configuration. The generated Diff test exempts exactly the report's `allowedDeletions` when every binding matches, and fails otherwise.

## Revocation (D22)

To withdraw an unused authorization, open a revocation-only PR. Its changed set may contain only:

- plain deletions of schema-valid base records;
- its own plan pair.

Any other change in the same PR turns each deleted record into a consumption candidate, and an unused candidate fails.
