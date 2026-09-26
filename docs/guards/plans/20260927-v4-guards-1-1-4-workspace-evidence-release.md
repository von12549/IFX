# V4 Guards 1.1.4 — Host workspace evidence release

Status: `AUTHORIZED — certification and publication in progress`

The user authorized publication of V4 Guards 1.1.4 on 2026-09-27. This patch is
built directly from the immutable `v4-guards-v1.1.3` tag and promotes shared
workspace enumeration, hashing and reusable evidence generation into the V4 Host.
It does not package the IFX C6 consumer bundle or change Windows/Linux platform
support.

## Frozen boundary

The release branch starts at peeled tag commit
`90aa87b5c5a8e866db3384564518377d50fe997c`. Replay only the reviewed V4 package
changes from development commit `87a12b1f053d7b9e3c13a5bf2a4709913de9c100`,
then add 1.1.4 product metadata, release notes and matching integrity records.
No path below `docs/guards/candidates/` or `docs/guards/inventories/` may enter the
release source diff or archive.

Release-focused P10 composition testing exposed that an empty legacy module `config`
object could fail under PowerShell strict mode after the evidence-aware synthetic
adapter was introduced. The release includes the same-path compatibility correction:
enumerate configuration properties safely when the object is empty, and align the
synthetic composition capability ceiling with the module's reviewed EvidenceRoot read
capability. This does not enable evidence for Profiles that omit `workspaceEvidence`.
The legacy P0 spike entry point must likewise accept that reviewed read capability
and pass its already validated EvidenceRoot plus an empty config to the adapter; its
result contract and absence of a workspace-evidence binding remain unchanged.

Windows-full certification also requires P6 nested repository clones to opt into
Git for Windows long-path handling per child process. The release therefore passes
`-c core.longpaths=true` on those isolated clone commands without changing global,
system or repository Git configuration. Linux behavior is unchanged.

The existing TargetScope Host fixture narrows its copied Profile from `.` to
`src`/`tests`. It must narrow the explicit workspace-evidence roots at the same
time; otherwise a deliberately created out-of-scope symlink remains inside the
separately declared `.` evidence scope and is correctly rejected on Linux. The
test now proves both scoped consumers use the same declared roots.

The Host capability is opt-in per Profile. A declared workspace evidence contract
selects one provider module, output path and readable roots. Before a stage runs,
the Host generates one schema-valid, deterministic evidence document containing
the shared file inventory and hashes, exposes its path through the module process
environment, and allows eligible modules to consume it. Profiles without the
declaration retain existing behavior. Stable CLI/API remains `1.0`; built-in
component versions remain independently versioned.

## Certification and publication

Formal Pre must pass before executable replay. Commit one clean source candidate,
run exact Formal Diff from `v4-guards-v1.1.3`, then require Windows-full and pinned,
network-disabled Linux-complete platform certification on that same commit. Both
reports must bind the same package hash. Build the distribution twice and require
byte-identical ZIP hashes, then run V1 candidate and recovery certification against
the same source, package and archive identities.

Before remote writes, fetch and confirm the tag and GitHub Release are absent. Push
the certified source to `codex/v4-guards-1.1.4-release`, create the annotated tag
`v4-guards-v1.1.4`, and publish a final GitHub Release containing only the certified
ZIP and SHA-256 sidecar. Never move or overwrite an existing ref or Release.

Install the downloaded release asset into the previously absent sibling
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.4`, with receipt
`D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.4.install.json`. Verify the
receipt, complete file inventory, installed package hash and `version` command.
Confirm earlier installed releases and receipts plus User/Machine PATH values are
unchanged. Record publication and installation evidence in a documentation-only
closure commit without moving the release tag.
