# CP11p — Head schema-reference bridge

This follow-up bridge closes the policy-candidate edge exposed by the frozen contract relocation rehearsal. When a registered policy/config document and its schema authority move in the same candidate, the base engine validates the document with the schema referenced by the schema-valid head registry and materializes that schema from the explicit head Git object.

The base registry still determines obligations and authorization coverage. The head registry cannot alter the current verdict; it only supplies the already validated candidate schema reference for head-candidate validation.
