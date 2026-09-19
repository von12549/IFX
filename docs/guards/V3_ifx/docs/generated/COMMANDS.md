# IFX guard commands

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `a5b74b1b2559896709ee60f214d725945e3c0dd18af5686bb29d1d0fdfa15a3c`

Sources:

- `docs/guards/V3_ifx/shared/commands.json` — command-contract

| Command | Kind | Entry point | Stages | Mutability | Explicit acceptance |
| --- | --- | --- | --- | --- | --- |
| ifx-guardrails | public | `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1` | pre, post, diff, ci | writes-artifacts | False |
| v3-runner | public | `docs/guards/V3/commands/Invoke-V3.ps1` | pre, post, diff | writes-generated | False |
| v3-setup | public | `docs/guards/V3/commands/Invoke-V3Setup.ps1` | bootstrap, analysis | writes-artifacts | False |
| v3-architecture-review | internal | `docs/guards/V3/scripts/Invoke-V3Architecture.ps1` | analysis | writes-artifacts | False |
| v3-docs | public | `docs/guards/V3/commands/Invoke-V3Docs.ps1` | pre, post | writes-generated | False |
| v3-deployment | public | `docs/guards/V3/commands/Invoke-V3Deployment.ps1` | ci | writes-activation | True |
| ifx-architecture | public | `docs/guards/V3_ifx/scripts/Invoke-IFX.ps1` | post | writes-artifacts | False |
| ifx-ci-contract | public | `docs/guards/V3_ifx/ci/Invoke-IFXCiContract.ps1` | ci | read-only | False |
| ifx-manifest-check | public | `docs/guards/V3_ifx/scripts/Invoke-IFXManifestCheck.ps1` | ci | read-only | False |
| ifx-specialized | internal | `docs/guards/V3_ifx/specialized/Invoke-IFXSpecialized.ps1` | post | writes-artifacts | False |
| ifx-quality | internal | `docs/guards/V3_ifx/quality/Invoke-IFXQuality.ps1` | post | writes-artifacts | False |
| ifx-historical-integrity | internal | `docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1` | post | writes-artifacts | False |
| ifx-policy-sync | maintenance | `docs/guards/V3_ifx/maintenance/Sync-IFXPolicyInputs.ps1` | post | writes-authority | True |
| ifx-history-manifest | maintenance | `docs/guards/V3_ifx/maintenance/New-IFXHistoryManifest.ps1` | post | writes-authority | True |
| ifx-analysis-evidence | maintenance | `docs/guards/V3_ifx/maintenance/Update-IFXAnalysisEvidence.ps1` | analysis | writes-authority | True |
| ifx-refactor-baseline | maintenance | `docs/guards/V3_ifx/analysis/ifx/refactor-baseline/tools/New-RefactorBaseline.ps1` | analysis | writes-authority | True |
| ifx-trusted-base | internal | `docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1` | ci | writes-artifacts | False |
| ifx-tcb-candidate | internal | `docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1` | ci | writes-artifacts | False |
| ifx-trusted-base-authorization | maintenance | `docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1` | diff | writes-authority | True |

## ifx-guardrails

- Audiences: ci, human
- Inputs: docs/guards/V3_ifx/profiles/ifx/; docs/guards/V3_ifx/policy/; docs/guards/V3_ifx/history/manifest.json; formal Plan (Pre/Diff); clean base worktree plus explicit BaseSha (-TrustedBase); reviewed head candidate test suites (CandidateTests)
- Outputs: artifacts/guards/v3-ifx/
- Evidence: artifacts/guards/v3-ifx/summary-<mode>.json

## v3-runner

- Audiences: ci, agent, human
- Inputs: docs/guards/V3_ifx/profiles/ifx/; docs/guards/V3/templates/dotnet/; formal Plan (Pre/Diff); docs/guards/V3/build/; docs/guards/V3_ifx/build/locks/
- Outputs: <generation-root>/v3-ifx/gates/stage/; artifacts/guards/v3-ifx/; artifacts/build/v3-ifx/stage-gate/; artifacts/guards/v3-ifx/build/stage-gate/
- Evidence: artifacts/guards/v3-ifx/pre.json; artifacts/guards/v3-ifx/summary-diff.json

## v3-setup

- Audiences: agent, human
- Inputs: repository tree
- Outputs: artifacts/guards/<package>/analysis/
- Evidence: artifacts/guards/<package>/analysis/inventory.json

## v3-architecture-review

- Audiences: agent, human
- Inputs: docs/guards/V3_ifx/stages/analysis/evidence/ARCHITECTURE.md; docs/guards/V3_ifx/stages/analysis/evidence/TECHNICAL.md; docs/guards/V3_ifx/profiles/ifx/
- Outputs: artifacts/guards/v3-ifx/analysis/
- Evidence: artifacts/guards/v3-ifx/analysis/architecture-review.json

