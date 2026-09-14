# Project map

Generated view of `project-map.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: project-map.json sha256: 034e182479fda92ca571028eb1d6cebf6bbef3eba87c02c735878c053f46117a -->

## Areas

| ID | Path | Layer | Owner | Similar implementation | Focused commands |
| --- | --- | --- | --- | --- | --- |
| App | src/App/** | application | sample-owner | src/App | sample-test |

## Risk triggers

| ID | Path | Reason |
| --- | --- | --- |
| project-files | **/*.csproj | Project dependency change |

```json
{
  "formatVersion": 1,
  "areas": [
    {
      "id": "App",
      "pathPattern": "src/App/**",
      "layer": "application",
      "owner": "sample-owner",
      "similarImplementationRoot": "src/App",
      "focusedCommands": ["sample-test"]
    }
  ],
  "riskTriggers": [
    { "id": "project-files", "pathPattern": "**/*.csproj", "reason": "Project dependency change" }
  ]
}
```
