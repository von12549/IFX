# P11.5 base-owned unregistered-entry fixture correction

The P11.5 cleanup removes the final files under `docs/guards/V3_ifx/scripts/`. The base-owned trusted-component suite currently creates its synthetic unregistered workflow executable in that legacy directory, so the test aborts before it can assert that the verifier rejects the executable.

This checkpoint moves only that synthetic fixture to the existing canonical `commands/` directory. The negative-control semantics stay unchanged: the workflow references a real but unregistered PowerShell entry, and trusted-component verification must reject it. This correction must merge into the trusted base before the compatibility cleanup can be judged without retaining an empty legacy directory or placeholder file.
