# IFX I2-C review packet (C4)

Plan `20261001-v4-ifx-i2c-main-promotion`. Repository head `e7fce33679617a754410dc1f354960f74dd07f72`.

## Remote state (C1, GET only)

- `main` `ecb03726a6c67208d25e7988695c53f6326d77c0`; target `codex/guards-principles-plan` `57647c9ae75c25666d825477c7a1ea11073468c5` (PR #107 merge, 13/13 on 2026-09-21); linear, 569 commits apart.
- Ruleset 23459908 canonical SHA-256 `857a51aaf9590758aa37ab0daf234695ba6e3a434644e598026d741b2c7d6f4a`; no bypass; 13 contexts, strict; no open pull requests; default branch `main`.

## Pull requests

| PR | Branch | Content | Authorization |
| --- | --- | --- | --- |
| P1 | `codex/i2c-p1-drain-wait-fix` | `src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainCoordinator.cs`<br>`tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.cs`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p1-drain-wait-fix.md`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p1-drain-wait-fix.plan.json` | none (no protected change) |
| P2 | `codex/i2c-p2-g03-documentation` | `docs/architecture/review/evidence/gates/G03/G03-closeout.md`<br>`docs/architecture/review/gates/G03/contract-event-governance.en.md`<br>`docs/architecture/review/gates/G03/contract-event-governance.zh-CN.md`<br>`docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json`<br>`docs/guards/V3_ifx/shared/policy-config.json`<br>`tests/IFX.IntegrationTests/Composition/Plan06DependencyBoundaryTests.cs`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p2-g03-documentation.md`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p2-g03-documentation.plan.json` | P2a first: `i2c-g03-documentation-trusted-base` (change-trusted-base), `i2c-g03-documentation-policy` (weaken-policy) |
| P3 | `codex/i2c-p3-v4-adoption-admission` | `docs/guards/V3_ifx/shared/decisions/history/20261001-v4-ifx-i2c-v4-adoption-admission.json`<br>`docs/guards/V3_ifx/shared/policy-config.json`<br>`docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p3-v4-adoption-admission.md`<br>`docs/guards/plans/20261001-v4-ifx-i2c-p3-v4-adoption-admission.plan.json`<br>`docs/guards/v4-adoption/README.md` | P3a first: `i2c-v4-adoption-admission-trusted-base` (change-trusted-base), `i2c-v4-adoption-admission-policy` (weaken-policy) |

Copied paths are byte-identical to `5f6008ee` on the development branch; authored files are under `docs/guards/candidates/ifx-i2c/pr/`.

### P3: the allowlist change

```diff
diff --git a/docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1 b/docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1
index 88630b14..b4567d63 100644
--- a/docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1
+++ b/docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1
@@ -47,12 +47,13 @@ $restoredCompatibilityPaths = @($retiredCompatibilityPaths | Where-Object { Test
 if ($restoredCompatibilityPaths.Count -gt 0) { throw "Retired compatibility paths remain: $($restoredCompatibilityPaths -join ', ')" }
 if (@($system.compatibility.entries).Count -ne 0) { throw 'Plan 06 P11.5 requires the compatibility registry to be empty.' }
 $topLevel = @(Get-ChildItem -LiteralPath (Join-Path $root 'docs/guards') -Force | ForEach-Object Name | Sort-Object)
-$expectedTopLevel = @('plans', 'V3', 'V3_ifx') | Sort-Object
-if (@(Compare-Object $expectedTopLevel $topLevel).Count -ne 0) {
+# Decision 20261001-v4-ifx-i2c-v4-adoption-admission admits exactly one V4 adoption entry; every other entry still fails.
+$expectedTopLevel = @('plans', 'V3', 'V3_ifx', 'v4-adoption') | Sort-Object
+if (@(Compare-Object -CaseSensitive $expectedTopLevel $topLevel).Count -ne 0) {
     throw "docs/guards top level contains an unexpected entry: $($topLevel -join ', ')"
 }
 $v3Workflow = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/v3-ifx-guardrails.yml')
 foreach ($trigger in @('pull_request', 'push', 'workflow_dispatch')) {
     if ($v3Workflow -notmatch "(?m)^  ${trigger}:") { throw "V3 workflow is missing its $trigger trigger." }
 }
-Write-Host "Cutover preservation passed: $($required.Count) required paths, $($baselines.Count) historical baselines, $($deletionManifest.deletedPaths.Count) prior retired paths absent, nine compatibility paths retired, compatibility registry closed, V3_backup retired and one V3 workflow active."
+Write-Host "Cutover preservation passed: $($required.Count) required paths, $($baselines.Count) historical baselines, $($deletionManifest.deletedPaths.Count) prior retired paths absent, nine compatibility paths retired, compatibility registry closed, V3_backup retired, one V4 adoption entry admitted and one V3 workflow active."
```

### P3: decision registration

```diff
diff --git a/docs/guards/V3_ifx/shared/policy-config.json b/docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/shared/policy-config.json
index 91715aed..67e998e9 100644
--- a/docs/guards/V3_ifx/shared/policy-config.json
+++ b/docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/shared/policy-config.json
@@ -288,7 +288,8 @@
         "docs/guards/V3_ifx/shared/decisions/history/20260921-v3-stage-d36-p11-minimal-compat-bridge.json",
         "docs/guards/V3_ifx/shared/decisions/history/20260921-v3-stage-d37-p11-candidate-layout-compatibility.json",
         "docs/guards/V3_ifx/shared/decisions/history/20260921-v3-stage-d38-cross-platform-inventory-bytes.json",
-        "docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json"
+        "docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json",
+        "docs/guards/V3_ifx/shared/decisions/history/20261001-v4-ifx-i2c-v4-adoption-admission.json"
       ],
       "format": "json",
       "schema": "docs/guards/V3/contracts/decision.schema.json",
```

## Rehearsal (C3)

Status **pass**; parity full fixed corpus; solution quality run: True. Every verdict came from the simulated base's own trusted runner, verifier and generator.

| Step | Expected exit | Exit | As expected |
| --- | --- | --- | --- |
| `p1-diff` | 0 | 0 | True |
| `p1-validate` | 0 | 0 | True |
| `p1-candidate-tests` | 0 | 0 | True |
| `p1-architecture` | 0 | 0 | True |
| `p1-historical` | 0 | 0 | True |
| `p1-quality-solution` | 0 | 0 | True |
| `p2-early-diff` | 1 | 1 | True |
| `p2-authorization-diff` | 0 | 0 | True |
| `p2-authorization-candidates` | 0 | 0 | True |
| `p2-authorization-validate` | 0 | 0 | True |
| `p2-change-diff` | 0 | 0 | True |
| `p2-change-candidates` | 0 | 0 | True |
| `p2-change-policy-candidates` | 0 | 0 | True |
| `p2-change-validate` | 0 | 0 | True |
| `p2-change-candidate-tests` | 0 | 0 | True |
| `p2-change-architecture` | 0 | 0 | True |
| `p2-change-historical` | 0 | 0 | True |
| `p2-change-g03` | 0 | 0 | True |
| `p3-early-diff` | 1 | 1 | True |
| `p3-authorization-diff` | 0 | 0 | True |
| `p3-authorization-candidates` | 0 | 0 | True |
| `p3-authorization-validate` | 0 | 0 | True |
| `p3-change-diff` | 0 | 0 | True |
| `p3-change-candidates` | 0 | 0 | True |
| `p3-change-policy-candidates` | 0 | 0 | True |
| `p3-change-validate` | 0 | 0 | True |
| `p3-change-candidate-tests` | 0 | 0 | True |
| `p3-change-architecture` | 0 | 0 | True |
| `p3-change-historical` | 0 | 0 | True |
| `p3-change-g03` | 0 | 0 | True |
| `p3-allowlist-positive` | 0 | 0 | True |
| `p3-allowlist-extra-entry` | 1 | 1 | True |
| `p3-allowlist-case` | 1 | 1 | True |
| `p3-allowlist-missing` | 1 | 1 | True |
| `p3-base-test-rejects` | 1 | 1 | True |
| `p3-replay-diff` | 1 | 1 | True |

### Generated records (rehearsal; regenerated on the real base in C6/C7)

- `docs/guards/V3_ifx/stages/diff/authorizations/i2c-g03-documentation-policy.json` (weaken-policy): docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json, docs/guards/V3_ifx/shared/policy-config.json
- `docs/guards/V3_ifx/stages/diff/authorizations/i2c-g03-documentation-trusted-base.json` (change-trusted-base): docs/guards/V3_ifx/shared/policy-config.json
- `docs/guards/V3_ifx/stages/diff/authorizations/i2c-v4-adoption-admission-policy.json` (weaken-policy): docs/guards/V3_ifx/shared/decisions/history/20261001-v4-ifx-i2c-v4-adoption-admission.json, docs/guards/V3_ifx/shared/policy-config.json
- `docs/guards/V3_ifx/stages/diff/authorizations/i2c-v4-adoption-admission-trusted-base.json` (change-trusted-base): docs/guards/V3_ifx/shared/policy-config.json, docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1

### Final state of the simulated target

- `docs/guards`: plans, V3, V3_ifx, v4-adoption
- `docs/guards/v4-adoption`: README.md
- remaining authorization records: 0; blob mismatches: 0

Not run locally (CI runs them on every pull request): v3-quality-assembly, v3-quality-frontend, v3-specialized-g04, v3-specialized-g05, v3-specialized-plan04, v3-specialized-database, v3-cross-platform-ubuntu-latest, v3-cross-platform-windows-latest (candidate suite).

## Remote steps after acceptance (each separately authorized)

| Step | Action | Then |
| --- | --- | --- |
| C5 | P1: push codex/i2c-p1-drain-wait-fix, open PR to codex/guards-principles-plan | merge (merge commit) after 13/13 |
| C6 | P2a: regenerate the two records on the then-current target head, push and open the authorization PR | merge after 13/13; then P2: push and open the change PR consuming both records; merge after 13/13 |
| C7 | P3a: regenerate the two records, push and open the authorization PR | merge after 13/13; then P3: push and open the change PR; merge after 13/13 |
| C8 | Set the default branch to codex/guards-principles-plan | GET verify |
| C9 | git push origin <target head>:refs/heads/main (fast-forward, no force) | GET verify; irreversible |
| C10 | Set the default branch back to main | Invoke-IFXCiContract.ps1 -Remote; ruleset equals C1 |
| C12 | Push the development branch (after C11 records) | GET verify |

## Questions

- Accept the three pull requests (P1, P2 with P2a, P3 with P3a), their V3 plans and the admission decision as prepared?
- Accept the rehearsal as the local proof, with the listed contexts left to CI?
- After acceptance, C5 (push and open P1) needs its own authorization.
