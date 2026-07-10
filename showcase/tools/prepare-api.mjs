import { copyFile, cp, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const showcaseRoot = resolve(here, "..");
const repoRoot = resolve(showcaseRoot, "..");
const publicRoot = resolve(showcaseRoot, "public");

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

const legacyApiRoot = resolve(publicRoot, "_build/js/release/build/src/api");
await rm(resolve(publicRoot, "_build"), { recursive: true, force: true });
await mkdir(legacyApiRoot, { recursive: true });
await copyFile(
  resolve(repoRoot, "_build/js/release/build/src/api/api.js"),
  resolve(legacyApiRoot, "api.js"),
);

const packsRoot = resolve(publicRoot, "packs");
await rm(packsRoot, { recursive: true, force: true });
await mkdir(packsRoot, { recursive: true });
await cp(resolve(repoRoot, "examples/valid-pack"), resolve(packsRoot, "valid-pack"), {
  recursive: true,
});

const demoRoot = resolve(publicRoot, "demo");
await rm(demoRoot, { recursive: true, force: true });
await cp(resolve(repoRoot, "demo/web"), resolve(demoRoot, "web"), { recursive: true });

const examplesRoot = resolve(publicRoot, "examples");
await rm(examplesRoot, { recursive: true, force: true });
await cp(resolve(repoRoot, "examples/valid-pack"), resolve(examplesRoot, "valid-pack"), {
  recursive: true,
});

console.log("Prepared MoonBit API, observatory assets, and Trust Workbench.");
