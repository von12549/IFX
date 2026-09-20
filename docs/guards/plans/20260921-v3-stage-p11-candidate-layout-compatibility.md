# P11 candidate-layout compatibility bridge

This second bridge lets the trusted base validate the final P11 layout after D36 exposed the candidate public facade and aggregate publication. It changes representation compatibility only; it does not authorize or exempt the final P11 change.

## Scope

- Let a formal aggregate plan name exact paths and area IDs introduced after the base profile, but only when both the plan id and filename end in `-aggregate`.
- Let the base policy verifier schema-validate the candidate policy and authority registries, classify their exact candidate paths, and validate candidate schemas, profile views, history and projections from the candidate tree.
- Let the legacy Markdown renderer check a split profile layout as generated read-only views with repository-relative provenance. Legacy editable views and Import keep their existing behavior.
- Let the authority projection generator accept exactly one legacy or stage-owned policy layout and exactly one legacy or shared authority registry.

## Security invariants

- The real Diff must still equal `plannedPaths`; an aggregate plan does not permit out-of-plan paths.
- Candidate registries classify changes but cannot authorize them. Their own semantic changes remain protected.
- Unknown policy JSON, `.gitattributes`, dual layouts, traversal, absolute paths and split-layout Import fail closed.
- Candidate executables never replace base-owned verification logic.

## Validation

1. V3 plan tests cover ordinary-plan rejection, aggregate exact success and aggregate out-of-plan failure.
2. IFX tools tests cover legacy editable views, split read-only views, exact provenance and traversal rejection.
3. Authority projection tests cover legacy and stage-owned layouts plus drift rejection.
4. From the independent base worktree at `67551a8959806fad61e6648c7573543fa204d2b2`, candidate `c2a072d87abb1cde7596e298c7c8fe3deb891462` passes policy-candidate validation. Protected classification has zero unregistered paths and leaves 645 explicit authorization obligations.

## Rollback

Reverting this bridge restores the old single-directory candidate assumptions. It neither consumes nor changes final P11 authorization records.
