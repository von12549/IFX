# IFX I2-D review packet (D5)

Plan `20261001-v4-ifx-i2d-publish-trusted-inputs`. Repository head `13a0d7bbdeb9a8803047d7f1e5c7d01644cd4eaa`.

## Remote state (D1, GET only)

- `main` = `codex/guards-principles-plan` = `7b9b53dcc102fd8513927681641493101b4599ca`; default branch `main`; no open pull request; `main`'s `v4-adoption` holds only the README.
- Ruleset 23459908 canonical SHA-256 `857a51aaf9590758aa37ab0daf234695ba6e3a434644e598026d741b2c7d6f4a`, equal to the I2-C snapshot.

## What main receives

One pull request, `codex/i2d-publish-v4-adoption`. Every copied file is byte-identical to its development-branch source blob at `2c82d6e8`:

| Directory | Files |
| --- | --- |
| `docs/guards/v4-adoption/ci/` | 2 |
| `docs/guards/v4-adoption/extensions/` | 264 |
| `docs/guards/v4-adoption/integrations/` | 2 |
| `docs/guards/v4-adoption/migration/` | 7 |
| `docs/guards/v4-adoption/producers/` | 23 |

- `extensions/ifx/0.5.2/`: the certified bundle (manifest `a2f619a3…`: the manifest plus 262 package files) and the accepted review `38eb775a…`.
- Authored: the `main` edition of `docs/guards/v4-adoption/README.md` and the V3 plan pair `docs/guards/plans/20261001-v4-ifx-i2d-p1-publish-v4-adoption.plan.json` (it lists all 301 paths, as V3 Diff matches paths exactly).
- Not published (RD1, RD3): the design notes `plans/`, the development edition of the README, `docs/guards/TODO.md`.

## Rehearsal (D4)

Status **pass**. The V3 checks came from main's own trusted runner; the publication checks ran on fresh checkouts with `core.autocrlf` true (as hosted Windows runners) and false.

| Step | Exit | As expected |
| --- | --- | --- |
| `diff` | 0 | True |
| `candidates` | 0 | True |
| `validate` | 0 | True |
| `candidate-tests` | 0 | True |
| `architecture` | 0 | True |
| `historical` | 0 | True |
| `g03` | 0 | True |
| `inputs-autocrlf-true` | 0 | True |
| `bundle-autocrlf-true` | 0 | True |
| `bytes-autocrlf-true` | 0 | True |
| `scope-autocrlf-true` | 0 | True |
| `cutover-preservation-autocrlf-true` | 0 | True |
| `inputs-autocrlf-false` | 0 | True |
| `bundle-autocrlf-false` | 0 | True |
| `bytes-autocrlf-false` | 0 | True |
| `scope-autocrlf-false` | 0 | True |
| `cutover-preservation-autocrlf-false` | 0 | True |
| `compose` | 0 | True |
| `composed-package` | 0 | True |

The published bundle, copied out of the checkout as the specimen does and composed with the 1.1.6 base under the published review, gives package `0fab0676…`, the A3-10a package.

Not run locally (CI runs them on the PR): v3-quality-solution, v3-quality-assembly, v3-quality-frontend, v3-specialized-g04, v3-specialized-g05, v3-specialized-plan04, v3-specialized-database, v3-cross-platform-ubuntu-latest, v3-cross-platform-windows-latest (candidate suite).

## Remote steps after acceptance (each separately authorized)

| Step | Action | Then |
| --- | --- | --- |
| D6 | Rebuild the head on the then-current main, push codex/i2d-publish-v4-adoption and open the PR to main | the operator reports the checks or asks for one GET read |
| D7 | Merge with a merge commit after 13/13, --match-head-commit | GET verify |
| D8 | Post-state record, merge main into the development branch (README conflict by rule), receipt | local |
| D9 | Push the development branch (fast-forward) | GET verify |

## Questions

- Accept the publication pull request (the 298 copied files, the main README and its V3 plan) as prepared?
- After acceptance, D6 (push and open the PR) needs its own authorization.
