# V3_ifx lock root

Reviewed NuGet lock files for the IFX trusted guard projects, named `<MSBuildProjectName>.packages.lock.json`. Guard commands restore in locked mode against these files and fail when a lock is missing, changes during restore, or disagrees with `project.assets.json` or the package content hash (Plan 06 D14).

Regenerate only as a reviewed change: run the owning command with `-LockMode Update`, inspect the diff, and commit it with the formal Plan that changes the package references.
