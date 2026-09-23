# IFX Profile bundle draft 0.2.0

Status: **local source-bound draft; not approved for production composition**.

This draft targets the certified but unpublished V4 1.1.2 scope candidate, not the
installed 1.1.1 release. It binds eight exact V3_ifx source authorities and selects
the released-design Architecture Conformance module at local component version 1.0.1.
The `ifx_profile` declares `src` and `tests` as its scan roots and enables only the
Pre-stage resolved project-reference completeness claim. V4 1.1.2 now passes those
roots from the Profile to the adapter and rejects unsafe or out-of-scope references.

The Profile is not a complete IFX guard: project-area ownership, remaining architecture
claims, IFX toolchain prerequisites, baselines, G03/G04/G05 and other specialized gates,
full Stage ownership and detector-family zero-match proofs remain unresolved in
`authority-map.json`. There are no newly contributed modules or capability requests.

No Xiaolong Feng acceptance record exists. Do not compose this draft into an operational
installation, run IFX UI practice, assert V3/V4 parity or cut over. A future exact
bundle review must bind the final manifest and full inventory after those gaps close;
changing any byte invalidates the current manifest hash.
