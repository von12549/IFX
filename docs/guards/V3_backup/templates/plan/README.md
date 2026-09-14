# Formal Plan pair

Use one Markdown plan and one JSON sidecar with the same `YYYYMMDD-short-slug` stem for substantial or risk-triggered work. Small ordinary changes may use `Pre -PlannedPaths` and keep its impact summary in task notes. The JSON is machine input: give it an observable goal, acceptance criteria, exact paths, affected area IDs, applicable rule IDs, validation command IDs from `tech-stack.json`, and decision paths. The Markdown explains intent, architecture tradeoffs, steps and evidence. The Agent must update both if scope changes. The Pre validator checks structure and risk coverage, not business correctness or approval. Read the emitted JSON report and retain its input hash with the Plan evidence.

The files in this directory are examples; copy and rename them before use.
