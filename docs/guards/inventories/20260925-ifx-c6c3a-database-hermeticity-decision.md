# IFX C6c3a Database hermeticity decision — technical pass, C6c3 pending

Status: REMEDIATION TECHNICAL PASS / C6c3 STILL PENDING. This record closes
the Database clean-commit reproducibility defect found during C6c2. It is not
an independent C6c3 detector-family certification, Xiaolong Feng's accepted
review, a release authorization, or an installed Web UI verdict. Formal Pre
passed before implementation at
artifacts/guards/p10-ifx-c6c3a/formal-pre/summary-pre.json (SHA-256
34afc818a16427d588f701008185685c9c39c89adf745c6959d110c45936db74).

The implementation checkpoint is
9e71da3fd3dffe2bb342b3b75cdd75653b14f88a. Database evidence producer
`ifx-c4b-controlled-v2` and module `ifx-database-evidence` 0.2.0 bind the
source-inventory contract SHA-256
db094bb06d94e333cae348ccf60486359aa972cad8b0462a054bb5e5e451c222.
The contract freezes four roots, four source extensions, ordinal path order,
UTF-8/LF-normalized hashes and generated-directory exclusions. Production
fails unless the complete selected filesystem set equals the selected Git
tracked set; Host independently recomputes and compares the complete locked
projection without executing Git.

Windows repeated inventory reports and a clean native Linux clone in pinned
offline SDK image 10.0.303 produced byte-identical reports (SHA-256
b3088b27f3e6f0f89935ee74fc207e8a1c68064b201953cc8e234b28528fc259).
Each report is bound to the implementation checkpoint and contains 1,152
files, zero `node_modules` entries and source-tree SHA-256
b4b4cc62f4bbbd527aaa50c871e6ce2a01e7c2b9345c746cdd535075374d3a61.
The Linux run used image digest
sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773
with network disabled and did not transport ignored dependency/cache bytes.
Reports are at
artifacts/guards/p10-ifx-c6c3a/final-windows-source-inventory.json,
artifacts/guards/p10-ifx-c6c3a/final-windows-source-inventory-repeat.json and
artifacts/guards/p10-ifx-c6c3a/linux-source-inventory.json.

The full Database producer passed 109 boundary tests and 13 specialized tests
and issued
artifacts/guards/p10-ifx-c4b/database-runs/f17c3a4d8e2b4a91b6d05f7e3c829104/evidence-lock.json
(SHA-256 90a53cbeea7bf994f58302a26353c6d6ca4b2ec1c056fdbcafac1323c9680145).
That lock is bound to the implementation checkpoint, the exact contract,
1,152 source entries and the source-tree hash above. It supersedes the C6c2
Database lock and every pre-remediation lock.

The C4b candidate and published Host Post test passed with the real lock at
artifacts/guards/p10-ifx-c6c3a/final-c4b-real-lock-tests/0e31904de4004f7abad5c00543fce530/summary.json
(SHA-256 a5299c1036f97c9029aa50d2bfc25ae223cb484859ca4aabfc6d05335db44052).
The 17-case matrix retains clean and real-lock passes and proves fail-closed
behavior for selected untracked input, v1 producer identity, wrong contract,
reordered or duplicate inventory entries, wrong normalized hash, deleted
source, false SQL matrix, artifact tamper, stale evidence, missing/zero
scripts, source drift and missing lock. Ignored `node_modules`, `.bin` and
`.vite` injection leaves the clean verdict and source projection unchanged.

The regenerated C6b0 ordinal inventory passed with 37 modules, 83 rules and
79 claims at
artifacts/guards/p10-ifx-c6c3a/final-module-inventory/4260c185a3d64958b86faff92a57642c/ordinal-inventory.json
(SHA-256 6562cf8f84e6d722dcad11c68428e04698b1c48a8279e906e7abc09972c0c77e).
Published V4 1.1.3 remained unchanged: Package SHA-256
9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494
and archive SHA-256
28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e.
The isolated IFX Package positive and six negative regression cases passed at
artifacts/guards/v3-ifx-package-test-4f2d2948117248e985f3bb0d02a81934.
Exact committed Formal Diff for the declared remediation paths is the
post-commit check under artifacts/guards/p10-ifx-c6c3a/formal-diff.

C6c3 must now regenerate every short-lived detector lock and the final bundle
from a fresh source-bound commit, then execute the full independent Windows
and native Linux clean/deliberate-violation/missing-input/zero-match matrix.
No C6c2 candidate, lock or transported Database input set may be reused. C6c,
C6d and C6e remain unpassed; G04 remains PRE-READY and P10.2/P10.3 plus V3
retirement remain out of scope.
