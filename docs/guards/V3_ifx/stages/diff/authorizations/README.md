# Protected change authorizations

Base pre-authorizations for protected changes, following Plan 06 §12. Only records that already exist in the **base** commit count. The change PR that consumes a record must delete it in the same diff, so each record can be used only once. Records are immutable: to change one, revoke it and add a new record.

The schema is `stages/diff/contracts/authorization.schema.json` and covers all five operations of §12.2. The base verifier currently enables these operations for consumption:

| Operation | Enabled | Covers |
| --- | --- | --- |
| `change-trusted-base` | yes (P2) | the trusted component change of the PR |
| `delete` | yes (CP06a) | removals of protected paths at or below `source` |
| `move` | yes (CP06a) | removals below `source`, with the `destination` result |
| `case-rename` | yes (CP06a) | the same as `move`, when source and destination differ only in letter case |
| `weaken-policy` | yes (CP06b1, CP06b2) | semantic changes of registered policy and configuration files, and D18 domain authority blocking findings |

## Two-PR flow

1. Prepare the change on a branch, without merging it.
2. Generate each record against the base that the change will merge into:

   ```powershell
   # trusted component change
   pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1 `
     -Id <id> -BaseRevision <base> -HeadRevision <prepared-change> `
     -PlanPath <formal plan> -DecisionPaths <decision.json,...> `
     -ParityContract '<expected behaviour>'

   # semantic change of registered policy or configuration (all such changes, or -PolicyPaths)
   pwsh -NoProfile -File docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1 `
     -Id <id> -Operation weaken-policy `
     -BaseRevision <base> -HeadRevision <prepared-change> `
     -PlanPath <formal plan> -DecisionPaths <decision.json,...>

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
- one obligation for any trusted component change;
- each semantic change of a file registered in `shared/policy-config.json` (D24). JSON is compared after parsing, and `.gitattributes` after line-ending normalization. With zero comparators every such change is a potential weakening;
- each D18 domain authority with blocking findings (a governing-policy change or a widened exception), with schema `domain-authority:<id>` and exactly the blocking pointers (D25).

One path can carry several obligations. For example, deleting a protected engine script needs a `delete` record and a `change-trusted-base` record. A trust/meta-policy change, such as a stage manifest edit, needs a `change-trusted-base` record and a `weaken-policy` record, which can share one authorization PR.

The **candidates** are the schema-valid base records that head deletes. Every obligation must be covered by exactly one candidate, and every candidate must cover at least one obligation. Uncovered, duplicate and unused coverage all fail.

Each record must also match the change exactly:

- `change-trusted-base`: the component set, changed paths, base and head tuples, base validation suite, and plan and decision references. The candidate verification job then runs the base-owned validation and parity.
- `weaken-policy`: each listed policy must be a semantic change of this PR. The base and head blob SHA-256, head tuple, registered schema or format, and the exact set of changed JSON Pointers must all match.
- Path operations: `source` must match its tree entry at the merge base and be absent in head. `destination` must match its recorded base state and its expected head tree entry. The changed paths below source and destination must equal `changedPaths`, with matching tuples in `entries`. A `delete` cannot cover a case-only rename, and a `move` cannot be case-only; declare a `case-rename`.

Independent of records, these always fail:

- gitlinks in the protected scope;
- an unregistered JSON file inside the registry roots, or an unregistered `.gitattributes` file;
- a changed record;
- an added record that is schema-invalid or whose file name is not its id.

The verifier writes a report bound to the base commit, merge base, head commit and the SHA-256 of the base protection configuration, policy registry and authorization schema. The runner re-checks the registry and schema hashes. The generated Diff test exempts exactly the report's `allowedDeletions` when every binding matches, and fails otherwise.

## Revocation (D22)

To withdraw an unused authorization, open a revocation-only PR. Its changed set may contain only:

- plain deletions of schema-valid base records;
- its own plan pair.

Any other change in the same PR turns each deleted record into a consumption candidate, and an unused candidate fails.

## Head policy candidates (D24)

`trusted-base/Test-IFXPolicyCandidates.ps1` also runs in the trusted Diff, from base, on the Git objects of the explicit head commit. The head versions are validated but never decide the current verdict:

- registered JSON parses and matches its schema; the head schema is used when this PR changes that schema;
- the base V3 runner validates a changed head profile, and the base renderer checks its views;
- the base historical integrity engine checks a changed head `history/manifest.json` against head evidence;
- the base projection generator must reproduce the head projections from head authority sources, for the exact targets in the base `shared/authorities/authorities.json`;
- the head registry must declare monotonicity for every field of every schema it registers.

## Domain authorities in the gates (D25)

Validate, Architecture and Specialized runs receive the explicit pull request head as `-HeadRef`. The trusted runner compares domain authorities as Git objects of that commit and its merge base. When blocking findings exist, it runs the base protected change verifier for that commit and accepts the findings only when:

- the report is bound to base, merge base, head and the base registry and schema hashes;
- each blocking authority is covered by exactly one consumed `weaken-policy` authorization with the same pointers.

Every changed authority in the checkout must also equal the explicit head commit. Without `-HeadRef`, blocking findings fail closed.

## Rehearsal (P4.7)

`trusted-base/Invoke-IFXProtectedChangeRehearsal.ps1 -BaseRevision <base>` runs a complete two-PR sequence in a disposable clone, judged entirely by that base's own trusted scripts. The change combines a protected move, a `weaken-policy` change and a `change-trusted-base` change. The report lists every commit and verdict, including the negative steps: the change opened before its authorizations exist, and a replay after the change merges. The 2026-09-17 evidence is in `docs/architecture/review/evidence/guards/p4-rehearsal-20260917.md`.
