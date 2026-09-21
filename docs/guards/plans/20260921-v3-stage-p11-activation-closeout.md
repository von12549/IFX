# P11.4 activation closeout

P11.4 is complete on `codex/guards-principles-plan`.

- Final candidate PR #76 passed all 13 required checks in run `35544469838`; workflow-dispatch run `35545258607` passed with `windowsCoverage=full`.
- Exact activation authorization PR #83 passed all 13 checks in run `35552248196` and merged as `28ef65d7`.
- Activation PR #84 consumed that authorization, passed all 13 checks on corrected head `7f487578` in run `35553485690`, and merged as `1c5d4ddb`.
- From merged commit `1c5d4ddb`, Generate reproduced both candidates, Verify reported both targets `current`, and the CI contract matched all 13 checks.

The selective-restore rehearsal used an isolated worktree. Its exact rollback target list was `.github/workflows/v3-ifx-guardrails.yml` and `.github/CODEOWNERS`, with pre-activation restore commit `28ef65d7`. Restoring only those paths made Preview pass as `legacy-equivalent` and Verify fail with exit 1 as expected; restoring them from activation head `ad69de18` made Verify pass again, with zero tracked changes left behind. This proves the activation rollback mechanism, but P11.6 remains open until P11.5 supplies the final cleanup deletion list and recovery commit set.
