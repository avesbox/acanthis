"""Archive a measured run and produce a compact report (Python stdlib only).

Run after the benchmark commands: python report_baseline.py baselines/2026-09-11
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

bench = Path(__file__).resolve().parent
repo = bench.parent
target = bench / (sys.argv[1] if len(sys.argv) > 1 else "baselines/latest")
target.mkdir(parents=True, exist_ok=True)
evidence_path = Path(sys.argv[2]) if len(sys.argv) > 2 else None
evidence = json.loads(evidence_path.read_text(encoding="utf-8-sig")) if evidence_path else {}
if evidence_path and evidence_path.resolve() != (target / "evidence.json").resolve():
    shutil.copy2(evidence_path, target / "evidence.json")
data = {}
for name in ["continuous_jit", "continuous_aot", "continuous_allocations_jit", "continuous_allocations_aot"]:
    source = bench / f"{name}.json"
    data[name] = json.loads(source.read_text(encoding="utf-8"))
    if name == "continuous_allocations_jit" and data[name].get("status") != "allocation_unavailable":
        raise ValueError("Rerun the corrected allocation probe; old accumulated-counter estimates are invalid")
    shutil.copy2(source, target / source.name)

profiles = []
for path in sorted((bench / ".dart_tool").glob("continuous_profile_*.json")):
    profile = json.loads(path.read_text(encoding="utf-8"))
    functions = sorted(profile["functions"], key=lambda f: f.get("exclusiveTicks", 0), reverse=True)
    profiles.append({"case": path.stem.removeprefix("continuous_profile_"),
                     "sample_count": profile["sampleCount"],
                     "sample_period_us": profile["samplePeriod"],
                     "top_exclusive": [{"function": f.get("function", {}).get("name"),
                                        "url": f.get("resolvedUrl"),
                                        "ticks": f.get("exclusiveTicks", 0)} for f in functions[:20]]})
(target / "profiles.json").write_text(json.dumps(profiles, indent=2) + "\n", encoding="utf-8")
sources = sorted([*repo.glob("lib/**/*.dart"), *repo.glob("test/**/*.dart"),
                  *repo.glob("test/fixtures/*.json"), *repo.glob("tool/*.dart"),
                  *repo.glob("doc/**/*.md"), *bench.glob("bin/*.dart"),
                  bench / "report_baseline.py",
                  repo / "pubspec.yaml", repo / "pubspec.lock", bench / "pubspec.yaml", bench / "pubspec.lock"])
manifest = {str(p.relative_to(repo)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
(target / "source-sha256.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True, check=True).stdout.strip()
jit = {row["case"]: row for row in data["continuous_jit"]["rows"]}
aot = {row["case"]: row for row in data["continuous_aot"]["rows"]}
lines = ["# Correctness and performance baseline", "",
         f"SDK: `{data['continuous_jit']['sdk']}`. OS: {data['continuous_jit']['os']}; logical processors: {data['continuous_jit']['processors']}.",
         f"Git base: `{revision}` plus the working-tree sources fingerprinted in `source-sha256.json`.",
         "Raw timing samples, separate lifecycle heap probes, and profile summaries are archived beside this report. Total allocation is unavailable in this baseline.", "",
         evidence.get("environment", "Power plan and machine isolation were not recorded. Treat these measurements as a local baseline with scheduling noise."), "",
         "These are local descriptive measurements, not speed targets or cross-library rankings. Five 100 ms samples per case; construction is excluded from first-validation timing. First validation uses 128 fresh schemas in an already running VM. Process-start observations remain in JSON and are not cold-start confidence intervals.", "",
         "## Lifecycle times (microseconds per operation)", "",
         "| Workload | JIT build | JIT first | JIT warm | AOT build | AOT first | AOT warm |",
         "|---|---:|---:|---:|---:|---:|---:|"]
for name, row in jit.items():
    other = aot[name]
    times = [row[phase]["median_ns"] / 1000 for phase in ["construction", "fresh_schema_first_validation", "warm_validation"]]
    times += [other[phase]["median_ns"] / 1000 for phase in ["construction", "fresh_schema_first_validation", "warm_validation"]]
    lines.append(f"| {name} | " + " | ".join(f"{v:.3f}" for v in times) + " |")
lines += ["", "Warm ranges and all raw samples are in the JSON. Session setup includes initial validation, and live deltas do more work than the full-parse comparator. Zero-delay events measure local scheduling, not network latency.", "",
          "## Allocation limitations", "", data["continuous_allocations_jit"]["reason"], "",
          data["continuous_allocations_aot"].get("reason", "See AOT probe JSON."), "",
          "## CPU sampling and executor decision", ""]
for profile in profiles:
    top = ", ".join(f"`{f['function']}` ({f['ticks']} exclusive ticks)" for f in profile["top_exclusive"][:6])
    lines.append(f"- {profile['case']}: {profile['sample_count']} samples; {top}.")
lines += ["", "Profiles are descriptive samples, not total-allocation measurements or proof that another generated executor would help. No speedup target is introduced. Require equivalent acceptance, output, diagnostics and mutation behavior before pursuing optimization.", "",
          "## Correctness evidence", "", evidence.get("correctness", "No correctness evidence supplied to this report. Run the checks in benchmark/README.md and archive their logs before using this as a correctness baseline."), ""]
(target / "README.md").write_text("\n".join(lines), encoding="utf-8")
print(target / "README.md")
