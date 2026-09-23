# IFX Profile bundle candidate 0.1.0

Status: **source-derived draft; not ready for human acceptance or composition**.

The bundle root is `bundle/`. Its `ifx_profile` is a real IFX-source-bound V4 Profile,
but only the existing `architecture-conformance` project-reference-resolution check is
selected. The other IFX architecture claims, G03/G04/G05 specialized gates, full Stage
ownership, toolchain prerequisite translation, baselines and detector-family zero-match
proofs have not been implemented. The candidate must not be described as a complete IFX
guard or as parity with V3_ifx.

`authority-map.json` binds the source commit and hashes of the existing IFX authorities
and distinguishes the partial mapping from missing coverage. It is provenance data, not
an executable V3 runtime import. The bundle requests no new modules or capabilities;
the selected V4 built-in module retains its released manifest and capability boundary.
The Profile's proposed `src` and `tests` roots are descriptive today: the 1.1.1 built-in
architecture adapter scans the entire TargetRoot, so exact IFX root confinement remains
an explicit blocking compatibility gap.

No `extension-review` acceptance record exists for this candidate. In particular, the
prior H1–H4 design choice and the designation of Xiaolong Feng as reviewer do not accept
these bytes. Do not compose, install, run Stage/UI practice, or use this candidate as a
cutover argument until the missing coverage is addressed and the final manifest hash,
complete inventory and capability ceiling are independently accepted.
