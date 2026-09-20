# CP11c profile layout bridge authorization

This authorization-only checkpoint permits the exact trusted-base bridge prepared for CP11c. The trusted-base record binds all changed tuples in the generic V3 runner, its new layout contract/resolver, the additive test coverage and the trusted-component manifest. A separate policy/config record binds the exact additive `trusted-components.json` pointers because the registry has no semantic comparator for that manifest.

The candidate must consume both authorizations in the same protected diff. No profile authority relocation, IFX caller switch, CI activation or behavior weakening is authorized.
