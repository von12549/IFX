# IFX 1.1.4 C6c failure recovery plan

Status: authorized for corrective implementation and targeted qualification only
Date: 2026-09-27
Base runtime: `v4-guards-1.1.4`
Candidate version: `0.4.2`
Recovery evidence root: `artifacts/guards/p10-ifx-114/recovery-042`

## Preserved failure

The single `0.4.1` C6c attempt at Target commit
`a1d13627913883f69b1818e93e24598b008b3d24` is final and remains preserved.
It failed in three parallel branches:

1. Windows stopped on C6c4 inventory-projection drift because seven adapter
   hashes changed without rebinding the matrix contract.
2. Controls rejected `type/current` with `integrity-failure`.
3. Linux rejected `direct-post` because the Type evidence was stale.

The Type, evaluated-graph and generated-input locks have one-hour expiries.
They were created before focused qualification and the authorized C6c was
started after that hour had elapsed. The failed attempt must not be overwritten,
repaired in place or counted as a passing certification.

## Decision boundary

This recovery authorizes tracked corrective changes, focused tests and creation
of a new deterministic `0.4.2` candidate. It does not authorize another full
C6c. A future C6c requires a separate explicit decision after all readiness
criteria below pass. C6d and C6e remain unauthorized.

## Corrective scope

1. Rebind the C6c4 matrix contract to the current 37-module ordinal inventory,
   including the seven changed adapter hashes, and refresh the supplemental
   fixture binding to the new contract hash.
2. Add a recovery readiness gate that verifies the exact clean Target commit,
   inventory/candidate binding, all seven evidence-lock hashes and commits, and
   at least 2700 seconds of remaining life for every expiring lock.
3. Run the existing C6c4 contract checker from the readiness gate so matrix and
   fixture drift is rejected before a full-attempt marker is written.
4. Create a recovered single-C6c wrapper with new evidence, attempt and decision
   paths. Require an explicit authorization switch and refuse any existing path.
5. After the corrective implementation is committed, regenerate all seven locks
   and both deterministic candidates in one continuous workflow. Do not pause
   between lock generation, focused qualification and readiness evaluation.
6. Preserve the original failure evidence and write separate recovery evidence.

## Acceptance criteria

- The C6c4 matrix contract projection equals the current ordinal inventory and
  every non-architecture module adapter hash matches its current file.
- The fixture specification is bound to the corrected matrix contract hash.
- Readiness fails closed for an old commit, inventory mismatch, missing or
  modified lock, expired lock, or less than 2700 seconds of remaining lock life.
- Fresh solution, assembly, frontend, database, Type, graph and generated locks
  all bind the exact clean recovery Target commit.
- Two independently composed `0.4.2` candidates have identical manifest,
  profile, composition projection and package fingerprints.
- Contract compatibility, focused qualification and the new readiness gate pass
  while the tracked checkout remains clean.
- The historical `c6c-attempt.json`, `c6c-full` tree and failure decision remain
  byte-for-byte unchanged.
- No full C6c is run until separately authorized.

## Stop conditions

Stop before C6c on tracked dirt, matrix/fixture drift, candidate nondeterminism,
lock lineage mismatch, less than 2700 seconds of remaining expiry, focused
qualification failure, evidence-path reuse or lack of explicit recovered-C6c
authorization. A failed readiness check may be repaired and repeated because it
is not a full C6c attempt.
