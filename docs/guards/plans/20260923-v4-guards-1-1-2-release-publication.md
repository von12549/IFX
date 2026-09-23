# V4 Guards 1.1.2 — scope compatibility patch publication

Status: `AUTHORIZED — release-safe source and publication pending`

On 2026-09-23 the user authorized publication of the 1.1.2 patch. This Plan is
limited to the certified TargetRoot scan-scope change and release-safe package
documentation. It does not approve the incomplete IFX bundle, compose an IFX
installation, activate a workflow/ruleset, cut over from V3, or retire 1.1.1.

## Frozen predecessor and release-safe source

The local 1.1.2 candidate source checkpoint is
`46d1a99fb34c92639d2a484612fab58195903a9d`. Windows-full passed 34 tests
and pinned, network-disabled Linux-complete passed 33 tests with Package hash
`339becabfd0124aaa8bd5ef2c78dbfc76093bda2c823c7c7d7ce0a787a289bdb`.
Its local archive SHA-256 is
`7a6d1582a695d9857149da185aa8b4209addce061ab4976bcc718fbbfdd5901b`.
The 0.2.0 IFX draft is a later documentation-only commit and remains unaccepted.

The packaged README and candidate notes still say 1.1.2 is uncertified or unpublished.
Replace those statements with release-safe text and release notes while preserving
the API, product/module versions, implementation, contracts and built-in Profiles.
The packaged release must explicitly exclude any real `ifx_profile` and avoid
suggesting that scope repair closes the remaining IFX gates.

Formal Pre must pass on the exact paths before edits, followed by a clean source
commit and exact Formal Diff. Rebuild from that commit and rerun Windows-full and
pinned, `--network none` Linux-complete. Require identical Package hashes across
both platforms, deterministic ZIP output, manifest/source/version bindings,
sidecar correctness and candidate certification/recovery evidence. Prior candidate
reports do not certify changed package documentation.

## Remote publication and sibling installation

Immediately before each remote write, recheck the remote development branch is an
ancestor of the release source, and that the `v4-guards-v1.1.2` tag and Release are
absent. Do not force-update any remote ref. Push the exact certified source commit
to `codex/v4-development-base`, create/push an annotated tag at that commit, then
publish a final GitHub Release containing only the certified ZIP and SHA-256 sidecar.
Verify remote tag peel, release flags, asset names/sizes/digests and source manifest.

Install the exact released archive into a previously absent
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.2` sibling with an external receipt
at `D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.2.install.json`.
Verify receipt schema, complete file inventory and Package hash. Preserve the
existing 1.1.0 and 1.1.1 installations and receipts byte-for-byte.

Record publication/installation evidence in this Plan in a separate documentation
closure commit, pass exact Formal Diff for that closure, and push it without moving
the release tag. On partial remote failure, report the exact state; do not delete,
move or overwrite a tag, release or installation without separate authorization.

The pre-publication certification may continue to say `releaseAuthorized=false`:
it is an immutable candidate proof, and this Plan records the separate human
authorization. P10.1 composition requires a final complete IFX bundle and an
independent Xiaolong Feng review of its exact manifest/inventory/capability ceiling.
