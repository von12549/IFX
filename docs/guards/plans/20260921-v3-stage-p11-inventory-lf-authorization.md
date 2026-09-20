# P11 inventory LF authority authorization

This authorization-only checkpoint publishes D38 and one immutable `weaken-policy` record for prepared bridge commit `72ddfe02`. It contains no `.gitattributes`, inventory, runner or verifier implementation change.

The record covers exactly `.gitattributes`, from base normalized-text SHA-256 `d14bd5de...bfd23e` to candidate SHA-256 `f5cf3f5c...483d3`, with the root pointer and exact head blob tuple. The approved semantic change declares LF checkout authority only for text classes whose raw bytes V3 Analyze records. It does not ignore byte drift or authorize any other policy file.

After this authorization merges into `codex/guards-principles-plan`, bridge PR #73 will merge the updated base, delete this record together with its existing TCB authorization, and rerun all 13 checks. The original ten-path TCB authorization remains unchanged.
