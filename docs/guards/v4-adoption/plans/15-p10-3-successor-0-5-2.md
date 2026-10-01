# V4 P10.3 successor — V4 Guards 1.1.6 + `ifx_profile` 0.5.2

Status: `DESIGN AND LOCAL REHEARSAL — I2-B A3-10; REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260929-v4-ifx-i2b-ci-evidence-and-bundle`, amendment A3, step A3-10.

This successor rebinds the A2-10 design (`14-p10-3-successor-0-5-1.md`) from `ifx_profile` 0.5.1 to 0.5.2. The P10.3
rules, the staged-by-workflow evidence model and the v4-native ownership rule are unchanged. A3 adds closure (finding
F-C1 of I2-C): `main` admits only `docs/guards/v4-adoption`, so everything the specimen runs from the trusted base and
every producer now lives there. The A2-10 decision stays historical.

## Bound baseline

| Item | Value |
| --- | --- |
| V4 release | `v4-guards-v1.1.6` from `von12549/Guard`, commit `960678fd…`; archive SHA-256 `92f1ec54…` (pinned) |
| IFX bundle | `ifx-profile-candidate` 0.5.2, manifest `a2f619a31c2751949058812d73fdf6a6b6142832c85e772d23a714f40304e372` |
| Production review | `38eb775a…` (human review by `xiaolong-feng`, A3-9 packet `e8d0b0ca…`) |
| Composed Package | `0fab0676…`, receipt `01011be2…` (A3-10a) |
| IFX Target commit | `3600988cc9e91f0a523ec60f5f4378dd4c83c541` (the A3-8 C6c commit) |

The identity file `docs/guards/candidates/ifx-i2b-052/a310-identity.json` binds every record below.

## Evidence

| Step | Result |
| --- | --- |
| A3-1 | Closure inventory: 46 references over 18 roots; the paths outside `v4-adoption` are exactly five relocate origins and the aggregate |
| A3-2, A3-3 | Byte-identical copy into `producers/graph/` and `ci/`, then a reviewable adaptation; closure controls with nine negative mutations |
| A3-4 | Lab and relocated graph producers: semantically equal locks (155 edges, 58 projects); negative parity 4/4; aggregate 16/16 |
| A3-5 | `ifx-c1-evaluated-reference` 0.2.1: 12 cases on relocated evidence, the 10 shared with A1-3 identical |
| A3-8 | C6c: Windows 191/191, controls 180 + 42, Linux 191/191 semantic equal |
| A3-9 | Exact 0.5.2 packet accepted: six package files, one module version, four adapter lines, the lineage paths |
| A3-10a | Production composition; installed Host: clean Pre, deliberate fault, staged Post, dependency run, fail-closed unstaged Post |
| A3-10b | Against 0.5.1: P10.2 replay 52/52 equal (0 gaps, 15 strengthenings); C6c matrix equal with no first-finding change; installed-Host outcomes 5/5 equal |
| A3-10c | Rehearsal: the design, evidence-model and ownership rules plus the closure rule; 16 negative controls rejected |

## What the successor specimen and proposal change

- The specimen binds the 0.5.2 bundle (`extensions/ifx/0.5.2`). It runs `ci/Invoke-IFXEvidenceProducers.ps1` and
  `ci/Invoke-IFXV4Aggregate.ps1` from the trusted base, and names no path outside `docs/guards/v4-adoption`. Its steps
  are unchanged.
- The proposal's evidence model names the relocated graph producer `ifx-v4a-graph-v1` and the `ci/` staging script, and
  records the closure rule. The activation prerequisites now read:
  - publish the curated `v4-adoption` package to `main` (promotion itself was done by I2-C);
  - publish the exact 0.5.2 bundle.
- Rollback anchor: the remote development-branch commit `e2ffb2eb…` with the unchanged V3 workflow blob `51986b5a…`,
  from a GET-only snapshot (`a3-052/p10-3-successor-052/remote-snapshot.json`).

## Closure rule and its controls

The rehearsal requires all of the following:

- every `docs/guards` path in the specimen lies under `docs/guards/v4-adoption`;
- the staging script lies under `v4-adoption/ci/`;
- every producer lies under `v4-adoption/producers/`;
- no producer body names `docs/guards/candidates` (any letter case; the provenance header line excepted).

| Control | Mutation | Expected |
| --- | --- | --- |
| `specimen-reads-lab-tree` | the specimen and the proposal name the lab-tree staging script again | rejected |
| `producer-reads-lab-tree` | the graph producer points back to the lab tree | rejected |

The aggregate check now expects `ci/Invoke-IFXV4Aggregate.ps1`, and `candidate-self-judgment` mutates that path. The
other 14 controls are kept.

## Activation blockers retained

Each blocker needs its own exact Plan and authorization:

- publishing the curated `v4-adoption` package and the exact 0.5.2 bundle to `main` (I2-D);
- installing and negative-testing the specimen, including the producers' runtime prerequisites on the hosted runner:
  for example the graph producer's pinned .NET SDK `10.0.303` and SQL Server for the database matrix (I2-E);
- adding `v4-ifx-required` to the ruleset (I2-F);
- the coexistence window (I2-G).

The lab originals stay on the development branch; `Copy-IFX052Closure.ps1 -Check` reports any change to them. P10.GATE,
cutover and V3 retirement stay false.
