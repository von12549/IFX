# V4 Guards 1.1.1 — release publication

Status: `AUTHORIZED — release-safe source and recertification pending`

On 2026-09-23 the user explicitly authorized publication of the 1.1.1 compatibility patch,
in sequence before real P10.1 IFX Profile practice. This authorization covers the exact local
source and release workflow below. It does not authorize a real extension bundle, workflow or
ruleset activation, IFX cutover, or V3 retirement.

## Frozen predecessor

The P10.0, composition prototype and 1.1.1 local-candidate commits are `8e3e1c74`,
`c819a6fe` and `fa89f663f47a587e26dc5b1e2f49b6002c520486`. The last is a certified
local candidate, not automatically the publication commit. Its Windows-full 33-test and pinned,
network-disabled Linux-complete 32-test reports passed with Package hash
`dbb05cbdb9d900ad637b6eb17628693228fe74937bb0616869563e2758da4e5d`.
Its candidate archive SHA-256 is
`56b5567b86021dbe9b1334aeab262dcd2723e25ace2d264d61c29016b9a315cb`.
The candidate certification record deliberately retains `releaseAuthorized=false`.

Pre-publication read-only checks found no local or remote `v4-guards-v1.1.1` tag and no
GitHub Release at that tag. The remote `codex/v4-development-base` branch was at
`e94c2084e09ba5ba13eacdabf674840883ecdfc0`, an ancestor of the local candidate.
Recheck immediately before writing any remote reference; abort on a changed branch, tag,
release, version or archive identity.

## Release-safe source checkpoint

The certified candidate's packaged README, 1.1.1 notes, certification guide and Companion
guide still describe 1.1.1 as unpublished or certification as pending. Publishing those bytes
would give installed users a false status. Change only the declared package-documentation
paths to timeless, release-safe descriptions. Preserve the stable API `1.0`, product/Host/
Companion `1.1.1`, built-in component versions, all executable authorities, test hashes and
the immutable 1.1.0 release. Do not claim that a real IFX bundle is approved.

Run Formal Pre before source edits; commit the release-safe source checkpoint and run exact
Formal Diff. Rebuild a deterministic archive from that commit, rerun Windows-full and pinned
`--network none` Linux-complete, require the same Package hash and approved tests, then
generate a new local certification/recovery record. Verify the archive manifest's source
commit and package hash, the sidecar, and installed-path synthetic composition. The prior
candidate's reports and archive cannot certify changed documentation bytes.

## Publication sequence and acceptance

1. Verify the newly certified source commit is clean; local and remote 1.1.1 tag and Release
   remain absent; remote development branch is the expected fast-forward predecessor.
2. Push only the development branch to the exact certified commit. Re-read its remote ref.
3. Create and push an annotated `v4-guards-v1.1.1` tag at that exact commit. Verify the
   remote annotated tag object and peeled commit.
4. Publish a final GitHub Release named `V4 Guards 1.1.1`, with the certified ZIP and its
   SHA-256 sidecar only. Verify its tag, draft/prerelease flags, asset sizes and remote
   digests against the local certification and sidecar.
5. Install the exact released archive under a previously absent
   `D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.1` sibling, with an external receipt
   under `D:\IFX-Root\guard-runtime\receipts`. Verify the complete installed inventory,
   package hash, version and receipt while leaving 1.1.0 untouched.
6. Record exact publication and installation evidence in this Plan, close predecessor
   status text, run Formal Diff for the documentation closure, and push only that closure
   commit. The release tag stays on the certified source commit.

The certified pre-publication record remains immutable and may continue to state
`releaseAuthorized=false`; this Plan carries the separate user authorization and actual
publication evidence. If a remote mutation partially succeeds, stop and report the exact
state. Do not delete or force-move a tag, release or branch without separate approval.

## P10.1 boundary

Publication creates a compatible V4 base, not an `ifx_profile` installation. Xiaolong Feng
(`xiaolong-feng`) still must review an exact future IFX bundle inventory and capability
ceiling in a separate human-review record. Only then may P10.1 compose it into another
receipted sibling and run IFX detector-family and installed Web UI practice. P10.2 parity,
remote governance activation and cutover remain later, separately authorized gates.
