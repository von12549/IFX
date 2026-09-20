import hashlib, json, os, re, shutil, sys
import xml.etree.ElementTree as ET

src = sys.argv[1]
dst = sys.argv[2]
run_id = "35055279816"
merge_ref = "5154f9cbbf0dd3102b79b759a6f62e282b4ad197"
out_root = os.path.join(dst, "ci-evidence", f"run-{run_id}")
if os.path.exists(out_root):
    shutil.rmtree(out_root)

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()

def sha_lf(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read().replace(bytes([13, 10]), bytes([10]))).hexdigest()

checks = sorted(os.listdir(src))
archived, trx, skipped = [], [], {}
for check in checks:
    base = os.path.join(src, check)
    for dirpath, _, names in os.walk(base):
        for name in sorted(names):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, base).replace("\\", "/")
            # quality-solution uploads repository-relative paths; normalize to the artifacts/guards/v3-ifx layout
            rel = re.sub(r"^artifacts/guards/v3-ifx/", "", rel)
            ext = os.path.splitext(name)[1].lower()
            if "npm-cache/" in rel or "/publish/" in rel or "/bin/" in rel or "/obj/" in rel:
                skipped[ext + " (cache/publish)"] = skipped.get(ext + " (cache/publish)", 0) + 1
                continue
            if ext == ".trx":
                root = ET.parse(full).getroot()
                ns = {"t": root.tag.split("}")[0].strip("{")}
                counters = root.find("t:ResultSummary/t:Counters", ns)
                outcome = root.find("t:ResultSummary", ns).get("outcome")
                trx.append({
                    "check": check, "file": rel, "sha256": sha(full), "outcome": outcome,
                    "total": int(counters.get("total")), "executed": int(counters.get("executed")),
                    "passed": int(counters.get("passed")), "failed": int(counters.get("failed")),
                })
                continue
            if ext != ".json":
                skipped[ext] = skipped.get(ext, 0) + 1
                continue
            target = os.path.join(out_root, check, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copyfile(full, target)
            archived.append({"check": check, "path": f"ci-evidence/run-{run_id}/{check}/{rel}", "artifactSha256": sha(full), "committedSha256": sha_lf(full), "size": os.path.getsize(full)})

# TRX files uploaded by both solution and assembly jobs are the same solution run; keep unique by hash.
unique_trx = {}
for item in trx:
    unique_trx.setdefault(item["sha256"], item)
trx_items = sorted(unique_trx.values(), key=lambda x: x["file"])
manifest = {
    "formatVersion": 1,
    "run": {"id": int(run_id), "url": f"https://github.com/von12549/IFX/actions/runs/{run_id}", "event": "pull_request",
            "testedCommit": merge_ref, "testedRootTree": "c744f9c128337122bce92574bbacfa2505163c96",
            "baselineCommit": "d2663392db1bacd34dd866917c45b7cdf3ede7cc", "conclusion": "success",
            "artifactExpiry": "2026-12-15T04:21:29Z", "downloadedAt": "2026-09-16"},
    "selection": "All JSON summaries and reports from the 13 check artifacts. Excluded: npm cache, database publish output, build output (bin/obj, including uploaded Domain assemblies), binaries, SQL scripts and TRX files; TRX results are summarized below with their SHA-256.",
    "hashBasis": "artifactSha256 is over the downloaded artifact bytes; committedSha256 is over the same bytes with CRLF normalized to LF, which is what .gitattributes (text eol=lf) stores in Git. Verify committed copies against git cat-file blob content.",
    "excludedByExtension": dict(sorted(skipped.items())),
    "files": sorted(archived, key=lambda x: x["path"]),
    "solutionTestResults": {
        "files": len(trx_items),
        "total": sum(i["total"] for i in trx_items), "executed": sum(i["executed"] for i in trx_items),
        "passed": sum(i["passed"] for i in trx_items), "failed": sum(i["failed"] for i in trx_items),
        "trx": trx_items,
    },
}
with open(os.path.join(dst, "ci-evidence", "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(manifest, indent=2) + "\n")
print(len(archived), "json archived;", len(trx_items), "unique trx;", manifest["solutionTestResults"]["total"], "tests", manifest["solutionTestResults"]["failed"], "failed")
print("excluded", skipped)
