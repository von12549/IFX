# Plan 06 P11.7 branch cleanup execution record

Execution date: 2026-09-21  
Base: `codex/guards-principles-plan` at `d980fdf77adc0a72538a276ec221abba242a3beb`  
Snapshot current branch: `codex/plan06-closeout`

## Result

The snapshot contained 337 Plan 06-related refs: 267 local and 70 remote. A ref was eligible only when its exact current tip was an ancestor of the base snapshot. The operation deleted 51 local refs and 70 remote refs, then independently verified all 121 refs absent. Remote deletion used an exact per-ref `force-with-lease`, so any tip change would have rejected the push.

The remaining 216 local refs were not proven absorbed by the base, or were the current closeout branch. They were retained. The base branch was outside the child-branch inventory and was never a deletion target. There were no retained remote Plan 06 refs in the snapshot.

## Exact ref inventory

| Scope | Branch | Snapshot tip | Base ancestor | Disposition | Reason |
|---|---|---|---|---|---|
| local | `codex/cp12-ci2-authorization` | `b1d6d3875c7e03df347feb3341919628886ecc34` | yes | deleted | tip-is-base-ancestor |
| local | `codex/cp12-ci2-windows-smoke` | `87ebf850d8eb98c7e3527bc1c1f013684dfb7317` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-activation` | `7f487578654d2e19ea8cf7a4bc286fcac4d34edc` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-activation-authorization` | `33baf97656262884b1d104ece29dba5ae4021d45` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-activation-closeout` | `a15443c4846d76f28e225e26d19ea040d9ecdbb1` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-aggregate-compat-bridge` | `7f9eb2ff62ada63e386b5c44ca423559db223790` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-base-test-fixture-authorization` | `dbe6c9f5e300c4dd544b209852e72663ec0167bb` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-base-test-fixture-fix` | `a50142add066750a5b9066add813b2a1e8af9bfe` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-candidate-layout-compat-auth` | `5f7cace6f26bc48afb21d0c074670c62a8033a08` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-final` | `d4aa33976e0e4685c6357b8959df32336765be8a` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-policy-compat` | `92fc81a8608652dfe69427f1f0608d65c0a56571` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-policy-compat-authorization` | `687eb7fa73e14fd1df6d85d8a81482e491bd9e98` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep` | `7f2ff42f5c9d1154f79fe1a5ec85a38ed94a7a4c` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-authorization` | `aeb478fb29f5810c7b4a907356c3213a9b36db4f` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-bridge-scope-auth` | `7fed7c4c9061baafabb62de9090a038dcb97788f` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-combined-reauth-revocation` | `d2e58077e1ccda399ed471e435c3c4347cb97389` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-combined-reauthorization` | `6aeedb09e75288f1632ef80059249f32b934e20d` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-reauth-revocation` | `ff3a2968311ccd7229126c1891829c8a9f348e92` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-reauth-revocation-r2` | `f7e9a44cc30e2b8017277dc85cf97c4606397732` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-reauthorization` | `99b29c1a798a95e2eef3b038afa85c4cd819e185` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-reauthorization-r2` | `534f7402fe86e5cb3f0f013412924c1940273133` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-prep-revocation` | `c3fb7f8eb636eabcad58216f47c8de5de37a09ae` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-tcb-reauth-revocation` | `6556a365b5bbc59de96d6faf1458592963d7b821` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-cleanup-tcb-reauthorization` | `c2b14b8523f429d0362592fbb8373f4f0b4a4215` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-compatibility-cleanup-authorization` | `cc98619214368d7c7f4f7f2f35c4261c97a0a758` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-authorization` | `2109a3b229c0db81dcc0a5cf929981b402b28242` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-p11-4` | `96e8b8519345f6a44e7548ab4af2c5369287a304` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r2-authorization` | `0f526e8d44ff6dfb6af19854f359d20894204c67` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r3-authorization` | `496e23be80bcdb398298b5fc608942fd410c2869` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r4-authorization` | `c8953e025f4750e6d91ff13146769af78116208e` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r5-authorization` | `1a659af163be075e0503ac5b603abebab4678d17` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r6-authorization` | `e0aec9f9d440b1a3ba7f29344ba690a2bdeacd1b` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-final-tcb-r7-authorization` | `0b2feffa1a0543b7e20e0dec0cd8f7ca1f0453a6` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-inventory-lf-auth` | `08664ad34b3a9c2f06e584fb15af002032e059ca` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-merged-branch-cleanup-plan` | `6880b0e0c07cbe0f51be52fecc5e042e7b9cf047` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-minimal-compat-bridge` | `69cb24a2f04c52c09cb8c6ba804c271a303b639f` | yes | deleted | tip-is-base-ancestor |
| local | `codex/p11-minimal-compat-bridge-auth` | `03359868863ea8d21fbc86eaec99b97648676e7e` | yes | deleted | tip-is-base-ancestor |
| local | `codex/plan06-closeout` | `d980fdf77adc0a72538a276ec221abba242a3beb` | yes | retained | current-unmerged-closeout |
| local | `codex/v3-stage-cp01-p0-baseline` | `268474650cb885bb7b1b1ae769cea0e120c5b87e` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp02-p1-decisions-drift` | `9a04c399deeedc1605c6af6d638a9903ed8e306a` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp03-p5-build-baseline` | `55456fae832d4a692795630e5024e92fc7cc98c7` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp04a-p2-target-root` | `df52a54fc7b807812cac1eace3ee889113361230` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp04b-p2-trusted-base-runner` | `45bbb7915e656a3a580ebfb8d0cd03d91998628e` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07a-authorization` | `449e29d62f7f1dc08d8d40244ef679f1a074742f` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07a-prep-authorization` | `0e2fcc58d8339abf9fd89ae46d00ece58bae30d2` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07a-prep-binding-root` | `6dd58b1ea55b16bc50678ac21469f8fac012249e` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07a-single-source-layerguard` | `17988390ff651d7af20fdf58a9bd9115e78d5826` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07b-authorization` | `6e617ae54c3724858c6a0b1b43eb904593b2fb05` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp07b-engine-binding-separation` | `acd4322ed14436e182986a9b1be9e743d2be73ac` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp07b-prep-authorization` | `716afe41f2e3423319f6c471b601c73d2eb15479` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07b-prep-authorization-r2` | `8c440544e65444a6d2fc965b5e74ba03233243cc` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07b-prep-revocation` | `4d545afe3f259b71f4bfad6d86d3d67812e71cee` | yes | deleted | tip-is-base-ancestor |
| local | `codex/v3-stage-cp07c-authorization` | `737bbd790535f7886113f6363016f58d9feac021` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp07c-engine-in-v3` | `ef55121d73d68caba982f03aadfea6653cc86d63` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp07c-prep-authorization` | `7174b728cac9a4ed859b9fe0fd14a17251b8e8ed` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp07c-prep-v3-engine-paths` | `e033964abc0e6a8c855b666c264f9dac0a82ed2b` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-contract-authorization` | `899bac5bba2d6692c183e57e672808c4ad0c9080` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-contract-authorization-r2` | `2cbf9e9d41d0a98126f49c5be86da13615796550` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep-authorization` | `2fea84b85f69dd7cd081885754186de8aee6dc5e` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep-authorization-r2` | `bda4ae7b52f43295206c94c0c4f6bdc558c3409e` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep-canonical-v3` | `597f72457d94f3f8069196fb365db2c8dc028f23` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep-canonical-v3-r2` | `32fcf3a78166bc758c42e970fe7e5759a55bef5e` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep0-authorization` | `d22d53763e9c3e480ca618fd37c8f1232152099c` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-cp08-prep0-base-tests` | `b4eecb7331473fa185759dd7dee5b84fab5d1202` | no | retained | not-proven-absorbed |
| local | `codex/v3-stage-oriented-package-refactor` | `0df794cbd2b19f148d685133f5a7cb4307991764` | yes | deleted | tip-is-base-ancestor |
| local | `sim/cp07a-work2` | `02fbb36fbcf83a4141ba9cb3cef54981edfbc778` | no | retained | not-proven-absorbed |
| local | `sim/cp07b-work` | `93029fa505ab22a68a709ad789a9bc9d0f9b5a42` | no | retained | not-proven-absorbed |
| local | `sim/cp07c-work` | `c3eef38c5ba0ad9d5186ce241591af32cd8ceefe` | no | retained | not-proven-absorbed |
| local | `sim/cp08-contract-work` | `9ab7d74ad06cb855cc349b3e393b4b771a80a44e` | no | retained | not-proven-absorbed |
| local | `sim/cp08-prep0-work` | `4ce9e5f7f67697c1ef7ffe821917ebba41617cad` | no | retained | not-proven-absorbed |
| local | `sim/cp08-work` | `63042556ee3f3205c6c7bee53490baf24ed65a93` | no | retained | not-proven-absorbed |
| local | `sim/cp09-base-compat` | `2b45b48ac86747ea39d6b8d4a028095e7fbbfedb` | no | retained | not-proven-absorbed |
| local | `sim/cp09-base-compat-raw` | `0a01c670a9cd63c17a7229c4df92359743891fe3` | no | retained | not-proven-absorbed |
| local | `sim/cp09-docs-analysis` | `2988c3f0bf279b2731d47ec815cde851afbb2d31` | no | retained | not-proven-absorbed |
| local | `sim/cp09-docs-analysis-r3` | `630ce6d223f9b1bf981ba565419942afab3722aa` | no | retained | not-proven-absorbed |
| local | `sim/cp09-docs-analysis-raw` | `dff579b5bdae064a3273f8ccb441482fa26b15c1` | no | retained | not-proven-absorbed |
| local | `sim/cp09-docs-analysis-raw-r2` | `c3048abd649d13f85c43d9a4899947c33e692f31` | no | retained | not-proven-absorbed |
| local | `sim/cp09-docs-analysis-raw-r3` | `0fa4378072573d9942b186e10fb1e2907a0b0ba9` | no | retained | not-proven-absorbed |
| local | `sim/cp09-registry-prep` | `4a5a3a57f92946f3b1faff7a0ee60c3aad760a8c` | no | retained | not-proven-absorbed |
| local | `sim/cp09-registry-prep-raw` | `9bffcdf3f88947aff6aef3c3dc7dc8f4f1de2a98` | no | retained | not-proven-absorbed |
| local | `sim/cp10-base-compat-auth` | `8f65cf6953f3a55ab78aeb558b7256a638f7cd4a` | no | retained | not-proven-absorbed |
| local | `sim/cp10-base-compat-auth-r2` | `51b8405403800a1c3da3ee93817b954364e2b9b8` | no | retained | not-proven-absorbed |
| local | `sim/cp10-base-compat-change` | `b1cca7c5e4c43cb1b721d05bde72f7889211e930` | no | retained | not-proven-absorbed |
| local | `sim/cp10-base-compat-change-r2` | `aeed75e282270ecc58ef014dc5730274a7ba28c3` | no | retained | not-proven-absorbed |
| local | `sim/cp10-base-compat-prepared` | `d3e2f810e609e7966e3fae6395ea36cba8298c61` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-auth-r2` | `726b38a0cf92a8d4a1d27bdf5ce1d7dc66b0c0b3` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-auth-r3` | `2553f7dd2312e91173f5e1592da6eb02a597cafa` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-final-r2` | `1e2a054cf86349d5553ad048ff4436c1f2634577` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-final-r3` | `2929bd87ef881fd0458be6d8492d063d5831fa3c` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-lifecycle` | `ef763adc4f242af746b20b70afd5d469749c3730` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-prepared-r2` | `643661d0c0c8838d9ee81da9a671686bbdbbc2bf` | no | retained | not-proven-absorbed |
| local | `sim/cp10-ci-activation-prepared-r3` | `2c907369a4387ae25c991e8b72961e0c75957312` | no | retained | not-proven-absorbed |
| local | `sim/cp10-registry-prep` | `d223e1a2e93b8da5db32df437754007d7dd03f21` | no | retained | not-proven-absorbed |
| local | `sim/cp10-registry-prep-auth` | `5ca166e5c0d3d7673a6276890309b676596b9c83` | no | retained | not-proven-absorbed |
| local | `sim/cp10-registry-prep-auth-r2` | `c563cb9b92dcc49b7ba5ed475205d916c48dc85b` | no | retained | not-proven-absorbed |
| local | `sim/cp10-registry-prep-change` | `cea99294b3d4fecd6bbd9d3fcd7b90bdd84936a4` | no | retained | not-proven-absorbed |
| local | `sim/cp10-registry-prep-change-r2` | `2ef914f98513ff09d34c4770a17af863c90def53` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-bridge-auth` | `e9d6d0d49accb273f5136ab55aad617fedf0492a` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-bridge-change` | `8719ae8bd78da6c241b679018649ea0fb9c16279` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-bridge-prepared` | `8b7cd709f5ff12929c30eebcf1d76f2b0e50983f` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-auth` | `2dcc81f9c9b560653f07e4c2a4b6b8ac71b463f2` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-auth-r2` | `eab88251dfc85945fd2f39e4510b157facd9cec5` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-change` | `f2867cc4ed433fcf6c604d8710224e8fee576042` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-change-r2` | `9add404eb7925f3f3ca491d57397e46905cff2df` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-prepared` | `524a5cf4b2cac38e5561641c01b047ef620fb627` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-maintenance-relocation-prepared-r2` | `e545a2c29317166679a97db15e22c573e69bbd26` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-trusted-base-test-bridge-auth` | `0b0bf32511ce0313f9436c60a38e71733bfeaabb` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-trusted-base-test-bridge-change` | `91f8041fc8e59a0bfe1400cd9198b144ea29c76d` | no | retained | not-proven-absorbed |
| local | `sim/cp11a-trusted-base-test-bridge-prepared` | `685405f91aa61ec3a490905db0f820bc12f4f4a4` | no | retained | not-proven-absorbed |
| local | `sim/cp11b-v3-backup-retirement-bridge-auth` | `ff191f840008d4a1e317818f2039903ed2bb6e9c` | no | retained | not-proven-absorbed |
| local | `sim/cp11b-v3-backup-retirement-bridge-prepared` | `e18894b554fb45b0a19f32567e3377cd521dbe73` | no | retained | not-proven-absorbed |
| local | `sim/cp11b-v3-backup-retirement-change` | `409ff738165ade33bd926bd27512363053f086bd` | no | retained | not-proven-absorbed |
| local | `sim/cp11b-v3-backup-retirement-prepared` | `b4194d11f79605ddec5fc00700b6767ab1faa070` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-manifest-contract-copy-auth` | `7a26c7c7287d8ed3958d20ec083734776960bc73` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-manifest-contract-copy-candidate` | `f149b5d5ea62f8bdcdba2255cf71b4b3509cc341` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-manifest-contract-copy-change` | `21bc98f452971bfe2a085c3dae8c6db5cb6adf36` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-authority-split-auth-r2` | `c8924506be5734d1d0d96b35a886527d816cec1a` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-authority-split-candidate` | `4a5c19b1135d4923a6053bf1508bb8b7132aef3c` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-authority-split-candidate-r2` | `9abf55a38ee2336cdeef4f6406520ecc74e7568d` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-authority-split-change-r2` | `d85819563d2669510a7802615557f09e5de24f19` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-authority-split-change-r3` | `72094201120ae412a23b58e7f135388d195a0b9f` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-auth` | `e04713b96c6aa2ba191a37bbd3fb09cafc46bd89` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-auth-r3` | `8fba3fcce7b1d739527d500f31f80f3a612fbdb9` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-candidate` | `452ff02f99908a7929563e62c51d40c431ead7a7` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-change` | `9e4ee3d0fec78528b4a203904958c1379cefa8d3` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-change-r2` | `cc396971432dbc8dc69b70aeb9bbcb373b8ba039` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-layout-bridge-change-r3` | `efe13f7fb83d0fa0423dc81ed2f04c4ea4dd460c` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-registry-prep-auth` | `671ffaf2ac9829ad33d4b2c88bb657a6072f0b41` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-registry-prep-auth-r2` | `be861265326b3a1ce5caca43de131495c7127f57` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-registry-prep-candidate` | `bddf1029689872f1c0e5cde9a6e0b8a72a36b4e6` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-registry-prep-candidate-r2` | `29532d8dbb29882d32bbd2324de2c5befc1636c0` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-registry-prep-change-r2` | `c2512eeadf03cd16a603013980558fe681d81765` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-repository-root-auth` | `02d81fd82ded95828042c06a22255b4e6b30e641` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-repository-root-candidate` | `792c420b9adb5ebd6266920ed598277aa42d88e3` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-repository-root-change` | `6ff14c2c6e3985a13c8fb676ad4cccd164afa137` | no | retained | not-proven-absorbed |
| local | `sim/cp11c-profile-repository-root-change-r2` | `14484b7b86d882a8baaaf3e2d8ecd5b9b962f310` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-auth` | `7e4d8e3d4e4bdd0cd55387d6a1a981cd11bc3ba8` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-auth-r2` | `05758278046d4200383fc401d091335e7d1a7e6a` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-candidate` | `a985bb797238b63a3192159433421ab077d345a4` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-candidate-r2` | `51eeb0eb860bc5a379432a699aac15f0b03aab05` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-change` | `b23b41cd418806a738b471dc242cb8db058dd73b` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-historical-integrity-relocation-change-r2` | `71227ebc6f1c0bf584ac560c6bbce8baceb3df24` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-candidate-report-root-auth` | `9210f795567444d50aa23a50e080565cfb08f170` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-candidate-report-root-candidate` | `0b044da89527117484faa123438b2bc218af1bd8` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-candidate-report-root-change` | `cd48d2a1c11bcedc6b89b76552224b47811188c6` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-relocation-bridge-auth` | `0532b56062516ed8b46d16762ad70e0761a9e61c` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-relocation-bridge-candidate` | `2fcfe8c6f8677bec1eceb608d797662602a94e4b` | no | retained | not-proven-absorbed |
| local | `sim/cp11d-history-relocation-bridge-change` | `cdfd2355434d68ec1f8ffbab6d67849e6997642b` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-auth` | `51b9aeb7a7caa15b3968bc1801f6e1edbd49c029` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-bridge-auth` | `c5fdef67894e127ce27cd226b35d770e156f7a9e` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-bridge-candidate` | `acc418d42dffe9d39951341194ab5e8a86f5f099` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-bridge-change` | `b8c8f78f0db4eae0cc2c04ff8ab7f6f5da6a0f25` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-candidate` | `84f5e4f3dfa9942b4e7f8234f4d45ac6c7a3562d` | no | retained | not-proven-absorbed |
| local | `sim/cp11e-quality-relocation-change` | `ef349217dac779650c8a9620dc57890ac86443d9` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-registry-prep-auth` | `af3c822a424dec45c605ac4f093979b2553c0bb5` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-registry-prep-candidate` | `e13422c86c863b92f4a27e9cf568d257eed68f5d` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-registry-prep-change` | `90ba06fc5c72c85fa1ce2b3de97fe16023e5b925` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-auth` | `692c492d69dffb661926e8960651a9d721d2493c` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-auth-r2` | `713945c7cb0af127b2460cf73d2390e3d4ae66ba` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-bridge-auth` | `c1cdc401b3c5e3b008f056d965567c40e5e854d7` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-bridge-candidate` | `ab2667f0e4209172b5960b852dc9ca17db162f99` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-bridge-change` | `692c492d69dffb661926e8960651a9d721d2493c` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-candidate` | `c7c4f3d3fa8ed9f28bc673e8bf542fd333129e62` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-candidate-r2` | `7e7e64fffa8e81cb26f7c1733123236aa293a20e` | no | retained | not-proven-absorbed |
| local | `sim/cp11f-specialized-relocation-change-r2` | `eb037102404940ed08cb56fe5b2b24c6f1e1f9f8` | no | retained | not-proven-absorbed |
| local | `sim/cp11g-agent-integrations-auth` | `719433c3e4a06d1d6b7710338756e8d934776694` | no | retained | not-proven-absorbed |
| local | `sim/cp11g-agent-integrations-candidate` | `cfe80e02547da81016edbdc02831e86fc26ad546` | no | retained | not-proven-absorbed |
| local | `sim/cp11g-agent-integrations-change` | `84546ceb147a4719a5361b141c20e3da00bd7e7d` | no | retained | not-proven-absorbed |
| local | `sim/cp11h-rule-guide-auth` | `0e3f4508d53624fbef8200fb7c239838ae2f36e1` | no | retained | not-proven-absorbed |
| local | `sim/cp11h-rule-guide-candidate` | `5ef1b5a5b660c6a732c3e3d526744223406536bc` | no | retained | not-proven-absorbed |
| local | `sim/cp11h-rule-guide-change` | `fba04b08cb1b1ee14c537c6abcac67c41ea8ddd1` | no | retained | not-proven-absorbed |
| local | `sim/cp11i-docs-examples-auth` | `10dac31f7d1516bd7fb61f58e1c03459a2a381fc` | no | retained | not-proven-absorbed |
| local | `sim/cp11i-docs-examples-candidate` | `fab4750427b809d03f9f477065b680a3ad6ebbcc` | no | retained | not-proven-absorbed |
| local | `sim/cp11i-docs-examples-change` | `e44e1774956cf4709c0eb2b14323a85ab6b60f2f` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-auth` | `e3fe0239eb0128da2f0aac8bd15e87761aa9e78e` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-candidate` | `8711bfac86f9cc4d2ee6e80559a6328d3ddca34c` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-candidate-v2` | `e981d0f540c52036ea24c3bd18f503942065d04a` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-candidate-v3` | `ab1fee2aa4cff859fe1b21a3078b6fd57c3c6bfa` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-candidate-v4` | `234a6e8e638b87e63798d4b2aaeeb947c3a275ad` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-relocation-change` | `f949825f80880d41560ee312213a50ffcf710dcd` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-auth` | `0da14662c027312b2340433e8bc5cfc8a65dcfdc` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-auth-v2` | `f7c5e03768f4a6ef5f59d354cfc95907d278e827` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-candidate` | `84a31b3e47ae1394a8f97add10b0ec5a4b74965e` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-candidate-v2` | `f3e24c93d1335af16be6bb9c554f12401cb7d145` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-change` | `e8be2b5b6a17ae82875f9962141851caa79b7c00` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-data-test-bridge-change-v2` | `a36b34a97d0738efa443791e9eadd9a6148ce6da` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-layout-bridge-auth` | `89d72fdc22bdd033d070f033781c5d317e5954f3` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-layout-bridge-candidate` | `786e9fb5bf88b208ce598558dcb5e088c8d14598` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-layout-bridge-change` | `16247b62b6a3866b9c0bff34caf4c990212ba418` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-registry-move-bridge-auth` | `a415aeab86e5521d04c201b671b9a1e6beb51560` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-registry-move-bridge-candidate` | `32858612f63c31f41bc65db14beffe5f2f3e0fe0` | no | retained | not-proven-absorbed |
| local | `sim/cp11j-policy-registry-move-bridge-change` | `e178c5c4a3c6ce51ab596c00c17303a2490bd0a6` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-layout-bridge-auth` | `d08c9ddeff4e1243c5588d50c8fa9ccc1f25dafc` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-layout-bridge-candidate` | `90e39aa709257c91f10d3a278fa3704c3ff5dd90` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-layout-bridge-change` | `9f5726e6ed690edeab5ee01c63b1d6d54eb07bf8` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-auth` | `fb5566376c6bf3060fdc454805239dd7db25252f` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-auth-v2` | `ceace349c49c440dc678e2629a670e73ef6f467f` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-candidate` | `658fec1f5282f20bdafbf1c42e7f589c80889feb` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-candidate-v2` | `4d4644bc63b8a0829bd61e1e3b113f9e5461cc0c` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-change` | `da5db1778f05710cf51cb08ce476a525a702ca1b` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-authority-registry-relocation-change-v2` | `b5f1e175a9f5b97c189c4d7dbb1f393efb310931` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-policy-test-layout-bridge-auth` | `fcd91a30b7fe7f05db13ef3b4cb1ba746be6b57a` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-policy-test-layout-bridge-candidate` | `8c115d15aa8f9f690de789f41afbf210735abc15` | no | retained | not-proven-absorbed |
| local | `sim/cp11k-policy-test-layout-bridge-change` | `a7d9dbc4a0a980c1102913248bb779774aa43e81` | no | retained | not-proven-absorbed |
| local | `sim/cp11l-analysis-progress-relocation-auth` | `81ef1771a5aae62436f13eb4a035c7f240447d30` | no | retained | not-proven-absorbed |
| local | `sim/cp11l-analysis-progress-relocation-candidate` | `c0bf2b1300b0f0164d5a63437e0a4f245c593518` | no | retained | not-proven-absorbed |
| local | `sim/cp11l-analysis-progress-relocation-change` | `4b7776cf05a364bca1c23179a624892ad09daae6` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-copy-bridge-auth` | `bc5496ffa8ec20970bf70c32b7d042fa12f71971` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-copy-bridge-candidate` | `214caf0b05559190d274336f246c862520485a7d` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-copy-bridge-change` | `fe4fb1c62ba8d46257fbf490d106834ddacb0dad` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-policy-bridge-auth` | `436c519945bb2e5ca444bdb242a4ad3af5e87c5d` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-policy-bridge-candidate` | `ff51cd533cbb061c7e98f3dd8113244770fc075a` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-policy-bridge-change` | `a2b828886062642a8842f119f64e5a9e28ed1aa7` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-relocation-auth` | `fe4fb1c62ba8d46257fbf490d106834ddacb0dad` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-relocation-auth-v2` | `ecdae69656aadc684c46347ccb900f2c845aeda8` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-relocation-candidate` | `102f23dcff54a890dd1ae2f29a418a40e6b9a6f8` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-relocation-candidate-v2` | `22f5631689c6c26cc31c483aad0104a04c7e015b` | no | retained | not-proven-absorbed |
| local | `sim/cp11m-refactor-baseline-relocation-change-v2` | `2f33e13360844677c364360bd7f56f254edf8629` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-candidate-test-execution` | `8aa759b27b1f0d65185910a6c354d3b8591418b4` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-candidate-test-execution-auth` | `54e685e1260e87ebfe1a5f41effab27eff77abff` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-candidate-test-execution-change` | `4b511c7180e5c86d2953aec32f1145f17e3e8a71` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-bridge` | `79a032ddda7b8ddc29a63bf34a76a0351965c3f2` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-bridge-auth` | `2dee7ece590cfbdfc272f164b684926e5b0e0cd9` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-bridge-change` | `ff201b257096bc1b7eaa16801ec96e1b7f42858c` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-relocation` | `7b8b1a92a231a9371997666826a5ae0b68deac22` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-relocation-auth` | `f051f641e70ae9e9cf2a65b782c6cbf274e1765b` | no | retained | not-proven-absorbed |
| local | `sim/cp11n-test-layout-relocation-change` | `64c5d403b2374dd985f73c54a61c972f023cbf73` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-history-relocation` | `e81ab4c641006b790f71d3836d9c5498276a9658` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-history-relocation-auth` | `d3e3fab84d14e424ca1f5f4a8bec0abd351725dc` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-history-relocation-auth-r2` | `fb208e6959fc2fc397561085ee612914ede89508` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-history-relocation-change` | `7c165c3271247e9e9002ee2d81cbe3d57b9d45d7` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-history-relocation-change-r2` | `f1a81d50ceab61ee059a41b8138d331e844ed7e6` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-layout-bridge` | `2524d3bbd7566afe76364764e9d4f2aa3fce0f63` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-layout-bridge-auth` | `d504f0fc862f77cdb2ce2cf7eaa2a8c752d596af` | no | retained | not-proven-absorbed |
| local | `sim/cp11o-decision-layout-bridge-change` | `739b172b34869c908c1ab8bab7489e98d31a8d06` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-layout-bridge` | `effd8443e618e6f302f41603b5eb8ad162f6a362` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-layout-bridge-auth` | `4adcaccde4dd0b5a08f29b66753b1475653ed283` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-layout-bridge-change` | `17818d323b6c19234c4311b8d43d4114f2a6abc7` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation` | `98caa8d3f73e74f4a88fb7d397d32b6783a451cb` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation-auth` | `b8b3ebd352a6f7017b470517fb6f4d33a69cbbed` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation-auth-r2` | `e76aa2c6e49681324b320df361e37c8066504a3d` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation-change` | `6b68c25ad55d7d7a96897aa2844a7552a26da655` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation-change-r2` | `74a2ce1a0822db8598fb45223571197de3767fd3` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-relocation-r2` | `bb5a68fdd6423bf5e4997f3a486f7f38114cf4fb` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-schema-reference-bridge` | `62ee9d9d2a869dfb514351facbe4f33f1dc615cc` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-schema-reference-bridge-auth` | `9028c8e038a086e132bae276966aafba23e443d7` | no | retained | not-proven-absorbed |
| local | `sim/cp11p-contract-schema-reference-bridge-change` | `32f7b43de74f36cd7435aa559ae0d22321d2402a` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-layout-test-bridge` | `90b19a5a4481be8537fe858e0a285e08c6c50927` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-layout-test-bridge-auth` | `592d8927d905ddf967c679a979f0c216f2c9b1c6` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-layout-test-bridge-change` | `8d671fa46b0ade2a449649b3c495be8836830f77` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-ownership-relocation` | `c0b3d925b561e09028320be916865cb24c01f2b3` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-ownership-relocation-auth` | `a938b425be4fe903889c6a8022dedc2472468b4f` | no | retained | not-proven-absorbed |
| local | `sim/cp11q-verifier-ownership-relocation-change` | `7b66a4bc7b541d3ee877a0ba9c44c55a73cca44a` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-layout-bridge` | `4f9c3c9c7a338105490055598ed50d5210b45be2` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-layout-bridge-auth` | `e3df5989e8392ccea06362786431d558576b4e38` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-layout-bridge-auth-r2` | `595954e181e2a28ed9b0757fe5aa25d7f461e51c` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-layout-bridge-change` | `99e258e172001ef670b7f97e79eaa3001cc8d2ad` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-layout-bridge-change-r2` | `7990855f5cb5581c00e424c59f1c0246459d0caf` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation` | `7487b1266605cdb21f87ec0f555c1af7944d4bdb` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-auth` | `0d06964d1683eb1b7530ff67b1bd0513cb8a0b21` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-auth-r2` | `d5eab094836d8b304f16570efa9b972e40afc0f6` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-auth-r3` | `3fe287f4a63158c94c10afd48684c9a1eda84501` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-change` | `de60dfb867692776d530acd2308fb74baed62ccb` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-change-r2` | `6d947a1ebcb3ffde572faba132384c579698a340` | no | retained | not-proven-absorbed |
| local | `sim/cp11r-layerguard-post-relocation-change-r3` | `63ae9f6521d035a6fafb43533a3518842d10ad94` | no | retained | not-proven-absorbed |
| local | `sim/cp12a-final-verification` | `d74cda2369b0ecc7a27788d014cfc85bbb830fb8` | no | retained | not-proven-absorbed |
| local | `sim/cp12a-p11-final-prepared` | `9c5682811efa93a9249c2920218e17ba74e4c708` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/cp12-ci2-authorization` | `b1d6d3875c7e03df347feb3341919628886ecc34` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/cp12-ci2-windows-smoke` | `87ebf850d8eb98c7e3527bc1c1f013684dfb7317` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-activation` | `7f487578654d2e19ea8cf7a4bc286fcac4d34edc` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-activation-authorization` | `33baf97656262884b1d104ece29dba5ae4021d45` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-activation-closeout` | `a15443c4846d76f28e225e26d19ea040d9ecdbb1` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-base-test-fixture-authorization` | `dbe6c9f5e300c4dd544b209852e72663ec0167bb` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-base-test-fixture-fix` | `a50142add066750a5b9066add813b2a1e8af9bfe` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-final` | `d4aa33976e0e4685c6357b8959df32336765be8a` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-policy-compat` | `92fc81a8608652dfe69427f1f0608d65c0a56571` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-policy-compat-authorization` | `687eb7fa73e14fd1df6d85d8a81482e491bd9e98` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep` | `7f2ff42f5c9d1154f79fe1a5ec85a38ed94a7a4c` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-authorization` | `aeb478fb29f5810c7b4a907356c3213a9b36db4f` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-bridge-scope-auth` | `7fed7c4c9061baafabb62de9090a038dcb97788f` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-combined-reauth-revocation` | `d2e58077e1ccda399ed471e435c3c4347cb97389` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-combined-reauthorization` | `6aeedb09e75288f1632ef80059249f32b934e20d` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-reauth-revocation` | `ff3a2968311ccd7229126c1891829c8a9f348e92` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-reauth-revocation-r2` | `f7e9a44cc30e2b8017277dc85cf97c4606397732` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-reauthorization` | `99b29c1a798a95e2eef3b038afa85c4cd819e185` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-reauthorization-r2` | `534f7402fe86e5cb3f0f013412924c1940273133` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-prep-revocation` | `c3fb7f8eb636eabcad58216f47c8de5de37a09ae` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-tcb-reauth-revocation` | `6556a365b5bbc59de96d6faf1458592963d7b821` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-cleanup-tcb-reauthorization` | `c2b14b8523f429d0362592fbb8373f4f0b4a4215` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-compatibility-cleanup-authorization` | `cc98619214368d7c7f4f7f2f35c4261c97a0a758` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-authorization` | `2109a3b229c0db81dcc0a5cf929981b402b28242` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-p11-4` | `96e8b8519345f6a44e7548ab4af2c5369287a304` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r2-authorization` | `0f526e8d44ff6dfb6af19854f359d20894204c67` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r3-authorization` | `496e23be80bcdb398298b5fc608942fd410c2869` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r4-authorization` | `c8953e025f4750e6d91ff13146769af78116208e` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r5-authorization` | `1a659af163be075e0503ac5b603abebab4678d17` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r6-authorization` | `e0aec9f9d440b1a3ba7f29344ba690a2bdeacd1b` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-final-tcb-r7-authorization` | `0b2feffa1a0543b7e20e0dec0cd8f7ca1f0453a6` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-merged-branch-cleanup-plan` | `6880b0e0c07cbe0f51be52fecc5e042e7b9cf047` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-minimal-compat-bridge` | `69cb24a2f04c52c09cb8c6ba804c271a303b639f` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/p11-minimal-compat-bridge-auth` | `03359868863ea8d21fbc86eaec99b97648676e7e` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp01-p0-baseline` | `268474650cb885bb7b1b1ae769cea0e120c5b87e` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp02-p1-decisions-drift` | `9a04c399deeedc1605c6af6d638a9903ed8e306a` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp03-p5-build-baseline` | `55456fae832d4a692795630e5024e92fc7cc98c7` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp04a-p2-target-root` | `df52a54fc7b807812cac1eace3ee889113361230` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp04b-p2-trusted-base-runner` | `45bbb7915e656a3a580ebfb8d0cd03d91998628e` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp04c-p2-trusted-build-isolation` | `4096cee83a563db0dba7ef8e6764165bface180d` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp04d-p2-workflow-switch` | `0c4187ff36b5c9b4fdaaee24713a13834c1d5130` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05-authorization` | `238791152071ab96fe2d129def5d627f76ce0856` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05-p3-diff-hardening` | `780f6c4ffdccbfa51fd4d615e63839e082c2b433` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05a-authorization` | `065b4513e56970a6cc10b6ce57fd801b3e6db1f3` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05a-authorization-consumption` | `6a4452d5c24618111c37baee611b452d364c5f25` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05a-break-glass-evidence` | `add7e41d56cff7ee3b0f4a508dd5757fc149ad2a` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05a-verify-authorization` | `a7bcfe4337d58cd8c5ade2c94d17fb3daff081d5` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp05a-verify-change` | `0d681119b80e0dd1e006c182fb1d99ecc9b3e5cb` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06a-authorization` | `56381c36772aca77b9fffd6d0612ad4a7ccff91b` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06a-protected-change-obligations` | `6f4055a2f182ecd30a7b4a61c3d67eb4defaf007` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06b1-authorization` | `25c2a33222adbad7beea97034aef46bb900e4281` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06b1-policy-config-dual-track` | `78acecf4697c23994a4b7dc554ba6fefd029023a` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06b2-authorization` | `ffec7aa2132492ff41467b1146a6b410f74d9c38` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06b2-domain-authority-coverage` | `ac3d897f1fb4eedd0c245fb85adb2256145279d8` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06c-authorization` | `82145d5f5d8b20a3dd072745c622f440d3ec1812` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06c-rehearsal-evidence` | `6fd890db4b8c001192275e7ae869fd1a84b55cdf` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06d-authorization` | `33a2bb118fcbaa015f3c19ef3f7b4cc67158ed8b` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp06d-d17-validator-retirement` | `2b1210fae27e188a95da5c07ce4d73dcd7f77d55` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07a-authorization` | `449e29d62f7f1dc08d8d40244ef679f1a074742f` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07a-prep-authorization` | `0e2fcc58d8339abf9fd89ae46d00ece58bae30d2` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07a-prep-binding-root` | `6dd58b1ea55b16bc50678ac21469f8fac012249e` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07a-single-source-layerguard` | `17988390ff651d7af20fdf58a9bd9115e78d5826` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07b-prep-authorization` | `716afe41f2e3423319f6c471b601c73d2eb15479` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07b-prep-authorization-r2` | `8c440544e65444a6d2fc965b5e74ba03233243cc` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07b-prep-ifx-facade` | `44ce95c09f880d10d47c6070ace18a9a0b3f21b4` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07b-prep-revocation` | `4d545afe3f259b71f4bfad6d86d3d67812e71cee` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07ci-authorization` | `c7e7b436bfbd61fe3b8972ace8ea3020f1f0277f` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-cp07ci-cost-controls` | `42a04e522d9cf186bfd5a5da8f1973833aed7553` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-oriented-package-refactor` | `0df794cbd2b19f148d685133f5a7cb4307991764` | yes | deleted | tip-is-base-ancestor |
| remote | `codex/v3-stage-p28-trusted-base-verification` | `1762733a7cc034e516336e510a0dd0fbcf80e3fb` | yes | deleted | tip-is-base-ancestor |

