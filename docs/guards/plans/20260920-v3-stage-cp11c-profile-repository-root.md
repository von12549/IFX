# CP11c — profile repository-root bridge

This checkpoint separates the repository that owns profile authorities from the repository being inspected. Generic V3 entry points now accept an explicit `ProfileRepositoryRoot`; when omitted it remains equal to `TargetRoot`, preserving the existing public contract.

The IFX facade supplies its package repository explicitly, so trusted-base candidate packages and installed package copies can validate a different target checkout without reading profile policy through that checkout. Both relative and absolute profile-layout inputs remain confined to the declared authority root, and the generic tool test includes a separated-root positive case plus an escape negative control.

This bridge does not move an IFX authority or alter a gate verdict. It only makes the already-supported package/target separation explicit for profile resolution.
