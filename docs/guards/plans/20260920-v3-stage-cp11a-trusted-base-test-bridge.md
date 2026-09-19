# CP11a — trusted-base workflow fixture bridge

The first CP11 maintenance relocation candidate exposed a stale base-owned negative fixture: after CP10 routed workflow execution through the public `Invoke-IFXGuardrails.ps1` facade, `Test-IFXTrustedBase.ps1` still tried to inject its unregistered executable after the removed direct historical-integrity test path. The replacement was therefore a no-op, and the negative control incorrectly reported no trusted component change.

This bridge selects one of the two explicitly recognized workflow generations: the legacy direct historical-integrity entry or the current public facade. Absence of both anchors fails closed. It then injects the unregistered executable reference and retains the existing assertion that TCB candidate verification must reject it.

Production workflow, verifier and manifests are unchanged. The exact base-owned test change requires a separate change-trusted-base authorization and must pass candidate parity before the maintenance relocation is rebuilt on top of it.

