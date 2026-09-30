# V4 P10.3 successor — V4 Guards 1.1.6 + `ifx_profile` 0.5.0

Status: `DESIGN AND LOCAL REHEARSAL — I2-B A1-8; REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260929-v4-ifx-i2b-ci-evidence-and-bundle`, amendment A1, step A1-8.

This successor rebinds the I1 successor design (`11-p10-3-successor-1-1-6.md`, rehearsal decision `b5882ec7…`)
from `ifx_profile` 0.4.4 to 0.5.0 on the same V4 Guards 1.1.6 release. The P10.3 rules are unchanged:
coexistence, ownership, the Linux bridge and the rollback order. What is new is the evidence model of 0.5.0-a:
the workflow produces and stages the evidence that the Post lock consumers read. The I1 decision stays
historical.

## Bound baseline

| Item | Value |
| --- | --- |
| V4 release | `v4-guards-v1.1.6` from `von12549/Guard`, commit `960678fd1a193d87d5c499f08e79e7ce0550d96a` |
| Archive | `v4-guards-1.1.6.zip`, SHA-256 `92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8` (pinned) |
| IFX bundle | `ifx-profile-candidate` 0.5.0, manifest `086a3911a2cb8f5cef0caf7621cecaf49dcc9bf08e30acd8a376748b9e38a284`, Profile `abe31668…` |
| Production review | `3dec187b…` (human review by `xiaolong-feng`, A1-7 decision `57a10370…`, packet `9d1e95d0…`) |
| Composed Package | `f94d724a…`, receipt `dc0e2aaf…` (A1-8a) |
| IFX Target commit | `c0d927eb7d81256d10194b894e20d4ad92333ad9` (the A1-6 C6c commit) |

The identity file `docs/guards/candidates/ifx-i2b-050a/a18-identity.json` binds every record below.

## Evidence

| Step | Result | Record |
| --- | --- | --- |
| A1-6 C6c | Windows product certification: independent matrix 191/191, controls 180 capability + 42 staged-evidence. Linux portability 191/191, semantic projection equal | `artifacts/guards/p10-ifx-i2b/c6c-decision.json` `315a8251…` |
| A1-7 review | Exact 0.5.0 packet accepted, including what "pass" now means per module | `c6d-review-050/c6d-decision.json` `57a10370…` |
| A1-8a composition | Production composition verified. Installed Host: clean Pre passes (10 modules, 22 claims); the deliberate `A18Fault.cs` blocks with `IMPORT-DIRECTION`; Post on staged evidence passes (27 modules, 57 claims); the dependency run passes (37 modules, 79 claims); Post without staged evidence fails closed (`prerequisite-missing`) | `a1-8a-decision.json` `6bbe11b7…` |
| A1-8b parity | P10.2 replay 52/52, zero gaps, the same 15 strengthenings, row by row equal to the accepted 0.4.4 replay. The 191 C6c cases equal the 0.4.4 matrix in IDs, contracts and outcomes; 7 cases report a different first finding because the 0.5.0 fixtures differ, each listed | `p10-2-parity-050/p10-2-decision.json` `12a0b200…`, `parity-against-044.json` |
| A1-8c rehearsal | Design rules and the evidence-model rules re-proved on the successor proposal and specimen; 13 negative controls rejected | `p10-3-successor-050/rehearsal/p10-3-successor-decision.json` |

## What the successor specimen adds

`integrations/github/proposed-v4-ifx-guardrails.yml` keeps the I1 jobs and inputs and binds the 0.5.0 bundle
under `docs/guards/v4-adoption/extensions/ifx/0.5.0`. The Windows job now:

1. materializes the previously trusted base, as the contract and aggregate jobs already do;
2. after installing and composing, **produces** the evidence at the PR head with the staging script taken from
   the trusted base (`Invoke-IFX050EvidenceProducers.ps1 -Phase Produce`);
3. **stages** the consumed runs into the Host EvidenceRoot (`-Phase Stage`), before Pre and Post;
4. runs Pre and Post with dependencies, as before;
5. **uploads** the EvidenceRoot and the production record with `if: always()`, so a failed Post keeps its
   evidence.

The producer scripts themselves run from the PR checkout. That is safe because each lock consumer verifies the
producer script SHA-256 pinned in its accepted module policy; a changed producer is `integrity-failure`.

## Ownership until 0.5.0-b

Four of the six consumed producers still run a V3 gate:

| Evidence gate | Producer | V3 gate it runs | V3 context |
| --- | --- | --- | --- |
| solution | `ifx-c5b-controlled-v1` | `Invoke-IFXGuardrails -Mode Quality -QualityTarget Solution` | `v3-quality-solution` |
| assembly | `ifx-c5c-controlled-v1` | `-QualityTarget Assembly` | `v3-quality-assembly` |
| frontend | `ifx-c5d-controlled-v1` | `-QualityTarget Frontend` | `v3-quality-frontend` |
| database | `ifx-c4b-controlled-v2` | `-Mode Specialized -SpecializedGate Database` | `v3-specialized-database` |

The proposal records these four contexts with `attestation: re-attests-v3-producer-until-0.5.0-b`, and the
two evidence families with status `v4-owner-re-attests-v3-producer`. V4 owns the verdict, but the check itself is
still the V3 code until 0.5.0-b relocates the producers. No V3 context may be retired on the strength of these
four families before that. The graph and type producers are V4-native. The type producer reads two V3_ifx
rule and policy files, which its consumer embeds.

## Negative controls executed by the rehearsal

The eight I1 controls, plus:

| Control | Mutation | Expected |
| --- | --- | --- |
| `producer-step-missing` | the Produce step is removed | rejected |
| `staging-from-candidate` | staging runs the script from the PR checkout instead of the trusted base | rejected |
| `post-before-staging` | Pre and Post run before the Stage step | rejected |
| `evidence-upload-missing` | the production record is dropped from the always-run upload | rejected |
| `ownership-hides-v3-producer` | `v3-quality-solution` is declared `v4-native` | rejected |

## Activation blockers retained

Each needs its own exact Plan and authorization:

- default-branch promotion;
- publication of the exact 0.5.0 bundle;
- installing and negative-testing the specimen, which must also prove the producers' runtime prerequisites on the
  hosted runner (for example the database producer's SQL Server matrix and the frontend toolchain);
- adding `v4-ifx-required` to the ruleset;
- the coexistence window;
- relocating the four V3-wrapping producers (0.5.0-b) before any V3 retirement.

The rollback anchor is the remote development-branch commit `ffe03be5…` with the unchanged V3 workflow blob
`51986b5a…`, from a GET-only snapshot (`p10-3-successor-050/remote-snapshot.json`). P10.GATE, cutover and V3
retirement stay false. The installed Web UI hands-on record for 1.1.6 + 0.5.0 is left to the P10.GATE successor.
