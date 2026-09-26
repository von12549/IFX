# IFX 1.1.4 focused-qualification recovery plan

Status: authorized for corrective implementation and focused qualification only
Date: 2026-09-27
Base runtime: `v4-guards-1.1.4`
Candidate version: `0.4.1`

## Decision boundary

The failed `0.4.0` focused run is preserved as evidence. It did not authorize a C6c run because the qualification harness treated the adapter's structured error response as a process failure and therefore stopped before C6c.

This recovery may correct the candidate harness, produce deterministic `0.4.1` candidates, and execute focused qualification. It must not start, resume, or mark a C6c attempt. C6c requires a separate decision after all recovery acceptance criteria pass.

## Corrective scope

1. Align negative-case assertions with the adapter contract: a handled rejection exits `0` and returns JSON with `status=error` plus the expected `exitCategory`; a non-zero process exit is an execution failure.
2. Enforce producer and adapter timeouts at process level, including process-tree termination, rather than checking elapsed time only after completion.
3. Execute hash, commit, missing-path, path-overlap, stale-evidence, provider-scope, provider-output, and linked-input negatives against every one of the seven workspace-evidence consumers.
4. Exercise Host trust-boundary behavior for profile/provider configuration tampering and for a module variant without `EvidenceRoot` capability.
5. Write a failure summary as well as a success summary, so qualification evidence survives fail-closed exits.
6. Parameterize the future single-C6c wrapper with the candidate version while leaving its attempt marker untouched.

## Acceptance criteria

- The recovery commit is clean and uniquely recorded before evidence generation.
- Two independently generated `0.4.1` candidate bundles have identical manifest, profile, composition projection, and package fingerprints.
- All seven consumers are semantically equivalent between Host-provided workspace evidence and direct-scan fallback.
- Every actual negative case fails closed with the expected structured category within its declared timeout.
- Host rejects tampered provider/profile configuration, linked inputs are actually exercised, and a consumer without `EvidenceRoot` is not given workspace-evidence fields.
- The focused summary is durably written and reports `status=pass`.
- `artifacts/guards/p10-ifx-114/c6c-attempt.json` remains absent or unchanged with `attempted=false`, and no `c6c-full` run is created.

## Stop conditions

Stop before C6c on any nondeterminism, timeout, schema/contract drift, unexpected process exit, negative-case acceptance, missing failure evidence, dirty tracked state, or inability to prove a trust-boundary assertion. A further harness correction is allowed only when the failure is demonstrably in the recovery harness and the failed evidence remains preserved.
