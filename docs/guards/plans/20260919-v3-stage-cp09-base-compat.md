# CP09 base compatibility bridge

This preparatory checkpoint makes base-owned validation dual-layout aware before CP09 moves stable commands and reviewed analysis evidence.

The manifest checker still accepts only the current scripts layout unless `guard-system.json` declares `docsMap`; that declaration selects the future commands/docs layout and its exact canonical paths. Package tests likewise select one complete layout from files present in the candidate, never mix arbitrary entry points. The tools test preserves current analysis behavior on the existing tree and exercises the future artifact/evidence/maintenance contract when the command layout exists. Trusted-base self-tests locate the same exact old-or-new public entry.

This bridge changes validation code only. It neither activates the future layout nor weakens existing verdicts, and it must pass current package tests plus trusted candidate parity before becoming the base for CP09 authorization.
