# CP11d Historical Integrity relocation authorization

This authorization-only checkpoint binds the exact CP11d physical relocation candidate prepared from the repaired bridge base. The move record covers the complete legacy and destination trees, the trusted-base record binds the dispatcher, gate engine, candidate verifier and manifest metadata tuples, and the policy record binds all six semantic configuration changes.

The relocation candidate must delete and consume all three records in the same protected diff. This checkpoint itself changes no production input or trusted component.