## v3-docs

- Audiences: agent, human
- Inputs: docs/guards/V3_ifx/docs/docs-map.json; docs/guards/V3_ifx/profiles/ifx/; declared authority and trust-contract sources
- Outputs: docs/guards/V3_ifx/docs/generated/; docs/guards/V3_ifx/profiles/ifx/views/
- Evidence: (none)

## v3-deployment

- Audiences: ci, agent, human
- Inputs: docs/guards/V3_ifx/stages/ci/activation.json; docs/guards/V3_ifx/stages/ci/workflow.template.yml; docs/guards/V3_ifx/stages/ci/workflow.variables.json; docs/guards/V3_ifx/stages/ci/codeowners.template
- Outputs: artifacts/generated/v3-ifx/activation/; .github/workflows/v3-ifx-guardrails.yml (Install only); .github/CODEOWNERS managed block (Install only)
- Evidence: optional -ReportPath JSON

## ifx-architecture

- Audiences: ci, validation-command, human
- Inputs: docs/guards/V3_ifx/policy/layerguard.json; docs/guards/V3_ifx/templates/ifx-layerguard/; docs/guards/V3/build/; docs/guards/V3_ifx/build/locks/
- Outputs: artifacts/guards/v3-ifx/architecture/; artifacts/build/v3-ifx/architecture-conformance/; artifacts/guards/v3-ifx/build/architecture-conformance/
- Evidence: artifacts/guards/v3-ifx/architecture/layerguard.json

## ifx-ci-contract

- Audiences: ci, human
- Inputs: .github/workflows/v3-ifx-guardrails.yml; docs/guards/V3_ifx/stages/ci/required-checks.json; GitHub ruleset (read-only, -Remote)
- Outputs: 
- Evidence: optional -ReportPath JSON

## ifx-manifest-check

- Audiences: ci, human
- Inputs: docs/guards/V3_ifx/guard-system.json; docs/guards/V3_ifx/shared/; docs/guards/V3_ifx/stages/; docs/guards/V3_ifx/contracts/; .github/workflows/v3-ifx-guardrails.yml; docs/guards/V3_ifx/stages/ci/required-checks.json
- Outputs: 
- Evidence: (none)

## ifx-specialized

- Audiences: ci
- Inputs: docs/guards/V3_ifx/policy/; repository source and documentation
- Outputs: artifacts/guards/v3-ifx/specialized/
- Evidence: artifacts/guards/v3-ifx/specialized/summary.json

## ifx-quality

- Audiences: ci
- Inputs: IFX.sln; src/Frontend/IFX.FrontEnd/
- Outputs: artifacts/guards/v3-ifx/quality/
- Evidence: artifacts/guards/v3-ifx/quality/summary.json

## ifx-historical-integrity

- Audiences: ci
- Inputs: docs/guards/V3_ifx/history/manifest.json
- Outputs: artifacts/guards/v3-ifx/history/
- Evidence: artifacts/guards/v3-ifx/history/summary.json

## ifx-policy-sync

- Audiences: human
- Inputs: docs/guards/V3_ifx/policy/authorities.json; domain-owned policy sources
- Outputs: docs/guards/V3_ifx/policy/
- Evidence: (none)

## ifx-history-manifest

- Audiences: human
- Inputs: tracked historical evidence
- Outputs: docs/guards/V3_ifx/history/manifest.json
- Evidence: (none)

## ifx-analysis-evidence

- Audiences: human
- Inputs: reviewed analysis input or frozen report snapshot
- Outputs: docs/guards/V3_ifx/stages/analysis/evidence/; docs/guards/V3_ifx/stages/analysis/reports/
- Evidence: (none)

## ifx-refactor-baseline

- Audiences: human
- Inputs: baseline commit Git objects
- Outputs: docs/guards/V3_ifx/analysis/ifx/refactor-baseline/
- Evidence: (none)

## ifx-trusted-base

- Audiences: ci
- Inputs: clean base worktree at the verified base SHA; head checkout as -HeadRoot; docs/guards/V3_ifx/policy/authorities.json
- Outputs: artifacts/guards/v3-ifx/trusted-base/
- Evidence: artifacts/guards/v3-ifx/trusted-base/summary-<mode>.json

## ifx-tcb-candidate

- Audiences: ci
- Inputs: clean base worktree at the verified base SHA; docs/guards/V3_ifx/shared/trusted-components.json; docs/guards/V3_ifx/stages/diff/authorizations/
- Outputs: artifacts/guards/v3-ifx/trusted-base/
- Evidence: artifacts/guards/v3-ifx/trusted-base/tcb-candidate.json

## ifx-trusted-base-authorization

- Audiences: human
- Inputs: prepared change revision; docs/guards/V3_ifx/shared/trusted-components.json
- Outputs: docs/guards/V3_ifx/stages/diff/authorizations/
- Evidence: (none)
