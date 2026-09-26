# IFX C6c22 Windows product certification decision

Decision: `IFX WINDOWS PRODUCT EVIDENCE ACCEPTED — LINUX PORTABILITY ADVISORY-FAIL`

Product evidence source commit:
`30a29b9f8b91277e6ef258edf7701cbf88e6d5f6`

## Decision boundary

IFX is a Windows Server-only target product. Its C6 product certification has
two blocking requirements: Windows-full and the certification controls. Linux
remains mandatory to attempt and mandatory to report in this orchestrated
assessment, but is non-blocking portability evidence. This decision does not
remove Linux support from V4, certify a V4 package release, claim that IFX can
be deployed on Linux, accept the final bundle review, compose an installation
or authorize cutover.

The prior C6c contract incorrectly required Linux-complete to pass before the
IFX Windows product could pass. C6c22 replaces that product-level decision
policy. Generic V4 release certification still requires its existing exact
Linux-complete and Windows-full suites.

## Evidence disposition

- Windows-full passed 37 suites and 191/191 core cases. Report:
  `artifacts/guards/p10-ifx-c6c21/certification-full/windows/summary.json`,
  SHA-256
  `6ba09c657218185efa8c5128110c57a448560226b05b028de59046e24b987c2a`.
- Certification controls passed 180 capability variants and 42 lock controls.
  Report:
  `artifacts/guards/p10-ifx-c6c21/certification-full/controls/summary.json`,
  SHA-256
  `a7ae99c33c784761fc62912c03aae712c7b98cf5e03fcfa77f0650a30a8b8b0e`.
- Linux direct Post failed because `ifx-database-evidence` exceeded its declared
  60-second Host timeout. Report:
  `artifacts/guards/p10-ifx-c6c21/certification-full/linux/linux-failure-direct-post.json`,
  SHA-256
  `60b7795d50008ccbe34910266e2e0d325cef50d69171270d445c3dabb3f177c4`.
  Its product effect is non-blocking; its portability status is
  `advisory-fail`, and semantic parity is `not-evaluated`.

No module, adapter, manifest, timeout, lock, rule, bundle, reviewed capability
ceiling or published V4 byte changed in C6c22. Therefore the completed Windows
and control evidence remains evidence for the exact product snapshot; another
long full run is not required merely to exercise the new decision branch.

## Implementation and verification

The IFX parallel orchestrator now emits separate `productCertification` and
`portabilityAssessment` objects. It still uses the pinned Linux image,
`--network none` and the offline cache when available. Linux process failure,
missing prerequisites, invalid reports, missing cases and semantic mismatch are
preserved as `advisory-fail`; an unpinned image is never substituted. The report
explicitly sets `v4PackageReleaseCertification` to `not-adjudicated`.

The policy has six focused passing scenarios: complete success, Linux process
failure, Linux report failure, semantic mismatch, Windows failure and control
failure. All three PowerShell files pass parser validation. Formal Pre passed at
`artifacts/guards/p10-ifx-c6c22/formal-pre/summary-pre.json`, SHA-256
`f24c3232e1e854dfddc7580e668af0654390d731cffaceda9fb12ddc3a35e32c`.
The isolated package regression passed all positive, read-only and protected
negative cases at
`artifacts/guards/v3-ifx-package-test-d3c03c339dcf422081bcf7a3bf2b8792`.

## Shared workspace evidence classification

The C6c20 producer and consumers are under `docs/guards/candidates/ifx-*`, and
the published V4 Host does not provide their optional workspace-evidence input.
The implemented optimization is therefore **IFX project-specific today**, not
a V4 capability change. Its bounded enumeration, canonical hash cache and
commit-bound evidence format are suitable candidates for reuse. Making them a
V4 capability would require a separate compatibility Plan, a generic
evidence-provider contract, Host/schema review and normal V4 dual-platform
release certification.

With the Windows product evidence accepted under this boundary, P10.1 may
proceed to the separately governed C6d human review step. Linux portability
remediation may continue independently and cannot be represented as complete
until a later Linux-complete run passes.
