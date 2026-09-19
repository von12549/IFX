# CP11c — manifest fixture contract-copy bridge

The CP11c profile-layout candidate adds a generic V3 contract. The base-owned manifest fixture copied generic build, test, template, script, hook, stage and command roots, but omitted `docs/guards/V3/contracts`; consequently its isolated repository dropped a valid head contract before running the manifest checker.

This bridge adds the missing generic contract root to that fixture copy. It changes no production command, manifest, policy, profile, workflow or verdict. Once merged into the authorization base, the unchanged base-owned test can evaluate new generic contracts without trusting candidate test code.
