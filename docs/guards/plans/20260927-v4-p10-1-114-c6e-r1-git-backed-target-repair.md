# V4 P10.1 / 1.1.4 C6e-R1 Git-backed Target repair

Status: authorized repair implementation

## Authorization and dependency

The user explicitly requested a separate repair Plan and authorized the repair
to begin on 2026-09-27. This Plan follows the stopped C6e execution recorded by
`artifacts/guards/p10-ifx-114/c6e-042/c6e-decision.json` (SHA-256
`f6e1802660b656c6d3468ed72b761bb3d6e49a36d27dec9afdc04707773f595b`).

C6e failed before any IFX module ran because its `git archive` Target exports
did not contain repository metadata. The installed Host requires
`git -C <TargetRoot> rev-parse HEAD` while constructing workspace evidence.

## Goal

Repeat the bounded C6e installation and Web UI practice with new output paths
and Git-backed detached worktrees whose HEAD is exactly the certified C6c
Target commit. Prove a clean Pre pass, a blocking deliberate violation, UI/Host
agreement, receipt validity and protected-root invariance. Stop before P10.2 or
P10.3.

## Frozen identities

- Target commit: `40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`
- Base version/archive SHA-256: `1.1.4` /
  `dce037149d0fa38995e244ad417888a15d90809467e8ecc83708faef2b995c4d`
- Base receipt SHA-256:
  `5e7a5d2c604b6f78a463be40158f871b1fb9823dee17975841d64f09f93d2126`
- Bundle version/manifest SHA-256: `0.4.2` /
  `82eb0c5db8ec3779bc10a43b89f0a9235e38d02819745e8f42bffa7fd9635ee5`
- C6d review packet SHA-256:
  `25a865b584ea332a54e5f30632f4c3a0b7ccebc3095a83ef4d5fc06433d4fc9f`
- Production review SHA-256:
  `871173d4fc27236c06ff0a0c940c6f2d8a8983771b897878261de092826d8ced`
- C6d decision SHA-256:
  `e68eccd421e45d4671911d973ec9af9d847563aae00e6ebb4061b8375d6b4173`

## New absent outputs

- sibling install:
  `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2-c6e-r1`
- external receipt:
  `D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4-ifx-0.4.2-c6e-r1.compose.json`
- StateRoot: `D:/IFX-Root/guard-runtime/state/ifx-c6e-r1-042`
- EvidenceRoot: `D:/IFX-Root/guard-runtime/evidence/ifx-c6e-r1-042`
- clean worktree:
  `D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-clean-042`
- violating worktree:
  `D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-violating-042`
- retained evidence:
  `artifacts/guards/p10-ifx-114/c6e-r1-042`

Every path above must be absent before execution. No C6e path may be reused,
overwritten, repaired or treated as C6e-R1 evidence.

## Planned implementation

1. Validate the exact C6d acceptance, stopped C6e decision, base installation,
   accepted Bundle and all frozen hashes before creating an output.
2. Add two detached Git worktrees at the exact certified Target commit. Refuse
   any branch attachment, HEAD mismatch or initial worktree change.
3. Add only
   `src/Modules/CRM/IFX.Modules.CRM.Domain/C6eR1Fault.cs` to the violating
   worktree. It imports `IFX.Modules.CRM.Contracts` from Domain and must produce
   a blocking `IMPORT-DIRECTION` finding from `ifx-source-policy`.
4. Record deterministic pre-run file inventories and Git facts for the base,
   Bundle and both Target worktrees.
5. Create a new production sibling composition and external receipt through
   the installed public composer; verify it through the public composition
   verifier without `AllowSyntheticFixture`.
6. Launch only `Invoke-V4ReceiptedWebCompanion.ps1`, registering both new
   worktrees. Through the browser UI, run direct Pre on clean, switch Target by
   Host project ID, then run direct Pre on violating.
7. Query runs and evidence through the installed Host. Require exact UI/Host
   agreement, clean pass, non-vacuous coverage and the intended blocking
   violation.
8. Recompute inventories and Git facts. The clean worktree must remain clean;
   the violating worktree must retain exactly its one deliberate untracked
   file; all tracked and authority roots must be unchanged.

## Acceptance criteria

- both Target roots are Git worktrees with detached HEAD exactly
  `40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`;
- the new production sibling receipt and package pass public verification;
- clean Web UI Pre passes with ten module results and non-vacuous coverage;
- violating Web UI Pre blocks and includes `IMPORT-DIRECTION` from
  `ifx-source-policy` for the deliberate file;
- installed Host queries match UI run IDs, verdicts, findings, coverage and
  authority hashes;
- protected roots and Git facts match their pre-run records; and
- no P10.2 parity, P10.3 activation, publication, V3 retirement or IFX cutover
  action occurs.

## Planned repository paths

- `docs/guards/plans/20260927-v4-p10-1-114-c6e-r1-git-backed-target-repair.md`
- `docs/guards/plans/20260927-v4-p10-1-114-c6e-r1-git-backed-target-repair.plan.json`
- `docs/guards/candidates/ifx-gate-coverage-c6e2/Invoke-IFX114C6eR1Preparation.ps1`
- `artifacts/guards/p10-ifx-114/c6e-r1-042`

## Stop conditions

Stop without repair, path reuse or rerun on any existing output, frozen
identity mismatch, worktree registration or HEAD mismatch, unexpected Git
status, composition/receipt failure, launcher refusal, clean UI failure,
missing/non-blocking deliberate finding, zero coverage, UI/Host disagreement
or protected-root mutation. Preserve the exact failure evidence. Any further
correction requires another explicit Plan and new absent paths.
