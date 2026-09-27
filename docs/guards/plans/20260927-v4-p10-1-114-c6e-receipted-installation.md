# IFX 1.1.4 C6e receipted composition and installed Web UI plan

Status: `AUTHORIZED — C6e EXECUTION`
Date: 2026-09-27
Base runtime: `v4-guards-1.1.4`
Accepted candidate: `ifx-profile-candidate` version `0.4.2`
C6c target commit: `40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`
C6e evidence root: `artifacts/guards/p10-ifx-114/c6e-042`

## Authorization and boundary

The user explicitly authorized C6e after C6d accepted review packet SHA-256
`25a865b584ea332a54e5f30632f4c3a0b7ccebc3095a83ef4d5fc06433d4fc9f`.
The schema-valid production review record SHA-256 is
`871173d4fc27236c06ff0a0c940c6f2d8a8983771b897878261de092826d8ced`.
This Plan authorizes only receipted local composition, verification and installed
Web UI practice. It does not authorize P10.2 parity, P10.3 activation, V3
retirement, remote publication or IFX cutover.

## Exact inputs

- Base install: `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4`.
- Base receipt:
  `D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4.install.json`.
- Base archive:
  `artifacts/guards/p10-ifx-114/base-archive/v4-guards-1.1.4.zip`, SHA-256
  `dce037149d0fa38995e244ad417888a15d90809467e8ecc83708faef2b995c4d`.
- Accepted Bundle manifest SHA-256:
  `82eb0c5db8ec3779bc10a43b89f0a9235e38d02819745e8f42bffa7fd9635ee5`.
- Production review record:
  `artifacts/guards/p10-ifx-114/c6d-review-042/production-extension-review.json`.

## New external outputs

- Sibling install:
  `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2`.
- Composition receipt:
  `D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4-ifx-0.4.2.compose.json`.
- StateRoot: `D:/IFX-Root/guard-runtime/state/ifx-c6e-042`.
- EvidenceRoot: `D:/IFX-Root/guard-runtime/evidence/ifx-c6e-042`.
- Clean frozen Target:
  `D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-clean-042`.
- Deliberately violating frozen Target:
  `D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-violating-042`.

Every output must be absent before C6e starts. No existing installation,
receipt, fixture, StateRoot or EvidenceRoot may be reused or overwritten.

## Execution

1. Validate the base installation, receipt/archive identities, C6d decision,
   production review schema, accepted manifest and all external output absence.
2. Export the exact C6c Target commit twice without `.git`, generated outputs or
   mutable evidence. Add one bounded source-policy `IMPORT-DIRECTION` violation
   only to the violation fixture. Freeze complete path/size/hash inventories for
   both targets.
3. Invoke the installed public `Compose-V4Extension.ps1` contract without the
   synthetic-fixture switch. Require a new sibling installation and external
   composition receipt, then pass `Test-V4ComposedInstallation.ps1`.
4. Launch only the installed, receipt-gated Web Companion. Register the clean
   and violation fixtures with external mutable roots and select `ifx_profile`.
5. Through the browser, inspect Profile, prerequisites, enabled Stages and
   dependency chain. Run direct Pre on the clean target and direct Pre on the
   deliberate violation target. Require clean `pass` and violation `fail` with
   a visible blocking `IMPORT-DIRECTION` finding.
6. Match UI project IDs, run IDs, verdicts, findings and coverage to installed
   Host `query` results and retained evidence. Recompute all frozen authority
   and target inventories after the browser session.

## Acceptance criteria

- Base 1.1.4, accepted Bundle, C6d review and C6c target identities match the
  exact frozen hashes.
- Composition creates only the new sibling and external receipt and validates
  as a production `local-extension-composition`.
- The installed launcher verifies that receipt before Web Companion start.
- The clean Pre run passes with non-vacuous coverage; the deliberate fixture
  remains visibly blocking and is not relabeled as success.
- UI and installed Host query projections agree on project, run, Stage order,
  verdict, findings, coverage and package identity.
- Base install, base receipt/archive, Bundle, review record, clean target and
  violation target inventories are byte-identical before and after execution.
- State and evidence writes remain confined to the new external mutable roots.
- A final C6e decision records exact receipt, installation, run and root hashes.

## Stop conditions

Stop without repair or path reuse on an existing output, identity mismatch,
composition or receipt failure, launcher receipt refusal, hidden UI failure,
unexpected target/authority mutation, missing/non-blocking deliberate finding,
or Host/UI disagreement. Preserve all evidence. Any correction requires a new
explicit Plan and new absent output paths.
