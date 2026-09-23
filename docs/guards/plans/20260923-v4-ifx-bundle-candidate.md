# V4 P10.1 — source-derived IFX bundle candidate

Status: `SOURCE-BOUND DRAFT BUILT — static checks pass; production review blocked`

On 2026-09-23 the user authorized construction of a candidate from existing IFX authority
materials. This is not Xiaolong Feng's acceptance of fixed bundle bytes or capability
ceilings, and it does not authorize composition, installation, Stage/UI practice, parity,
remote governance changes or cutover.

## Scope and source boundary

Build a separate, versioned `ifx_profile` candidate outside the released V4 package and
outside both installed releases. Bind the exact V3_ifx source commit and SHA-256 values of
the profile identity, project map, toolchain, architecture policy, G03/G04/G05 authorities
and baseline. Do not copy V3 runtime commands into the bundle, claim V3/V4 parity, or
silently translate unsupported policy as if it were enforced.

The initial candidate selects only a V4 built-in detector with a defensible source mapping.
The source map must explicitly distinguish mapped, partial and missing IFX claims. Request
no new extension-module capabilities until each module and dependency is implemented and
reviewed. The bundle manifest must have a complete ordinally sorted file inventory, bind
every file size and SHA-256, and validate under the released 1.1.1 bundle/Profile schemas.

## Validation and stop conditions

Run Formal Pre before candidate edits, then validate source hashes, schema, file inventory,
profile/module references and the published 1.1.1 base identity. Run exact Formal Diff
after freezing the candidate. A candidate with missing detector-family or root-confinement
coverage must remain `NOT READY FOR HUMAN ACCEPTANCE`; do not manufacture an accepted
`extension-review` record or call the composer. If further modules or V4 core changes are
needed, expand this Plan and rerun Formal Pre before implementation.

The human-review record, when appropriate, must be a separate decision by
`xiaolong-feng` over the final manifest hash, complete inventory and per-module ceilings.
Any change to candidate bytes invalidates that future decision.

## Draft checkpoint (2026-09-23)

The source snapshot is commit `a0bb723dc8030fc5ebabda44ffe0a2f000e55dac`.
Candidate `ifx-profile-candidate` version `0.1.0` targets V4 base `1.1.1` and adds
Profile `ifx_profile` version `0.1.0`. It selects the released
`architecture-conformance` module for Pre-stage
`ARCH.GRAPH_COMPLETENESS` only; it adds zero modules and requests zero new capabilities.
The bundle manifest SHA-256 is
`c8bf10e9ce148b96f3178c3e44d9095360a3167a7323b8cd315b98c08a79a07e`.

The released 1.1.1 bundle/Profile/module-config schemas passed, as did the complete
ordinally sorted two-file inventory (size and SHA-256), the eight source-authority hashes,
the Profile binding and the installed base-version check. The candidate is intentionally
not composed or installed; no human-review acceptance record exists.

Production-scope review is blocked. The 1.1.1 architecture adapter enumerates project
and source files from the entire TargetRoot, so `projectIdentity.relativeRoots` cannot
enforce the proposed `src`/`tests` IFX scope or exclude `guard/**`. The G03/G04/G05
specialized gates, most architecture claims, IFX toolchain prerequisites, baselines,
Bootstrap/Analysis/Post ownership and detector-family zero-match proofs are also absent.
Those are substantive coverage gaps, not grounds for implicit approval. The next revision
must implement and test exact IFX module/detector mappings or obtain a separate public
compatibility decision; any changed bundle bytes require a fresh manifest hash and review.
