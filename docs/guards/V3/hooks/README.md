# Optional Agent hook adapter

`Invoke-PlanHook.ps1` calls the same Pre validator used manually. Register it with the Agent host's supported plan-completion or file-change event and provide explicit profile, target and Plan paths. Host registration differs by Agent; copying this folder alone does not activate a hook. A skipped hook is not evidence of a pass. CI must independently check committed plans and code when hard enforcement is required.
