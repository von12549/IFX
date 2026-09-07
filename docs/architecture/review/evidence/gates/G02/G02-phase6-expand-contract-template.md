# G02 Phase 6 Expand / Contract release template

Date: 2026-09-08

Copy this template into the change record for every schema evolution. A single release must not both
introduce a replacement and remove the old representation.

## 1. Expand

- Module / MigrationId / source hash:
- Additive objects or nullable/defaulted columns:
- Current-release read/write compatibility proof:
- Lock/log/storage estimate and bounded execution time:
- `compatibleAdditionalMigrationIds` entries for already-deployed releases:
- Architecture approval / Database approval:

Exit condition: old code can run against the expanded schema and readiness reports
`newer-expand-compatible`. Unknown IDs remain rejected.

## 2. Deploy and read transition

- Consumer-first release and readiness evidence:
- New read path with fallback to the old representation:
- Metrics comparing old/new reads and mismatch threshold:
- Rollback image and compatible schema check:

Exit condition: all supported application versions read both representations correctly.

## 3. Write transition

- Dual-write or forward-write rule, ownership and idempotency:
- Cutover flag/command and reversal procedure:
- Consistency query and alert threshold:

Exit condition: no supported writer depends exclusively on the representation scheduled for removal.

## 4. Backfill

- Idempotent batch command and resume token:
- Batch size, throttle, timeout, lock/log-growth limits:
- Before/after row counts and semantic validation query:
- Abort/restart behavior:

Exit condition: the backfill is complete, validated, and can be safely rerun with no further changes.

## 5. Contract

- Last old reader/writer removal evidence and compatibility-window end:
- Drop/rename/non-null/type narrowing statements:
- Approved restore point, data-loss assessment and reviewed rollback/restore script:
- Architecture / Database / Operations approvals:
- Release manifests that must become incompatible with this schema:

Exit condition: no supported rollback image requires the removed representation. Contract migrations
are never added to an older release's compatibility allowlist.
