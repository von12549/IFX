# CP12a — Final parity and isolated-package verification

This checkpoint records the local verification boundary for Plan 06 P11.1–P11.3. It changes no runtime, generated view, trusted component or policy input. The evidence is produced from the clean CP11 final tree at commit `63ae9f6521d035a6fafb43533a3518842d10ad94`.

## Verification result

- `CandidateTests -CandidateSuite Architecture` passed. The suite covers Pre, Post Architecture, assembly, specialized, historical-integrity, deployment, manifest, CI-contract and protected-change authorization positive and negative cases.
- `CandidateTests -CandidateSuite CrossPlatform` passed with a repository-external generation root. The suite covers generic V3 positive and negative parity, target-root separation, IFX domain authorities, the base-owned trusted-base matrix and isolated package build.
- `Test-V3.ps1`, reached by the CrossPlatform suite, bootstrapped a blank synthetic Git fixture and exercised runnable Validate, Generate, Check, Test/Post, Pre and Diff gates.
- `Test-V3BuildBaseline.ps1`, reached by the CrossPlatform suite, copied the V3 source package outside the IFX tree and proved locked restore, content-hash enforcement, dependency completeness and pre/post-build import isolation under hostile parent configuration.
- `Invoke-V3Deployment.ps1 -Mode Generate`, `-Mode Check` and `-Mode Preview` passed. Preview classified the active workflow and CODEOWNERS as legacy-equivalent; activation is intentionally deferred to the separately authorized P11.4 checkpoint.
- `Invoke-IFXCiContract.ps1 -Remote` passed against the GitHub ruleset, confirming the 13 strict required checks without mutating remote state.

## Fail-closed matrix

The two candidate suites exercise the P11.2 matrix, including protected deletion and moves, case-only rename, gitlink, duplicate or repeated authorization consumption, unknown schema and command values, unauthorized policy weakening, head-side dispatcher/engine/policy/test tampering, non-equivalent TCB changes, missing generated output, hash and policy drift, lock/content/import drift, shallow history, empty diff and target-root escape.

## Boundary

This checkpoint is evidence-only. It does not activate the candidate workflow, change required checks, delete compatibility wrappers, or claim P11.4–P11.6. Those operations remain separate because activation requires explicit authorization and cleanup is gated on activation plus rollback proof.
