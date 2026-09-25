# V4 P10.1 C6c10 — Linux enumeration and long-path repair

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c9 proved the Windows matrix but exposed two remaining platform harness
failures. The controls shadow clone can exceed the Windows checkout path limit,
and `ifx-package-reference` spends its 180-second Linux budget enumerating and
revalidating every file below `src` even though only project files are semantic
inputs. Both failures are fail-closed and neither is a product finding.

## Exact remediation

1. Run the controls shadow clone with Git `core.longpaths=true` while preserving
   its no-local clone and autocrlf settings.
2. Enumerate only `*.csproj` files in the package-reference adapter. Continue to
   validate the source root, every selected project and every ancestor for link
   or path escape before parsing project XML.
3. Add a structural regression assertion for the project-only enumeration and
   rebind the module manifest, matrix contract and fixture specification hashes.

## Validation and boundary

Formal Pre must precede executable edits. The C1c owning suite, matrix-contract
check, parser checks and a focused Linux direct-pre replay must pass before a
fresh C6 evidence chain is generated. Final certification still requires equal
Windows/Linux 191/191 semantics, 42 lock controls, 180 capability variants and
zero gaps.

The module timeout remains 180 seconds. Claims, rules, policy, reviewed
capabilities, cases, baselines, waivers, published 1.1.3 bytes and G04
governance remain unchanged. C6d/C6e, P10.2/P10.3 and V3 retirement remain out
of scope.

