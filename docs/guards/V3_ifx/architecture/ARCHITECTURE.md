# Architecture and coverage contract

V3 has two responsibilities. Before coding, a Plan skill, template and optional hook help an Agent state intent, paths, risks, owners and evidence. `Pre` validates only that declaration and its association to known rules and decisions. After coding, a generated .NET project performs independent structural checks. `Check` proves the project matches the configured source; `Test` runs detector self-tests and the target scan. Its `Diff` test compares final Git paths against a formal Plan; risk metadata is checked by Pre and must also be reviewed in CI.

The default package is project-neutral. A profile supplies project paths and rule parameters. Detector implementations are versioned templates, not prose synthesis. Each rule has a unique ID, kind, enforcement, authority and coverage. `blocking` is accepted only for implemented detector kinds with positive and negative self-tests. An unsupported detector kind fails generation; a rule with no detector must remain advisory/uncovered.

Initial supported detector: `forbidden-project-reference`. It scans matching `.csproj` files and rejects `ProjectReference Include` values matching a forbidden target glob. This checks declared project edges only. It does not analyze transitive references, imports, compiled assembly references, symbol binding or behavior. Keep an existing specialized detector for those requirements.

The generated .NET project is placed under V3 by default, but GitHub Actions workflows and Agent host registration must be installed at host-specific paths outside V3 to be active. Generation and activation must remain separate operations. No generated output may rewrite an existing authority or gate.
