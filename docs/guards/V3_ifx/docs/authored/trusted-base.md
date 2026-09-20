# Trusted base guard execution: guarantees and break-glass

Plan 06 §11 moves every guard verdict to the base commit. This page states what that does and does not guarantee (§11.4), and the only way to proceed when the base engine itself is wrong (§11.7).

## Guarantee scope

The workflow definition and the Git-side approval settings are outside the trust boundary. Plan 06 §18 O1 defers tightening them. The claims below all assume that `.github/workflows/v3-ifx-guardrails.yml` has not been modified to bypass the trusted base.

Within that scope:

- **Judging gates** (`v3-pre-diff`, `v3-specialized-g03`/`g04`/`g05`/`plan04`, `v3-historical-integrity`): a PR head cannot change the verdict by modifying the public entry point, dispatcher, modules, `commands.json`, engine scripts, contracts, package policy, authorizations, or MSBuild/NuGet/SDK inheritance files. The base runner executes from a clean base worktree and reads head only as the target.
- **Domain authorities** (D18, D25): head content is compared with base by the role recorded in `shared/authorities/authorities.json`, as Git objects of the explicit pull request head. Declarations may change in a single PR. A governing-policy change, or any widening of an exception, needs a base `weaken-policy` authorization.
- **Mixed and executing gates** (`v3-architecture`, `v3-quality-*`, `v3-specialized-database`, `v3-cross-platform-*`): each gate's guarantee is the one stated in its trust contract in `stages/*/stage.json`. Executing gates build and run head code; base fixes only the commands, arguments, exit-code judgement and required evidence.
- **Trusted components** (§11.5): the current PR is always judged by the base components. A change to a trusted component needs a base `change-trusted-base` authorization that the change PR deletes. The head candidate must pass the base-owned validation and parity.
- **Protected changes** (§12.3, D22, D23): in `v3-pre-diff`, the base verifier derives obligations from the committed diff (read without rename detection): each protected path removal, plus any trusted component change.
  - Each obligation must be covered by exactly one base authorization that the PR deletes. Uncovered, duplicate and unused authorizations fail.
  - Each semantic change of registered policy or configuration (`shared/policy-config.json`) needs a `weaken-policy` authorization, and a trust/meta-policy change needs it in addition to `change-trusted-base` (D24). Head policy candidates are validated by base engines from the head commit's Git objects.
  - Operations not yet enabled fail closed. So do unregistered policy files, gitlinks in the protected scope and changed authorization records.
  - D18 governing-policy and exception findings pass only when the base verifier, recomputed for the explicit pull request head commit, finds each covered by exactly one consumed `weaken-policy` authorization (D25). Without an explicit head they fail closed.
  - The Diff stage exempts only the deletions listed in the verifier's report, which is bound to base, merge base, head and the protection configuration.
  - Deleting unused authorizations is allowed only in a revocation-only PR.

These rules make trusted component and protected path changes explicit and traceable. They do not stop an unreviewed two-step sequence (authorize, then change) while O1 is deferred.

Do not describe the guards as offering more than this.

## First introduction (D19)

The PR that switched the workflow to the trusted base (CP04d) was judged by the CP04c base runner. Trusted component verification and the activation contract are read from the base commit, so they first applied to the next PR. That PR must show that they block. The exception applies once and must not be reused.

## Break-glass

If the base engine produces a false failure, a fix PR is blocked by that same engine. There is no bypass inside the repository, and none may be added. The only way out is external governance of the repository settings:

1. An administrator with ruleset rights authorizes the break-glass. A second maintainer reviews it.
2. The administrator makes the smallest possible temporary ruleset change, for example removing one required check from ruleset 23459908 for the fix PR's merge.
3. The fix PR merges.
4. The ruleset is restored immediately. `commands/Invoke-IFXCiContract.ps1 -Remote` must pass, proving 13 required checks and `strict`.
5. After restoration, a follow-up PR shows the affected check passing on a normal case and failing on a negative case.

Record the following for every break-glass, as an evidence file under `docs/architecture/review/evidence/` added in the follow-up PR:

| Field | Content |
| --- | --- |
| Authorizer and reviewer | GitHub handles |
| Reason | The false failure, with a link to the failing run |
| Affected checks | Required check names |
| Start and restore time | UTC timestamps |
| Temporary ruleset change | Exact settings before and during |
| Restored configuration proof | `Invoke-IFXCiContract.ps1 -Remote` report |
| Post-restore verification | Runs showing the normal and negative cases |
