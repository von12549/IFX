# V3 lock root

Default lock root for projects built by this package's commands (`<MSBuildProjectName>.packages.lock.json`). The portable V3 package has no production gate project of its own; target packages keep their reviewed lock files under their own `build/locks/`, and tests create locks inside their fixtures with `-LockMode Update`.
