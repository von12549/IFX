# P11 minimal compatibility bridge — aggregate publication and public facade

This checkpoint prepares the existing `codex/guards-principles-plan` trusted base to evaluate the already completed P11 candidate layout. It is a compatibility release, not the P11 publication itself.

## Scope

- Resolve one changed formal plan normally; when several historical plan files are published together, require exactly one changed `*-aggregate.plan.json` and pass only that plan to Diff.
- Let the old CI contract verify the new public guard facade, including base-worktree gate provenance, base-owned scope classification, ordinary Windows smoke, Ubuntu full coverage and the P11.4 Windows full dispatch route.
- Let the old manifest verifier recognize only a target workflow entry that exists and is covered by a schema-valid active candidate TCB.
- Let protected-change discovery classify newly laid-out JSON with a schema-valid candidate policy registry. The registry is still a base-registered trust/meta-policy file, so changing its semantics remains a `weaken-policy` obligation.

## Non-goals

- No protected deletion, TCB change or policy weakening is exempted.
- No broad directory exclusion is introduced.
- No required check, runner, ruleset context or strict policy changes.
- This pair does not mark P11.4 complete and does not activate the final candidate.

## Validation

1. CI contract positive and negative fixtures pass, including aggregate-plan selector removal.
2. Manifest fixtures pass; an unregistered workflow executable still fails.
3. Trusted-base Diff fixtures prove that an unregistered JSON still fails, while a candidate-registry exact path is routed to the ordinary `weaken-policy` obligation.
4. From an isolated base worktree, the bridge validates the final P11 candidate tree; its remaining protected-change obligations are handled only by separate authorization PRs.

## Rollback

Reverting the bridge restores single-plan-only publication and legacy internal entry recognition. It does not consume or alter final P11 authorizations.
