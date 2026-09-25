# IFX C6c11 pre-scan and lock-shape decision

Date: 2026-09-25
Status: implementation complete; final C6 certification rerun required

## Trigger

The C6c10 final certification rooted at
`%TEMP%/ifx-c6c10/385764a969044b07b3222718a338b19d` established two independent
remaining harness defects:

- Windows completed the 191-case matrix, while Linux reached
  `ifx-ring-graph` and exceeded its 180-second adapter limit.
- Certification controls reached the binary-lock shadow copy and assumed
  every assembly entry exposed `sourcePath`. Assembly locks expose `path`;
  type-provenance locks expose `sourcePath`.

Neither failure changed a product or rule outcome. Both occurred before the
cross-platform and control summaries could be certified.

## Decision

The five remaining source-tree pre adapters now use a bounded directory queue:

- link directories and link files are rejected when they are enumerated;
- `bin`, `obj`, `.git`, guard, and existing policy-excluded directories are
  pruned before descent, as applicable to each adapter;
- only the semantic extensions required by the adapter are collected;
- each entry receives one filesystem attribute check, eliminating the prior
  per-file ancestor-chain revalidation.

The C6 control harness now selects an assembly source from either `sourcePath`
or `path`, and uses the same selector for post-production mutation and binary
shadow-copy controls. A focused invocation against the C6c10 locks resolved
the assembly lock through `path` and the type lock through `sourcePath` to the
same governed DLL.

Four owning tests had stale assertions for a 30-second timeout even though
their manifests already declared 180 seconds. Those assertions were corrected
to the existing manifest contract; no timeout was increased.

## Verification

The amended formal Pre gate passed:

- `artifacts/guards/p10-ifx-c6c11/formal-pre-amended/summary-pre.json`
- SHA-256 `fbb3c08e26737f137d6ad609cfd4c9d2751cbf40e2de3bbf46c029698807a2a6`

All affected owning suites passed their link fixtures and real IFX scans:

- C1d: `artifacts/guards/p10-ifx-c6c11/owning-final-c1d/65ca795a46ee45559b3c5715d9ce3c1e`
- C1e: `artifacts/guards/p10-ifx-c6c11/owning-final-c1e/4eb3e25706ca4c43be686dd6de2d210f`
- C1g: `artifacts/guards/p10-ifx-c6c11/owning-final-c1g/4827de3ea1974deb846c670091c6e675`
- C1h: `artifacts/guards/p10-ifx-c6c11/owning-final-c1h/d004178b0fd4489eaca21bca053aa549`
- C1o: `artifacts/guards/p10-ifx-c6c11/owning-final-c1o/7ef8028969d0498b82ba87938078cc7c`

The refreshed 37-module inventory is
`artifacts/guards/p10-ifx-c6c11/development-inventory-final/08f46b62c761451790a2aee08e2a25c5/ordinal-inventory.json`
(SHA-256 `7d7d4525cd2a713dedaf812a5979d69d6ddb4496954a2e6ecc591bd1044e411d`).
The independent matrix contract passed at
`artifacts/guards/p10-ifx-c6c11/matrix-contract-final/summary.json`
(SHA-256 `e10fa630a7c4e00e272c611329f8e44abbfa70b1d8ec88e79e602b9e4aed1768`).

An offline Linux container using `ifx-c6c-sdk:10.0.303` completed each affected
real-repository adapter below the unchanged 180-second limit:

| Adapter | Seconds | Result |
| --- | ---: | --- |
| `ifx-ring-graph` | 32.613 | pass |
| `ifx-ownership-graph` | 32.823 | pass |
| `ifx-embedded-adapter` | 26.079 | pass |
| `ifx-source-policy` | 37.895 | pass |
| `ifx-injection` | 29.486 | pass |

## Certification consequence

C6c remains open until a clean committed HEAD is used to regenerate every
lineage lock and candidate bundle, followed by the full Windows/Linux matrix,
42 certification controls, 180 capability variants, semantic parity checks,
and the formal Diff gate. This decision authorizes that rerun; it does not by
itself claim final certification.
