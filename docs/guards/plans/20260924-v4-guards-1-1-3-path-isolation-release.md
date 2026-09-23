# V4 Guards 1.1.3 — child-process PATH isolation release

Status: `AUTHORIZED — release-safe source and publication pending`

On 2026-09-24 the user authorized publication of a new patch release built directly
from the immutable `v4-guards-v1.1.2` tag. The release contains only the V4
build-evidence child-process PATH isolation repair and the metadata, integrity,
tests and documentation required to publish it as 1.1.3.

## Frozen base and exact boundary

The release branch starts at the peeled 1.1.2 tag commit
`5bc176f61508fd01ddceb2d4e33ee34136493a35`. It must not merge, rebase onto,
or cherry-pick a commit whose ancestry contains the concurrent IFX C1-C6 candidate
work. In particular, no path below `docs/guards/candidates/` or
`docs/guards/inventories/` may enter the release diff or archive.

Replay only the six reviewed V4 package changes from the local PATH-isolation fix:
the README, CI test hash, build-evidence adapter, module manifest, module registry
and focused build-evidence test. The adapter must set
`DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=0` in every isolated dotnet child environment
beside `DOTNET_CLI_HOME`. The test must prove the child environment and persisted
Windows User PATH remain unchanged, and scan runtime sources for permanent
User/Machine environment mutation APIs. The separately developed repository repair
utility is outside this release and is neither packaged nor executed.

Update product and assembly metadata to 1.1.3, refresh only the integrity hashes
made stale by these changes, and add 1.1.3 release notes. Stable API 1.0, built-in
Profiles, module component versions, contracts and the incomplete IFX bundle remain
unchanged. No live User or Machine PATH repair is part of this publication.

## Certification and publication

Formal Pre must pass on the exact Plan before executable replay. Commit the complete
source candidate, run exact Formal Diff from the 1.1.2 tag, and require a clean
tracked worktree. Run the complete Windows-full and pinned, network-disabled
Linux-complete suites against that single commit, require identical package hashes,
then build the deterministic ZIP and SHA-256 sidecar and produce V1 candidate and
recovery evidence bound to the same source commit.

Before every remote write, fetch and confirm that `v4-guards-v1.1.3` and its GitHub
Release are absent. Push the exact certified commit to the dedicated
`codex/v4-guards-1.1.3-release` branch without modifying
`codex/v4-development-base`, create and push an annotated release tag, then publish
a final GitHub Release containing only the certified ZIP and SHA-256 sidecar. Do not
force-update, delete, move or overwrite any existing remote ref or Release.

Install the exact released archive into a previously absent sibling
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.3`, with the receipt at
`D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.3.install.json`. Verify the
receipt schema, complete file inventory and package hash, while preserving all
earlier installations, receipts, archives, tags and releases byte-for-byte.

Record final publication and installation evidence in a separate documentation-only
closure commit, pass exact Formal Diff for that closure, and push the branch without
moving the release tag. On partial failure, preserve and report the exact state.
