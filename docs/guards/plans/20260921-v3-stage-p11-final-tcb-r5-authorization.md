# P11.4 final TCB authorization r5

This authorization-only checkpoint binds the completed mixed-layout compatibility candidate `07140746b909117f07d440e1f78766d4ee6262d9` against base `711c5e91e5e169e4776966c4b9e357782954fa52`.

The candidate invokes the pre-layout base trusted runner for required-check verdicts, exposes the legacy smoke/full command declaration inside a non-executable PowerShell block comment for the pre-layout CI verifier, and runs head candidate suites through the new commands facade. The candidate manifest checker excludes only that syntactically closed comment from executable-entry discovery. Both candidate contract suites and a local pre-layout base `Validate` gate pass. The record covers the complete single TCB obligation: 19 components and 753 changed paths.

All earlier P11 final TCB records remain immutable and unconsumed. Only this r5 record is consumed by the final aggregate candidate.
