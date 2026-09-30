# V4 P10.3 successor — V4 Guards 1.1.6 + `ifx_profile` 0.5.1

Status: `DESIGN AND LOCAL REHEARSAL — I2-B A2-10; REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260929-v4-ifx-i2b-ci-evidence-and-bundle`, amendment A2, step A2-10.

This successor rebinds the A1-8 design (`13-p10-3-successor-0-5-0.md`) from `ifx_profile` 0.5.0 to 0.5.1. The P10.3
rules and the staged-by-workflow evidence model are unchanged. What changes is ownership: the four producers that ran V3
gates in 0.5.0-a now run from `docs/guards/v4-adoption/producers/`, so V4 owns the eleven contexts without re-attesting
any V3 producer. The A1-8 decision stays historical.

## Bound baseline

| Item | Value |
| --- | --- |
| V4 release | `v4-guards-v1.1.6` from `von12549/Guard`, commit `960678fd…`; archive SHA-256 `92f1ec54…` (pinned) |
| IFX bundle | `ifx-profile-candidate` 0.5.1, manifest `b7a6751612f2279809b07988916112b499c52e7b1b36ae175c68924bd979e5e7` |
| Production review | `077edb6c…` (human review by `xiaolong-feng`, A2-9 packet `f65fa234…`) |
| Composed Package | `52364a8d…`, receipt `3e9a3e9d…` (A2-10a) |
| IFX Target commit | `351b504bd6549a8e9cede9ab34571986f6188c49` (the A2-8 C6c commit) |

The identity file `docs/guards/candidates/ifx-i2b-051/a210-identity.json` binds every record below.

## Evidence

| Step | Result |
| --- | --- |
| A2-1 to A2-3 | 18 files relocated from V3_ifx and the lab tree; byte-identical copy, then a reviewable adaptation; static controls: no consumed producer names `docs/guards/V3` or `V3_ifx` |
| A2-4 | V3/V4 producer parity on one commit: zero semantic differences; three negative mutations fail both sides the same way |
| A2-5 | the five changed consumer suites pass on relocated-producer evidence; cases shared with A1-3 identical |
| A2-8 | C6c: Windows 191/191, controls 180 + 42, Linux 191/191 semantic equal |
| A2-9 | exact 0.5.1 packet accepted (producer identity only; 0.5.0 claims carried forward) |
| A2-10a | production composition; installed Host: clean Pre, deliberate fault, staged Post, dependency run, fail-closed unstaged Post |
| A2-10b | against 0.5.0: P10.2 replay 52/52 equal; C6c matrix equal with no first-finding change; installed-Host outcomes 5/5 equal |
| A2-10c | rehearsal: the design and evidence-model rules plus the new ownership rule; 14 negative controls rejected |

## What the successor specimen and proposal change

- The specimen binds the 0.5.1 bundle (`extensions/ifx/0.5.1`), the 0.5.1 staging script from the trusted base and the
  0.5.1 aggregate; its steps are unchanged.
- The proposal's evidence model names the relocated producers (`ifx-v4a-*`), all `v4-native-producer`; the four
  contexts `v3-quality-solution`, `v3-quality-assembly`, `v3-quality-frontend` and `v3-specialized-database` are
  `v4-native`; the two evidence families are `v4-owner` again.
- Rollback anchor: the remote development-branch commit `13502169…` with the unchanged V3 workflow blob `51986b5a…`,
  from a GET-only snapshot (`a2-051/p10-3-successor-051/remote-snapshot.json`).

## Ownership rule and its controls

The rehearsal requires every producer in the evidence model to be `v4-native-producer`, its script to exist and to
contain no path under `docs/guards/V3` or `V3_ifx` (any letter case; the provenance header line excepted), and no context
or detector family to carry the 0.5.0-a re-attestation marker.

| Control | Mutation | Expected |
| --- | --- | --- |
| `producer-reads-v3` | the solution producer points back to the lab script that runs the V3 gate | rejected |
| `re-attestation-returns` | `v3-specialized-database` is declared as re-attesting a V3 producer | rejected |

`ownership-hides-v3-producer` (A1-8) is retired: with no V3-wrapping producer it has nothing to test. The eight I1 and
the four other A1-8 controls are kept.

## Activation blockers retained

Each needs its own exact Plan and authorization: default-branch promotion; publication of the exact 0.5.1 bundle;
installing and negative-testing the specimen, including the producers' runtime prerequisites on the hosted runner;
adding `v4-ifx-required` to the ruleset; the coexistence window. The V3 originals of the relocated gate logic stay in
`V3_ifx` and keep running in V3 CI until V3 retirement; `Copy-IFX051Producers.ps1 -Check` reports any change to them.
P10.GATE, cutover and V3 retirement stay false.
