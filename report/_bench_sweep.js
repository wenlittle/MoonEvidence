// Real end-to-end verify timing sweep (js backend), used only to plot an
// honest performance curve for the report. Builds packs of N files with the
// tool's own `create`, then times `verify` (min of 3 runs, node startup incl.).
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const CLI = "_build/js/debug/build/src/cmd/main/main.js";
const SIZES = [500, 1000, 2000, 4000, 8000];
const REPEAT = 3;

function build(n, dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(path.join(dir, "files"), { recursive: true });
  for (let i = 0; i < n; i++) {
    fs.writeFileSync(path.join(dir, "files", `f${i}.txt`), `evidence file ${i}\n`);
  }
  execSync(
    `node --no-warnings ${CLI} create "${dir}" --subject-id bench --subject-type dataset -o "${path.join(dir, "manifest.json")}"`,
    { cwd: ROOT, stdio: "ignore" },
  );
}

function timeVerify(dir) {
  let best = Infinity;
  for (let r = 0; r < REPEAT; r++) {
    const t0 = process.hrtime.bigint();
    try {
      execSync(`node --no-warnings ${CLI} verify "${dir}"`, { cwd: ROOT, stdio: "ignore" });
    } catch (_) { /* exit code may be nonzero; timing still valid */ }
    const t1 = process.hrtime.bigint();
    best = Math.min(best, Number(t1 - t0) / 1e6);
  }
  return best;
}

const rows = [["files", "verify_ms"]];
for (const n of SIZES) {
  const dir = path.join(ROOT, "report", "_bench_tmp", `pack_${n}`);
  build(n, dir);
  const ms = timeVerify(dir);
  console.log(`N=${n}  verify=${ms.toFixed(1)} ms`);
  rows.push([n, ms.toFixed(2)]);
  fs.rmSync(dir, { recursive: true, force: true });
}
fs.writeFileSync(
  path.join(__dirname, "_bench_data.csv"),
  rows.map((r) => r.join(",")).join("\n"),
);
console.log("wrote _bench_data.csv");
