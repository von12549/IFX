# CP11n — Candidate test argument forwarding

The Stage-oriented test relocation exposed an existing PowerShell unrolling edge case in the public CandidateTests dispatcher: a command with exactly one switch produced a scalar string, and array splatting forwarded its characters as separate arguments.

This checkpoint initializes an explicit `string[]` and fills it from the command tail. Commands with no arguments remain empty, one switch remains one argument, and longer CrossPlatform command lines preserve their original ordering and values.

The full Architecture suite also exercises `-DiffConsumptionOnly`. Its protected policy-move fixture now derives the one active legacy or Stage-owned policy root and moves to the other layout, so the negative control remains meaningful after CP11j removed the legacy policy tree.
