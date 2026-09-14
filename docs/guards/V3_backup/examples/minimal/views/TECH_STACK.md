# Tech stack

Generated view of `tech-stack.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: tech-stack.json sha256: 5d554f898ff0c285809ceb65d42eb2968ed09f21d77d1c0364488582477bd28f -->

| Languages | .NET gate target | Framework |
| --- | --- | --- |
| C# | net10.0 | xunit |

## Commands

| ID | Executable | Arguments | Working directory |
| --- | --- | --- | --- |
| sample-test | dotnet | test | . |

```json
{
  "formatVersion": 1,
  "targetLanguages": ["C#"],
  "commands": [
    { "id": "sample-test", "executable": "dotnet", "arguments": ["test"], "workingDirectory": "." }
  ],
  "testProject": { "targetFramework": "net10.0", "framework": "xunit" }
}
```
