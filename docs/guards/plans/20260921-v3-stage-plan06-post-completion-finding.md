# Plan 06 post-completion finding — V3 portable layout was not completed

Finding ID: `P06-PCF-01`

Recorded: 2026-09-21

Status: accepted; in-place Plan 08 remediation cancelled; disposition deferred to V4 design

Base branch: `codex/guards-principles-plan`

## Finding

Plan 06 correctly established `docs/guards/V3` as the single canonical portable engine and
`docs/guards/V3_ifx` as an IFX overlay that references V3. The implementation also moved the generic
Architecture Conformance engine into V3, upstreamed the hardened Stage Gate behavior, added the
package-local build baseline and removed the executable/script/test forks from V3_ifx.

The physical package-layout portion of Plan 06 was not completed for V3, however. Plan 06 section 5
described one stage-oriented ownership model for both packages and section 13 explicitly mapped V3
`templates/dotnet/` to `generators/stage-gate/`. P10.3 required internal implementation under
`engine/`, generators under `generators/`, agent integrations under `integrations/`, maintenance tools
under `maintenance/` and tests grouped by Stage. CP11a through CP11r applied those classifications
primarily to V3_ifx and then marked P10 complete without an equivalent V3 migration checkpoint.

The current V3 root therefore still contains the pre-target top-level layout:

- `architecture/`, `contracts/`, `generated/`, `hooks/`, `rules/`, `scripts/`, `skills/`, `templates/`
  and a flat `tests/` directory;
- no V3 `guard-system.json`, `shared/`, `engine/`, `generators/`, `integrations/`, `maintenance/` or
  package `docs/` authority;
- only the generic Architecture Conformance implementation is already under a Stage-owned path.

This is a completion-scope defect, not evidence that V3_ifx should mirror V3 and not evidence of a
second executable engine. V3_ifx is expected to retain IFX-only profile, policy, baseline, binding,
specialized gates, trusted-base, CI, maintenance and evidence content. A byte-hash audit found only
eight cross-root duplicate groups: three schemas, four minimal example inputs and one example Plan;
it found no duplicate PowerShell or C# generic implementation.

## Why existing validation passed

Current manifests, trusted-component declarations and tests consistently point to the existing V3
paths, including `V3/templates/dotnet/`, `V3/scripts/ProfileLayout.psm1` and the flat V3 test paths.
They prove that the current composition is internally consistent, isolated and fail-closed; they do
not compare the V3 tree with Plan 06's target layout. The completion ledger consequently treated
behavioral parity and absence of V3_ifx forks as sufficient evidence for P10.

On 2026-09-21 the following current-tree checks passed while the structural mismatch remained:

- `Invoke-IFXArchitecture.ps1 -Mode Check`;
- `Invoke-IFXGuardrails.ps1 -Mode Validate`, including six stages, nineteen commands, seventeen
  trusted components, thirteen gates, twenty generated documents and the thirteen-check CI contract.

This demonstrates a missing plan-conformance assertion rather than a failing runtime composition.

## Impact

1. V3 remains usable as the canonical portable source package and V3_ifx currently consumes it
   correctly.
2. V3's ownership boundaries are less explicit than V3_ifx's and differ from the approved Plan 06
   target. New consumers can reasonably infer the wrong extension and maintenance boundaries.
3. Current CI cannot prevent the legacy V3 top-level layout from becoming permanent because it
   declares those paths as the active trusted layout.
4. Treating Plan 06 as fully complete without this qualification makes its P10.3 evidence and CP11
   completion statement broader than the executed checkpoints support.

## Disposition

- Preserve the immutable authorization, PR and CI history of Plan 06.
- Do not reinterpret V3_ifx-only content as missing V3 content and do not make the overlay
  self-contained.
- Record this qualification in the Plan 06 closeout.
- The in-place V3 remediation proposed by Plan 08 was cancelled on 2026-09-21. Retain that document as
  a rejected-alternative record; do not execute its checkpoints.
- Carry this finding into the separately designed V4 product boundary. V4 is intended to be one
  self-contained guard plugin with project profiles rather than another V3/V3_ifx package pair; its
  planning baseline is [`docs/guards/v4/plans/`](../v4/plans/README.md).
- Keep current V3 and V3_ifx active and unchanged until a reviewed V4 plan defines coexistence,
  activation, rollback and retirement. A future V4 plan may supersede this finding instead of moving
  the V3 tree in place, but it must say so explicitly.
- No move, deletion, compatibility bridge, TCB change, CI activation or remote action is authorized by
  this finding or by the planning checkpoint that records it.

## Closure criteria

This finding may be closed or superseded only when the future V4 plan has:

- explicitly accepted that Plan 06 did not complete the proposed V3 physical layout and stated whether
  V3 is retained, frozen or retired;
- established V4 as a single unambiguous authority without creating simultaneous writable generic
  implementations;
- defined and verified profile, state, reset, stage execution and project-isolation contracts;
- defined V3/V3_ifx coexistence, cutover, rollback and retirement with fail-closed validation; and
- proved the selected V4 distribution and activation model on Linux and Windows.
