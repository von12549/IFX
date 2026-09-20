# P11.4 final TCB authorization r6

This authorization-only checkpoint binds candidate `391f2d7f9444a06e87be981020a9be63c1a92e4c` against base `87c22f8590cb239f06d646709e6130ed1d2b63d3` after real PR run `35541565873` exposed presentation-only PowerShell error formatting differences on Ubuntu.

The candidate changes one existing CI contract test helper. It removes ANSI escape sequences, console gutters and line wrapping before matching the same expected semantic error text. Exit-code assertions, negative controls, smoke/full command coverage, required-check identities, executable-entry discovery and all production verdict code remain unchanged. The complete CI contract suite passes locally. The record still covers the complete single P11.4 TCB obligation: 19 components and 753 changed paths.

All earlier P11 final TCB records remain immutable and unconsumed. Only this r6 record is consumed by the final aggregate candidate.

The authorization record cites D35-D38 at their final shared candidate paths; this authorization PR's formal plan cites the corresponding pre-layout decision authorities available to its base-owned validator.
