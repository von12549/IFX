# V4 P10.2-R1 frozen-corpus repair and rerun

Status: authorized execution

## Authorization and predecessor

The user explicitly authorized a separate repair Plan and continuation of
P10.2 on 2026-09-27. The predecessor decision is
`artifacts/guards/p10-ifx-114/p10-2-parity-042/p10-2-decision.json`, SHA-256
`73a7fce1b42b504326267eba078f130ce83f643bea07def38d90e9947645c7f5`.
It stopped P10.2 before either engine started because one frozen Target had
six added generated files. It did not authorize P10.3.

## Goal

Restore the single drifted C6c Target to its already-certified byte
inventory by removing only the six verified V3 import-manifest outputs, prove
all 52 frozen Target fingerprints again, then rerun P10.2 through the fixed
V3, receipted V4 and independent comparer using new absent mutable and
repository evidence paths. Stop before P10.3 regardless of outcome.

## Exact repair allowlist

The repair root is:

`artifacts/guards/p10-ifx-114/c6c-recovery-042-full/windows/suites/c1b/a63d23c0a6234bab8bfeb906bff5f8a3/forbidden-reference/artifacts/guards/v3-ifx/build/architecture-conformance`

Only these six files may be removed:

- `Guards.ArchitectureConformance.imports.pre-build.json`, SHA-256
  `1bcfca59e3ef740a53d02c8497e3b9715b1c9e7e167709428a43d99d1bc64529`;
- `Guards.ArchitectureConformance.Tests.imports.pre-build.json`, SHA-256
  `4b4647f5996ef2a3ce7c5f5d143904560e31234fcd86a611f24c61f54ca2f4c1`;
- `LayerGuard.Ifx.imports.post-build.json`, SHA-256
  `0eb9c614629724f44e553783a4a7d0789e9a87ba876ed7367a4c6ac8dbbf55ca`;
- `LayerGuard.Ifx.imports.pre-build.json`, SHA-256
  `40724b242785b2763cd2b3171da0a9eac14f3b222f288c3b76080a7b9f217a76`;
- `LayerGuard.Ifx.Tests.imports.pre-build.json`, SHA-256
  `b16bdfd19e8a4208fbaf9d57c8e2dda1c5abf2b67ea9528b22d2056e90140cf2`;
- `LayerGuard.Tests.imports.pre-build.json`, SHA-256
  `f6037c30f7f5a73325359fcbfef9977596aab5ba581e8ea8095bf1437f8ad87f`.

Every file must exist at the exact resolved path and match its allowlisted
hash before removal. No wildcard, recursive deletion or broader directory
cleanup is permitted. The certified Target fingerprint after repair must be
`5b0a57b92e2848f475316b1f41ff2aa859c22a8868de403ab75693acdb50e59c`.

## Repair and continuation procedure

1. Verify the predecessor decision, all six paths and all six hashes.
2. Record a pre-repair inventory under the new repair evidence path.
3. Remove exactly the six allowlisted generated files, leaving directories
   intact and touching no certified source file.
4. Recompute all 52 C6c production-corpus Target fingerprints. Require zero
   drift and record the post-repair inventory and repair decision.
5. Require the new P10.2 repository output, external build root and external
   runtime evidence root to be absent.
6. Run the committed P10.2 executor at commit
   `3ce13b96756001fcfbd953b4d395c2cdf12d7cb1` with the new paths. The runner
   must execute the exact 52 cases with both engines and a third comparison
   process, or preserve a new fail-closed stopped decision.
7. Reconfirm P10.3, activation, publication, V3 retirement and IFX cutover
   remain false.

## New paths

- repair evidence:
  `artifacts/guards/p10-ifx-114/p10-2-r1-repair-042/`;
- rerun evidence:
  `artifacts/guards/p10-ifx-114/p10-2-r1-parity-042/`;
- external build:
  `D:/IFX-Root/guard-runtime/build/p10-2-r1-parity-042`;
- external runtime evidence:
  `D:/IFX-Root/guard-runtime/evidence/p10-2-r1-parity-042`.

All four paths must be absent before their respective phase begins. The
stopped P10.2 evidence at `p10-2-parity-042` is immutable.

## Acceptance criteria

- exactly the six allowlisted files are removed after exact hash checks;
- all 52 frozen Target fingerprints match their certified C6c captures;
- the repair evidence closes with no unexplained mutation;
- the P10.2-R1 run uses only the committed runner, frozen engines and new
  absent paths;
- V3, V4 and the independent comparer close with no unresolved gap for an
  accepted result, or a new stopped decision preserves every gap; and
- P10.3 and every activation/cutover boundary remain false.

## Stop conditions

Stop before deletion on any missing path, hash mismatch, unexpected seventh
file or predecessor mismatch. Stop after deletion on any remaining Target
drift. Stop the rerun on identity drift, engine failure, corpus drift or a
comparison gap. Do not repair or rerun in place after the new P10.2-R1
evidence closes.

