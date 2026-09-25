# V4 P10.1 C6c12 — generated-source binding refresh

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c11 intentionally changed the C1h adapter bytes while preserving its
generated-source exclusion semantics. The controlled generated-input producer
correctly rejected its frozen C1h SHA-256, preventing issuance of a lock for
the new commit.

## Exact remediation

1. Replace only the frozen C1h scanner SHA-256 in the generated-input producer
   with the C6c11 manifest-bound adapter SHA-256.
2. Preserve the independent structural assertion that C1h excludes guard,
   `bin`, and `obj` paths.
3. Run the generated-input producer against fresh same-commit solution
   evidence before rebuilding the final lineage.

No detector, policy, rule, claim, timeout, generated-file classification,
expected generator hash, baseline, waiver, published package byte, or G04
governance state changes in C6c12.

