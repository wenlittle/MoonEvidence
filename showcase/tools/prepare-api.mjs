import { copyFile, cp, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const showcaseRoot = resolve(here, "..");
const repoRoot = resolve(showcaseRoot, "..");
const publicRoot = resolve(showcaseRoot, "public");

for (const staleRoot of ["_build", "demo", "examples"]) {
  await rm(resolve(publicRoot, staleRoot), { recursive: true, force: true });
}

const build = spawnSync(
  "moon",
  ["build", "--target", "js", "--release", "src/api"],
  {
    cwd: repoRoot,
    stdio: "inherit",
  },
);

if (build.status !== 0) {
  process.exit(build.status ?? 1);
}

await mkdir(publicRoot, { recursive: true });
await copyFile(
  resolve(repoRoot, "_build/js/release/build/src/api/api.js"),
  resolve(publicRoot, "moon-api.js"),
);

const packsRoot = resolve(publicRoot, "packs");
await rm(packsRoot, { recursive: true, force: true });
await mkdir(packsRoot, { recursive: true });
await cp(resolve(repoRoot, "examples/valid-pack"), resolve(packsRoot, "valid-pack"), {
  recursive: true,
});

console.log("Prepared MoonBit API and evidence-pack assets for the integrated app.");
