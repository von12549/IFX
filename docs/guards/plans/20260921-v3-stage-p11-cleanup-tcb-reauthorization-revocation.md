# P11.5 cleanup trusted-base reauthorization revocation (D22)

This D22 revocation-only checkpoint deletes the current `p11-compatibility-cleanup-trusted-base` authorization record and adds only this formal plan pair.

The authorization was exact when issued, but the base-owned unregistered-entry fixture correction has since landed independently. That base change removes `Test-IFXTrustedBase.ps1` from the compatibility-cleanup candidate diff and shrinks the candidate's trusted-component set. Because authorization records are immutable, the existing record cannot be edited in place and must be revoked before the same required ID is reissued against the new base and exact candidate tuples.

The nine wrapper deletion authorizations and the cleanup policy authorization remain exact and are deliberately left unchanged. A following authorization-only PR will restore `p11-compatibility-cleanup-trusted-base` for the reduced trusted-component set.

The trusted Diff must report one revocation, zero protected obligations, and all 13 required checks must pass.