## Worktrees required for branch deletion

The following 18 clean worktrees held local branches in the deletion set. Each path was resolved and constrained to the Codex worktree root or `D:\IFX\artifacts\worktrees\`, rechecked clean, and removed through `git worktree remove`. One Windows long-path residual was removed only after Git had unregistered it and a second clean-status check passed.

- `D:/IFX/artifacts/worktrees/p11-minimal-bridge-audit-base`
- `C:/Users/von12/.codex/worktrees/p11-base-test-fixture-fix/IFX`
- `D:/IFX/artifacts/worktrees/p11-candidate-layout-compat-auth`
- `D:/IFX/artifacts/worktrees/p11-cleanup-policy-compat`
- `D:/IFX/artifacts/worktrees/p11-cleanup-policy-compat-authorization`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-authorization`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-bridge-scope-auth`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-combined-reauth-revocation`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-combined-reauthorization`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-reauth-revocation`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-reauthorization`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-reauthorization-r2`
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-revocation`
- `C:/Users/von12/.codex/worktrees/p11-cleanup-tcb-reauth-revocation/IFX`
- `C:/Users/von12/.codex/worktrees/p11-cleanup-tcb-reauthorization/IFX`
- `D:/IFX/artifacts/worktrees/p11-final-authorization`
- `D:/IFX/artifacts/worktrees/p11-inventory-lf-auth`
- `D:/IFX/artifacts/worktrees/p11-bridge-auth`

## Detached worktrees deliberately retained

A separate scan found the following 70 clean detached worktrees whose names suggest CP10, CP11 or P11 activity. They were not needed to delete a branch, and the P11.7 authorization does not establish that every filesystem tree with those name fragments is disposable. A safety review rejected broad recursive cleanup, so these paths were left untouched.

- `C:/Users/von12/.codex/worktrees/cp11c-authority-split-auth-r2/IFX` at `93f109e9125c739185c7d1fa540c5f37a21391b8` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-authority-split-auth-r3/IFX` at `c8924506be5734d1d0d96b35a886527d816cec1a` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-authority-split-base/IFX` at `efe13f7fb83d0fa0423dc81ed2f04c4ea4dd460c` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-manifest-contract-copy-authorized-base/IFX` at `7a26c7c7287d8ed3958d20ec083734776960bc73` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-layout-authorized-base/IFX` at `2ecc0d9ab189812886a009203db34519354fd964` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-layout-authorized-base-r2/IFX` at `e04713b96c6aa2ba191a37bbd3fb09cafc46bd89` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-layout-base/IFX` at `409ff738165ade33bd926bd27512363053f086bd` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-layout-final-authorized-base/IFX` at `8fba3fcce7b1d739527d500f31f80f3a612fbdb9` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-layout-post-fixture-base/IFX` at `21bc98f452971bfe2a085c3dae8c6db5cb6adf36` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-root-auth-base/IFX` at `a9f87ba2e4e3147ab069e8f61c5d17b8b06247c9` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-root-auth-r2/IFX` at `02d81fd82ded95828042c06a22255b4e6b30e641` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-profile-root-final-base/IFX` at `14484b7b86d882a8baaaf3e2d8ecd5b9b962f310` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-registry-prep-auth-r2/IFX` at `be861265326b3a1ce5caca43de131495c7127f57` (detached)
- `C:/Users/von12/.codex/worktrees/cp11c-registry-prep-final-base/IFX` at `c2512eeadf03cd16a603013980558fe681d81765` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-auth-base/IFX` at `f8020796025ee49c7384a2b371bd84f39ff3f4d4` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-base/IFX` at `72094201120ae412a23b58e7f135388d195a0b9f` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-relocation-auth-base/IFX` at `7e4d8e3d4e4bdd0cd55387d6a1a981cd11bc3ba8` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-relocation-auth-base-r2/IFX` at `05758278046d4200383fc401d091335e7d1a7e6a` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-relocation-base/IFX` at `cdfd2355434d68ec1f8ffbab6d67849e6997642b` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-report-auth-base/IFX` at `9210f795567444d50aa23a50e080565cfb08f170` (detached)
- `C:/Users/von12/.codex/worktrees/cp11d-history-report-final-base/IFX` at `cd48d2a1c11bcedc6b89b76552224b47811188c6` (detached)
- `C:/Users/von12/.codex/worktrees/cp11e-quality-auth-base/IFX` at `c5fdef67894e127ce27cd226b35d770e156f7a9e` (detached)
- `C:/Users/von12/.codex/worktrees/cp11e-quality-base/IFX` at `71227ebc6f1c0bf584ac560c6bbce8baceb3df24` (detached)
- `C:/Users/von12/.codex/worktrees/cp11e-quality-relocation-auth-base/IFX` at `51b9aeb7a7caa15b3968bc1801f6e1edbd49c029` (detached)
- `C:/Users/von12/.codex/worktrees/cp11e-quality-relocation-base/IFX` at `b8c8f78f0db4eae0cc2c04ff8ab7f6f5da6a0f25` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-registry-prep-auth-base/IFX` at `af3c822a424dec45c605ac4f093979b2553c0bb5` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-relocation-auth-base-r2/IFX` at `713945c7cb0af127b2460cf73d2390e3d4ae66ba` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-relocation-base/IFX` at `ef349217dac779650c8a9620dc57890ac86443d9` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-relocation-bridge-auth-base/IFX` at `c1cdc401b3c5e3b008f056d965567c40e5e854d7` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-relocation-physical-base/IFX` at `692c492d69dffb661926e8960651a9d721d2493c` (detached)
- `C:/Users/von12/.codex/worktrees/cp11f-specialized-relocation-registry-base/IFX` at `90ba06fc5c72c85fa1ce2b3de97fe16023e5b925` (detached)
- `C:/Users/von12/.codex/worktrees/cp11g-agent-integrations-auth-base/IFX` at `719433c3e4a06d1d6b7710338756e8d934776694` (detached)
- `C:/Users/von12/.codex/worktrees/cp11g-agent-integrations-base/IFX` at `eb037102404940ed08cb56fe5b2b24c6f1e1f9f8` (detached)
- `C:/Users/von12/.codex/worktrees/cp11h-rule-guide-auth-base/IFX` at `0e3f4508d53624fbef8200fb7c239838ae2f36e1` (detached)
- `C:/Users/von12/.codex/worktrees/cp11h-rule-guide-base/IFX` at `84546ceb147a4719a5361b141c20e3da00bd7e7d` (detached)
- `C:/Users/von12/.codex/worktrees/cp11i-docs-examples-auth-base/IFX` at `10dac31f7d1516bd7fb61f58e1c03459a2a381fc` (detached)
- `C:/Users/von12/.codex/worktrees/cp11i-docs-examples-base/IFX` at `fba04b08cb1b1ee14c537c6abcac67c41ea8ddd1` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-candidate-bridge-auth-base/IFX` at `0da14662c027312b2340433e8bc5cfc8a65dcfdc` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-candidate-bridge-final-base/IFX` at `e8be2b5b6a17ae82875f9962141851caa79b7c00` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-candidate-bridge-v2-auth-base/IFX` at `f7c5e03768f4a6ef5f59d354cfc95907d278e827` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-candidate-bridge-v2-final-base/IFX` at `a36b34a97d0738efa443791e9eadd9a6148ce6da` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-data-relocation-auth-base/IFX` at `e3fe0239eb0128da2f0aac8bd15e87761aa9e78e` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-data-test-bridge/IFX` at `16247b62b6a3866b9c0bff34caf4c990212ba418` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-layout-base/IFX` at `e44e1774956cf4709c0eb2b14323a85ab6b60f2f` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-layout-bridge-auth-base/IFX` at `89d72fdc22bdd033d070f033781c5d317e5954f3` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-registry-move-bridge-auth-base/IFX` at `a415aeab86e5521d04c201b671b9a1e6beb51560` (detached)
- `C:/Users/von12/.codex/worktrees/cp11j-policy-registry-move-bridge-final-base/IFX` at `e178c5c4a3c6ce51ab596c00c17303a2490bd0a6` (detached)
- `C:/Users/von12/.codex/worktrees/p11-bridge-base/IFX` at `ed063c964e50dabd08b8dbb15ffce57654a2ac53` (detached)
- `C:/Users/von12/.codex/worktrees/p11-cleanup-prep-base2/IFX` at `f3e02e205b246fed32e4ce85293cf21e1f6efa50` (detached)
- `C:/Users/von12/.codex/worktrees/p11-compatibility-cleanup-base-validation/IFX` at `95325f548432e49fb5b0879282f2c1820096c541` (detached)
- `C:/Users/von12/.codex/worktrees/p11-fresh-win-check/IFX` at `398fb5d98edf05be51fe6f035674ad65297c19d1` (detached)
- `D:/IFX/artifacts/worktrees/cp10-base-compat-base` at `8f65cf6953f3a55ab78aeb558b7256a638f7cd4a` (detached)
- `D:/IFX/artifacts/worktrees/cp10-base-compat-base-r2` at `51b8405403800a1c3da3ee93817b954364e2b9b8` (detached)
- `D:/IFX/artifacts/worktrees/cp10-final-base-r2` at `726b38a0cf92a8d4a1d27bdf5ce1d7dc66b0c0b3` (detached)
- `D:/IFX/artifacts/worktrees/cp10-final-base-r3` at `2553f7dd2312e91173f5e1592da6eb02a597cafa` (detached)
- `D:/IFX/artifacts/worktrees/cp10-final-preauth-base-r3` at `aeed75e282270ecc58ef014dc5730274a7ba28c3` (detached)
- `D:/IFX/artifacts/worktrees/cp10-prep-base` at `5ca166e5c0d3d7673a6276890309b676596b9c83` (detached)
- `D:/IFX/artifacts/worktrees/cp10-prep-base-r2` at `c563cb9b92dcc49b7ba5ed475205d916c48dc85b` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-bridge-auth-base` at `e9d6d0d49accb273f5136ab55aad617fedf0492a` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-bridge-base` at `2929bd87ef881fd0458be6d8492d063d5831fa3c` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-relocation-auth-base` at `2dcc81f9c9b560653f07e4c2a4b6b8ac71b463f2` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-relocation-auth-r2` at `eab88251dfc85945fd2f39e4510b157facd9cec5` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-relocation-base` at `8719ae8bd78da6c241b679018649ea0fb9c16279` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-maintenance-relocation-base-r2` at `91f8041fc8e59a0bfe1400cd9198b144ea29c76d` (detached)
- `D:/IFX/artifacts/worktrees/cp11a-trusted-base-test-bridge-auth` at `0b0bf32511ce0313f9436c60a38e71733bfeaabb` (detached)
- `D:/IFX/artifacts/worktrees/cp11c-profile-layout-base` at `409ff738165ade33bd926bd27512363053f086bd` (detached)
- `D:/IFX/artifacts/worktrees/p11-cleanup-policy-compat-proof` at `68afe4e7f8f93cd852665ace9c3c37730532b683` (detached)
- `D:/IFX/artifacts/worktrees/p11-cleanup-prep-base` at `600800ce0a2d19f7e7c890bbb4f51149079eeca6` (detached)
- `D:/IFX/artifacts/worktrees/p11-fresh-win` at `398fb5d98edf05be51fe6f035674ad65297c19d1` (detached)
- `D:/IFX/artifacts/worktrees/p11-inventory-lf-fresh` at `3337b1a0c813aa1858e7c1dad28adcee885b964d` (detached)

## Verification

- 51 local deletion targets were absent after deletion.
- 70 remote-tracking deletion targets were absent after the lease-protected push.
- 216 retained refs were outside the proven deletion set.
- `codex/plan06-closeout` is retained by the snapshot because it is the current, unmerged closeout branch; after this record merges it is deleted as the final operational cleanup.

