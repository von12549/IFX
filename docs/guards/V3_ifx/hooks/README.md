# Optional Agent hook adapter

`Invoke-PlanHook.ps1` calls the same Pre validator used manually. Register it with the Agent host's supported plan-completion or before-edit event and provide explicit profile and target paths plus exactly one of `-PlanPath` or `-PlannedPaths`. It forwards optional `-ReportPath` and `-OutputDirectory` settings. Host registration differs by Agent; copying this folder alone does not activate a hook. A skipped hook is not evidence of a pass. CI must independently check committed plans and code when hard enforcement is required.
