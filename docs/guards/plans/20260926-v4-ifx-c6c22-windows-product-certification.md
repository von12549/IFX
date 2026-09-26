# V4 P10.1 C6c22 — IFX Windows product certification boundary

Status: `IMPLEMENTED — IFX WINDOWS PRODUCT EVIDENCE ACCEPTED`

IFX is a Windows Server-only target product. V4 remains a dual-platform
verification package: its release certification and portable rule capability
continue to require the existing Linux and Windows suites. The current IFX C6c
orchestrator incorrectly combines those two decisions by allowing a Linux
portability failure to reject the Windows-only IFX product result.

## Exact remediation

1. Define an explicit, testable IFX certification policy. Windows-full and the
   certification controls are blocking product requirements. Linux-complete is
   retained as non-blocking V4/rule portability evidence for this product run.
2. Keep starting the pinned, network-disabled Linux assessment alongside the
   Windows and control processes. Record its exit code, available reports and
   semantic parity result even when it fails.
3. Emit separate `productCertification` and `portabilityAssessment` decisions.
   The process succeeds only when the IFX Windows product decision passes;
   Linux failure or semantic mismatch must be visible as `advisory-fail` and
   must not be presented as a V4 package-release pass.
4. Add focused policy tests for Windows failure, control failure, Linux process
   failure, Linux report failure and Windows/Linux semantic mismatch. No full
   certification rerun is required to test this decision logic.
5. Update the IFX program and decision record. Do not change V4 generic release
   targets, Host contracts, CI required contexts, modules, rule semantics,
   reviewed capability ceilings, locks, bundle bytes or published packages.

## Shared-evidence boundary

The C6c20 shared workspace evidence implementation lives in IFX candidate paths
and is not supplied by the published V4 Host contract. It is therefore an IFX
project optimization today. Its bounded enumeration, canonical hashing and
commit binding are reusable design candidates, but promoting them to a V4
evidence-provider capability requires a separate V4 compatibility Plan and
Host/schema contract; this tranche does not make that promotion.

## Verification record

Formal Pre passed before executable edits. The three changed PowerShell files
passed parser validation, all six focused certification-policy scenarios passed,
and the isolated `ifx-package-test` passed its positive, read-only and protected
negative cases. The decision record binds the prior immutable Windows 191/191
and certification-control results and retains the Linux timeout as an explicit
non-blocking portability failure. No full certification rerun was performed
because this tranche changes only decision policy and report construction, not
the already tested product, module, rule, lock or bundle bytes.

## Exit

Formal Pre must pass before executable edits. The focused policy tests,
PowerShell parser checks and isolated `ifx-package-test` must pass. The decision
record must distinguish an IFX Windows product verdict from V4 package-release
certification and preserve the latest Linux timeout as an unresolved
portability result rather than silently discarding it.
